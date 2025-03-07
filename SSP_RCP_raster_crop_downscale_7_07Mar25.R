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

# Optional: Inspect the original raster
plot(angola_modis_raster, main = "Original MODIS Reference Map")
print(unique(angola_modis_raster))
print(names(angola_modis_raster))
print(levels(angola_modis_raster))

# --- Update Levels ---
# Extract the original levels (attribute table)
orig_levels <- levels(angola_modis_raster)[[1]]
cat("Original Levels:\n")
print(orig_levels)

# Remove rows with value 3 (Deciduous_Needleleaf_Forests) and value 15 (Snow_and_Ice)
new_levels <- orig_levels[ !orig_levels$value %in% c(3, 15), ]

# Reassign new sequential values (new_value from 1 to nrow(new_levels))
new_levels$new_value <- seq_len(nrow(new_levels))

# Rename classes: assign new names as "LC1", "LC2", ..., "LC15"
new_levels$name <- paste0("LC", new_levels$new_value)
cat("Updated Levels with new LC names:\n")
print(new_levels)

# --- Create a Reclassification Matrix ---
# For each retained level, classify pixels within [old_value - 0.5, old_value + 0.5]
reclass_mat <- matrix(nrow = nrow(new_levels), ncol = 3)
for(i in seq_len(nrow(new_levels))){
  old_val <- new_levels$value[i]
  new_val <- new_levels$new_value[i]
  reclass_mat[i, ] <- c(old_val - 0.5, old_val + 0.5, new_val)
}
cat("Reclassification Matrix:\n")
print(reclass_mat)

# Reclassify the raster using terra's classify function
angola_modis_raster_new <- classify(angola_modis_raster, rcl = reclass_mat, include.lowest = TRUE)

# Update the raster's levels with the new LC names
levels(angola_modis_raster_new) <- list(new_levels[, c("new_value", "name")])
cat("New Levels in Reclassified Raster:\n")
print(levels(angola_modis_raster_new))

# Optional: Inspect the unique pixel values (will show only numbers)
print("Unique values in the reclassified raster:")
print(unique(values(angola_modis_raster_new)))

# Save the new MODIS reference map as version 6 (with levels already named LC1 - LC15)
output_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country", "Angola_modis_ref_map_7.tif")
writeRaster(angola_modis_raster_new, output_path, overwrite = TRUE)
cat("Angola_modis_ref_map_6.tif has been saved with updated LC-level names.\n")


# -----------------------------------------------------------------------------
# PART 2: SETUP FOR DOWNSCALING WITH THE NEW REFERENCE MAP (Version 7)

# Load MODIS reference map (version 7)
# (Assuming you have saved the reclassified file as "Angola_modis_ref_map_7.tif")
country_ref_map_file <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m",
                                  "by_country", "Angola_modis_ref_map_7.tif")
ref_raster <- rast(country_ref_map_file)
plot(ref_raster, main = "Angola MODIS Ref Map (Version 7)")

# Extract the reference map levels (which should be like "LC1", "LC2", ..., "LC15")
ref_levels <- levels(ref_raster)[[1]]
cat("Reference map levels:\n")
print(ref_levels)

# Use the 'name' field from the levels as the MODIS classes (already in LCx format)
modis_classes <- ref_levels$name  
cat("MODIS unique classes (new reclassified values):\n")
print(modis_classes)

# Load a representative PLUM raster to extract its layer names
plum_raster_path <- file.path(
  base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26",
  "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped",
  "Angola_SSP1_RCP26_LUC_fractions_2021_2022.tif"
)
angola_plum_raster <- rast(plum_raster_path)
plum_layer_names <- names(angola_plum_raster)
cat("PLUM layer names:\n")
print(plum_layer_names)

# Initialize the matching matrix:
# Rows = PLUM layer names, Columns = MODIS classes (taken directly from ref_levels$name)
match_LC_classes <- matrix(
  0,
  nrow = length(plum_layer_names),
  ncol = length(modis_classes),
  dimnames = list(plum_layer_names, modis_classes)
)
cat("Initial Matching Matrix Structure:\n")
print(match_LC_classes)

# (Optional) Verify that the reference map's level names match the matrix column names
matrix_codes <- colnames(match_LC_classes)
if (!all(matrix_codes %in% modis_classes)) {
  missing_codes <- setdiff(matrix_codes, modis_classes)
  cat("The following LC codes are in match_LC_classes but missing in the reference map:\n", 
      missing_codes, "\n")
} else {
  cat("All matching matrix column names are present in the reference map levels.\n")
}

# --- Populate the Matching Matrix with Preferred Allocations ---
# Note: Since the reference map levels are already "LCx", no additional prefix is needed.
allocations <- list(
  Cropland       = c("LC11" = 0.5, "LC13" = 0.5),
  Pasture        = c("LC5"  = 0.1, "LC6"  = 0.2, "LC7"  = 0.1, "LC8"  = 0.2, "LC9"  = 0.2, "LC10" = 0.1, "LC14" = 0.1),
  TimberForest   = c("LC1"  = 0.1, "LC2"  = 0.2, "LC3"  = 0.2, "LC4"  = 0.1, "LC5"  = 0.1, "LC6"  = 0.1, "LC7"  = 0.1, "LC8"  = 0.1),
  UnmanagedForest= c("LC1"  = 0.1, "LC2"  = 0.2, "LC3"  = 0.3, "LC4"  = 0.2, "LC5"  = 0.2),
  OtherNatural   = c("LC11" = 0.5, "LC13" = 0.2, "LC15" = 0.3),
  Barren         = c("LC5"  = 0.1, "LC6"  = 0.1, "LC7"  = 0.1, "LC8"  = 0.2, "LC9"  = 0.1, "LC14" = 0.4),
  Urban          = c("LC12" = 1)
)

# Apply allocations to the matrix
for (category in names(allocations)) {
  match_LC_classes[category, names(allocations[[category]])] <- allocations[[category]]
}

cat("Updated Matching Matrix with Allocations:\n")
print(match_LC_classes)

# Optional: Verify that the reference map's names match the matrix column names
cat("Reference map level names:\n")
print(ref_levels$name)
cat("Matching matrix column names:\n")
print(colnames(match_LC_classes))
missing_codes <- setdiff(colnames(match_LC_classes), ref_levels$name)
cat("Mismatched LC Codes:\n", missing_codes, "\n")


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

