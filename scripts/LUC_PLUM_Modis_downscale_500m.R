# Author: Markus Shiweda
# Date: 2024-10-23

# Load necessary libraries
library(LandScaleR)
library(terra)

# Set the base directory dynamically to the current working directory
base_dir <- getwd()


# Paths for MODIS and PLUM data
modis_reference_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "MODIS_LandCover_2021_SouthernAfrica.tif")
masked_scenario_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", "masked_SSP1_RCP26")
downscale_base_dir <- file.path(base_dir, "LU_downscalled_dataset", "LU_PLUM_Modis_500m", "downscale_SSP1_RCP26")

# Ensure the output directory exists
if (!dir.exists(downscale_base_dir)) {
  dir.create(downscale_base_dir, recursive = TRUE)
}



# Load the masked PLUM file for 2022 to extract layer names to be used in the layer classes matching matrix
masked_plum_file_path <- file.path(masked_scenario_dir, "masked_s1_2022_SSP1_RCP26.tif")
masked_plum_raster <- rast(masked_plum_file_path)

# Extract and inspect layer names from the PLUM raster
plum_layer_names <- names(masked_plum_raster)   
print(plum_layer_names)

# Load and inspect MODIS raster, reordering layers based on ascending class values
modis_raster <- rast(modis_reference_path)
plot(modis_raster, main = "MODIS Raster Classes")
unique_modis_classes <- unique(values(modis_raster))
unique_modis_classes
levels(modis_raster)

###
### The code below was used to modify the original MODIS file from Google Eather Engine (GEE)
### The modified file was saved by REPLACING the original file from GEE, so the original file was removed
### So, the MODIS file loaded above as `modis_raster` is the modified file that is ready to use now.
### 
### That means the code below is not needed to run again, but it is kept here for reference.
### 
### To avoid running it again, it is wrapped in a conditional statement
### Set `run_modis_processing <- TRUE` ONLY if you need to run this block again
### To prepare a raw MODIS file from GEE, you can use the original file from GEE and run this block




# Extract unique non-NA values
unique_values <- sort(unique(values(modis_raster), na.rm = TRUE))

# Create a mapping from original values to sequential values (1, 2, ..., length of unique_values)
value_map <- data.frame(from = unique_values, to = seq_along(unique_values))

# Ensure the mapping is complete
print(value_map)

# Reclassify the MODIS raster based on the mapping
modis_raster <- classify(modis_raster, rcl = as.matrix(value_map))

# Verify the updated values in the raster
unique_modis_classes_2 <- unique(values(modis_raster))
print(unique_modis_classes_2)

# MODIS class values
class_values <- 1:17

# Reassign levels with proper names
modis_class_labels <- c(
  "Evergreen Needleleaf Forests",
  "Evergreen Broadleaf Forests",
  "Deciduous Needleleaf Forests",
  "Deciduous Broadleaf Forests",
  "Mixed Forests",
  "Closed Shrublands",
  "Open Shrublands",
  "Woody Savannas",
  "Savannas",
  "Grasslands",
  "Permanent Wetlands",
  "Croplands",
  "Urban and Built-Up",
  "Cropland/Natural Vegetation Mosaics",
  "Snow and Ice",
  "Barren or Sparsely Vegetated",
  "Water Bodies"
)

# Create levels data frame
levels_df <- data.frame(id = class_values, name = modis_class_labels)

# Assign levels to the raster
levels(modis_raster) <- levels_df
plot(modis_raster, main = "MODIS Raster Classes")

# # Save the updated MODIS reference raster
# modis_ref_map <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "modis_ref_map.tif")
# writeRaster(modis_raster, modis_ref_map, overwrite = TRUE)




#------------------------------------------------------------------------------


# The following function worked after I have included all plum classes in the match_LC_classes matrix
# That is, I have included all the classes in the match_LC_classes matrix, 
# even if they are not present in the MODIS reference map and are not needed 
# to be downscaled. This is because the function requires a complete mapping of all classes in the PLUM data to the MODIS reference map classes.
# This means even though all PLUM classes are included in the match_LC_classes matrix,
# They are assigned a zero (0) value in the matrix, indicating that they are not to be downscaled.


