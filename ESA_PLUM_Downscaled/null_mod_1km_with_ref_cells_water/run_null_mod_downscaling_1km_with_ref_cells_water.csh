#!/bin/tcsh

# SLURM submission script for ESA null model 1km downscaling with assign_ref_cells=TRUE (water-filled reference)

if ( $#argv < 1 ) then
    echo "Usage: run_null_mod_downscaling_1km_with_ref_cells_water.csh <scenario_name> [milan|rome|rogp] [nodeA,nodeB] [jobsA:jobsB|jobs] [memGB]"
    exit 1
endif

set scenario = $argv[1]

# Optional: target partition, default to milan
set partition = "milan"
if ( $#argv >= 2 ) then
    set partition = $argv[2]
endif

# Optional: explicit node list (comma-separated, e.g., milan01,milan02 or rome01,rome02)
set nodelist = ""
if ( $#argv >= 3 ) then
    set nodelist = $argv[3]
endif

set jobsA = 4
set jobsB = 4
if ( $#argv >= 4 ) then
    set jobs_spec = $argv[4]
    if ( "$jobs_spec" =~ *:* ) then
        set jobsA = `echo $jobs_spec | awk -F':' '{print $1}'`
        set jobsB = `echo $jobs_spec | awk -F':' '{print $2}'`
    else
        set jobsA = $jobs_spec
        set jobsB = $jobs_spec
    endif
endif

if ( "$partition" != "milan" && "$partition" != "rome" && "$partition" != "rogp" ) then
    echo "ERROR: Partition must be milan, rome, or rogp"
    exit 1
endif

set num_nodes = 0
if ( "$nodelist" != "" ) then
    set num_nodes = `echo $nodelist | awk -F',' '{print NF}'`
endif

if ( "$scenario" != "SSP2_RCP45" && "$scenario" != "SSP3_RCP70" && "$scenario" != "SSP4_RCP60" ) then
    echo "ERROR: Scenario must be SSP2_RCP45, SSP3_RCP70, or SSP4_RCP60"
    exit 1
endif

set job_name = "esa_null1km_${scenario}"
set log_dir = "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/null_mod_1km_with_ref_cells_water/slurm_logs/${scenario}"
mkdir -p $log_dir

set slurm_dir = "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/null_mod_1km_with_ref_cells_water/slurm_scripts"
mkdir -p $slurm_dir

if ( $num_nodes == 2 ) then
    set memGB = 50
    if ( $#argv >= 5 ) then
        set memGB = $argv[5]
    endif
    set nodeA = `echo $nodelist | awk -F',' '{print $1}'`
    set nodeB = `echo $nodelist | awk -F',' '{print $2}'`

    set slurm_script_a = "${slurm_dir}/${scenario}_${nodeA}.slurm"
    set slurm_script_b = "${slurm_dir}/${scenario}_${nodeB}.slurm"

    cat > $slurm_script_a <<EOF
#!/bin/tcsh
#SBATCH --job-name=${job_name}_A
#SBATCH --output=${log_dir}/${job_name}_A_%A_%a.out
#SBATCH --error=${log_dir}/${job_name}_A_%A_%a.err
#SBATCH --partition=${partition}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --time=3-00:00:00
#SBATCH --mem=${memGB}G
#SBATCH --array=1-4%${jobsA}
#SBATCH --nodelist=${nodeA}

module purge
module load proj/8.2.1-gcc-11.3.1
module load geos/3.9.1-gcc-11.3.1
module load gdal/3.5.3-gcc-11.3.1
module load r/4.2.2-gcc-11.3.1

echo "SLURM_JOB_ID: \$SLURM_JOB_ID"
echo "Scenario: ${scenario}"
echo "Node list: \$SLURM_NODELIST"
echo "Array task: \$SLURM_ARRAY_TASK_ID"

set region = \$SLURM_ARRAY_TASK_ID

echo "Launching 1km null model downscaling for region \$region"
Rscript /bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/null_mod_1km_with_ref_cells_water/run_downscale_null_mod_esa_with_ref_cells_water_1km_wrapper_node.R ${scenario} \$region
EOF

    cat > $slurm_script_b <<EOF
#!/bin/tcsh
#SBATCH --job-name=${job_name}_B
#SBATCH --output=${log_dir}/${job_name}_B_%A_%a.out
#SBATCH --error=${log_dir}/${job_name}_B_%A_%a.err
#SBATCH --partition=${partition}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --time=3-00:00:00
#SBATCH --mem=${memGB}G
#SBATCH --array=5-8%${jobsB}
#SBATCH --nodelist=${nodeB}

module purge
module load proj/8.2.1-gcc-11.3.1
module load geos/3.9.1-gcc-11.3.1
module load gdal/3.5.3-gcc-11.3.1
module load r/4.2.2-gcc-11.3.1

echo "SLURM_JOB_ID: \$SLURM_JOB_ID"
echo "Scenario: ${scenario}"
echo "Node list: \$SLURM_NODELIST"
echo "Array task: \$SLURM_ARRAY_TASK_ID"

set region = \$SLURM_ARRAY_TASK_ID

echo "Launching 1km null model downscaling for region \$region"
Rscript /bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/null_mod_1km_with_ref_cells_water/run_downscale_null_mod_esa_with_ref_cells_water_1km_wrapper_node.R ${scenario} \$region
EOF

    chmod +x $slurm_script_a $slurm_script_b
    set outA = `sbatch $slurm_script_a`
    set outB = `sbatch $slurm_script_b`
    echo $outA
    echo $outB
else
    set slurm_script = "${slurm_dir}/${scenario}_${partition}.slurm"
    set memGB = 50
    if ( $#argv >= 5 ) then
        set memGB = $argv[5]
    endif

    cat > $slurm_script <<EOF
#!/bin/tcsh
#SBATCH --job-name=${job_name}
#SBATCH --output=${log_dir}/${job_name}_%A_%a.out
#SBATCH --error=${log_dir}/${job_name}_%A_%a.err
#SBATCH --partition=${partition}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --time=3-00:00:00
#SBATCH --mem=${memGB}G
#SBATCH --array=1-8%${jobsA}
EOF

    if ( "$nodelist" != "" ) then
        cat >> $slurm_script <<EOF
#SBATCH --nodelist=${nodelist}
EOF
    endif

    cat >> $slurm_script <<EOF

module purge
module load proj/8.2.1-gcc-11.3.1
module load geos/3.9.1-gcc-11.3.1
module load gdal/3.5.3-gcc-11.3.1
module load r/4.2.2-gcc-11.3.1

echo "SLURM_JOB_ID: \$SLURM_JOB_ID"
echo "Scenario: ${scenario}"
echo "Node list: \$SLURM_NODELIST"
echo "Array task: \$SLURM_ARRAY_TASK_ID"

set region = \$SLURM_ARRAY_TASK_ID

echo "Launching 1km null model downscaling for region \$region"
Rscript /bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/null_mod_1km_with_ref_cells_water/run_downscale_null_mod_esa_with_ref_cells_water_1km_wrapper_node.R ${scenario} \$region
EOF

    chmod +x $slurm_script
    sbatch $slurm_script
endif