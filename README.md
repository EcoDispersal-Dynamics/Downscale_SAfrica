# Africa Land Use Downscaling Project

This repository contains scripts and analysis assets for Africa-wide downscaling of PLUM (Parsimonious Land Use Model) land use projections using LandScaleR and ESA-based reference workflows.

## Project Overview

The project downscales coarse-resolution PLUM land use projections to finer spatial products across Africa. Current release scope focuses on the approved ESA/PLUM script set for eight model variants (deterministic, fuzzy, and null-model families).

## Repository Structure

```
/bg/data/kaza_elephant/Downscale_SAfrica/
├── ESA_PLUM_Downscaled/         # Main ESA/PLUM downscaling workflows and analysis
│   ├── deterministic_1.1_with_ref_cells_water/
│   ├── deterministic_1.2_with_ref_cells_water/
│   ├── deterministic_1.3_with_ref_cells_water/
│   ├── deterministic_2.1_with_ref_cells_water/
│   ├── deterministic_2.2_with_ref_cells_water/
│   ├── deterministic_2.3_with_ref_cells_water/
│   ├── fuzzy/
│   ├── null_mod_1km_with_ref_cells_water/
│   └── analysis/
├── PLUM_Africa_Data/            # PLUM model input data
├── ESA_WorldCover/              # ESA WorldCover reference inputs
├── Africa_Shapefile/            # Africa boundary shapefiles
├── analysis/                    # Publication and diagnostics workspace
├── scripts/                     # Utility scripts
├── slurm_scripts/               # SLURM job submission scripts
└── slurm_logs/                  # SLURM job logs
```

## Key Components

### Approved Release Variants (8)

1. **deterministic_1.1_with_ref_cells_water**
2. **deterministic_1.2_with_ref_cells_water**
3. **deterministic_1.3_with_ref_cells_water**
4. **deterministic_2.1_with_ref_cells_water**
5. **deterministic_2.2_with_ref_cells_water**
6. **deterministic_2.3_with_ref_cells_water**
7. **fuzzy**
8. **null_mod_1km_with_ref_cells_water**

Excluded from release scope: `500m` variants and `fuzzy_3`.

### Key Script Pattern

Each approved variant folder contains a small run stack:

- `run_downscale_*.R`: main downscaling script
- `run_*node*.csh` or wrapper script: node-level execution wrapper
- `submit_*.csh` or `slurm_*.sh`: cluster submission entry point

## Setup and Dependencies

### Required Software

- R 4.2.2
- LandScaleR package (v1.2.0)
- terra R package
- future R package (for parallel processing)

### R Library Path Setup

R libraries are expected in:
```
/bg/home/[username]/R/library
```

### Required Data

- PLUM projections: `/bg/data/kaza_elephant/Downscale_SAfrica/PLUM_Africa_Data/processed_data/[SCENARIO]/`
- ESA reference inputs under `/bg/data/kaza_elephant/Downscale_SAfrica/ESA_WorldCover/`

## Execution Instructions

### Running on the HPC Cluster

The project uses the SLURM job scheduler for high-performance computing. Two main partitions are available:

1. **genius**: Original partition (limited availability)
2. **ROGP**: Current preferred partition with 4 nodes (rogp01-04), each with 128 CPUs and 245GB memory

### Parallel Job Submission

Example (one approved deterministic variant):

```bash
cd /bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/deterministic_2.1_with_ref_cells_water
./submit_esa_deterministic_2_with_ref_cells_water_array.csh
```

This submits scenario-region jobs in parallel for the selected variant.

### Resource Allocation

- Each job uses one full ROGP node
- Parallel processing configured for 64 cores per job
- Memory fraction set to 0.5 (~122.5GB per job)
- 24-hour runtime limit per job

### Monitoring Jobs

```bash
# Check all your jobs
squeue -u $USER

# Filter for ESA jobs
squeue -u $USER | grep ESA

# Monitor ROGP node usage
sinfo -p rogp
```

## Performance Notes

1. The ROGP partition has 4 nodes, so a maximum of 4 jobs can run simultaneously regardless of dependencies.

