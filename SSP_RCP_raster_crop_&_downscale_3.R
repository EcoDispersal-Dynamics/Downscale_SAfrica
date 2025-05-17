

# Libraries needed
library(terra)
library(LandScaleR) # NB: You can install the development version from GitHub 
                    # using devtools::install_github(".../LandScaleR-dev.git")
                    # the complete code is available at line 37 in the `install_packages.R` script
#library(sf)
#library(rgdal)
# Skip the following code chunk since the data has already been processed

# This first code chuck is for data processing: Specific country data extraction
# and reprojecting the data to a common coordinate reference system (CRS) UTM Zone 33
# using the MODIS raster as the reference raster for the area extent 


# ============================================================
# Recreate Reclassified Country-Specific MODIS Rasters (UTM, Global LC Names)
# ============================================================

library(terra)

# === Setup ===
base_dir <- getwd()
shapefile_path <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")
modis_raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "modis_ref_map_2.tif")
modis_output_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country")
dir.create(modis_output_dir, showWarnings = FALSE, recursive = TRUE)

# === Load shapefile and MODIS raster ===
regions <- vect(shapefile_path)
modis_raster <- rast(modis_raster_path)

# === Global MODIS class-to-LC mapping ===
global_modis_mapping <- data.frame(
  value = 1:17,
  name = paste0("LC", 1:17)
)

# === Helper: UTM CRS by longitude ===
get_utm_crs <- function(longitude, is_southern = FALSE) {
  zone <- floor((longitude + 180) / 6) + 1
  epsg <- ifelse(is_southern, 32700 + zone, 32600 + zone)
  return(paste0("EPSG:", epsg))
}

# === Process Each Country ===
for (country in unique(regions$CNTRY_NAME)) {
  cat("\n--- Processing:", country, "---\n")
  
  country_polygon <- regions[regions$CNTRY_NAME == country, ]
  centroid <- crds(centroids(country_polygon))
  longitude <- centroid[1]
  latitude <- centroid[2]
  is_southern <- latitude < 0
  
  utm_crs <- get_utm_crs(longitude, is_southern)
  country_polygon_utm <- project(country_polygon, utm_crs)
  modis_raster_utm <- project(modis_raster, utm_crs)
  
  modis_cropped <- crop(modis_raster_utm, country_polygon_utm)
  modis_masked <- mask(modis_cropped, country_polygon_utm)
  
  # === Extract values and reclassify to consistent global LC names ===
  present_vals <- sort(na.omit(unique(values(modis_masked))))
  if (length(present_vals) == 0) {
    cat("⚠️ No values found for:", country, "\n")
    next
  }
  
  present_mapping <- global_modis_mapping[global_modis_mapping$value %in% present_vals, ]
  reclass_mat <- matrix(ncol = 3, nrow = nrow(present_mapping))
  for (i in seq_len(nrow(present_mapping))) {
    val <- present_mapping$value[i]
    reclass_mat[i, ] <- c(val - 0.5, val + 0.5, val)
  }
  
  modis_reclassified <- classify(modis_masked, rcl = reclass_mat, include.lowest = TRUE)
  levels(modis_reclassified) <- list(present_mapping)
  
  out_path <- file.path(modis_output_dir, paste0(country, "_modis_ref_map_8.tif"))
  writeRaster(modis_reclassified, out_path, overwrite = TRUE)
  cat("✅ Saved:", out_path, "\n")
}

cat("\n🎯 All reclassified MODIS country rasters saved with consistent LC names and UTM CRS.\n")






















#--------------------------------------------------------------------------------
# Base directory and paths
base_dir <- getwd()
shapefile_path <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")
modis_raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "modis_ref_map_2.tif")
modis_output_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country")
plum_rasters_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26", "SSP1_RCP26_fraction")
plum_rasters_dir
plum_output_dir <- file.path(plum_rasters_dir, "SSP1_RCP26_fraction_croped")

# Inspect original PLUM raster files

file.exists(file.path(plum_rasters_dir, "SSP1_RCP26_LUC_fractions_2021_2022.tif"))

full_path <- file.path(plum_rasters_dir, "SSP1_RCP26_LUC_fractions_2029_2030.tif")
plum_ras_ori <- rast(full_path)
plot(plum_ras_ori)






