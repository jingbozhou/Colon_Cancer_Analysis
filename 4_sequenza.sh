#!/bin/bash
#SBATCH --job-name              4_sequenza
#SBATCH --partition             serial-normal
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       4
#SBATCH --time                  120:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                ./logs/sequenza.%j.out
#SBATCH --error                 ./logs/sequenza.%j.err
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

SEQUENZA=/home/jingbozhou/anaconda3/envs/REnv/bin/sequenza-utils
SEQUENZAR=${working_dir}/sequenza-result.R
SEQUENZAP=${working_dir}/get_gistic_seg.py

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
      
      conda activate REnv
      
      if [ ! -f ${working_dir}/hg38.gc50Base.txt.gz ];then
        echo "Get hg38.gc50Base.txt.gz"
        ${SEQUENZA} gc_wiggle -f ${GENOME} -w 50 -o - | gzip > ${working_dir}/hg38.gc50Base.txt.gz
      fi
#####################################################
################ Run Sequenza #######################
#####################################################
      echo "${sample_name} start at `date`"

      start_time=$(date +%s.%N)

      mkdir ${sample_name}

      ${SEQUENZA} bam2seqz -gc ${working_dir}/hg38.gc50Base.txt.gz \
      -F ${GENOME} -n ${control_file} -t ${tumor_file} | gzip > ./${sample_name}/${sample_name}_big.seqz.gz

      ${SEQUENZA} seqz_binning -w 50 \
      -s ./${sample_name}/${sample_name}_big.seqz.gz | gzip > ./${sample_name}/${sample_name}_small.seqz.gz

      Rscript ${SEQUENZAR} ./${sample_name}_small.seqz.gz ${sample_name} ${working_dir}/${sample_name}/
      
      python ${SEQUENZAP} ${working_dir}/${sample_name}/ ${sample_name}
      
      cnvkit.py import-seg ${working_dir}/${sample_name}/${sample_name}_seg.in -d ${working_dir}/${sample_name}/

      conda deactivate
      
      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for run sequenza: %.3f seconds" ${dur}
      echo
    fi
  fi
  i=$((i+1))

done

echo "ALL DONE!"
