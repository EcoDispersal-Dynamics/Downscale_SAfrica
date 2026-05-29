#!/usr/bin/env Rscript

# Wrapper that sets envars and calls the 1km null model runner; node argument optional

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("Usage: Rscript run_downscale_null_mod_esa_with_ref_cells_water_1km_wrapper_node.R [node] <scenario_name> <region_id>\n")
  quit(status = 1)
}

if (length(args) == 3) {
  node <- args[1]
  scenario <- args[2]
  region <- args[3]
} else {
  scenario <- args[1]
  region <- args[2]
  node <- Sys.getenv("SLURM_JOB_NODELIST")
  if (node == "") {
    node <- Sys.getenv("SLURM_NODELIST")
  }
  if (node == "") {
    node <- "unknown"
  }
}

Sys.setenv(R_LIBS_USER = "/bg/home/shiweda-m/R/library")
Sys.setenv(OMP_NUM_THREADS = "1")
Sys.setenv(UV_USE_IO_URING = "0")
Sys.setenv(TMPDIR = "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/null_mod_1km_with_ref_cells_water/temp_r_files")

cat("Target node:", node, "\n")
Sys.setenv(SLURM_HINT = "nomultithread")

script_path <- "/bg/data/kaza_elephant/Downscale_SAfrica/ESA_PLUM_Downscaled/null_mod_1km_with_ref_cells_water/run_downscale_null_mod_esa_with_ref_cells_water_1km.R"

cmd <- c(script_path, scenario, region)
cat("Running command:", paste("Rscript", paste(cmd, collapse = " ")), "\n")

exit_status <- system2("Rscript", args = cmd)
quit(status = exit_status)