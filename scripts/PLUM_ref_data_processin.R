# Author: Markus Shiweda
# Date: 10.10.2024

# Load necessary libraries
library(data.table)  # For reading large .txt.gz files efficiently
library(ggplot2)     
library(dplyr)      
library(reshape2)    # For reshaping data if needed
library(terra)      # For working with raster data
library(R.utils)    # For reading and unzip `.txt.gz` files
library(progress)   # For tracking progress of simulations)

# Set the base directory (to make it ear to run on the HPC)
base_dir <- getwd()


# Load the land cover and land use data for the SSP1_RCP26 scenario to inspect it
# Define paths for each file
landcover_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", "SSP1_RCP26", "s1", "2020", "LandCover.txt.gz")
landuse_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", "SSP1_RCP26", "s1", "2020", "LandUse.txt.gz")
# Read and inspect each file
landcover_data <- fread(landcover_path)
landuse_data <- fread(landuse_path)


# Inspect the structure of each dataset

str(landcover_data)
crs(landcover_data)
summary(landcover_data)
plot(landcover_data)


str(landuse_data)

# Visualize unique land land use classes using the `Crop` column
ggplot(landuse_data, aes(x = factor(Crop))) +  
  geom_bar(fill = "lightblue") + 
  theme_minimal() +
  labs(title = "Distribution of Land Cover Classes", x = "Class", y = "Frequency")

# Summary of unique Crop classes
unique_landuse_classes <- unique(landuse_data$Crop)

# Summary of unique crop classes
cat("\nUnique LandUse Classes:\n")
print(unique_landuse_classes)


# Further visualizations 

# Load necessary libraries

# Visualize the land use data: scatter plot to compare area by type
ggplot(landuse_data, aes(x = Crop, y = A, color = Crop)) +  # Replace `TotalArea` and `A` with relevant columns
  geom_point() +
  theme_minimal() +
  labs(title = "Comparison of crop type and land use area",
       x = "Total Land Cover Area",
       y = "Crop type",
       color = "Land Use Type")


#-------------------------------------------------------------------------------

# Unzipping the land cover files


# Define the SSP-RCP scenarios to process
scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")

# Define the years to process from 2022 to 2100
years <- 2022:2100

# My study area shapefile already in R environment processed in SAfrica_LUprocessing script
# The path to the study area shapefile for the South Africa region
path_SAfrica_states_proj_final_shp <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")

# Load the shapefile of the study area
study_area_shapefile <- vect(path_SAfrica_states_proj_final_shp)

# Ensure the CRS matches between the raster and shapefile
if (!identical(crs(study_area_shapefile), "+proj=longlat +datum=WGS84")) {
  study_area_shapefile <- project(study_area_shapefile, "+proj=longlat +datum=WGS84")
}

# Function to unzip the land cover files and create rasters for each year
create_rasters <- function(climate_scenario) {
  
  # Initialize the progress bar
  pb <- progress_bar$new(
    total = length(years),
    format = "Processing [:bar] :percent in :elapsed, ETA: :eta"
  )
  
  # Loop through each year to process
  for (year in years) {
    
    pb$tick()  # Update progress bar
    
    # Unzip the LandCover.txt.gz file for the specific scenario and year
    gz_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", climate_scenario, "s1", as.character(year), "LandCover.txt.gz")
    txt_path <- sub(".gz", "", gz_path)
    
    # Unzip the file if it exists
    if (file.exists(gz_path)) {
      gunzip(gz_path, destname = txt_path, remove = FALSE, overwrite = TRUE)
      cat("Unzipped file for year:", year, "in scenario:", climate_scenario, "\n")
    } else {
      cat("LandCover.txt.gz file not found for year", year, "in scenario", climate_scenario, "\n")
      next
    }
    
    # Load the land cover data and convert to raster
    convert_to_raster <- function(year) {
      
      # Define the path to the unzipped LandCover.txt file
      txt_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", climate_scenario, "s1", as.character(year), "LandCover.txt")
      
      # Read the land cover data
      landcover_data <- fread(file = txt_path)
      
      # Rename TotalArea to cell_area
      names(landcover_data)[names(landcover_data) == "TotalArea"] <- "cell_area"
      
      # Extract longitude and latitude
      lon <- landcover_data$Lon
      lat <- landcover_data$Lat
      
      # Initialize a template raster using the longitude and latitude information
      r_template <- rast(nrows = length(unique(lat)), ncols = length(unique(lon)),
                         xmin = min(lon), xmax = max(lon), ymin = min(lat), ymax = max(lat),
                         crs = "+proj=longlat +datum=WGS84")
      
      # Initialize an empty list to store raters for each land cover class
      rasters_list <- list()
      
      # Loop through each numeric land cover column and add it to the raster
      for (landcover_class in names(landcover_data)[4:length(names(landcover_data))]) {
        r_class <- r_template
        
        # Convert from hectares to square meters (1 ha = 10,000 m²)
        r_class[] <- landcover_data[[landcover_class]] * 10000  # Convert values to square meters
        
        # Add this class's raster to the list
        rasters_list[[landcover_class]] <- r_class
      }
      
      # Add the Protection column: convert it to a factor and then to numeric for rasterizing
      protection_factor <- as.numeric(as.factor(landcover_data$Protection))
      protection_raster <- r_template
      protection_raster[] <- protection_factor
      rasters_list[["Protection"]] <- protection_raster
      
      # Combine all the individual classes into a multi-layer raster
      multi_layer_raster <- rast(rasters_list)
      
      # Calculate and add the cell_area layer (converted to square meters)
      cell_area_raster <- terra::cellSize(r_template, unit = 'm')
      names(cell_area_raster) <- 'cell_area'
      multi_layer_raster <- c(multi_layer_raster, cell_area_raster)
      
      # Define the output file path for the multi-layer raster
      output_filepath <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", climate_scenario, paste0("s1_", year, "_MultiLayer_3.tif"))
      
      # Save the multi-layer raster as a GeoTIFF
      writeRaster(multi_layer_raster, output_filepath, filetype = "GTiff", overwrite = TRUE)
      
      # Print progress
      cat("Saved multi-layer raster for year", year, "in scenario:", climate_scenario, "at", output_filepath, "\n")
    }
    
    # Call the convert_to_raster function
    convert_to_raster(year)
  }
}

