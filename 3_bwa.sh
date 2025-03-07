#!/bin/bash
#SBATCH --job-name              3_bwa
#SBATCH --partition             serial-normal
#SBATCH --nodes                 1
#SBATCH --ntasks-per-node       4
#SBATCH --time                  120:00:00
#SBATCH --mem                   MaxMemPerNode
#SBATCH --output                ./logs/bwa.%j.out
#SBATCH --error                 ./logs/bwa.%j.err
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
conda activate wes


# Configure
working_dir=$1
in_name_file=$2
number_1=$3
number_2=$4

# Change to the working directory
cd ${working_dir}

GENOME=/home/jingbozhou/Project/databases/GATK/hg38/genome/Homo_sapiens_assembly38.fasta
INDEX=/home/jingbozhou/Project/databases/GATK/hg38/bwaIndex/Homo_sapiens_assembly38.fasta.64
#dbSNP=/home/jingbozhou/Project/databases/GATK/hg38/annotation/dbsnp_146.hg38.vcf.gz
#dbSNP=/home/jingbozhou/Project/databases/GATK/hg38/annotation/Homo_sapiens_assembly38.dbsnp138.vcf
kgSNP=/home/jingbozhou/Project/databases/GATK/hg38/annotation/1000G_phase1.snps.high_confidence.hg38.vcf.gz
kgINDEL=/home/jingbozhou/Project/databases/GATK/hg38/annotation/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
GATK=/home/jingbozhou/anaconda3/envs/seqtools/bin/gatk
BWA=/home/jingbozhou/anaconda3/envs/wes/bin/bwa
SAMTOOLS=/home/jingbozhou/anaconda3/envs/wes/bin/samtools
SAMBAMBA=/home/jingbozhou/anaconda3/envs/wes/bin/sambamba
POLTBAMSTATS=/home/jingbozhou/anaconda3/envs/wes/bin/plot-bamstats

#####################################################
################# Read Configure ####################
#####################################################
echo "Working dir:${working_dir} Input file>:${in_name_file} <number_1>:${number_1} <number_2>${number_2}"

cat ${in_name_file} | while read line
do
  arr=(${line})
  sample_name=${arr[0]}
  fq_1=${arr[1]}
  fq_2=${arr[2]}

  if((i%${number_1}==${number_2}));then
    if [ ! -f ./recal/${sample_name}_recal.bam ];then

#####################################################
################ Step 1 : Alignment #################
#####################################################
      echo "${sample_name} start at `date`"
      start_time=$(date +%s.%N)
      
      ${BWA} mem -t 4 -M -R "@RG\tID:${sample_name}\tSM:${sample_name}\tLB:WES\tPL:Illumina" ${INDEX} ${fq_1} ${fq_2} 1>${sample_name}.sam
      
      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc) 
      printf "Execution time for BWA (Alignment): %.3f seconds" ${dur} 
      echo 

####################################################
############### Step 2: Sort and Index #############
####################################################
      start_time=$(date +%s.%N)
      
      ${GATK} --java-options "-Xmx25G -Djava.io.tmpdir=./" SortSam \
      -SO coordinate  \
      -I ${sample_name}.sam \
      -O ${sample_name}.bam
      ${SAMTOOLS} index -@ 4 ${sample_name}.bam
      
      rm ${sample_name}.sam

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for SortSam (Sort and Index): %.3f seconds" ${dur}
      echo
      

####################################################
###### Step 3: multiple filtering for bam files ####
####################################################

      ### MarkDuplicates
      start_time=$(date +%s.%N)
    
      ${SAMBAMBA} markdup -p -r -t 4 --overflow-list-size 600000 --tmpdir='./' ${sample_name}.bam ${sample_name}_rmd.bam
    
      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for sambamba (MarkDuplicates): %.6f seconds" ${dur}
      echo
    
      rm ${sample_name}.bam
      rm ${sample_name}.bam.bai

      ### FixMateInfo
      start_time=$(date +%s.%N)

      ${GATK} --java-options "-Xmx25G -Djava.io.tmpdir=./" FixMateInformation \
      -I ${sample_name}_rmd.bam \
      -O ${sample_name}_marked_fixed.bam \
      -SO coordinate
      ${SAMTOOLS} index -@ 4 ${sample_name}_marked_fixed.bam

      rm ${sample_name}_rmd.bam
      rm ${sample_name}_rmd.bam.bai
      
      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for FixMateInfo  : %.3f seconds" ${dur}
      echo

####################################################
################### Step 4: recal ##################
####################################################
      start_time=$(date +%s.%N)

      bam=${sample_name}_marked_fixed.bam
      ${GATK} --java-options "-Xmx25G -Djava.io.tmpdir=./" BaseRecalibrator \
      -I ${bam} \
      -R ${GENOME} \
      --output ${sample_name}_recal.table \
      --known-sites ${kgSNP} --known-sites ${kgINDEL}
      ${GATK} --java-options "-Xmx25G -Djava.io.tmpdir=./" ApplyBQSR \
      -I ${bam} \
      -R ${GENOME} \
      --output ${sample_name}_recal.bam -bqsr ${sample_name}_recal.table
      ${SAMTOOLS} index -@ 4 ${sample_name}_recal.bam

      rm ${sample_name}_marked_fixed.bam
      rm ${sample_name}_marked_fixed.bam.bai
      rm ${sample_name}_recal.bai
      mv ${sample_name}_recal.bam ./recal/
      mv ${sample_name}_recal.bam.bai ./recal/
      mv ${sample_name}_recal.table ./tables/
      mv *.config ./logs/

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc)
      printf "Execution time for recal : %.3f seconds" ${dur}
      echo

#####################################################
################ Step 5: Basic Statistics ###########
#####################################################
      start_time=$(date +%s.%N)

      ${SAMTOOLS} flagstat -@ 4 ./recal/${sample_name}_recal.bam > ./stats/${sample_name}.alignment.flagstat
      ${SAMTOOLS} stats -@ 4 ./recal/${sample_name}_recal.bam > ./stats/${sample_name}.alignment.stat
      #${POLTBAMSTATS} -p ./stats/${sample_name}_BC ./stats/${sample_name}.alignment.stat

      dur=$(echo "$(date +%s.%N) - ${start_time}" | bc) 
      printf "Execution time for Basic Statistics : %.3f seconds" ${dur} 
      echo 

      echo "${sample_name} finish at `date`"
    fi
  fi
  i=$((i+1))
done

echo "ALL DONE!"