# Ensure output directories exist
dir.create(modis_output_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(plum_output_dir, showWarnings = FALSE, recursive = TRUE)

# Load region/countries shapefile and MODIS raster
regions <- vect(shapefile_path)
modis_raster <- rast(modis_raster_path)

# Function to determine UTM zone based on longitude
get_utm_crs <- function(longitude, is_southern = FALSE) {
  zone <- floor((longitude + 180) / 6) + 1  # Calculate UTM zone
  epsg <- ifelse(is_southern, 32700 + zone, 32600 + zone)  # EPSG code: 326XX (N), 327XX (S)
  return(paste0("EPSG:", epsg))
}

# List all original PLUM raster files for the SSP1_RCP26 scenario
plum_raster_files <- list.files(plum_rasters_dir, pattern = "SSP1_RCP26_LUC_fractions_.*\\.tif$", full.names = TRUE)

# Crop and save rasters for each country
for (country in unique(regions$CNTRY_NAME)) {
  # Get the polygon for the current country
  country_polygon <- regions[regions$CNTRY_NAME == country, ]
  
  # Compute the centroid longitude to determine UTM zone
  centroid <- crds(centroids(country_polygon))
  longitude <- centroid[1]  # Extract longitude
  
  # Check if country is in the southern hemisphere (latitude < 0)
  latitude <- centroid[2]
  is_southern <- latitude < 0
  
  # Get correct UTM projection
  utm_crs <- get_utm_crs(longitude, is_southern)
  
  # Reproject country's polygon to the correct UTM zone
  country_polygon_utm <- project(country_polygon, utm_crs)
  
  # Reproject MODIS raster to the correct UTM zone
  modis_raster_utm <- project(modis_raster, utm_crs)
  
  # Crop and save the MODIS raster
  modis_cropped <- crop(modis_raster_utm, country_polygon_utm)
  modis_masked <- mask(modis_cropped, country_polygon_utm)
  modis_output_path <- file.path(modis_output_dir, paste0(country, "_modis_ref_map_2.tif"))
  # writeRaster(modis_masked, modis_output_path, overwrite = TRUE)
  
  # Process and save PLUM rasters for the current country
  for (plum_raster_path in plum_raster_files) {
    plum_raster <- rast(plum_raster_path)
    
    # Reproject PLUM raster to the correct UTM zone
    plum_raster_utm <- project(plum_raster, utm_crs)
    
    # Crop and mask
    plum_cropped <- crop(plum_raster_utm, country_polygon_utm)
    plum_masked <- mask(plum_cropped, country_polygon_utm)
    
    # Create the output filename
    plum_raster_name <- basename(plum_raster_path)
    plum_output_path <- file.path(plum_output_dir, paste0(country, "_", plum_raster_name))
    plum_output_path
    # writeRaster(plum_masked, plum_output_path, overwrite = TRUE)
  }
}


# End of cropping and re-projection script

#--------------------------------------------------------------------------------

# Experiment 1
# Reclassifying modis reference maps for each country

# Define the path to the reference dataset
modis_ref_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country")

# List all countries (assuming each country has a file in the directory)
country_files <- list.files(modis_ref_dir, pattern = "_modis_ref_map_2\\.tif$", full.names = TRUE)

# Define a global MODIS class-to-LC mapping
global_modis_mapping <- data.frame(
  value = 1:17,  # All possible MODIS classes
  name = c("LC1", "LC2", "LC3", "LC4", "LC5", "LC6", "LC7", "LC8", "LC9", 
           "LC10", "LC11", "LC12", "LC13", "LC14", "LC15", "LC16", "LC17")  
)

# Process each country's MODIS reference map
for (country_path in country_files) {
  # Extract country name from the file path
  country_name <- gsub("_modis_ref_map_2\\.tif$", "", basename(country_path))
  cat(sprintf("\nProcessing: %s\n", country_name))
  
  # Load the MODIS raster for the country
  modis_raster <- rast(country_path)
  
  # Extract original levels (full attribute table with all 17 MODIS classes)
  orig_levels <- levels(modis_raster)[[1]]
  if (is.null(orig_levels)) {
    warning(sprintf("No category levels found for %s. Skipping...", country_name))
    next
  }
  
  cat("Original Levels from Attribute Table:\n")
  print(orig_levels)
  
  # Extract unique values actually present in the raster
  existing_classes <- unique(values(modis_raster))
  existing_classes <- existing_classes[!is.na(existing_classes)]  # Remove NA values
  
  cat("Classes Present in Raster:\n")
  print(existing_classes)
  
  # Identify missing classes (those in levels() but not in unique(values()))
  missing_classes <- setdiff(orig_levels$value, existing_classes)
  
  cat("Classes Missing in Raster:\n")
  print(missing_classes)
  
  # Remove missing classes from the attribute table
  new_levels <- orig_levels[!orig_levels$value %in% missing_classes, ]
  
  # **Manually assign LC names using global mapping**
  new_levels$name <- global_modis_mapping$name[match(new_levels$value, global_modis_mapping$value)]
  
  # Check if the "name" column exists, stop if missing
  if (!"name" %in% colnames(new_levels) || any(is.na(new_levels$name))) {
    stop(sprintf("Error: 'name' column missing after assigning class names for %s", country_name))
  }
  
  cat("Updated Levels for", country_name, ":\n")
  print(new_levels)
  
  # Create a reclassification matrix based on available values
  reclass_mat <- matrix(nrow = nrow(new_levels), ncol = 3)
  for (i in seq_len(nrow(new_levels))) {
    old_val <- new_levels$value[i]
    new_val <- i  # Ensures sequential values (1,2,3,...) for downscaleLC
    reclass_mat[i, ] <- c(old_val - 0.5, old_val + 0.5, new_val)
  }
  cat("Reclassification Matrix for", country_name, ":\n")
  print(reclass_mat)
  
  # Reclassify the raster
  modis_raster_new <- classify(modis_raster, rcl = reclass_mat, include.lowest = TRUE)
  
  # Update levels with consistent LC names
  new_levels$new_value <- seq_len(nrow(new_levels))  # Assign sequential numbers
  levels(modis_raster_new) <- list(new_levels[, c("new_value", "name")])
  
  cat("New Levels in Reclassified Raster for", country_name, ":\n")
  print(levels(modis_raster_new))
  
  # Save the reclassified MODIS reference map (now as `_modis_ref_map_8.tif`)
  output_path <- file.path(modis_ref_dir, paste0(country_name, "_modis_ref_map_8.tif"))
  writeRaster(modis_raster_new, output_path, overwrite = TRUE)
  cat(sprintf("✅ Saved reclassified map for %s: %s\n", country_name, output_path))
}

cat("\n✅ All countries' MODIS reference maps have been successfully reclassified and saved.\n")



#--------------------------------------------------------------------------------


# Inspected the rasters to ensure they are correctly cropped and masked
# And that the extents, resolutions, and coordinate reference systems match
# 
# Start of inspection

# Message to indicate start of inspection
cat("Inspecting Angola MODIS and PLUM raster data...\n")

# Define paths to Angola rasters
base_dir <- getwd()
angola_modis_raster <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                      "by_country", "Angola_modis_ref_map_8.tif")


