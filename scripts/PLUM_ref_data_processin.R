# Author: Markus Shiweda
# Date: 10.10.2024

# Load necessary libraries
library(data.table)  # For reading large .txt.gz files efficiently
library(ggplot2)     
library(dplyr)      
library(reshape2)    # For reshaping data if needed
library(terra)      # For working with raster data

# Set the base directory (to make it ear to run on the HPC)
base_dir <- getwd()

# Define paths for each file
landcover_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", "SSP1_RCP26", "s1", "2020", "LandCover.txt.gz")
landcover_change_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", "SSP1_RCP26", "s1", "2020", "LandCoverChange.txt.gz")
landuse_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", "SSP1_RCP26", "s1", "2020", "LandUse.txt.gz")
forestry_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", "SSP1_RCP26", "s1", "2020", "Forestry.txt.gz")
# Read and inspect each file
landcover_data <- fread(landcover_path)
landcover_change_data <- fread(landcover_change_path)
landuse_data <- fread(landuse_path)
forestry_data <- fread(forestry_path)

# Inspect the structure of each dataset
cat("Structure of LandCover Data:\n")
str(landcover_data)
cat("\nStructure of LandCoverChange Data:\n")
str(landcover_change_data)
cat("\nStructure of LandUse Data:\n")
str(landuse_data)


# Display first few rows of each dataset to understand columns
cat("\nFirst 10 rows of LandCover Data:\n")
print(head(landcover_data))

cat("\nFirst 6 rows of LandCoverChange Data:\n")
print(head(landcover_change_data))

cat("\nFirst 6 rows of LandUse Data:\n")
print(head(landuse_data))



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

# Unzipping the files
library(R.utils)


# Define the climate scenario and the years to process
climate_scenario <- "SSP1_RCP26"
years <- 2020:2100

# Loop through each year and replicate
for (year in years) {
  for (replicate in 1:30) {
    
    # Define the path to the gzipped LandUse.txt.gz file
    gz_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", climate_scenario, paste0("s", replicate), as.character(year), "LandUse.txt.gz")
    
    # Define the path to save the unzipped file
    txt_path <- sub(".gz", "", gz_path)
    
    # Unzip the file
    gunzip(gz_path, destname = txt_path, remove = FALSE, overwrite = TRUE)
    
    # Print progress
    cat("Unzipped file for year:", year, "replicate:", replicate, "\n")
  }
}



#-------------------------------------------------------------------------------
# Process the land use data.
# 
# Define the climate scenario you are working on (e.g., SSP1_RCP26)
climate_scenario <- "SSP1_RCP26"

# Define the years to process (e.g., 2020-2100)
years <- 2020:2100

# Create a list to store rasters for each year
yearly_rasters <- list()

# Loop through each year from 2020 to 2100
for (year in years) {
  
  # Create a list to store replicate rasters for this year
  replicate_data <- list()
  
  # Loop through each replicate (s1 to s30)
  for (replicate in 1:30) {
    
    # Define the path to the unzipped LandUse.txt file
    replicate_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", climate_scenario, paste0("s", replicate), as.character(year), "LandUse.txt")
    
    # Check if the file exists
    if (file.exists(replicate_path)) {
      # Read the .txt file using fread() 
      landuse_data <- fread(replicate_path)
      
      # Initialize the raster template for the first replicate
      if (replicate == 1) {
        lon <- landuse_data$Lon
        lat <- landuse_data$Lat
        r_template <- rast(nrows = length(unique(lat)), ncols = length(unique(lon)),
                           xmin = min(lon), xmax = max(lon), ymin = min(lat), ymax = max(lat),
                           crs = "+proj=longlat +datum=WGS84")
      }
      
      # Assign values from the 'A' column to the raster (use the relevant numeric column)
      replicate_raster <- r_template
      replicate_raster[] <- landuse_data$A  # Ensure 'A' is the relevant numeric column
      
      # Add the replicate raster to the list
      replicate_data[[replicate]] <- replicate_raster
    } else {
      cat("File not found for replicate", replicate, "in year", year, "\n")
    }
  }
  
  # Stack the replicate rasters and compute the mean across all 30 replicates
  if (length(replicate_data) > 0) {
    raster_stack <- rast(replicate_data)
    yearly_rasters[[as.character(year)]] <- app(raster_stack, mean, na.rm = TRUE)
    
    # Print progress
    cat("Processed year:", year, "\n")
    
    # Save the averaged raster for this year as a GeoTIFF in the same scenario directory
    output_file <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", climate_scenario, 
                             paste0("LandUse_all_rep_", year, ".tif"))
    writeRaster(yearly_rasters[[as.character(year)]], filename = output_file, overwrite = TRUE)
  } else {
    cat("No valid data for year", year, "\n")
  }
}



# Example: Visualize the raster for a specific year (e.g., 2020)
plot(yearly_rasters[["2020"]], main = "Averaged Land Use for 2020")


