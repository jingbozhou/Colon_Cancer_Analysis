#!/bin/bash
#SBATCH --job-name              trim
#SBATCH --partition             serial-normal
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       4
#SBATCH --time                  120:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                ./logs/trim.%j.out
#SBATCH --error                 ./logs/trim.%j.err
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
#mkdir -p cleanFq

source /home/jingbozhou/anaconda3/etc/profile.d/conda.sh
conda activate seqqc

# Configure
working_dir=$1
in_name_file=$2
number_1=$3
number_2=$4

# Change to the working directory
cd ${working_dir}

bin_trim_galore="trim_galore"

echo "Working dir:${working_dir} <Input file>:${in_name_file} <number_1>:${number_1} <number_2>:${number_2}"

cat ${in_name_file} | while read line
do
  arr=(${line})
  sample_name=${arr[0]}
  fq_1=${arr[1]}
  fq_2=${arr[2]}

  if((i%${number_1}==${number_2}));then
    if [ ! -f ./cleanFq/${sample_name}_2_val_2.fq.gz ];then
      echo "start trim_galore for $sample_name" `date`

      ${bin_trim_galore} --quality 25 --gzip --phred33 --paired --length 50 -e 0.1 --stringency 3 --cores 4 -o ./cleanFq/ ${fq_1} ${fq_2}

      echo "end trim_galore for $sample_name" `date`

    fi
  fi
  i=$((i+1))
done

echo "ALL DONE!"
