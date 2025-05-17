# ---------------------------
# 1. Load Required Libraries
# ---------------------------
library(terra)
library(LandScaleR)

# ---------------------------
# 2. Setup Directories & File Paths
# ---------------------------
base_dir     <- getwd()
country_name <- "Angola"

# (A) Path to the classified MODIS reference map
country_ref_map_file <- file.path(
  base_dir, 
  "LU_ref_dataset", "LU_ref_Modis_500m",
  "by_country", 
  paste0(country_name, "_modis_ref_map_8.tif")
)

if (!file.exists(country_ref_map_file)) {
  stop("❌ ERROR: MODIS reference map not found at: ", country_ref_map_file)
}

ref_map <- rast(country_ref_map_file)
plot(ref_map, main = "Classified MODIS Reference Map - Version 8")

# Extract Levels & Classes
ref_levels    <- levels(ref_map)[[1]]
modis_classes <- ref_levels$name
cat("✅ MODIS Classes Extracted:\n", modis_classes, "\n")


# (B) Path to the first PLUM raster file
plum_raster_path <- file.path(
  base_dir, 
  "LU_ref_dataset", 
  "LU_ref_PLUM_SSPs", 
  "SSP1_RCP26",
  "SSP1_RCP26_fraction", 
  "SSP1_RCP26_fraction_croped",
  paste0(country_name, "_SSP1_RCP26_LUC_fractions_2021_2022.tif")
)
if (!file.exists(plum_raster_path)) {
  stop("❌ ERROR: PLUM raster not found at: ", plum_raster_path)
}
angola_plum_raster <- rast(plum_raster_path)
plum_layer_names   <- names(angola_plum_raster)

# (C) Create or define the output directory for downscaling
plum_raster_dir       <- dirname(plum_raster_path)
downscale_output_dir  <- file.path(
  base_dir, 
  "LU_downscalled_dataset", 
  "LU_PLUM_Modis_500m",
  "downscale_SSP1_RCP26", 
  "Downscale_by_country", 
  country_name,
  "Angola_script_8"
)

if (!dir.exists(downscale_output_dir)) {
  dir.create(downscale_output_dir, recursive = TRUE)
}

# (D) List all PLUM transition maps
country_LUC_map_files <- list.files(
  path       = plum_raster_dir,
  pattern    = paste0("^", country_name, "_SSP1_RCP26_LUC_fractions_\\d{4}_\\d{4}\\.tif$"),
  full.names = TRUE
)
country_LUC_map_files <- sort(country_LUC_map_files)
if (length(country_LUC_map_files) == 0) {
  stop("❌ ERROR: No PLUM transition maps found in: ", plum_raster_dir)
}


# ---------------------------
# 3. Initialize Matching Matrix
# ---------------------------
match_LC_classes <- matrix(
  0, 
  nrow = length(plum_layer_names), 
  ncol = length(modis_classes),
  dimnames = list(plum_layer_names, modis_classes)
)

# Fill in allocations
allocations <- list(
  Cropland        = c("LC12" = 0.5, "LC14" = 0.5),
  Pasture         = c("LC6"  = 0.1, "LC7"  = 0.2, "LC8"  = 0.1, "LC9"  = 0.2,  
                      "LC10" = 0.2, "LC11" = 0.1, "LC16" = 0.1),
  TimberForest    = c("LC1"  = 0.1, "LC2"  = 0.2, "LC4"  = 0.2, "LC5"  = 0.1,  
                      "LC6"  = 0.1, "LC7"  = 0.1, "LC8"  = 0.1, "LC9"  = 0.1),
  UnmanagedForest = c("LC1"  = 0.1, "LC2"  = 0.2, "LC4"  = 0.3, "LC5"  = 0.2,  
                      "LC6"  = 0.2),
  OtherNatural    = c("LC12" = 0.5, "LC14" = 0.2, "LC17" = 0.3),
  Barren          = c("LC6"  = 0.2, "LC7"  = 0.2, "LC8"  = 0.2, "LC9"  = 0.4),  
  Urban           = c("LC13" = 1)
)

for (category in names(allocations)) {
  match_LC_classes[category, names(allocations[[category]])] <- allocations[[category]]
}
cat("✅ Updated Matching Matrix:\n")
print(match_LC_classes)


# ---------------------------
# 4. Helper Functions (Time Index Tracking)
# ---------------------------
get_latest_time_index <- function(output_dir) {
  time_index_file <- file.path(output_dir, "latest_time_index.txt")
  if (!file.exists(time_index_file)) return(0)
  
  latest_time_index <- as.numeric(readLines(time_index_file, warn = FALSE))
  ifelse(is.na(latest_time_index), 0, latest_time_index)
}

