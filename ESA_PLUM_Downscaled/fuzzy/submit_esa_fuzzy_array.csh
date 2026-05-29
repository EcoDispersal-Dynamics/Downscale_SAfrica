#!/bin/tcsh

# Submit an 8-region ESA fuzzy 1 km run as a SLURM array.
# Usage: submit_esa_fuzzy_array.csh <SSP1_RCP26|SSP2_RCP45|SSP3_RCP70|SSP4_RCP60|SSP5_RCP85> [rome|rogp|fat] [nodelist]

if ($#argv < 1 || $#argv > 3) then
    echo "Usage: $0 <SSP1_RCP26|SSP2_RCP45|SSP3_RCP70|SSP4_RCP60|SSP5_RCP85> [rome|rogp|fat] [nodelist]"
    exit 1
endif

set scenario = "$1"
if ("$scenario" != "SSP1_RCP26" && "$scenario" != "SSP2_RCP45" && "$scenario" != "SSP3_RCP70" && "$scenario" != "SSP4_RCP60" && "$scenario" != "SSP5_RCP85") then
    echo "ERROR: Scenario must be SSP1_RCP26, SSP2_RCP45, SSP3_RCP70, SSP4_RCP60, or SSP5_RCP85"
    exit 1
endif

set partition = "rome"
if ($#argv >= 2) then
    set partition = "$2"
endif

if ("$partition" != "rome" && "$partition" != "rogp" && "$partition" != "fat") then
    echo "ERROR: Partition must be rome, rogp, or fat"
    exit 1
endif

set nodelist = ""
if ($#argv == 3) then
    set nodelist = "$3"
endif

if ("$nodelist" == "") then
    if ("$partition" == "rome") then
        set nodelist = "rome02"
    endif
    if ("$partition" == "rogp") then
        set nodelist = "rogp03"
    endif
    if ("$partition" == "fat") then
        set nodelist = "fat02"
    endif
endif

set base_dir = "/bg/data/kaza_elephant/Downscale_SAfrica"
set module_dir = "$base_dir/ESA_PLUM_Downscaled/fuzzy"
set script = "$module_dir/run_downscale_fuzzy_genius_clean.R"
set logs_dir = "$module_dir/slurm_logs"
mkdir -p $logs_dir

set out = `sbatch \
    --job-name=esa_fuzzy_1km \
    --partition=$partition \
    --nodes=1 \
    --ntasks=1 \
    --cpus-per-task=8 \
    --mem=24G \
    --time=3-00:00:00 \
    --nodelist=$nodelist \
    --array=1-8 \
    --output=$logs_dir/%x_%A_%a.out \
    --error=$logs_dir/%x_%A_%a.err \
    --export=ALL,SCENARIO=$scenario,SCRIPT=$script \
    --wrap 'module purge; module load r/4.2.2-gcc-11.3.1; Rscript $SCRIPT $SCENARIO $SLURM_ARRAY_TASK_ID'`
set jobid = `echo "$out" | awk '{print $4}'`
if ("$jobid" != "") then
    echo "Submitted ESA fuzzy 1 km array for $scenario as JobID $jobid"
    exit 0
endif

echo "Failed to submit ESA fuzzy 1 km array for $scenario"
exit 1