Namibia_modis_raster <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                      "by_country", "Namibia_modis_ref_map_8.tif")

Botswana_modis_raster <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                      "by_country", "Botswana_modis_ref_map_8.tif")

Mauritius_modis_raster <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                      "by_country", "Mauritius_modis_ref_map_8.tif")


# Create raster for random countries for inspection
angola_modis_raster <- rast(angola_modis_raster)
Namibia_modis_raster <- rast(Namibia_modis_raster)
Botswana_modis_raster <- rast(Botswana_modis_raster)
Mauritius_modis_raster <- rast(Mauritius_modis_raster)

summary(angola_modis_raster)
summary(Namibia_modis_raster)
summary(Botswana_modis_raster)
summary(Mauritius_modis_raster)
unique(angola_modis_raster)
plot(angola_modis_raster)
unique(levels(angola_modis_raster))
unique(Namibia_modis_raster)
# Plot namibia LC13 class 
plot(Namibia_modis_raster)
# Replace 13 with your target class value
target_class <- 1

# Create mask for Class 13
LC4 <- mask(
  Namibia_modis_raster,
  Namibia_modis_raster == target_class,
  maskvalue = FALSE
)

# Plot with custom color
plot(LC4, 
     col = "red",  # Highlight class 13 in red
     main = "Class 13 (Urban/Built-up) in Namibia")




