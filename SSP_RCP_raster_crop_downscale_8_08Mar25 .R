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
country_ref_map_file <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m",
                                  "by_country", "Angola_modis_ref_map_8.tif")
ref_raster <- rast(country_ref_map_file)
plot(ref_raster, main = "Angola MODIS Ref Map (Version 8)")
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
                                  "downscale_SSP1_RCP26", "Downscale_by_country", "Angola", "Angola_script_7")
if (!dir.exists(downscale_output_dir)) {
  dir.create(downscale_output_dir, recursive = TRUE)
}

# -----------------------------------------------------------------------------
# Example: Minimal Fix for Iteration-Based Filenames

downscaleLC_with_progress <- function(ref_map_file_name, LC_deltas_file_list, ...) {
  start_time <- Sys.time()
  cat(sprintf("Starting downscaling process at: %s\n", start_time))
  
  log_file <- file.path(base_dir, "downscaling_log.txt")
  cat(sprintf("Processing started at: %s\n", start_time), file = log_file, append = TRUE)
  
  if (!file.exists(ref_map_file_name)) {
    stop("ERROR: MODIS reference map not found!")
  }
  
  current_ref_map <- ref_map_file_name
  
  for (i in seq_along(LC_deltas_file_list)) {
    file <- LC_deltas_file_list[i]
    years <- gsub(".*_(\\d{4}_\\d{4})\\.tif$", "\\1", file)
    
    log_message <- sprintf("[%d/%d] Processing %s at %s", 
                           i, length(LC_deltas_file_list), file, Sys.time())
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
    
    # Continuous downscaled map (if relevant)
    output_file <- file.path(
      downscale_output_dir, 
      paste0("Downscaled_ref_map_", years, ".tif")
    )
    
    # ----------------------------------------------------------------
    # REMOVE the if() statement and ALWAYS name the file with the
    # current iteration index 'i' in the suffix:
    # ----------------------------------------------------------------
    discrete_output_file <- file.path(
      downscale_output_dir, 
      paste0("Angola_MODIS_PLUM_500m_s1_", years, "_Discrete_Time", i, ".tif")
    )
    
    # Call the downscaleLC function
    downscaleLC(
      ref_map_file_name   = current_ref_map,
      LC_deltas_file_list = list(file),
      output_file_prefix  = paste0(country_name, "_MODIS_PLUM_500m_s1_", years),
      ...
    )
    
    process_end <- Sys.time()
    time_taken <- as.numeric(difftime(process_end, process_start, units = "secs"))
    
    ram_after <- sum(gc()[, 2])
    cat(sprintf("RAM Usage After Processing: %.2f MB\n", ram_after))
    
    # Update the reference map if the new discrete file was written successfully
    if (file.exists(discrete_output_file)) {
      current_ref_map <- discrete_output_file
    } else {
      warning(sprintf(
        "WARNING: Expected reference map not found: %s. Using last available map instead.", 
        discrete_output_file
      ))
      cat(sprintf("WARNING: Missing next reference map: %s\n", discrete_output_file), 
          file = log_file, append = TRUE)
    }
    
    log_message <- sprintf(
      "Completed %s in %.2f seconds | RAM Before: %.2f MB | RAM After: %.2f MB",
      file, time_taken, ram_before, ram_after
    )
    cat(log_message, "\n")
    cat(log_message, "\n", file = log_file, append = TRUE)
  }
  
  end_time <- Sys.time()
  total_time <- as.numeric(difftime(end_time, start_time, units = "mins"))
  cat(sprintf("Downscaling completed in %.2f minutes\n", total_time))
  cat(sprintf("Downscaling completed at: %s (Total: %.2f mins)\n", 
              end_time, total_time), file = log_file, append = TRUE)
}

# -----------------------------------------------------------------------------
# Run the Downscaling Function with Memory Profiling Using profmem

# Load the profmem package (install if necessary)
if (!require(profmem)) install.packages("profmem")
library(profmem)

prof <- profmem({
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
})

print(summary(prof))

# -----------------------------------------------------------------------------

# # Load first downscaled reference map
# first_downscaled_ref_map_path <- file.path(
#   base_dir, "LU_downscalled_dataset", "LU_PLUM_Modis_500m",
#   "downscale_SSP1_RCP26", "Downscale_by_country", "Angola_scr_6",
#   "Angola_MODIS_PLUM_500m_s1_2021_2022_Discrete_Time1.tif"
# )
# 
# first_downscaled_ref_map <- rast(first_downscaled_ref_map_path)
# 
# # Inspect
# print(levels(first_downscaled_ref_map))  # Confirm that LC16 and LC17 are present
# unique(values(first_downscaled_ref_map))  # Confirm that the unique values are as expected
# print(setdiff(colnames(match_LC_classes), paste0("LC", unique(values(first_downscaled_ref_map)))))  # Should return an empty set
# print(levels(angola_modis_raster))  # Confirm that LC16 and LC17 are present))
# 
