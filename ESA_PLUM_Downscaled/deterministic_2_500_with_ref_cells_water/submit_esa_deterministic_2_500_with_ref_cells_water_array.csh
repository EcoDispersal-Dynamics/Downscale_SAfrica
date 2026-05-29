#!/bin/tcsh

# Submit 8-region ESA deterministic_2 500m (assign_ref_cells=TRUE, water reference) runs as a SLURM array
# Usage: submit_esa_deterministic_2_500_with_ref_cells_water_array.csh <SSP1_RCP26|SSP5_RCP85> [genius|rogp|fat] [nodelist]

if ($#argv < 1 || $#argv > 3) then
    echo "Usage: $0 <SSP1_RCP26|SSP5_RCP85> [genius|rogp|fat] [nodelist]"
    exit 1
endif

set scenario = "$1"
if ("$scenario" != "SSP1_RCP26" && "$scenario" != "SSP5_RCP85") then
    echo "ERROR: Scenario must be SSP1_RCP26 or SSP5_RCP85"
    exit 1
endif

set partition = "genius"
if ($#argv >= 2) then
    set partition = "$2"
endif

if ("$partition" != "genius" && "$partition" != "rogp" && "$partition" != "fat") then
    echo "ERROR: Partition must be genius, rogp, or fat"
    exit 1
endif

set nodelist = ""
if ($#argv == 3) then
    set nodelist = "$3"
else
    if ("$partition" == "genius") then
        set nodelist = "genius02,genius06"
    else if ("$partition" == "rogp") then
        set nodelist = "rogp01,rogp02"
    else
        set nodelist = "fat02"
    endif
endif

if ("$nodelist" == "") then
    echo "ERROR: Unable to determine nodelist. Provide explicitly as second argument."
    exit 1
endif

set base_dir = "/bg/data/kaza_elephant/Downscale_SAfrica"
set module_dir = "$base_dir/ESA_PLUM_Downscaled/deterministic_2_500_with_ref_cells_water"
set script   = "$module_dir/run_downscale_deterministic_2_esa_with_ref_cells_water_500m.R"
set logs_dir = "$module_dir/slurm_logs"
set job_tmp_root = "$module_dir/temp_r_files/slurm_${scenario}"
mkdir -p $logs_dir
mkdir -p $job_tmp_root

set script_node = "$module_dir/run_deterministic_2_esa_node_with_ref_cells_water_500m.csh"
set out = `sbatch \
    --job-name=esa_det500_water \
    --partition=$partition \
    --nodes=1 \
    --ntasks=1 \
    --cpus-per-task=8 \
    --mem=16G \
    --time=3-00:00:00 \
    --nodelist=$nodelist \
    --array=1-8 \
    --output=$logs_dir/%x_%A_%a.out \
    --error=$logs_dir/%x_%A_%a.err \
    --export=ALL,SCENARIO=$scenario,SCRIPT=$script_node,TMPDIR=$job_tmp_root,TMP=$job_tmp_root,TEMP=$job_tmp_root \
    --wrap 'module purge; module load r/4.2.2-gcc-11.3.1; tcsh $SCRIPT $SCENARIO $SLURM_ARRAY_TASK_ID'`
set jobid = `echo "$out" | awk '{print $4}'`
if ("$jobid" != "") then
    echo "Submitted deterministic_2_500_with_ref_cells_water array for $scenario as JobID $jobid"
    echo "Partition: $partition  Nodelist: $nodelist"
else
    echo "Failed to submit deterministic_2_500_with_ref_cells_water array for $scenario"
endif