2. Removing job dependencies allows more efficient resource utilization but doesn't increase the total number of simultaneous jobs beyond hardware limitations.

3. Each scenario-region combination takes approximately 24 hours to process.

## Scenarios

The project processes 5 climate scenarios:

1. SSP1_RCP26: Sustainability - Taking the Green Road
2. SSP2_RCP45: Middle of the Road
3. SSP3_RCP70: Regional Rivalry - A Rocky Road
4. SSP4_RCP60: Inequality - A Road Divided
5. SSP5_RCP85: Fossil-fueled Development - Taking the Highway

Each scenario is processed across an 8-region Africa-wide tiling used for parallel execution.

## Regional Division

The reference map is divided into an 8-region grid to parallelize processing while maintaining manageable memory requirements.

## Output Structure

Outputs for each job are stored under variant-specific folders, for example:
```
/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/deterministic_2.1_with_ref_cells_water/output/[SCENARIO]/region[ID]/
```

Each directory contains:
- Initial reference map
- PLUM fraction maps for each year
- Downscaled discrete land use maps for each year
- Log files with processing details

## Analysis and Figures (Fig1a–Fig3c)

The `ESA_PLUM_Downscaled/analysis/` folder contains scripts that generate the figure suite for ESA and MODIS comparisons, keeping naming and styling consistent across figures. All figures are exported as both PNG and TIF into `ESA_PLUM_Downscaled/analysis/results/`.

Prerequisites (R packages): data.table, ggplot2, terra, sf, scales, gridExtra, stringr, exactextractr.

General styling/decisions used across figures:
- X-axis label tilt is 25° (titles remain upright).
- Units are absolute km^2 (not scientific notation; formatted with commas).
- Water and Snow excluded; Built-up sometimes dropped depending on comparison; ESA mangroves merged into forest where aligning classes with MODIS.
- For map legends, a shared overlay is used (left side) with consistent sizes.

### Fig1a–c: Net change maps (null models, SSP1 and SSP5)

- Scripts:
	- `ESA_PLUM_Downscaled/analysis/Fig1a_net_forest_change_SSP1_and_5.R`
	- `ESA_PLUM_Downscaled/analysis/Fig1b_net_cropland_change_SSP1_and_5.R`
	- `ESA_PLUM_Downscaled/analysis/Fig1c_net_grassland_change_SSP1_and_5.R`
- What they show:
	- 2×2 panels (portrait): ESA (top row) and MODIS (bottom row), SSP1_RCP26 and SSP5_RCP85 columns.
	- Net land cover change maps for forest (Fig1a), cropland (Fig1b), and grassland (Fig1c) using null models.
	- Overlay legend (left), consistent color scales, larger titles, smaller tile titles for readability.
- Outputs (examples):
	- `results/Fig1a_net_forest_change_SSP1_and_5.(png|tif)`
	- `results/Fig1b_net_cropland_change_SSP1_and_5.(png|tif)`
	- `results/Fig1c_net_grassland_change_SSP1_and_5.(png|tif)`
- How to run (tcsh):
	```tcsh
	Rscript "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/analysis/Fig1a_net_forest_change_SSP1_and_5.R"
	Rscript "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/analysis/Fig1b_net_cropland_change_SSP1_and_5.R"
	Rscript "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/analysis/Fig1c_net_grassland_change_SSP1_and_5.R"
	```

### Fig2a–c: Net change by region (grouped bars; null models)

- Scripts:
	- `ESA_PLUM_Downscaled/analysis/Fig2a_net_forest_change_by_region_SSP1_and_5.R`
	- `ESA_PLUM_Downscaled/analysis/Fig2b_net_cropland_change_by_region_SSP1_and_5.R`
	- `ESA_PLUM_Downscaled/analysis/Fig2c_net_grassland_change_by_region_SSP1_and_5.R`
