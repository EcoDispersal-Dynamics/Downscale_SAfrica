

# Libraries needed
library(terra)
gdal(lib="")
library(LandScaleR) # NB: You can install the development version from GitHub 
                    # using devtools::install_github(".../LandScaleR-dev.git")
                    # the complete code is available at line 37 in the `install_packages.R` script
#library(sf)
#library(rgdal)
# Skip the following code chunk since the data has already been processed

# This first code chuck is for data processing: Specific country data extraction
# and reprojecting the data to a common coordinate reference system (CRS) UTM Zone 33
# using the MODIS raster as the reference raster for the area extent 



# Base directory and paths
base_dir <- getwd()
# shapefile_path <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")
# modis_raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "modis_ref_map_2.tif")
# modis_output_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country")
# plum_rasters_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26", "SSP1_RCP26_fraction")
# plum_output_dir <- file.path(plum_rasters_dir, "SSP1_RCP26_fraction_croped")
# 
# # # Ensure output directories exist
# # dir.create(modis_output_dir, showWarnings = FALSE, recursive = TRUE)
# # dir.create(plum_output_dir, showWarnings = FALSE, recursive = TRUE)
# 
# # Load region/countries shapefile and MODIS raster
# regions <- vect(shapefile_path)
# modis_raster <- rast(modis_raster_path)
# 
# # Reproject shapefile and MODIS raster to UTM zone 33 since I am testing with Angola
# utm_crs <- "EPSG:32633"  # UTM zone 33
# regions_utm <- project(regions, utm_crs)
# modis_raster_utm <- project(modis_raster, utm_crs)
# 
# # List all original PLUM raster files for the SSP1_RCP26 scenario
# # that need to be cropped and projected to match the Angola MODIS raster
# plum_raster_files <- list.files(plum_rasters_dir, pattern = "SSP1_RCP26_LUC_fractions_.*\\.tif$", full.names = TRUE)
# 
# # Uncomment the function if needs to process the data

# # Crop and save rasters for each country
# for (country in unique(regions_utm$CNTRY_NAME)) {
#   # Get the polygon for the current country
#   country_polygon <- regions_utm[regions_utm$CNTRY_NAME == country, ]
#   
#   # Crop and save the MODIS raster
#   modis_cropped <- crop(modis_raster_utm, country_polygon)
#   modis_masked <- mask(modis_cropped, country_polygon)
#   modis_output_path <- file.path(modis_output_dir, paste0(country, "_modis_ref_map_2.tif"))
#   writeRaster(modis_masked, modis_output_path, overwrite = TRUE)
#   
#   # Crop and save PLUM rasters
#   for (plum_raster_path in plum_raster_files) {
#     plum_raster <- rast(plum_raster_path)
#     plum_raster_utm <- project(plum_raster, utm_crs)  # Reproject PLUM raster to UTM zone 33
#     plum_cropped <- crop(plum_raster_utm, country_polygon)
#     plum_masked <- mask(plum_cropped, country_polygon)
#     
#     # Create the output filename
#     plum_raster_name <- basename(plum_raster_path)
#     plum_output_path <- file.path(plum_output_dir, paste0(country, "_", plum_raster_name))
#     writeRaster(plum_masked, plum_output_path, overwrite = TRUE)
#   }
# }

# End of cropping and re-projection script




#--------------------------------------------------------------------------------

# Inspected the rasters to ensure they are correctly cropped and masked
# And that the extents, resolutions, and coordinate reference systems match
# 
# Start of inspection

# Message to indicate start of inspection
cat("Inspecting Angola MODIS and PLUM raster data...\n")

# Define paths to Angola rasters
base_dir <- getwd()
angola_modis_raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                      "by_country", "Angola_modis_ref_map_3.tif")
angola_plum_raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", 
                                     "SSP1_RCP26", "SSP1_RCP26_fraction", 
                                     "SSP1_RCP26_fraction_croped", 
                                     "Angola_SSP1_RCP26_LUC_fractions_2021_2022.tif")

# Load rasters
angola_modis_raster <- rast(angola_modis_raster_path)
unique(angola_modis_raster)

angola_plum_raster <- rast(angola_plum_raster_path)