# Downscale PLUM data for years 2022 to 2030 using updated paths and iterative reference map updates

# Load modis reference map, ignore this, it does not work
modis_ref_map <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "modis_ref_map.tif")
modis_ref_map <- rast(modis_ref_map)
plot(modis_ref_map, main = "MODIS Reference Map")
unique_ref_map_classes <- unique(values(modis_ref_map))
unique_ref_map_classes
levels(modis_ref_map)

# Define LULC classes to allocate and ensure all PLUM layers are included in the match_LC_classes matrix
LULC_classes <- plum_layer_names  # Use all PLUM layers

# Create the matching matrix row by row, aligning with plum_layer_names
match_LC_classes_1 <- matrix(
  data = c(
    # cell_area (PLUM) -> Not allocated (placeholder row of zeros)
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    
    # Cropland (PLUM) -> MODIS Cropland (12) and Cropland/Natural Vegetation Mosaics (14)
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.5, 0, 0.5, 0, 0, 0),
    
    # Pasture (PLUM) -> Grasslands
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0),
    
    # TimberForest (PLUM) -> Mixed Forests and Closed/Open Shrublands
    c(0, 0, 0, 0, 0.6, 0.2, 0, 0.2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    
    # CarbonForest (PLUM) -> Mixed Forests, Open Shrublands, Woody Savannas
    c(0, 0, 0, 0, 0.5, 0, 0.3, 0.2, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    
    # UnmanagedForest (PLUM) -> Woody Savannas, Grasslands, Barren or Sparsely Vegetated
    c(0, 0, 0, 0, 0, 0, 0.4, 0, 0.3, 0, 0, 0, 0, 0, 0.3, 0, 0),
    
    # OtherNatural (PLUM) -> Croplands and Cropland/Natural Vegetation Mosaics
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.5, 0, 0.5, 0, 0, 0),
    
    # Photovoltaics (PLUM) -> Not allocated (placeholder row of zeros)
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    
    # Agrivoltaics (PLUM) -> Not allocated (placeholder row of zeros)
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    
    # Barren (PLUM) -> Barren or Sparsely Vegetated
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0),
    
    # Urban (PLUM) -> Urban and Built-Up
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0),
    
    # Protection (PLUM) -> Not allocated (placeholder row of zeros)
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    
    # cell_area (PLUM duplicate) -> Not allocated (placeholder row of zeros)
    c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  ),
  byrow = TRUE,
  nrow = length(plum_layer_names),  # Match number of PLUM layers
  ncol = 17,  # Match number of MODIS classes (1 to 17)
  dimnames = list(plum_layer_names, levels(modis_ref_map)[[1]]$name)  # PLUM and MODIS names as row/column names
)

# Verify the matrix setup
print(match_LC_classes_1)

# Check dimensions
print(dim(match_LC_classes_1))

# Verify all PLUM layers are accounted for
if (!all(plum_layer_names %in% rownames(match_LC_classes_1))) {
  stop("Some PLUM layers are not included in the match_LC_classes matrix.")
}



# Check matrix dimensions
expected_rows <- length(plum_layer_names)
expected_cols <- 17  # Number of MODIS classes
actual_dims <- dim(match_LC_classes_1)

if (!all(actual_dims == c(expected_rows, expected_cols))) {
  stop(paste("Matrix dimensions mismatch. Expected:", 
             expected_rows, "rows x", expected_cols, "columns.",
             "Got:", actual_dims[1], "rows x", actual_dims[2], "columns."))
}

# Check if all matrix columns are present in the raster levels
all(colnames(match_LC_classes_1) %in% levels(modis_raster)[[1]]$name)
identical(colnames(match_LC_classes_1), levels(modis_ref_map)[[1]]$name)


#-------------------------------------------------------------------------------

# Test code 1 for downscaling


