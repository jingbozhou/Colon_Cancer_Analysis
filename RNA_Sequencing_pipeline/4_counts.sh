#!/bin/bash
#SBATCH --job-name              4_counts
#SBATCH --partition             fhs-fast
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       48
#SBATCH --time                  120:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                ./logs/counts.%j.out
#SBATCH --error                 ./logs/counts.%j.err
#SBATCH --mail-type             FAIL
#SBATCH --mail-user             jingbozhou@um.edu.mo

source /etc/profile
source /etc/profile.d/modules.sh

#Adding modules
# module add openmpi/4.0.0/gcc/4.8.5

ulimit -s unlimited

#Your program starts here
# Activate conda environment
source /home/jingbozhou/anaconda3/etc/profile.d/conda.sh
conda activate RNASeq


# Configure
working_dir=$1
bam_file=$2

# Change to the working directory
cd ${working_dir}

hg38_gtf=/home/jingbozhou/Project/databases/vep/Homo_sapiens.GRCh38.84.gtf
bin_featurecounts="featureCounts"

#####################################################
################# featureCounts #####################
#####################################################
echo "featureCounts start at `date`"
start_time=$(date +%s.%N)
      
${bin_featurecounts} -a ${hg38_gtf} -F GTF -p -g gene_name -t exon -o ./alloldSam_counts -T 48 ${bam_file}/*.bam
      
dur=$(echo "$(date +%s.%N) - ${start_time}" | bc) 
printf "Execution time for featureCounts: %.3f seconds" ${dur} 
echo