# Perform inspection
results <- list(
  "Head of Angola MODIS Raster" = head(values(angola_modis_raster)),
  "Head of Angola PLUM Raster" = head(values(angola_plum_raster)),
  "Unique Values in Angola MODIS Raster" = unique(values(angola_modis_raster)),
  "Unique Values in Angola PLUM Raster" = unique(values(angola_plum_raster)),
  "CRS Comparison" = list("MODIS CRS" = crs(angola_modis_raster), "PLUM CRS" = crs(angola_plum_raster)),
  "Extent Comparison" = list("MODIS Extent" = ext(angola_modis_raster), "PLUM Extent" = ext(angola_plum_raster)),
  "Resolution Comparison" = list("MODIS Resolution" = res(angola_modis_raster), "PLUM Resolution" = res(angola_plum_raster)),
  "Units Comparison" = list("MODIS Units" = crs(angola_modis_raster, describe = TRUE)$UNIT, 
                            "PLUM Units" = crs(angola_plum_raster, describe = TRUE)$UNIT),
  "Data Type Comparison" = list("MODIS Data Type" = datatype(angola_modis_raster), "PLUM Data Type" = datatype(angola_plum_raster)),
  "Layer Count" = list("MODIS Layer Count" = nlyr(angola_modis_raster), "PLUM Layer Count" = nlyr(angola_plum_raster)),
  "Summary Statistics" = list("MODIS Summary" = global(angola_modis_raster, fun = "mean", na.rm = TRUE),
                              "PLUM Summary" = global(angola_plum_raster, fun = "mean", na.rm = TRUE))
)

# Print all inspection results
print(results)


#-------------------------------------------------------------------------------
#
# Test the downscaling script on a single country (Angola)
# 
# Start bz generating a dznamic Transition Matrix
#
# Extract PLUM layer names for row names
plum_layer_names <- names(angola_plum_raster)
plum_layer_names
unique(values(angola_modis_raster))
unique(angola_modis_raster)

# Extract unique MODIS class values for column names
modis_classes <- unique(values(angola_modis_raster)) # Extract unique values
modis_classes <- sort(modis_classes[!is.na(modis_classes)]) # Remove NA and sort

# Create the matching matrix dynamically with appropriate dimensions
match_LC_classes <- matrix(
  data = 0, # Initialize the matrix with zeros
  nrow = length(plum_layer_names), # Number of rows matches the PLUM layers
  ncol = length(modis_classes),   # Number of columns matches the unique MODIS classes
  dimnames = list(plum_layer_names, paste0("LC", modis_classes)) # Dynamic row and column names
)

# Print the matrix for inspection
cat("Matching Matrix Structure:\n")
print(match_LC_classes)             # You will see that the matrix is initialized with zeros only
                                    # In column names, LC15 is missing because I removed it from the MODIS raster
                                    # I originally represented Ice and Snow, which is not significantly present in sub-Saharan Africa
# Note that Agrivoltaic and Photovoltaic are also missing from rows (rows refer to PLUM year-to-year change raster).


# Populate the matrix with your preferred allocations, note our discussion on the allocations % strategy
match_LC_classes["Cropland", c("LC12", "LC14")] <- c(0.5, 0.5)           # Cropland allocations
match_LC_classes["Pasture", "LC10"] <- 1                                 # Pasture allocation
match_LC_classes["TimberForest", c("LC5", "LC7", "LC9")] <- c(0.6, 0.2, 0.2) # TimberForest allocations
match_LC_classes["UnmanagedForest", c("LC4", "LC5", "LC6")] <- c(0.4, 0.3,0.3) # UnmanagedForest allocations
match_LC_classes["OtherNatural", c("LC12", "LC14")] <- c(0.5, 0.5)       # OtherNatural allocations
match_LC_classes["Barren", "LC14"] <- 1                                  # Barren allocation
match_LC_classes["Urban", "LC11"] <- 1                                  # Urban allocation

# Print the updated matrix for inspection
cat("Updated Matching Matrix:\n")
print(match_LC_classes)         # You will see that the M.Matrix is updated with preferred % allocations     


#-------------------------------------------------------------------------------

# Define the function to test downscaleLC in the fourth script
#
# 444444444444444444444444444444444444444444444444444444444444444444444444444444
# Test with updated reference maps at every iteration
# RAM traking and logging
# Skipping missing files and logging them

# Define paths and setup
base_dir <- getwd()
country_name <- "Angola"

# Path to the original MODIS reference map (used only in the first iteration)
country_ref_map_file <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                  "by_country", paste0(country_name, "_modis_ref_map_3.tif"))

# Directory containing PLUM transition maps
plum_raster_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", 
                             "SSP1_RCP26", "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped")

