#!/bin/bash
#SBATCH --job-name              4_cnvkit
#SBATCH --partition             serial-short
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       4
#SBATCH --time                  24:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                ./logs/cnvkit.%j.out
#SBATCH --error                 ./logs/cnvkit.%j.err
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
conda activate REnv

# Configure
working_dir=$1
in_name_file=$2
number_1=$3
number_2=$4

# Change to the working directory
cd ${working_dir}

GENOME=/home/jingbozhou/Project/databases/GATK/hg38/genome/Homo_sapiens_assembly38.fasta
TARGET=/home/jingbozhou/Project/databases/UCSC/hg38.exon.bed
ACCESS=/home/jingbozhou/Project/databases/UCSC/access-5kb-mappable.hg38.bed

#####################################################
################# Read Configure ####################
#####################################################
echo "Working dir:${working_dir} Input file>:${in_name_file} <number_1>:${number_1} <number_2>${number_2}"

cat ${in_name_file} | while read line
do
  arr=(${line})
  sample_name=${arr[0]}
  tumor_file=${arr[1]}
  control_file=${arr[2]}

  if((i%${number_1}==${number_2}));then
    if [ ! -d ./${sample_name} ];then
      echo "${sample_name} start at `date`"
      start_time=$(date +%s.%N)
    
      mkdir ${sample_name}
      cp ${tumor_file} ./${sample_name}/${sample_name}.bam
      cp ${tumor_file}.bai ./${sample_name}/${sample_name}.bam.bai

      cp ${control_file} ./${sample_name}/${sample_name}_control.bam
      cp ${control_file}.bai ./${sample_name}/${sample_name}_control.bam.bai

      cnvkit.py batch ./${sample_name}/${sample_name}.bam --normal ./${sample_name}/${sample_name}_control.bam \
      --targets ${TARGET} --fasta ${GENOME} --access ${ACCESS} \
      --output-reference ./${sample_name}/${sample_name}.reference.cnn --output-dir ${sample_name} --processes 4 \
      --diagram --scatter

      cnvkit.py export seg ./${sample_name}/${sample_name}.cns -o ./${sample_name}/${sample_name}_raw.seg

      grep -vw "chrM" ./${sample_name}/${sample_name}_raw.seg > ./${sample_name}/${sample_name}_rmM.seg

      rm ./${sample_name}/${sample_name}.bam
      rm ./${sample_name}/${sample_name}.bam.bai

      rm ./${sample_name}/${sample_name}_control.bam
      rm ./${sample_name}/${sample_name}_control.bam.bai

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for cnvkit: %.3f seconds" ${dur}
      echo
      echo "${sample_name} finish at `date`"
    
    fi
  fi
  i=$((i+1))
done

echo "ALL DONE!"


