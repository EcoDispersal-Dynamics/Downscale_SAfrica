# Africa Land Use Downscaling Project

This repository contains scripts for Africa-wide downscaling of PLUM (Parsimonious Land Use Model) land use projections using LandScaleR with ESA WorldCover reference data.

## Overview

This project downscales PLUM v2 land use projections from their native 0.5° resolution to 1 km across continental Africa for five SSP-RCP scenarios (SSP1-RCP2.6 through SSP5-RCP8.5). The workflow uses LandScaleR deterministic allocation with ESA WorldCover 2021 as the fine-resolution reference map, producing annual land use and land cover projections from 2021 to 2100.

The repository contains development code for eight model variants. The released product for publication is the **deterministic_2.1** configuration, selected through a four-diagnostic assessment framework documented in the associated ESSD data paper.

**Detailed Documentation:** Comprehensive methodology, data specifications, output structure, and usage instructions are available in the Zenodo data deposit (DOI: <ADD DOI>).

## Repository Contents

- **ESA_PLUM_Downscaled/** - Main downscaling workflows for 8 model variants (each includes SLURM submission scripts)
- **scripts/** - Utility scripts (e.g., package installation)

## Spatial Coverage

- **Domain**: Continental Africa
- **Projection**: ESRI:102022 (Africa Albers Equal Area)
- **Resolution**: 1 km
- **Processing**: 8-region tiling for parallel execution

## Model Variants

Eight model configurations were developed and evaluated:

1. **deterministic_1.1_with_ref_cells_water**
2. **deterministic_1.2_with_ref_cells_water**
3. **deterministic_1.3_with_ref_cells_water**
4. **deterministic_2.1_with_ref_cells_water** ← **Released product**
5. **deterministic_2.2_with_ref_cells_water**
6. **deterministic_2.3_with_ref_cells_water**
7. **fuzzy** - Probability-based transitions
8. **null_mod_1km_with_ref_cells_water** - Baseline comparison

The **deterministic_2.1** variant was selected as the released product based on a balanced performance across four diagnostics: Pontius disagreement, Aggregation Index, mean patch area, and inter-variant Spearman correlation.

Each variant folder contains:
- `run_downscale_*.R` - Core downscaling script
- `run_*node*.csh` - Execution wrapper
- `submit_*.csh` or `slurm_*.sh` - Job submission script

## Requirements

- R 4.2.2 or higher
- LandScaleR package (>= 1.2.0)
- R packages: terra, future, sf
- SLURM-based HPC environment (for parallel processing)

## Quick Start

Each variant can be executed independently:

```bash
cd ESA_PLUM_Downscaled/deterministic_2.1_with_ref_cells_water
./submit_esa_deterministic_2_with_ref_cells_water_array.csh
```

This submits parallel jobs for all scenarios and spatial regions.

## Climate Scenarios

The project processes five Shared Socioeconomic Pathways (SSPs):

- **SSP1-RCP2.6**: Sustainability pathway
- **SSP2-RCP4.5**: Middle-of-the-road pathway
- **SSP3-RCP7.0**: Regional rivalry pathway
- **SSP4-RCP6.0**: Inequality pathway
- **SSP5-RCP8.5**: Fossil-fueled development pathway

## Analysis Scripts

Figure generation scripts are located in `ESA_PLUM_Downscaled/analysis/`. These produce spatial maps and statistical summaries of land use change patterns. See the analysis folder README for details.

## Citation

If you use this code or data, please cite:


Data deposit: Zenodo 

## License

[To be specified]

## Contact

For questions or issues, please open a GitHub issue or contact @Markus-Shiweda.
