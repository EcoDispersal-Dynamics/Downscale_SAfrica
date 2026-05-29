#!/bin/tcsh

# Submit 8-region ESA deterministic runs as a SLURM array
# Usage: submit_esa_deterministic_2_with_ref_cells_water_array.csh <SSP1_RCP26|SSP2_RCP45|SSP3_RCP70|SSP4_RCP60|SSP5_RCP85> [genius|rogp|rome|fat|milan] [nodelist]

if ($#argv < 1 || $#argv > 3) then
    echo "Usage: $0 <SSP1_RCP26|SSP2_RCP45|SSP3_RCP70|SSP4_RCP60|SSP5_RCP85> [genius|rogp|rome|fat|milan] [nodelist]"
    exit 1
endif

set scenario = "$1"
if ("$scenario" != "SSP1_RCP26" && "$scenario" != "SSP2_RCP45" && "$scenario" != "SSP3_RCP70" && "$scenario" != "SSP4_RCP60" && "$scenario" != "SSP5_RCP85") then
    echo "ERROR: Scenario must be one of SSP1_RCP26, SSP2_RCP45, SSP3_RCP70, SSP4_RCP60, SSP5_RCP85"
    exit 1
endif

set partition = "rogp"
if ($#argv >= 2) then
    set partition = "$2"
endif

if ("$partition" != "genius" && "$partition" != "rogp" && "$partition" != "rome" && "$partition" != "fat" && "$partition" != "milan") then
    echo "ERROR: Partition must be genius, rogp, rome, fat, or milan"
    exit 1
endif

set nodelist = ""
if ($#argv == 3) then
    set nodelist = "$3"
else
    if ("$partition" == "rogp") then
        set nodelist = "rogp02"
    else if ("$partition" == "fat") then
        set nodelist = "fat02"
    else if ("$partition" == "milan") then
        set nodelist = "milan11"
    else if ("$partition" == "genius") then
        set nodelist = "genius12"
    else
        set nodelist = "rome01"
    endif
endif

if ("$nodelist" == "") then
    echo "ERROR: Unable to determine nodelist. Provide explicitly as second argument."
    exit 1
endif

set module_dir = `cd "$0:h" && pwd`
set module_name = `basename "$module_dir"`
set variant_label = `echo "$module_name" | sed 's/_with_ref_cells_water$//'`
set logs_dir = "$module_dir/slurm_logs"
mkdir -p $logs_dir

set script_node = "$module_dir/run_deterministic_2_esa_node_with_ref_cells_water.csh"
set out = `sbatch \
    --job-name=esa_${variant_label}_water \
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
    --export=ALL,SCENARIO=$scenario,SCRIPT=$script_node \
    --wrap 'module purge; module load r/4.2.2-gcc-11.3.1; tcsh $SCRIPT $SCENARIO $SLURM_ARRAY_TASK_ID'`
set jobid = `echo "$out" | awk '{print $4}'`
if ("$jobid" != "") then
    echo "Submitted ${variant_label}_with_ref_cells_water array for $scenario as JobID $jobid"
else
    echo "Failed to submit ${variant_label}_with_ref_cells_water array for $scenario"
    exit 1
endif
