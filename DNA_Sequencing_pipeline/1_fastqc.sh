#!/bin/bash
#SBATCH --job-name              fastqc
#SBATCH --partition             serial-normal
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       4
#SBATCH --time                  24:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                fastqc.%j.out
#SBATCH --error                 fastqc.%j.err
#SBATCH --mail-type             ALL
#SBATCH --mail-user             jingbozhou@um.edu.mo

if [ $# != 3 ];then
    echo "USAGE: file.sh <working_dir> <find_file> <suffix_name>"
    exit
fi

# example : sbatch 1_fastqc.sh /home/jingbozhou/Project/tryRNAseq/1_fastqc /home/jingbozhou/Project/tryRNAseq/rawData/rawdata2 fq.gz

source /etc/profile
source /etc/profile.d/modules.sh

#Adding modules
# module add openmpi/4.0.0/gcc/4.8.5

ulimit -s unlimited

#Your program starts here
source /home/jingbozhou/anaconda3/etc/profile.d/conda.sh
conda activate seqqc

# Configure
working_dir=$1
find_file=$2
suffix_name=$3

# Change to the working directory
cd ${working_dir}

bin_fastqc="fastqc"
bin_multiqc="multiqc"


for file_name in `find ${find_file} -name "*.${suffix_name}"`
do
    echo "fastqc for ${file_name} start at `date`"
    
    ${bin_fastqc} --threads 4 -o ./fqcRes/ --noextract ${file_name}

    echo "fastqc for ${file_name} end at `date`"

done

${bin_multiqc} -n raw_res ./fqcRes/

echo "ALL DONE!"