- What they show:
	- Grouped bar charts by Africa regions using the regions shapefile.
	- ESA vs MODIS across SSP1_RCP26 and SSP5_RCP85 for the null model; facets by dataset (rows) and SSPs.
	- Vertical divider lines between regions; larger, adjustable label sizes for region names and facet strips.
	- Y-axis labels use absolute km^2 with comma formatting.
- Regions shapefile:
	- `/bg/data/kaza_elephant/Downscale_SAfrica/MODIS_PLUM_Downscaled/Africa_countires_and_regions/Africa_regions.shp`
- Adjustable sizes via environment variables (optional):
	- `FIG2_TITLE_CEX`, `FIG2_AXIS_TEXT_X_SIZE`, `FIG2_AXIS_TEXT_Y_SIZE`, `FIG2_AXIS_TITLE_SIZE`, `FIG2_STRIP_TEXT_SIZE`, `FIG2_LEGEND_TEXT_SIZE`
- Outputs (examples):
	- `results/Fig2a_net_forest_change_by_region_SSP1_and_5.(png|tif)`
	- `results/Fig2b_net_cropland_change_by_region_SSP1_and_5.(png|tif)`
	- `results/Fig2c_net_grassland_change_by_region_SSP1_and_5.(png|tif)`
- How to run (tcsh):
	```tcsh
	# Optional size tuning for labels/strips
	setenv FIG2_STRIP_TEXT_SIZE 14
	Rscript "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/analysis/Fig2a_net_forest_change_by_region_SSP1_and_5.R"
	Rscript "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/analysis/Fig2b_net_cropland_change_by_region_SSP1_and_5.R"
	Rscript "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/analysis/Fig2c_net_grassland_change_by_region_SSP1_and_5.R"
	```

### Fig3a–c: Allocation efficiency (ESA vs MODIS; deterministic_2 and null_mod)

- Script:
	- `ESA_PLUM_Downscaled/analysis/Fig3a_c_allocation_efficiency_compare_ESA_MODIS.R`
- What it shows:
	- For each SSP (SSP1_RCP26, SSP5_RCP85) and sim type (deterministic_2, null_mod), it compares PLUM-projected land use change to what LandScaleR allocated vs left unallocated, by PLUM class.
	- Fig3a: SSP1 stacked bars (Allocated vs Unallocated) by PLUM class; facets by dataset (ESA/MODIS) × sim type.
	- Fig3b: Same for SSP5.
	- Fig3c: Allocation proportion (Allocated / Projected) by PLUM class; facets by sim type × SSP; bars colored by dataset (ESA vs MODIS).
- How it works:
	- Scans unallocated_LC.txt logs for ESA and MODIS under each sim/output/SSP tree.
	- Deduplicates reruns by keeping the newest file per (sim, ssp, region, start_year, end_year) using modification time.
	- Sums absolute unallocated per class per file, then aggregates across all regions and years for each sim_type and SSP.
	- Reads PLUM processed rasters (7 bands per class) to compute projected absolute change per class by summing |change| × cell area across all years; aligns to PLUM class names.
	- If logs only provide totals (no per-class), it falls back to a “Total” comparison for that path.
- Optional normalization (region coverage):
	- `ALLOC_EQUIV8=TRUE` will normalize unallocated totals to an equivalent-8-region basis using (8 / n_regions_detected) per dataset × sim_type × SSP. Default is off.
- Outputs:
	- `results/Fig3a_allocation_vs_unallocated_by_class_SSP1.(png|tif)`
	- `results/Fig3b_allocation_vs_unallocated_by_class_SSP5.(png|tif)`
	- `results/Fig3c_allocation_proportion_by_class_ESA_vs_MODIS.(png|tif)`
- How to run (tcsh):
	```tcsh
	# Optional: scale to equivalent-8 regions when coverage differs
	# setenv ALLOC_EQUIV8 TRUE
	Rscript "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/analysis/Fig3a_c_allocation_efficiency_compare_ESA_MODIS.R"
	```

Notes:
- ESA supports only SSP1_RCP26 and SSP5_RCP85; comparisons are restricted accordingly.
- Region folders and top-level region files are supported (region inferred from path or filename).
- All figures export both PNG and LZW-compressed TIF.