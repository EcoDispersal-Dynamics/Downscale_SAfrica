# -----------------------------------------------------------------------------
# Load libraries
library(terra)
library(LandScaleR)

# -----------------------------------------------------------------------------
# PART 1: RECLASSIFY THE ORIGINAL MODIS REFERENCE MAP
# Setup base directory and country name
base_dir <- getwd()
country_name <- "Angola"

# Define the path to the original MODIS reference map (version 2)
angola_modis_raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                      "by_country", "Angola_modis_ref_map_2.tif")
angola_modis_raster <- rast(angola_modis_raster_path)

# Inspect the original raster
plot(angola_modis_raster, main = "Original MODIS Reference Map")
print(unique(angola_modis_raster))
print(names(angola_modis_raster))
print(levels(angola_modis_raster))

# --- Update Levels ---
# Extract the original levels (attribute table)
orig_levels <- levels(angola_modis_raster)[[1]]
print("Original Levels:")
print(orig_levels)

# Remove rows with value 3 (Deciduous_Needleleaf_Forests) and value 15 (Snow_and_Ice)
new_levels <- orig_levels[ !orig_levels$value %in% c(3, 15), ]
# Reassign new sequential values: new_value from 1 to nrow(new_levels)
new_levels$new_value <- seq_len(nrow(new_levels))
print("Updated Levels with New Values:")
print(new_levels)

# --- Create a Reclassification Matrix ---
reclass_mat <- matrix(nrow = nrow(new_levels), ncol = 3)
for(i in seq_len(nrow(new_levels))){
  old_val <- new_levels$value[i]
  new_val <- new_levels$new_value[i]
  reclass_mat[i, ] <- c(old_val - 0.5, old_val + 0.5, new_val)
}
print("Reclassification Matrix:")
print(reclass_mat)

# Reclassify the raster using terra's classify function
angola_modis_raster_new <- classify(angola_modis_raster, rcl = reclass_mat, include.lowest = TRUE)

# Prepare updated levels table and update the raster's levels
updated_levels <- new_levels[, c("new_value", "name")]
names(updated_levels) <- c("value", "name")
levels(angola_modis_raster_new) <- list(updated_levels)

# Inspect the reclassified raster
plot(angola_modis_raster_new, main = "Angola MODIS Reclassified")
print("New Levels in Reclassified Raster:")
print(levels(angola_modis_raster_new))
print("Unique values in the reclassified raster:")
print(unique(values(angola_modis_raster_new)))

# Save the new MODIS reference map as version 6
output_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country", "Angola_modis_ref_map_6.tif")
writeRaster(angola_modis_raster_new, output_path, overwrite = TRUE)
cat("Angola_modis_ref_map_6.tif has been saved with updated levels and reclassification.\n")

# -----------------------------------------------------------------------------
# PART 2: SETUP FOR DOWNSCALING WITH THE NEW REFERENCE MAP

# Load the new MODIS reference map (version 6)
country_ref_map_file <- output_path
ref_raster <- rast(country_ref_map_file)

# <<< CRITICAL LINE: Remove any NaN level from the reference map >>>
levels(ref_raster) <- list(levels(ref_raster)[[1]][!is.nan(levels(ref_raster)[[1]]$value), ])

# Load a representative PLUM raster (to extract its layer names)
plum_raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26",
                              "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped",
                              "Angola_SSP1_RCP26_LUC_fractions_2021_2022.tif")
angola_plum_raster <- rast(plum_raster_path)
plum_layer_names <- names(angola_plum_raster)
cat("PLUM layer names:\n")
print(plum_layer_names)

# Extract unique MODIS class values from the new reference map
modis_classes <- unique(values(ref_raster))
modis_classes <- sort(modis_classes[!is.na(modis_classes)])
cat("MODIS unique classes (new reclassified values):\n")
print(modis_classes)
# Expected classes: 1 to 15

# Create the matching matrix: rows = PLUM layer names, columns = "LC" concatenated with modis_classes
match_LC_classes <- matrix(
  data = 0,
  nrow = length(plum_layer_names),
  ncol = length(modis_classes),
  dimnames = list(plum_layer_names, paste0("LC", modis_classes))
)
cat("Initial Matching Matrix Structure:\n")
print(match_LC_classes)

# --- INSPECTION ---
# Compare matching matrix column names with LC codes in the new reference map
ref_map_codes <- paste0("LC", sort(unique(values(ref_raster))[!is.na(unique(values(ref_raster)))])
)
cat("LC codes in the new reference map:\n")
print(ref_map_codes)
matrix_codes <- colnames(match_LC_classes)
cat("Column names in match_LC_classes matrix:\n")
print(matrix_codes)
missing_codes <- setdiff(matrix_codes, ref_map_codes)
cat("The following LC codes are in match_LC_classes but missing in the reference map:\n")
print(missing_codes)

# --- Populate the Matching Matrix with Preferred Allocations ---
match_LC_classes["Cropland", c("LC11", "LC13")] <- c(0.5, 0.5)
match_LC_classes["Pasture", c("LC5", "LC6", "LC7", "LC8", "LC9", "LC10", "LC14")] <- c(0.1, 0.2, 0.1, 0.2, 0.2, 0.1, 0.1)
match_LC_classes["TimberForest", c("LC1", "LC2", "LC3", "LC4", "LC5", "LC6", "LC7", "LC8")] <- c(0.1, 0.2, 0.2, 0.1, 0.1, 0.1, 0.1, 0.1)
match_LC_classes["UnmanagedForest", c("LC1", "LC2", "LC3", "LC4", "LC5")] <- c(0.1, 0.2, 0.3, 0.2, 0.2)
match_LC_classes["OtherNatural", c("LC11", "LC13", "LC15")] <- c(0.5, 0.2, 0.3)
match_LC_classes["Barren", c("LC5", "LC6", "LC7", "LC8", "LC9", "LC14")] <- c(0.1, 0.1, 0.1, 0.2, 0.1, 0.4)
match_LC_classes["Urban", "LC12"] <- 1
cat("Updated Matching Matrix with Allocations:\n")
print(match_LC_classes)

