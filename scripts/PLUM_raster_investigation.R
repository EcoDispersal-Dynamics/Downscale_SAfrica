library(terra)

# Base directory where the rasters are saved
base_dir <- getwd()

# Load the terra package
library(terra)

# Define the path to the saved multi-layer raster for the year 2022 (or any other year)
raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", "masked_SSP1_RCP26", "masked_s1_2022_SSP1_RCP26.tif")

# Load the multi-layer raster for the year 2022
multi_layer_raster <- rast(raster_path)
multi_layer_raster
plot(multi_layer_raster)
crs(multi_layer_raster)
units(multi_layer_raster)
# remove the 13th layer
multi_layer_raster <- multi_layer_raster[[1:12]]
multi_layer_raster
plot(multi_layer_raster)
head(multi_layer_raster)
# Check the structure of the raster
print(multi_layer_raster)
summary(multi_layer_raster)
unique_multi_layer_raster_classes <- unique(values(multi_layer_raster))
unique_multi_layer_raster_classes

# Compute full summary statistics for each layer using the global function
stats <- global(multi_layer_raster, fun = c("min", "max", "mean", "sum"))

# Display the statistics for each land cover class
print(stats)


# Plot the world map for different layers
# Plot Cropland
plot(multi_layer_raster[["Cropland"]], main = "Cropland in 2022")

# Plot Pasture
plot(multi_layer_raster[["Pasture"]], main = "Pasture in 2022")

# Plot Urban
plot(multi_layer_raster[["Urban"]], main = "Urban in 2022")


# Years to inspect other years
years <- c(2030, 2040, 2060, 2080, 2100)

# Path to the created rasters
raster_path <- function(year) {
  file.path(base_dir, "LU_ref_dataset", "LU_ref -PLUM_SSPs", paste0("s1_", year, "_MultiLayer_3.tif"))
}

# Function to inspect a raster and sum land use classes
inspect_raster <- function(year) {
  cat("Checking raster for year:", year, "\n")
  
  # Load the raster
  raster <- rast(raster_path(year))
  
  # Check structure and first few rows of raster
  print(raster)
  
  # Extract land use layers
  landuse_layers <- raster[[c("Cropland", "Pasture", "TimberForest", "CarbonForest", 
                              "UnmanagedForest", "OtherNatural", "Barren", "Urban")]]
  
  # Sum the proportions for each cell
  landuse_sum <- sum(landuse_layers)
  
  # Check summary of the sum of the layers to see if it equals approximately 1
  cat("Summary of sum of land cover classes for each cell in year", year, ":\n")
  print(summary(values(landuse_sum)))
  
  # Visualize specific land use classes
  par(mfrow = c(2, 2))  # To display multiple plots
  plot(raster[["Cropland"]], main = paste("Cropland in", year), col = hcl.colors(100, "YlOrRd"))
  plot(raster[["Pasture"]], main = paste("Pasture in", year), col = hcl.colors(100, "YlGnBu"))
  plot(raster[["Urban"]], main = paste("Urban in", year), col = hcl.colors(100, "YlGn"))
  plot(landuse_sum, main = paste("Sum of all land use classes in", year), col = hcl.colors(100, "YlOrBr"))
}

# Loop over the years and inspect each raster
for (year in years) {
  inspect_raster(year)
}


# Set the directory where the files are located
directory <- "C:/Users/shiweda-m/Documents/kaza_study/Downscaling for ecomodelling/Downscale_SAfrica/LU_ref_dataset/LU_ref -PLUM_SSPs/masked_SSP1_RCP26"

# List all files in the directory
files <- list.files(directory, full.names = TRUE)

# Loop through each file and rename if it contains "SSP_"
for (file in files) {
  # Extract the file name from the full path
  file_name <- basename(file)
  
  # Check if "SSP_" is in the file name
  if (grepl("SSP_", file_name)) {
    # Replace "SSP_" with "SSP1_" in the file name
    new_file_name <- gsub("SSP_", "SSP1_", file_name)
    
    # Define the full new file path
    new_file_path <- file.path(directory, new_file_name)
    
    # Rename the file
    file.rename(file, new_file_path)
  }
}

# Print completion message
cat("All files renamed successfully.")





