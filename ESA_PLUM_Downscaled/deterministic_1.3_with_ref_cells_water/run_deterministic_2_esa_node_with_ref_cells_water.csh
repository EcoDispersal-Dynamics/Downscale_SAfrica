#!/bin/tcsh

# Run one ESA deterministic variant downscaling job for a single region
# Usage: run_deterministic_2_esa_node_with_ref_cells_water.csh <SSP1_RCP26|SSP2_RCP45|SSP3_RCP70|SSP4_RCP60|SSP5_RCP85> <region_id>

if ($#argv != 2) then
    echo "ERROR: Incorrect arguments."
    echo "Usage: $0 <SSP1_RCP26|SSP2_RCP45|SSP3_RCP70|SSP4_RCP60|SSP5_RCP85> <region_id>"
    exit 1
endif

set scenario_name = "$1"
set region_id = "$2"

if ("$scenario_name" != "SSP1_RCP26" && "$scenario_name" != "SSP2_RCP45" && "$scenario_name" != "SSP3_RCP70" && "$scenario_name" != "SSP4_RCP60" && "$scenario_name" != "SSP5_RCP85") then
    echo "ERROR: Scenario must be one of SSP1_RCP26, SSP2_RCP45, SSP3_RCP70, SSP4_RCP60, SSP5_RCP85."
    exit 1
endif

if ($region_id < 1 || $region_id > 8) then
    echo "ERROR: region_id must be between 1 and 8."
    exit 1
endif

set module_dir = `cd "$0:h" && pwd`
set module_name = `basename "$module_dir"`
set variant_label = `echo "$module_name" | sed 's/_with_ref_cells_water$//'`
set r_script = "$module_dir/run_downscale_deterministic_2_esa_with_ref_cells_water.R"
set log_dir = "$module_dir/logs"
mkdir -p $log_dir
set ts = `date +%Y%m%d_%H%M%S`
set log_file = "$log_dir/${scenario_name}_region${region_id}_${variant_label}_with_ref_cells_water_ESA_${ts}.log"

if (-e /etc/profile.d/modules.csh) then
    source /etc/profile.d/modules.csh
endif

module purge
module load r/4.2.2-gcc-11.3.1

echo "Loading R module..."

echo "=== ESA ${variant_label}_with_ref_cells_water run ===" |& tee -a $log_file
echo "Scenario: $scenario_name  Region: $region_id" |& tee -a $log_file
Rscript $r_script $scenario_name $region_id |& tee -a $log_file

set status_code = $status
if ($status_code != 0) then
    echo "Run failed with status $status_code" |& tee -a $log_file
    exit $status_code
else
    echo "Run completed successfully" |& tee -a $log_file
endif
