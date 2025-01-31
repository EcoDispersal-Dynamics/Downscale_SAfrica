#!/bin/tcsh
#SBATCH -p milan
#SBATCH --nodes=2
#SBATCH --tasks-per-node=32
#SBATCH --cpus-per-task=2
#SBATCH --time=1-00:00:00
#SBATCH --job-name="run_r_script"
#SBATCH --output="run_r_script.out"
#SBATCH --error="run_r_script.err"
#SBATCH --mail-user=markus.shiweda@kit.edu
#SBATCH --mail-type=ALL

set rundir = /bg/data/kaza_elephant/Downscale_SAfrica
module purge
module load r/4.2.2-gcc-11.3.1

cd ${rundir}
Rscript SSP_RCP_raster_crop_&_downscale_2.R
set exitcode = $?
cd -
exit ${exitcode}
