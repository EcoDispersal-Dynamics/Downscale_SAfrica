# =============================
# Minimum Representation Rule (MRR) Adjustment Code with Debugging and Verbose Logging
# =============================

library(data.table)
library(terra)
library(doParallel)
library(foreach)
library(LandScaleR)

# === Parameters ===
base_dir <- getwd()
modis_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country")
plum_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26", "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped")
synergy_dir <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables", "by_country_final_synergy")
output_root <- file.path(base_dir, "LU_downscalled_dataset", "LU_PLUM_Modis_500m", "downscale_SSP1_RCP26", "Downscale_by_country")
scenario <- "SSP1_RCP26"

# === Get country list from shapefile ===
shapefile_path <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")
region <- vect(shapefile_path)
region_wgs84 <- project(region, "EPSG:4326")
countries <- sort(unique(region_wgs84$CNTRY_NAME))

# === Set up parallel backend ===
ncores <- detectCores() - 1
cl <- makeCluster(ncores)
registerDoParallel(cl)

# === Parallel Downscaling ===
results <- foreach(country_name = countries, .packages = c("terra", "data.table", "LandScaleR")) %dopar% {
  tryCatch({
    ref_map_path <- file.path(modis_dir, paste0(country_name, "_modis_ref_map_8.tif"))
    synergy_path <- file.path(synergy_dir, country_name, paste0(country_name, "_", scenario, "_Final_Synergy.rds"))
    plum_files <- list.files(plum_dir, pattern = paste0("^", country_name, ".*_\\d{4}_\\d{4}\\.tif$"), full.names = TRUE)
    
    downscale_output_dir <- file.path(output_root, country_name, "script_auto")
    dir.create(downscale_output_dir, recursive = TRUE, showWarnings = FALSE)
    log_file <- file.path(downscale_output_dir, "downscale_log.txt")
    
    if (!file.exists(ref_map_path)) {
      cat(sprintf("⚠️ Missing MODIS reference for %s\n", country_name), file = log_file, append = TRUE)
      return(NULL)
    }
    if (!file.exists(synergy_path)) {
      cat(sprintf("⚠️ Missing synergy file for %s\n", country_name), file = log_file, append = TRUE)
      return(NULL)
    }
    if (length(plum_files) == 0) {
      cat(sprintf("⚠️ No PLUM transition maps for %s\n", country_name), file = log_file, append = TRUE)
      return(NULL)
    }
    
    cat(sprintf("\n🔄 Starting downscaling for %s\n", country_name), file = log_file, append = TRUE)
    ref_map <- rast(ref_map_path)
    ref_levels <- levels(ref_map)[[1]]
    modis_classes <- ref_levels$name
    match_LC_classes <- as.matrix(readRDS(synergy_path))
    
    get_latest_time_index <- function(output_dir) {
      file <- file.path(output_dir, "latest_time_index.txt")
      if (!file.exists(file)) return(0)
      val <- as.numeric(readLines(file, warn = FALSE))
      ifelse(is.na(val), 0, val)
    }
    
    set_latest_time_index <- function(output_dir, index) {
      writeLines(as.character(index), file.path(output_dir, "latest_time_index.txt"))
    }
    
    current_ref_map <- ref_map_path
    for (i in seq_along(plum_files)) {
      file <- plum_files[i]
      years <- gsub(".*_(\\d{4}_\\d{4})\\.tif$", "\\1", file)
      latest_time_index <- get_latest_time_index(downscale_output_dir)
      next_time_index <- latest_time_index + 1
      
      cat(sprintf("\n📌 [%d/%d] %s - %s\n", i, length(plum_files), country_name, years), file = log_file, append = TRUE)
      
      downscaleLC(
        ref_map_file_name   = current_ref_map,
        LC_deltas_file_list = list(file),
        LC_deltas_type      = "proportions",
        ref_map_type        = "discrete",
        cell_size_unit      = "m",
        assign_ref_cells    = FALSE,
        match_LC_classes    = match_LC_classes,
        kernel_radius       = 1,
        simulation_type     = "deterministic",
        discrete_output_map = TRUE,
        random_seed         = 44,
        output_dir_path     = downscale_output_dir,
        output_file_prefix  = paste0(country_name, "_MODIS_PLUM_500m_s1_", years)
      )
      
      tif_out <- list.files(downscale_output_dir, pattern = paste0(country_name, ".*", years, ".*Time1\\.tif$"), full.names = TRUE)
      aux_out <- list.files(downscale_output_dir, pattern = paste0(country_name, ".*", years, ".*Time1\\.tif\\.aux\\.xml$"), full.names = TRUE)
      
      renamed_tif <- file.path(downscale_output_dir, paste0(country_name, "_MODIS_PLUM_500m_s1_", years, "_Discrete_Time", next_time_index, ".tif"))
      renamed_aux <- file.path(downscale_output_dir, paste0(country_name, "_MODIS_PLUM_500m_s1_", years, "_Discrete_Time", next_time_index, ".tif.aux.xml"))
      
      if (length(tif_out) > 0) file.rename(tif_out[1], renamed_tif)
      if (length(aux_out) > 0) file.rename(aux_out[1], renamed_aux)
      
      set_latest_time_index(downscale_output_dir, next_time_index)
      current_ref_map <- renamed_tif
    }
    
    cat(sprintf("✅ Completed %s\n", country_name), file = log_file, append = TRUE)
    return(TRUE)
  }, error = function(e) {
    cat(sprintf("⚠️ ERROR in %s: %s\n", country_name, conditionMessage(e)), file = log_file, append = TRUE)
    return(NULL)
  })
}

stopCluster(cl)
message("\n🎯 All countries processed in parallel.\n")