# List and sort all PLUM transition maps (2021_2022 to 2099_2100)
country_LUC_map_files <- list.files(
  path = plum_raster_dir,
  pattern = paste0("^", country_name, "_SSP1_RCP26_LUC_fractions_\\d{4}_\\d{4}\\.tif$"),
  full.names = TRUE
)
country_LUC_map_files <- sort(country_LUC_map_files)  # Ensure chronological order

# Ensure transition maps exist
if (length(country_LUC_map_files) == 0) {
  stop("ERROR: No PLUM transition maps found in: ", plum_raster_dir)
}

# Define the output directory for downscaled results
downscale_output_dir <- file.path(base_dir, "LU_downscalled_dataset", "LU_PLUM_Modis_500m", 
                                  "downscale_SSP1_RCP26", "Downscale_by_country", country_name)

# Ensure the output directory exists
if (!dir.exists(downscale_output_dir)) {
  dir.create(downscale_output_dir, recursive = TRUE)
}


# Define the dynamic downscaling function with RAM monitoring
downscaleLC_with_progress <- function(ref_map_file_name, LC_deltas_file_list, ...) {
  start_time <- Sys.time()
  cat(sprintf("Starting downscaling process at: %s\n", start_time))
  
  log_file <- file.path(base_dir, "downscaling_log.txt")
  writeLines(sprintf("Processing started at: %s", start_time), log_file)
  
  # Ensure the initial reference map exists
  if (!file.exists(ref_map_file_name)) {
    stop("ERROR: MODIS reference map not found!")
  }
  
  # Use MODIS as the first reference map
  current_ref_map <- ref_map_file_name  
  
  for (i in seq_along(LC_deltas_file_list)) {
    file <- LC_deltas_file_list[i]
    years <- gsub(".*_(\\d{4}_\\d{4})\\.tif$", "\\1", file)
    
    log_message <- sprintf("[%d/%d] Processing %s at %s", i, length(LC_deltas_file_list), file, Sys.time())
    writeLines(log_message, log_file, append=TRUE)
    cat(log_message, "\n")
    
    # Check if transition file exists
    if (!file.exists(file)) {
      warning(sprintf("WARNING: Transition map missing, skipping: %s\n", file))
      writeLines(sprintf("WARNING: File %s is missing!", file), log_file, append=TRUE)
      next
    }
    
    # Monitor RAM before processing
    ram_before <- sum(gc()[, 2])  # Get used memory before processing
    cat(sprintf("RAM Usage Before Processing: %.2f MB\n", ram_before))
    
    process_start <- Sys.time()
    
    # Define output file paths for this timestep
    output_file <- file.path(downscale_output_dir, paste0("Downscaled_ref_map_", years, ".tif"))
    discrete_output_file <- file.path(downscale_output_dir, paste0("Downscaled_ref_map_", years, "_Discrete_Time", i, ".tif"))
    
    # Run downscaling function
    downscaleLC(
      ref_map_file_name = current_ref_map,  # Use current reference map
      LC_deltas_file_list = list(file),  
      output_file_prefix = paste0(country_name, "_MODIS_PLUM_500m_s1_", years),
      ...
    )
    
    process_end <- Sys.time()
    time_taken <- as.numeric(difftime(process_end, process_start, units="secs"))
    
    # Monitor RAM after processing
    ram_after <- sum(gc()[, 2])  # Get used memory after processing
    cat(sprintf("RAM Usage After Processing: %.2f MB\n", ram_after))
    
    # Ensure the reference map updates correctly for the next timestep
    if (file.exists(discrete_output_file)) {
      current_ref_map <- discrete_output_file  # Update reference to the latest discrete map
    } else {
      warning(sprintf("WARNING: Expected reference map not found: %s. Using last available map instead.", discrete_output_file))
      writeLines(sprintf("WARNING: Missing next reference map: %s", discrete_output_file), log_file, append=TRUE)
    }
    
    log_message <- sprintf("Completed %s in %.2f seconds | RAM Before: %.2f MB | RAM After: %.2f MB", 
                           file, time_taken, ram_before, ram_after)
    writeLines(log_message, log_file, append=TRUE)
    cat(log_message, "\n")
  }
  
  end_time <- Sys.time()
  total_time <- as.numeric(difftime(end_time, start_time, units="mins"))
  cat(sprintf("Downscaling completed in %.2f minutes\n", total_time))
  writeLines(sprintf("Downscaling completed at: %s (Total: %.2f mins)", end_time, total_time), log_file, append=TRUE)
}



# Run the downscaling function
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


# End of the 4th downscaling script for Angola


