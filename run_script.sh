#!/bin/bash
#SBATCH -p cclake
#SBATCH --nodes=1
#SBATCH --tasks-per-node=64
#SBATCH --cpus-per-task=2
#SBATCH --time=1-00:00:00
#SBATCH --job-name="run_r_script"
#SBATCH --output="run_r_script.out"
#SBATCH --error="run_r_script.err"

module load r/4.2.2-gcc-11.3.1

cd /bg/data/kaza_elephant/Downscale_SAfrica/scripts

Rscript SSP_RCP_raster_crop_&_downscale_2.R