# Query values interactively by clicking on the map
click(Namibia_modis_raster)




unique(values(Namibia_modis_raster))
unique(Botswana_modis_raster)
# Inspect the raster projection and assigned Zones
results <- list(
  "Angola MODIS Raster" = angola_modis_raster,
  "Namibia MODIS Raster" = Namibia_modis_raster,
  "Botswana MODIS Raster" = Botswana_modis_raster,
  "Mauritius MODIS Raster" = Mauritius_modis_raster
)

results

library(terra)
# Inspect the reclassified MODIS rasters
# Define paths to reclassified MODIS rasters
Angola_modis_raster_reclass <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                      "by_country", "Angola_modis_ref_map_8.tif")
Namibia_modis_raster_reclass <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                      "by_country", "Namibia_modis_ref_map_8.tif")
Botswana_modis_raster_reclass <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m",
                                      "by_country", "Botswana_modis_ref_map_8.tif")
Mauritius_modis_raster_reclass <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m",
                                      "by_country", "Mauritius_modis_ref_map_8.tif")

# Create raster for random countries for inspection
Angola_modis_raster_reclass <- rast(Angola_modis_raster_reclass)
Namibia_modis_raster_reclass <- rast(Namibia_modis_raster_reclass)
Botswana_modis_raster_reclass <- rast(Botswana_modis_raster_reclass)
Mauritius_modis_raster_reclass <- rast(Mauritius_modis_raster_reclass)

unique(Angola_modis_raster_reclass)
levels(Angola_modis_raster_reclass)
unique(Namibia_modis_raster_reclass)
levels(Namibia_modis_raster_reclass)
crs(Namibia_modis_raster_reclass)
unique(Botswana_modis_raster_reclass)
levels(Botswana_modis_raster_reclass)
unique(Mauritius_modis_raster_reclass)
levels(Mauritius_modis_raster_reclass)
unique(Mauritius_modis_raster_reclass)
levels(Mauritius_modis_raster_reclass)


# Inspect the reclassified raster classes and levels
results_reclass <- list(
  "Angola MODIS Raster Reclassified" = Angola_modis_raster_reclass,
  "Namibia MODIS Raster Reclassified" = Namibia_modis_raster_reclass,
  "Botswana MODIS Raster Reclassified" = Botswana_modis_raster_reclass,
  "Mauritius MODIS Raster Reclassified" = Mauritius_modis_raster_reclass)

results_reclass


# Inspect cropped and masked PLUM rasters

Angola_plum_raster <- file.path(plum_output_dir, "Angola_SSP1_RCP26_LUC_fractions_2021_2022.tif")
# Angola_plum_raster
Namibia_plum_raster <- file.path(plum_output_dir, "Namibia_SSP1_RCP26_LUC_fractions_2021_2022.tif")
Botswana_plum_raster <- file.path(plum_output_dir, "Botswana_SSP1_RCP26_LUC_fractions_2021_2022.tif")
Mauritius_plum_raster <- file.path(plum_output_dir, "Mauritius_SSP1_RCP26_LUC_fractions_2021_2022.tif")

# Create raster for these countries
Angola_plum_raster <- rast(Angola_plum_raster)
plot(Angola_plum_raster)
Namibia_plum_raster <- rast(Namibia_plum_raster)
plot(Namibia_plum_raster)
Botswana_plum_raster <- rast(Botswana_plum_raster)
plot(Botswana_plum_raster)
Mauritius_plum_raster <- rast(Mauritius_plum_raster)
plot(Mauritius_plum_raster)
# Inspect the raster's projection and asigned Zones
plum.results <- list(
  "Angola PLUM Raster" = Angola_plum_raster,
  "Namibia PLUM Raster" = Namibia_plum_raster,
  "Botswana PLUM Raster" = Botswana_plum_raster,
  "Mauritius PLUM Raster" = Mauritius_plum_raster
)
plum.results



