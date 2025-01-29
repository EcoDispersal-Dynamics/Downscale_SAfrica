# Libraries needed
library(terra)
library(LandScaleR) # NB: You can install the development version from GitHub 
                    # using devtools::install_github(".../LandScaleR-dev.git")
                    # the complete code is available at line 37 in the `install_packages.R` script

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
                                      "by_country", "Angola_modis_ref_map_2.tif")
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

# Define the function to test downscaleLC 
# Re-define paths

base_dir <- getwd()
country_name <- "Angola"
plum_raster_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26", "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped")

# List all PLUM raster files for Angola
country_LUC_map_files <- list.files(
  path = plum_raster_dir,
  pattern = paste0("^", country_name, "_SSP1_RCP26_LUC_fractions_\\d{4}_\\d{4}\\.tif$"), # Matches files like Angola_SSP1_RCP26_LUC_fractions_2021_2022.tif
  full.names = TRUE
)

# Sort files to ensure chronological order
country_LUC_map_files <- sort(country_LUC_map_files)

# Print the files being used for LC_deltas_file_list to make sure paths are present
cat("Files included in LC_deltas_file_list:\n")
print(country_LUC_map_files)

# Reference map for Angola
country_ref_map_file <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country", paste0(country_name, "_modis_ref_map_2.tif"))

# Output directory
downscale_output_dir <- file.path(base_dir, "LU_downscalled_dataset", "LU_PLUM_Modis_500m", "downscale_SSP1_RCP26", "Downscale_by_country")



# Code with time tracking
# 

# Custom wrapper for downscaleLC with progress messages
downscaleLC_with_progress <- function(ref_map_file_name, LC_deltas_file_list, ...) {
  cat("Starting downscaling process...\n")
  
  for (file in LC_deltas_file_list) {
    # Extract years from the file name
    years <- gsub(".*_(\\d{4}_\\d{4})\\.tif$", "\\1", file)
    cat(sprintf("Processing year(s): %s...\n", years))
    
    # Run the downscaleLC function for the current file
    downscaleLC(
      ref_map_file_name = ref_map_file_name,
      LC_deltas_file_list = list(file), # Process one file at a time
      ...
    )
  }
  
  cat("Downscaling process completed!\n")
}


# Run custom downscaleLC wrapper
downscaleLC_with_progress(
  ref_map_file_name = country_ref_map_file,
  LC_deltas_file_list = country_LUC_map_files, # Pass the sorted list of files
  LC_deltas_type = "proportions",
  ref_map_type = "discrete",
  cell_size_unit = "m",
  assign_ref_cells = FALSE,
  match_LC_classes = match_LC_classes,
  kernel_radius = 1, # Update this if needed
  simulation_type = "deterministic",
  discrete_output_map = FALSE,
  random_seed = 44,
  output_file_prefix = paste0(country_name, "_MODIS_PLUM_500m_s1"), # Include country name in prefix
  output_dir_path = downscale_output_dir
)



# -------------------------------------------------------------------------------

# Second run with different parameters

# Define base directory and paths
base_dir <- getwd()
country_name <- "Angola"

# Manually specify the two raster files for testing
LC_deltas_file_list <- list(
  file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26", 
            "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped", 
            "Angola_SSP1_RCP26_LUC_fractions_2021_2022.tif"),
  
  file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26", 
            "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped", 
            "Angola_SSP1_RCP26_LUC_fractions_2022_2023.tif")
)

# Print file paths to verify correctness
cat("Testing with the following raster files:\n")
print(LC_deltas_file_list)

# Reference map file for Angola
country_ref_map_file <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                  "by_country", paste0(country_name, "_modis_ref_map_2.tif"))

# Output directory
downscale_output_dir <- file.path(base_dir, "LU_downscalled_dataset", "LU_PLUM_Modis_500m", 
                                  "downscale_SSP1_RCP26", "Downscale_by_country")

# Run the downscaleLC function separately for each raster file
downscaleLC(
  ref_map_file_name = country_ref_map_file,
  LC_deltas_file_list = LC_deltas_file_list,  # Manually defined file list
  LC_deltas_type = "proportions",
  ref_map_type = "discrete",
  cell_size_unit = "m",
  assign_ref_cells = FALSE,
  match_LC_classes = match_LC_classes,
  kernel_radius = 1,  # Update this if needed
  simulation_type = "deterministic",
  discrete_output_map = FALSE,
  random_seed = 44,
  output_file_prefix = paste0(country_name, "_MODIS_PLUM_500m_s1"),  # Include country name in prefix
  output_dir_path = downscale_output_dir
)

