#!/bin/bash
#SBATCH --job-name              5_mutect
#SBATCH --partition             serial-normal
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       4
#SBATCH --time                  120:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                ./logs/mutect.%j.out
#SBATCH --error                 ./logs/mutect.%j.err
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
################ Run Mutect2 ########################
#####################################################
      echo "${sample_name} start at `date`"
    
      conda activate seqtools

      start_time=$(date +%s.%N)

      mkdir ${sample_name}
      # Get tumor name
      ${GATK} GetSampleName -I ${tumor_file} -O ./${sample_name}/${sample_name}_tumor_bam_name
      tumor_bam_name=`cat ./${sample_name}/${sample_name}_tumor_bam_name`
      rm ./${sample_name}/${sample_name}_tumor_bam_name
    
      ${GATK} GetSampleName -I ${control_file} -O ./${sample_name}/${sample_name}_nom_bam_name
      normal_bam_name=`cat ./${sample_name}/${sample_name}_nom_bam_name`
      rm ./${sample_name}/${sample_name}_nom_bam_name

      ${GATK} --java-options "-Xmx25G -Djava.io.tmpdir=./" Mutect2 \
      -R ${GENOME} \
      -I ${tumor_file} -tumor ${tumor_bam_name} \
      -I ${control_file} -normal ${normal_bam_name} \
      -O ./${sample_name}/${sample_name}_mutect2.vcf

      ${GATK} --java-options "-Xmx25G -Djava.io.tmpdir=./" FilterMutectCalls \
      -R ${GENOME} \
      -V ./${sample_name}/${sample_name}_mutect2.vcf \
      --filtering-stats ./${sample_name}/${sample_name}_mutect2.vcf.stats \
      -O ./${sample_name}/${sample_name}_mutect2_somatic.vcf
    
      grep -E "^#|PASS" ./${sample_name}/${sample_name}_mutect2_somatic.vcf > ./${sample_name}/${sample_name}_mutect2_pass.vcf

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for Find snv (Mutect2 and FilterMutectCalls): %.3f seconds" ${dur}
      echo
      
#####################################################
################ VCF2MAF ############################
#####################################################
      start_time=$(date +%s.%N)

      ${VCF2MAF} --input-vcf ./${sample_name}/${sample_name}_mutect2_pass.vcf --output-maf ./${sample_name}/${sample_name}_mutect2.maf --vcf-tumor-id ${tumor_bam_name} --vcf-normal-id ${normal_bam_name} --tumor-id ${sample_name} --normal-id ${sample_name}_normal --ncbi-build GRCh38 --cache-version 104 --ref-fasta ${GENOME} --vep-forks 4 --vep-data /home/jingbozhou/.vep --vep-path ${VEP} --vep-overwrite

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for VCF2MAF: %.3f seconds" ${dur}

      conda deactivate
      echo
    fi
  fi
  i=$((i+1))

done

echo "ALL DONE!"