set_latest_time_index <- function(output_dir, time_index) {
  writeLines(as.character(time_index), file.path(output_dir, "latest_time_index.txt"))
}


# ---------------------------
# 5. Downscaling with Corrected Logic
# ---------------------------
downscaleLC_with_progress <- function(ref_map_file_name, LC_deltas_file_list, ...) {
  start_time <- Sys.time()
  cat(sprintf("🚀 Starting downscaling at: %s\n", start_time))
  
  log_file        <- file.path(downscale_output_dir, "downscaling_log.txt")
  time_index_file <- file.path(downscale_output_dir, "latest_time_index.txt")
  
  # Reset the time index tracking if needed
  if (file.exists(time_index_file)) file.remove(time_index_file)
  
  cat(sprintf("Processing started at: %s\n", start_time), file = log_file, append = TRUE)
  
  # The *initial* reference map for iteration 1
  current_ref_map <- ref_map_file_name
  
  # Loop through each PLUM transition map
  for (i in seq_along(LC_deltas_file_list)) {
    latest_time_index <- get_latest_time_index(downscale_output_dir)  
    next_time_index   <- latest_time_index + 1
    
    file  <- LC_deltas_file_list[i]
    years <- gsub(".*_(\\d{4}_\\d{4})\\.tif$", "\\1", file)
    
    cat(sprintf("📌 [%d/%d] Processing: %s at %s | Latest Time Index: %d\n", 
                i, length(LC_deltas_file_list), file, Sys.time(), latest_time_index))
    
    if (!file.exists(file)) {
      warning(sprintf("⚠️ WARNING: Missing transition map, skipping: %s\n", file))
      next
    }
    
    # Run the downscaling with the *current* reference map
    downscaleLC(
      ref_map_file_name   = current_ref_map,
      LC_deltas_file_list = list(file),
      output_file_prefix  = paste0(country_name, "_MODIS_PLUM_500m_s1_", years),
      ...
    )
    
    # New discrete output expected
    discrete_output_file <- file.path(
      downscale_output_dir,
      paste0(
        country_name, "_MODIS_PLUM_500m_s1_",
        years, "_Discrete_Time", next_time_index, ".tif"
      )
    )
    
    # Update time index for next iteration
    set_latest_time_index(downscale_output_dir, next_time_index)
    
    # Verify the newly created discrete output
    if (!file.exists(discrete_output_file)) {
      stop(sprintf("❌ ERROR: Expected discrete output not found after downscaling: %s", 
                   discrete_output_file))
    }
    
    # Update current_ref_map to the newly created file
    current_ref_map <- discrete_output_file
    
    # OPTIONAL: Rename the new discrete file from Time1 to Time2 if you like
    if (next_time_index >= 2) {
      # Adjust naming logic if needed
      new_time_index <- next_time_index
      renamed_discrete_file <- file.path(
        downscale_output_dir, 
        paste0(
          country_name, "_MODIS_PLUM_500m_s1_", 
          years, "_Discrete_Time", new_time_index, ".tif"
        )
      )
      
      # If the "renamed" file doesn't exist, rename the newly created one
      if (!file.exists(renamed_discrete_file)) {
        file.rename(discrete_output_file, renamed_discrete_file)
        cat(sprintf("✅ Renamed %s → %s\n", discrete_output_file, renamed_discrete_file))
        
        # Update reference map
        current_ref_map <- renamed_discrete_file
      }
    }
  }
  
  cat(sprintf("🏁 Downscaling completed at: %s\n", Sys.time()))
}


# ---------------------------
# 6. Run the Downscaling
# ---------------------------
downscaleLC_with_progress(
  ref_map_file_name   = country_ref_map_file,
  LC_deltas_file_list = country_LUC_map_files,
  LC_deltas_type      = "proportions",
  ref_map_type        = "discrete",
  cell_size_unit      = "m",
  assign_ref_cells    = FALSE,
  match_LC_classes    = match_LC_classes,
  kernel_radius       = 1,
  simulation_type     = "deterministic",
  discrete_output_map = TRUE,
  random_seed         = 44,
  output_dir_path     = downscale_output_dir
)




plum_fraction_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs",
                                "SSP1_RCP26", "SSP1_RCP26_fraction", 
                                "SSP1_RCP26_LUC_fractions_2030_2031.tif")
plum_fraction_rast <- rast(plum_fraction_path)
plot(plum_fraction_rast)
summary(plum_fraction_rast)
