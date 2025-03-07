#!/bin/bash
#SBATCH --job-name              5_lancet
#SBATCH --partition             fhs-highmem
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       32
#SBATCH --time                  240:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                ./logs/lancet.%j.out
#SBATCH --error                 ./logs/lancet.%j.err
#SBATCH --mail-type             FAIL
#SBATCH --mail-user             jingbozhou@um.edu.mo

if [ $# != 4 ];then
    echo "USAGE: file.sh <working_dir> <in_name_file> <number_1> <number_2>"
    exit
fi
# example : sbatch trim.sh ./ config 1 0
# example : sbatch trim.sh ./ config 3 0
# example : sbatch trim.sh ./ config 3 1
# example : sbatch trim.sh ./ config 3 2

source /etc/profile
source /etc/profile.d/modules.sh

#Adding modules
# module add openmpi/4.0.0/gcc/4.8.5

ulimit -s unlimited

#Your program starts here
# Activate conda environment
source /home/jingbozhou/anaconda3/etc/profile.d/conda.sh


# Configure
working_dir=$1
in_name_file=$2
number_1=$3
number_2=$4

# Change to the working directory
cd ${working_dir}

GENOME=/home/jingbozhou/Project/databases/GATK/hg38/genome/Homo_sapiens_assembly38.fasta
BED=/home/jingbozhou/Project/databases/UCSC/hg38.exon.bed

LANCET=/home/jingbozhou/Project/databases/lancet/lancet
GATK=/home/jingbozhou/anaconda3/envs/seqtools/bin/gatk
VEP=/home/jingbozhou/anaconda3/envs/seqtools/bin/
VCF2MAF=/home/jingbozhou/anaconda3/envs/seqtools/bin/vcf2maf.pl

#####################################################
################# Read Configure ####################
#####################################################
echo "Working dir:${working_dir} <Input file>:${in_name_file} <number_1>:${number_1} <number_2>${number_2}"

cat ${in_name_file} | while read line
do
  arr=(${line})
  sample_name=${arr[0]}
  tumor_file=${arr[1]}
  control_file=${arr[2]}

  if((i%${number_1}==${number_2}));then
    if [ ! -d ./${sample_name} ];then
#####################################################
################ Run Lancet #########################
#####################################################
      echo "${sample_name} start at `date`"

      start_time=$(date +%s.%N)

      mkdir ${sample_name}

      ${LANCET} --tumor ${tumor_file} --normal ${control_file} --ref ${GENOME} --bed ${BED} --num-threads 32 > ./${sample_name}/${sample_name}_lancet.vcf

      grep -E "^#|PASS" ./${sample_name}/${sample_name}_lancet.vcf > ./${sample_name}/${sample_name}_lancet_pass.vcf

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for Find SNV (Lancet): %.3f seconds" ${dur}
      echo

#####################################################
################ VCF2MAF ############################
#####################################################
      conda activate seqtools

      start_time=$(date +%s.%N)

      ${VCF2MAF} --input-vcf ./${sample_name}/${sample_name}_lancet_pass.vcf --output-maf ./${sample_name}/${sample_name}_lancet.maf --tumor-id ${sample_name} --normal-id ${sample_name}_normal --ncbi-build GRCh38 --cache-version 104 --ref-fasta ${GENOME} --vep-forks 32 --vep-data /home/jingbozhou/.vep --vep-path ${VEP} --vep-overwrite
    
      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for VCF2MAF: %.3f seconds" ${dur}

      conda deactivate
      echo

    fi
  fi
  i=$((i+1))

done

echo "ALL DONE!"
