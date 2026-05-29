#!/bin/tcsh

# Run ESA deterministic_2_500_with_ref_cells_water downscaling for a single region
# Usage: run_deterministic_2_esa_node_with_ref_cells_water_500m.csh <SSP1_RCP26|SSP5_RCP85> <region_id>

if ($#argv != 2) then
    echo "ERROR: Incorrect arguments."
    echo "Usage: $0 <SSP1_RCP26|SSP5_RCP85> <region_id>"
    exit 1
endif

set scenario_name = "$1"
set region_id = "$2"

if ("$scenario_name" != "SSP1_RCP26" && "$scenario_name" != "SSP5_RCP85") then
    echo "ERROR: Only SSP1_RCP26 and SSP5_RCP85 are supported."
    exit 1
endif

if ($region_id < 1 || $region_id > 8) then
    echo "ERROR: region_id must be between 1 and 8."
    exit 1
endif

set base_dir = "/bg/data/kaza_elephant/Downscale_SAfrica"
set module_dir = "$base_dir/ESA_PLUM_Downscaled/deterministic_2_500_with_ref_cells_water"
set r_script = "$module_dir/run_downscale_deterministic_2_esa_with_ref_cells_water_500m.R"
set log_dir = "$module_dir/logs"
mkdir -p $log_dir
set tmp_root = "$module_dir/temp_r_files"
set tmp_job_dir = "$tmp_root/${scenario_name}_region${region_id}"
if ($?SLURM_ARRAY_JOB_ID) then
    set tmp_job_dir = "$tmp_root/slurm_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
endif
mkdir -p $tmp_job_dir
setenv TMPDIR $tmp_job_dir
setenv TMP $tmp_job_dir
setenv TEMP $tmp_job_dir
set ts = `date +%Y%m%d_%H%M%S`
set log_file = "$log_dir/${scenario_name}_region${region_id}_det2_500_with_ref_cells_water_ESA_${ts}.log"

if (-e /etc/profile.d/modules.csh) then
    source /etc/profile.d/modules.csh
endif

module purge
module load r/4.2.2-gcc-11.3.1

echo "Loading R module..."
echo "TMPDIR: $TMPDIR" |& tee -a $log_file

echo "=== ESA deterministic_2_500_with_ref_cells_water run ===" |& tee -a $log_file
echo "Scenario: $scenario_name  Region: $region_id" |& tee -a $log_file
Rscript $r_script $scenario_name $region_id |& tee -a $log_file

set status_code = $status
if ($status_code != 0) then
    echo "Run failed with status $status_code" |& tee -a $log_file
    exit $status_code
else
    echo "Run completed successfully" |& tee -a $log_file
endif