# Call the function to create raster for each scenario
for (scenario in scenarios) {
  create_rasters(scenario)
}

# Cropping and Masking the rasters
for (scenario in scenarios) {
  
  # Create output directory for the current scenario
  output_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", paste0("masked_", scenario))
  
  # Create output directory if it doesn't exist for each SSP-RCP scenario
  if (!dir.exists(output_dir)) {
    dir.create(output_dir)
  }
  
  # Loop through each year and process the raster data
  for (year in years) {
    
    # Define the raster path for the specific scenario and year
    raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", scenario, paste0("s1_", year, "_MultiLayer_3.tif"))
    
    # Check if the raster file exists before processing
    if (file.exists(raster_path)) {
      
      # Load the raster for the given year
      raster_data <- rast(raster_path)
      
      # Ensure that the CRS (coordinate reference system) matches between the raster and shapefile
      if (!identical(crs(raster_data), crs(study_area_shapefile))) {
        study_area_shapefile <- project(study_area_shapefile, crs(raster_data))
      }
      
      # Crop the raster using the study area shapefile
      cropped_raster <- crop(raster_data, study_area_shapefile)
      
      # Mask the raster using the shapefile to remove values outside the study area
      masked_raster <- mask(cropped_raster, study_area_shapefile)
      
      # Save the cropped and masked raster with an appropriate filename indicating the scenario and year
      output_cropped_path <- file.path(output_dir, paste0("masked_s1_", year, "_", scenario, ".tif"))
      
      # Write the raster to the disk, overwriting existing files if necessary
      writeRaster(masked_raster, output_cropped_path, overwrite = TRUE)
      
      # Print progress message to indicate completion for this year and scenario
      cat("Processed and saved masked raster for", scenario, "in year", year, "to", output_cropped_path, "\n")
      
    } else {
      # Print a message if the raster file for the year is missing
      cat("Raster for year", year, "in scenario", scenario, "not found, skipping...\n")
    }
  }
}

#-------------------------------------------------------------------------------
























#-------------------------------------------------------------------------------


# Visualizing the Cropland layer for 2030 in each SSP-RCP scenario

# Set up a 2x3 grid for the plots (2 rows, 3 columns, but there are only 5 scenarios)
par(mfrow = c(2, 3))

# Define the SSP-RCP scenarios
scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")

# Define the year to inspect
year <- 2030

# Loop through each scenario to visualize the Cropland layer for 2030
for (scenario in scenarios) {
  
  # Define the path to the masked raster for 2030 for the current scenario
  raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", paste0("masked_", scenario), paste0("masked_s1_", year, "_", scenario, ".tif"))
  
  # Check if the raster file exists
  if (file.exists(raster_path)) {
    
    # Load the raster for the year and scenario
    raster_data <- rast(raster_path)
    
    # Check if Cropland exists in the raster, otherwise skip
    if ("Cropland" %in% names(raster_data)) {
      
      # Extract the Cropland layer
      cropland_layer <- raster_data[["Cropland"]]
      
      # Create a plot with a dynamic title based on the scenario and year
      plot(cropland_layer, main = paste0("Cropland in 2030 - ", scenario), col = terrain.colors(100))
      
    } else {
      # Print message if Cropland is not found in the raster
      cat("Cropland layer not found in the raster for scenario", scenario, "in year", year, "\n")
    }
    
  } else {
    # Print a message if the raster file does not exist for the year and scenario
    cat("Raster file not found for scenario", scenario, "in year", year, "\n")
  }
}

# Reset the plot layout to default (optional)
par(mfrow = c(1, 1))


#-------------------------------------------------------------------------------
# Inspecting the multi-layer raster stack


# Define the climate scenario and the years of interest
climate_scenario <- "SSP1_RCP26"
years <- c(2022, 2040, 2060, 2080, 2100)

# Define the land cover columns of interest for plotting
landcover_columns <- c("Cropland", "Pasture", "Urban")

# Loop through each year and inspect the rasters
for (year in years) {
  
  # Define the path to the raster file for each year
  raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", paste0("masked_s1_", year, "_MultiLayer.tif"))
  
  # Load the multi-layer raster
  multi_layer_raster <- rast(raster_path)
  
  # Print raster structure
  cat("Structure of raster for year", year, ":\n")
  print(str(multi_layer_raster))
  
  # Check the number of layers and display the first few rows of the data
  cat("First few rows of raster for year", year, ":\n")
  print(head(values(multi_layer_raster)))
  
  # Plot the relevant layers (Cropland, Pasture, Urban)
  for (landcover_class in landcover_columns) {
    if (landcover_class %in% names(multi_layer_raster)) {
      plot(multi_layer_raster[[landcover_class]], main = paste(landcover_class, "in", year))
    } else {
      cat("Layer", landcover_class, "not found in raster for year", year, "\n")
    }
  }
  
  # Optional: You can also crop the raster for visualization purposes
  # e.g., cropping to a specific extent if necessary
}