# -----------------------------------------------------------------------------
# Setup for Downscaling
# Define the directory containing PLUM transition maps and list the files
plum_raster_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26",
                             "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped")
country_LUC_map_files <- list.files(
  path = plum_raster_dir,
  pattern = paste0("^", country_name, "_SSP1_RCP26_LUC_fractions_\\d{4}_\\d{4}\\.tif$"),
  full.names = TRUE
)
country_LUC_map_files <- sort(country_LUC_map_files)
if (length(country_LUC_map_files) == 0) {
  stop("ERROR: No PLUM transition maps found in: ", plum_raster_dir)
}
downscale_output_dir <- file.path(base_dir, "LU_downscalled_dataset", "LU_PLUM_Modis_500m",
                                  "downscale_SSP1_RCP26", "Downscale_by_country", "Angola_scr_6")
if (!dir.exists(downscale_output_dir)) {
  dir.create(downscale_output_dir, recursive = TRUE)
}

# -----------------------------------------------------------------------------
# Define the Dynamic Downscaling Function (with Logging and RAM Monitoring)
downscaleLC_with_progress <- function(ref_map_file_name, LC_deltas_file_list, ...) {
  start_time <- Sys.time()
  cat(sprintf("Starting downscaling process at: %s\n", start_time))
  
  log_file <- file.path(base_dir, "downscaling_log.txt")
  cat(sprintf("Processing started at: %s\n", start_time), file = log_file, append = TRUE)
  
  if (!file.exists(ref_map_file_name)) {
    stop("ERROR: MODIS reference map not found!")
  }
  
  # Use the MODIS reference map as the first reference
  current_ref_map <- ref_map_file_name  
  
  for (i in seq_along(LC_deltas_file_list)) {
    file <- LC_deltas_file_list[i]
    years <- gsub(".*_(\\d{4}_\\d{4})\\.tif$", "\\1", file)
    
    log_message <- sprintf("[%d/%d] Processing %s at %s", i, length(LC_deltas_file_list), file, Sys.time())
    cat(log_message, "\n")
    cat(log_message, "\n", file = log_file, append = TRUE)
    
    if (!file.exists(file)) {
      warning(sprintf("WARNING: Transition map missing, skipping: %s\n", file))
      cat(sprintf("WARNING: File %s is missing!\n", file), file = log_file, append = TRUE)
      next
    }
    
    ram_before <- sum(gc()[, 2])
    cat(sprintf("RAM Usage Before Processing: %.2f MB\n", ram_before))
    
    process_start <- Sys.time()
    
    output_file <- file.path(downscale_output_dir, paste0("Downscaled_ref_map_", years, ".tif"))
    
    if (i == 1) {
      discrete_output_file <- file.path(downscale_output_dir, paste0("Angola_MODIS_PLUM_500m_s1_", years, "_Discrete_Time1.tif"))
    } else {
      prev_years <- gsub(".*_(\\d{4}_\\d{4})\\.tif$", "\\1", LC_deltas_file_list[i - 1])
      discrete_output_file <- file.path(downscale_output_dir, paste0("Angola_MODIS_PLUM_500m_s1_", prev_years, "_Discrete_Time", i - 1, ".tif"))
    }
    
    downscaleLC(
      ref_map_file_name = current_ref_map,
      LC_deltas_file_list = list(file),
      output_file_prefix = paste0(country_name, "_MODIS_PLUM_500m_s1_", years),
      ...
    )
    
    process_end <- Sys.time()
    time_taken <- as.numeric(difftime(process_end, process_start, units = "secs"))
    
    ram_after <- sum(gc()[, 2])
    cat(sprintf("RAM Usage After Processing: %.2f MB\n", ram_after))
    
    if (file.exists(discrete_output_file)) {
      current_ref_map <- discrete_output_file
    } else {
      warning(sprintf("WARNING: Expected reference map not found: %s. Using last available map instead.", discrete_output_file))
      cat(sprintf("WARNING: Missing next reference map: %s\n", discrete_output_file), file = log_file, append = TRUE)
    }
    
    log_message <- sprintf("Completed %s in %.2f seconds | RAM Before: %.2f MB | RAM After: %.2f MB", 
                           file, time_taken, ram_before, ram_after)
    cat(log_message, "\n")
    cat(log_message, "\n", file = log_file, append = TRUE)
  }
  
  end_time <- Sys.time()
  total_time <- as.numeric(difftime(end_time, start_time, units = "mins"))
  cat(sprintf("Downscaling completed in %.2f minutes\n", total_time))
  cat(sprintf("Downscaling completed at: %s (Total: %.2f mins)\n", end_time, total_time), file = log_file, append = TRUE)
}

# -----------------------------------------------------------------------------
# Run the Downscaling Function with the New Reference Map and Matching Matrix
downscaleLC_with_progress(
  ref_map_file_name = country_ref_map_file,
  LC_deltas_file_list = country_LUC_map_files,
  LC_deltas_type = "proportions",
  ref_map_type = "discrete",
  cell_size_unit = "m",
  assign_ref_cells = FALSE,
  match_LC_classes = match_LC_classes,
  kernel_radius = 1,
  simulation_type = "deterministic",
  discrete_output_map = TRUE,
  random_seed = 44,
  output_dir_path = downscale_output_dir
)

