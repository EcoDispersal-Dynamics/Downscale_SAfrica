#!/bin/tcsh

# Submit two SLURM arrays for ESA null model 500m with explicit node split:
#  - Regions 1-4 on nodeA
#  - Regions 5-8 on nodeB
# Usage:
#   submit_null500_split2.csh <SSP1_RCP26|SSP5_RCP85> <nodeA> <nodeB> [jobs_per_node]
# Example:
#   csh submit_null500_split2.csh SSP1_RCP26 genius01 genius02 4

if ($#argv < 3 || $#argv > 4) then
    echo "Usage: $0 <SSP1_RCP26|SSP5_RCP85> <nodeA> <nodeB> [jobs_per_node]"
    exit 1
endif

set scenario = "$1"
set nodeA = "$2"
set nodeB = "$3"
set jobs_per_node = 4
if ($#argv == 4) then
    set jobs_per_node = "$4"
endif

if ("$scenario" != "SSP1_RCP26" && "$scenario" != "SSP5_RCP85") then
    echo "ERROR: Scenario must be SSP1_RCP26 or SSP5_RCP85"
    exit 1
endif

set base_dir = "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/null_mod_500_with_ref_cells_water"
set log_dir = "$base_dir/slurm_logs/${scenario}"
set slurm_dir = "$base_dir/slurm_scripts"
mkdir -p $log_dir $slurm_dir

set job_name_base = "esa_null500_${scenario}"
set wrapper_R = "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/null_mod_500_with_ref_cells_water/run_downscale_null_mod_esa_with_ref_cells_water_500m_wrapper_node.R"

# Script for nodeA (regions 1-4)
set slurm_a = "$slurm_dir/${scenario}_${nodeA}_1-4.slurm"
cat > $slurm_a <<EOF
#!/bin/tcsh
#SBATCH --job-name=${job_name_base}_A
#SBATCH --output=${log_dir}/${job_name_base}_A_%A_%a.out
#SBATCH --error=${log_dir}/${job_name_base}_A_%A_%a.err
#SBATCH --partition=genius
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --time=48:00:00
#SBATCH --mem=50G
#SBATCH --array=1-4%${jobs_per_node}
#SBATCH --nodelist=${nodeA}

module purge
module load proj/8.2.1-gcc-11.3.1
module load geos/3.9.1-gcc-11.3.1
module load gdal/3.5.3-gcc-11.3.1
module load r/4.2.2-gcc-11.3.1

echo "SLURM_JOB_ID: $SLURM_JOB_ID"
echo "Scenario: ${scenario}"
echo "Node list: $SLURM_NODELIST"
echo "Array task: $SLURM_ARRAY_TASK_ID"

set region = $SLURM_ARRAY_TASK_ID

echo "Launching 500m null model downscaling for region $region"
Rscript ${wrapper_R} ${scenario} $region
EOF
chmod +x $slurm_a

# Script for nodeB (regions 5-8)
set slurm_b = "$slurm_dir/${scenario}_${nodeB}_5-8.slurm"
cat > $slurm_b <<EOF
#!/bin/tcsh
#SBATCH --job-name=${job_name_base}_B
#SBATCH --output=${log_dir}/${job_name_base}_B_%A_%a.out
#SBATCH --error=${log_dir}/${job_name_base}_B_%A_%a.err
#SBATCH --partition=genius
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --time=48:00:00
#SBATCH --mem=50G
#SBATCH --array=5-8%${jobs_per_node}
#SBATCH --nodelist=${nodeB}

module purge
module load proj/8.2.1-gcc-11.3.1
module load geos/3.9.1-gcc-11.3.1
module load gdal/3.5.3-gcc-11.3.1
module load r/4.2.2-gcc-11.3.1

echo "SLURM_JOB_ID: $SLURM_JOB_ID"
echo "Scenario: ${scenario}"
echo "Node list: $SLURM_NODELIST"
echo "Array task: $SLURM_ARRAY_TASK_ID"

set region = $SLURM_ARRAY_TASK_ID

echo "Launching 500m null model downscaling for region $region"
Rscript ${wrapper_R} ${scenario} $region
EOF
chmod +x $slurm_b

set outA = `sbatch $slurm_a`
set outB = `sbatch $slurm_b`
set jobidA = `echo "$outA" | awk '{print $4}'`
set jobidB = `echo "$outB" | awk '{print $4}'`

echo "Submitted: ${scenario} regions 1-4 on ${nodeA} as JobID ${jobidA}"
echo "Submitted: ${scenario} regions 5-8 on ${nodeB} as JobID ${jobidB}"