# Downscaling in the loop
for (year in 2022:2030) {
  masked_plum_file <- file.path(masked_scenario_dir, "2022-2030", paste0("masked_s1_", year, "_SSP1_RCP26.tif"))
  
  if (!file.exists(masked_plum_file)) {
    cat("File not found for year:", year, "\n")
    next
  }
  
  downscale_plum_file <- file.path(downscale_base_dir, paste0("MODIS_PLUM_500m_s1_", year, "_SSP1_RCP26.tif"))
  
  cat("Processing downscaling for year:", year, "\n")
  
  downscaleLC(
    ref_map_file_name = modis_ref_map,
    LC_deltas_file_list = list(masked_plum_file),
    LC_deltas_classes = LULC_classes,
    ref_map_type = "discrete",
    cell_size_unit = "m",
    match_LC_classes = match_LC_classes_1,
    kernel_radius = 1,
    simulation_type = "deterministic",
    discrete_output_map = TRUE,
    random_seed = 44,
    output_file_prefix = paste0("MODIS_PLUM_500m_s1_", year),
    output_dir_path = downscale_plum_file
  )
  
  cat("Downscaled PLUM", year, "saved at:", downscale_plum_file, "\n")
}


#-------------------------------------------------------------------------------


# Test code 2 for downscaling

# Downscaling without a loop

# Paths for the MODIS reference map and PLUM files for 2022 and 2023
masked_plum_file_2022 <- file.path(masked_scenario_dir, "masked_s1_2022_SSP1_RCP26.tif")
masked_plum_file_2023 <- file.path(masked_scenario_dir, "masked_s1_2023_SSP1_RCP26.tif")

# crteate raster
masked_plum_raster_2022 <- rast(masked_plum_file_2022)
masked_plum_raster_2023 <- rast(masked_plum_file_2023)




# check the raster names
masked_plum_names_2022 <- names(masked_plum_raster_2022)
masked_plum_names_2023 <- names(masked_plum_raster_2023)
masked_plum_names_2022
masked_plum_names_2023


# Matjch extends to see if it works


# Load the rasters      ********************************************
modis_extent <- ext(modis_ref_map)
plum_extent_2022 <- ext(masked_plum_raster_2022)
plum_extent_2023 <- ext(masked_plum_raster_2023)

# Print the extents
cat("MODIS extent:\n")
print(modis_extent)

cat("\nPLUM 2022 extent:\n")
print(plum_extent_2022)

cat("\nPLUM 2023 extent:\n")
print(plum_extent_2023)

# Check for overlap using logical comparisons
overlap_2022 <- modis_extent[1] <= plum_extent_2022[2] && modis_extent[2] >= plum_extent_2022[1] &&
  modis_extent[3] <= plum_extent_2022[4] && modis_extent[4] >= plum_extent_2022[3]

overlap_2023 <- modis_extent[1] <= plum_extent_2023[2] && modis_extent[2] >= plum_extent_2023[1] &&
  modis_extent[3] <= plum_extent_2023[4] && modis_extent[4] >= plum_extent_2023[3]

cat("\nOverlap with PLUM 2022 extent:", overlap_2022, "\n")
cat("Overlap with PLUM 2023 extent:", overlap_2023, "\n")

#                     **********************************************



downscale_output_dir <- downscale_base_dir  # Directory for downscaled outputs

# Downscaling function for multiple years (2022 and 2023 loaded separately)

downscaleLC(
  ref_map_file_name = modis_ref_map,              # MODIS reference map
  LC_deltas_file_list = list(masked_plum_file_2022,      # List of PLUM files for both years
                             masked_plum_file_2023),
  LC_deltas_classes = LULC_classes,                      # Land cover classes in PLUM data
  ref_map_type = "discrete",                             # Reference map type: discrete
  cell_size_unit = "m",                                  # Units in meters
  match_LC_classes = match_LC_classes_1,                   # Matching matrix for LULC classes
  kernel_radius = 1,                                     # Radius for kernel density calculation
  simulation_type = "deterministic",                     # Simulation type
  discrete_output_map = TRUE,                            # Generate discrete output map
  random_seed = 44,                                      # Seed for reproducibility
  output_file_prefix = "MODIS_PLUM_500m_s1",   # Prefix for output files
  output_dir_path = downscale_output_dir                 # Directory to save downscaled files
)

cat("Downscaled PLUM 2022 and 2023 saved at:", downscale_output_dir, "\n")


#-------------------------------------------------------------------------------