#-------------------------------------------------------------------------------
#
# Test the downscaling script on a single country (Angola)
# 

# Load rasters
angola_plum_raster <- file.path(base_dir, "Angola_SSP1_RCP26_LUC_fractions_2021_2022_3.tif")
angola_modis_raster <- rast(angola_modis_raster_path)


# Start bz generating a dznamic Transition Matrix
#
# Extract PLUM layer names for row names
plum_layer_names <- names(angola_plum_raster)
plum_layer_names
#unique(values(angola_modis_raster))
#unique(angola_modis_raster)

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
#
# 111111111111111111111111111111111111111111111111111111111111111111111111111111
# Test with updated reference maps at every iteration

# Define paths and variables
base_dir <- getwd()
country_name <- "Angola"

# Path to the original MODIS reference map
country_ref_map_file <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                  "by_country", paste0(country_name, "_modis_ref_map_2.tif"))

# Directory for PLUM raster files
plum_raster_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", 
                             "SSP1_RCP26", "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped")

# List and sort all PLUM raster files for Angola
country_LUC_map_files <- list.files(
  path = plum_raster_dir,
  pattern = paste0("^", country_name, "_SSP1_RCP26_LUC_fractions_\\d{4}_\\d{4}\\.tif$"),
  full.names = TRUE
)
country_LUC_map_files <- sort(country_LUC_map_files)

# Verify files
cat("Files included in LC_deltas_file_list:\n")
print(country_LUC_map_files)

# Define output directory for downscaled results
downscale_output_dir <- file.path(base_dir, "LU_downscalled_dataset", "LU_PLUM_Modis_500m", 
                                  "downscale_SSP1_RCP26", "Downscale_by_country", country_name)

# Custom wrapper for downscaleLC with reference map updates and progress messages
downscaleLC_with_progress <- function(ref_map_file_name, LC_deltas_file_list, ...) {
  cat("Starting downscaling process...\n")
  
  # Initialize the reference map with the original MODIS map
  current_ref_map <- ref_map_file_name  # This will be updated with the output file in each iteration
  
  for (file in LC_deltas_file_list) {
    # Extract years from the file name (e.g., "2021_2022")
    years <- gsub(".*_(\\d{4}_\\d{4})\\.tif$", "\\1", file)
    cat(sprintf("Processing year(s): %s...\n", years))
    
    # Define the output file path for the current downscaled map
    output_file <- file.path(downscale_output_dir, paste0("Downscaled_ref_map_", years, ".tif"))
    
    # Run the downscaleLC function, dynamically passing the required output_file_prefix
    downscaleLC(
      ref_map_file_name = current_ref_map,       # Use the current reference map
      LC_deltas_file_list = list(file),          # Process one file at a time
      output_file_prefix = paste0(country_name, "_MODIS_PLUM_500m_s1_", years),  # Provide the required prefix
      ...                                        # Remaining parameters are passed through ...
    )
    
    # Update the reference map to the new downscaled output
    current_ref_map <- output_file  # This becomes the reference for the next timestep
  }
  
  cat("Downscaling process completed!\n")
}

# Run the custom wrapper function
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






library(terra)

# === Setup ===
base_dir <- getwd()
scenario <- "SSP1_RCP26"
sim      <- "s6"
year     <- 2021

# === File path ===
plum_file <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs",
                       scenario, sim, as.character(year),
                       paste0(scenario, "_", sim, "_", year, "_MultiLayer_cropped.tif"))

# === Load raster ===
if (!file.exists(plum_file)) stop("Raster not found:", plum_file)
plum_r <- rast(plum_file)

# === Optional: drop unwanted layers ===
drop_layers <- c("Protection", "cell_area", "cell_area_calc", "Photovoltaics", "Agrivoltaics", "CarbonForest")
keep_layers <- setdiff(names(plum_r), drop_layers)
plum_r <- plum_r[[keep_layers]]

# === Plot all layers ===
plot(plum_r, nc = 3, main = paste("PLUM Land Use Fractions -", scenario, sim, year))

# === Optional: plot one specific layer ===
# plot(plum_r[["Cropland"]], main = paste("Cropland Fraction -", scenario, sim, year))
