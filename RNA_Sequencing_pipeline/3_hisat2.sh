#!/bin/bash
#SBATCH --job-name              3_hisat2
#SBATCH --partition             fhs-fast
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       48
#SBATCH --time                  120:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                ./logs/hisat2.%j.out
#SBATCH --error                 ./logs/hisat2.%j.err
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

REFERENCE=/home/jingbozhou/Project/databases/HISAT2/grch38/genome

HISAT2="hisat2"
GATK=/home/jingbozhou/anaconda3/envs/seqtools/bin/gatk
SAMTOOLS="samtools"
#####################################################
################# Read Configure ####################
#####################################################
echo "Working dir:${working_dir} <Input file>:${in_name_file} <number_1>:${number_1} <number_2>${number_2}"

cat ${in_name_file} | while read line
do
  arr=(${line})
  sample_name=${arr[0]}
  fq_1=${arr[1]}
  fq_2=${arr[2]}

  if((i%${number_1}==${number_2}));then
    if [ ! -f ./bams/${sample_name}.bam ];then

#####################################################
################ Step 1: Alignment ##################
#####################################################
      echo "${sample_name} start at `date`"
      start_time=$(date +%s.%N)
      
      conda activate RNASeq
      ${HISAT2} -p 48 -x ${REFERENCE} -1 ${fq_1} -2 ${fq_2} -S ./bams/${sample_name}.sam
      conda deactivate
      
      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc) 
      printf "Execution time for hisat2 (Alignment): %.3f seconds" ${dur} 
      echo

####################################################
############### Step 2: Sort and Index #############
####################################################
      start_time=$(date +%s.%N)
      
      conda activate wes
      ${GATK} --java-options "-Xmx25G -Djava.io.tmpdir=./" SortSam \
      -SO coordinate  \
      -I ./bams/${sample_name}.sam \
      -O ./bams/${sample_name}.bam
      
      ${SAMTOOLS} index -@ 48 ./bams/${sample_name}.bam
      # Basic Statistics
      ${SAMTOOLS} flagstat -@ 48 ./bams/${sample_name}.bam > ./stats/${sample_name}.alignment.flagstat
      ${SAMTOOLS} stats -@ 48 ./bams/${sample_name}.bam > ./stats/${sample_name}.alignment.stat
      rm ./bams/${sample_name}.sam
      conda deactivate

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for SortSam (Sort and Index): %.3f seconds" ${dur}
      echo
      
      echo "${sample_name} finish at `date`"
    fi
  fi
  i=$((i+1))
done

echo "ALL DONE!"
