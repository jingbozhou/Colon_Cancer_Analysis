#!/bin/bash
#SBATCH --job-name              5_strelka
#SBATCH --partition             serial-normal
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       4
#SBATCH --time                  120:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                ./logs/strelka.%j.out
#SBATCH --error                 ./logs/strelka.%j.err
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
BEDGZ=/home/jingbozhou/Project/databases/UCSC/hg38.exon.bed.gz

STRELKA=/home/jingbozhou/Project/databases/strelka-2.9.2.centos6_x86_64
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
################ Run Strelka2  ######################
#####################################################
      echo "${sample_name} start at `date`"

      start_time=$(date +%s.%N)

      mkdir ${sample_name}
      
      # configuration
      ${STRELKA}/bin/configureStrelkaSomaticWorkflow.py \
      --normalBam ${control_file} \
      --tumorBam ${tumor_file} \
      --referenceFasta ${GENOME} \
      --runDir ./${sample_name} \
      --exome \
      --reportEVSFeatures \
      --outputCallableRegions \
      --callRegions ${BEDGZ}

      # execution on a single local machine with parallel jobs
      ./${sample_name}/runWorkflow.py -m local -j 4

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for Somatic calling (Strelka2): %.3f seconds" ${dur}
      echo

########################################################
######## Strelka2: merge snv and indel result###########
########################################################
      start_time=$(date +%s.%N)

      conda activate wes

      bcftools concat -a ./${sample_name}/results/variants/somatic.snvs.vcf.gz ./${sample_name}/results/variants/somatic.indels.vcf.gz \
                      -o ./${sample_name}/${sample_name}_strelka.vcf

      grep -E "^#|PASS" ./${sample_name}/${sample_name}_strelka.vcf > ./${sample_name}/${sample_name}_strelka_pass.vcf

      conda deactivate

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)

      printf "Execution time for merge snv and indel result (Strelka2): %.3f seconds" ${dur}
      echo

#####################################################
################ VCF2MAF ############################
#####################################################
      conda activate seqtools

      start_time=$(date +%s.%N)

      ${VCF2MAF} --input-vcf ./${sample_name}/${sample_name}_strelka_pass.vcf --output-maf ./${sample_name}/${sample_name}_strelka.maf --vcf-tumor-id TUMOR --vcf-normal-id NORMAL --tumor-id ${sample_name} --normal-id ${sample_name}_normal --ncbi-build GRCh38 --cache-version 104 --ref-fasta ${GENOME} --vep-forks 4 --vep-data /home/jingbozhou/.vep --vep-path ${VEP} --vep-overwrite
    
      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for VCF2MAF: %.3f seconds" ${dur}

      conda deactivate
      echo

    fi
  fi
  i=$((i+1))

done

echo "ALL DONE!"
