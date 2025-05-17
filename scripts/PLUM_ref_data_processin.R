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
      output_filepath <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", climate_scenario, paste0("s1_", year, "_MultiLayer_3.tif"))
      
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











# # ============================================================
# 
# # ============================================================
# # 0. Remove existing .tif / .tiff under scenario/sim folders
# # ============================================================
# library(tools)   # For file_ext, but we’ll do pattern matching instead
# library(fs)      # Optionally for more advanced dir/file ops (not strictly needed)
# 
# base_dir <- getwd()
# plum_root_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs")
# 
# # If these are your scenario & sim vectors:
# scenarios   <- c("SSP1_RCP26","SSP2_RCP45","SSP3_RCP70","SSP4_RCP60","SSP5_RCP85")
# simulations <- paste0("s", 1:10)
# 
# for (scenario in scenarios) {
#   for (sim in simulations) {
#     sim_folder <- file.path(plum_root_dir, scenario, sim)
#     if (!dir.exists(sim_folder)) next
#     
#     # Recursively list all .tif or .tiff
#     tif_files <- list.files(
#       path       = sim_folder, 
#       pattern    = "\\.tiff?$",  # regex matches .tif or .tiff
#       recursive  = TRUE,        # go into subfolders
#       full.names = TRUE
#     )
#     
#     if (length(tif_files) > 0) {
#       # Remove them
#       file.remove(tif_files)
#       cat("Removed", length(tif_files), "TIF files under", sim_folder, "\n")
#     } else {
#       cat("No TIF files found under", sim_folder, "\n")
#     }
#   }
# }
# cat("✅ Done removing old .tif/.tiff!\n")
# 



# # ============================================================




# ============================================================
# 0) Setup & Libraries
# ============================================================
library(terra)
library(data.table)
library(R.utils)
library(doParallel)
library(foreach)

base_dir <- getwd()
plum_root_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs")

# Scenarios, simulations, years
scenarios   <- c("SSP1_RCP26","SSP2_RCP45","SSP3_RCP70","SSP4_RCP60","SSP5_RCP85")
simulations <- paste0("s", 1:10)
years       <- 2020:2100

# Shapefile path (only storing the path globally)
shapefile_path <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")

# ============================================================
# 1) Create multi-layer raster from .txt
# ============================================================
create_multilayer_raster <- function(scenario, sim, year) {
  gz_path  <- file.path(plum_root_dir, scenario, sim, as.character(year), "LandCover.txt.gz")
  txt_path <- sub("\\.gz$", "", gz_path)
  
  if (!file.exists(gz_path)) {
    cat("No LandCover.txt.gz for", scenario, sim, year, "\n")
    return(NULL)
  }
  
  if (!file.exists(txt_path)) {
    gunzip(gz_path, destname=txt_path, overwrite=TRUE, remove=FALSE)
    cat("Unzipped:", gz_path, "->", txt_path, "\n")
  }
  
  dt <- fread(txt_path)
  if ("TotalArea" %in% names(dt)) {
    setnames(dt, old="TotalArea", new="cell_area")
  }
  if (!all(c("Lon","Lat") %in% names(dt))) {
    cat("Missing Lon/Lat in", txt_path, "\n")
    return(NULL)
  }
  
  lon <- dt$Lon
  lat <- dt$Lat
  if (length(unique(lon))<2 || length(unique(lat))<2) {
    cat("Not enough unique lat/lon for", scenario, sim, year, "\n")
    return(NULL)
  }
  
  # template
  r_template <- rast(
    nrows=length(unique(lat)),
    ncols=length(unique(lon)),
    xmin=min(lon), xmax=max(lon),
    ymin=min(lat), ymax=max(lat),
    crs="EPSG:4326"
  )
  
  # coverage columns
  skip_cols <- c("Lon","Lat","Protection")
  coverage_cols <- setdiff(names(dt), skip_cols)
  
  ras_list <- list()
  for (col_nm in coverage_cols) {
    if (!is.numeric(dt[[col_nm]])) next
    r_class <- r_template
    r_class[] <- dt[[col_nm]] * 10000  # hectares->m²
    names(r_class) <- col_nm
    ras_list[[col_nm]] <- r_class
  }
  
  # add Protection factor if present
  if ("Protection" %in% names(dt)) {
    r_prot <- r_template
    r_prot[] <- as.numeric(as.factor(dt$Protection))
    names(r_prot) <- "Protection"
    ras_list[["Protection"]] <- r_prot
  }
  
  if (length(ras_list)==0) {
    cat("No coverage columns for", scenario, sim, year, "\n")
    return(NULL)
  }
  
  multi_rast <- rast(ras_list)
  # cell area
  r_area <- cellSize(r_template, unit="m")
  names(r_area) <- "cell_area_calc"
  multi_rast <- c(multi_rast, r_area)
  
  # output path
  out_dir <- file.path(plum_root_dir, scenario, sim, as.character(year))
  dir.create(out_dir, showWarnings=FALSE, recursive=TRUE)
  
  out_name <- paste0(scenario, "_", sim, "_", year, "_MultiLayer.tif")
  out_path <- file.path(out_dir, out_name)
  
  writeRaster(multi_rast, out_path, overwrite=TRUE)
  return(out_path)
}

# ============================================================
# 2) Crop+Mask function: re-load shapefile
# ============================================================
crop_and_mask <- function(raster_path, scenario, sim, year, shp_path) {
  if (!file.exists(raster_path)) return(NULL)
  
  # read the raster
  r_data <- rast(raster_path)
  
  # load shapefile fresh inside child process
  shp <- vect(shp_path)
  if (crs(r_data) != crs(shp)) {
    shp <- project(shp, crs(r_data))
  }
  
  r_crop <- crop(r_data, shp)
  r_mask <- mask(r_crop, shp)
  
  # save in same folder, appended _masked
  out_dir <- dirname(raster_path)
  out_name <- sub("\\.tif$", "_masked.tif", basename(raster_path))
  out_path <- file.path(out_dir, out_name)
  
  writeRaster(r_mask, out_path, overwrite=TRUE)
  return(out_path)
}

# ============================================================
# 3) Parallel Loop
# ============================================================
combo <- expand.grid(scenario=scenarios, sim=simulations, year=years, stringsAsFactors=FALSE)
total_tasks <- nrow(combo)

# parallel cluster
n_cores <- max(1, parallel::detectCores(logical=TRUE) - 0)
cl <- makeCluster(n_cores)
registerDoParallel(cl)

task_count <- 0

results <- foreach(i=seq_len(total_tasks), .packages=c("terra","data.table","R.utils")) %dopar% {
  
  row   <- combo[i, ]
  scen  <- row$scenario
  s     <- row$sim
  yr    <- row$year
  
  # 1) Create multi-layer
  r_path <- create_multilayer_raster(scen, s, yr)
  if (!is.null(r_path)) {
    # 2) Crop+mask
    masked_path <- crop_and_mask(r_path, scen, s, yr, shapefile_path)
  }
  
  # Basic progress line (order can be out-of-sequence in parallel)
  paste0("Done: ", scen, " - ", s, " - ", yr)
}

stopCluster(cl)

# Print final summary
cat("\nAll tasks done! Created + masked rasters for any existing LandCover.txt.gz.\n")









# ============================================================
# i have run the year 2021 separately since it was missing.
# ============================================================
base_dir <- getwd()

library(terra)
library(data.table)

plum_root_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs")

# The scenario & simulation sets:
scenarios   <- c("SSP1_RCP26","SSP2_RCP45","SSP3_RCP70","SSP4_RCP60","SSP5_RCP85")
simulations <- paste0("s", 1:10)
year_of_interest <- 2021

# Path to shapefile
shapefile_path <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")

# ============================================================
# 1) Single function: create + mask
# ============================================================
create_and_mask_2021 <- function(scenario, sim, year, shapefile_path) {
  
  # 1A) check for LandCover.txt
  txt_path <- file.path(plum_root_dir, scenario, sim, as.character(year), "LandCover.txt")
  if (!file.exists(txt_path)) {
    cat("No LandCover.txt for", scenario, sim, year, "\n")
    return(NULL)
  }
  
  # 1B) read data
  dt <- fread(txt_path)
  if ("TotalArea" %in% names(dt)) {
    setnames(dt, old="TotalArea", new="cell_area")
  }
  if (!all(c("Lon","Lat") %in% names(dt))) {
    cat("Missing Lon/Lat in", txt_path, "\n")
    return(NULL)
  }
  
  lon <- dt$Lon
  lat <- dt$Lat
  if (length(unique(lon))<2 || length(unique(lat))<2) {
    cat("Not enough unique lat/lon for", scenario, sim, year, "\n")
    return(NULL)
  }
  
  # 1C) create a template
  r_template <- rast(
    nrows=length(unique(lat)),
    ncols=length(unique(lon)),
    xmin=min(lon), xmax=max(lon),
    ymin=min(lat), ymax=max(lat),
    crs="EPSG:4326"
  )
  
  # coverage columns
  skip_cols <- c("Lon","Lat","Protection")
  coverage_cols <- setdiff(names(dt), skip_cols)
  
  ras_list <- list()
  for (col_nm in coverage_cols) {
    if (!is.numeric(dt[[col_nm]])) next
    r_class <- r_template
    # multiply by 10000 if data is in hectares
    r_class[] <- dt[[col_nm]] * 10000
    names(r_class) <- col_nm
    ras_list[[col_nm]] <- r_class
  }
  
  # add "Protection" factor if present
  if ("Protection" %in% names(dt)) {
    r_prot <- r_template
    r_prot[] <- as.numeric(as.factor(dt$Protection))
    names(r_prot) <- "Protection"
    ras_list[["Protection"]] <- r_prot
  }
  
  if (length(ras_list)==0) {
    cat("No coverage columns for", scenario, sim, year, "\n")
    return(NULL)
  }
  
  multi_rast <- rast(ras_list)
  
  # add cell_area_calc
  r_area <- cellSize(r_template, unit="m")
  names(r_area) <- "cell_area_calc"
  multi_rast <- c(multi_rast, r_area)
  
  # 1D) Write unmasked TIF
  out_dir <- file.path(plum_root_dir, scenario, sim, as.character(year))
  dir.create(out_dir, showWarnings=FALSE, recursive=TRUE)
  
  out_name <- paste0(scenario, "_", sim, "_", year, "_MultiLayer.tif")
  out_path <- file.path(out_dir, out_name)
  
  writeRaster(multi_rast, out_path, overwrite=TRUE)
  cat("✅ Created multi-layer for", scenario, sim, year, "->", out_path, "\n")
  
  # 1E) Crop + mask
  # re-load shapefile in this function so pointer is local
  shp <- vect(shapefile_path)
  if (crs(multi_rast) != crs(shp)) {
    shp <- project(shp, crs(multi_rast))
  }
  r_crop <- crop(multi_rast, shp)
  r_mask <- mask(r_crop, shp)
  
  # name for masked
  masked_name <- sub("\\.tif$", "_masked.tif", out_name)
  masked_path <- file.path(out_dir, masked_name)
  
  writeRaster(r_mask, masked_path, overwrite=TRUE)
  cat("✅ Wrote masked TIF:", masked_path, "\n")
  
  return(TRUE)
}

# ============================================================
# 2) Main loop over scenarios & sims
# ============================================================
for (scen in scenarios) {
  for (sim in simulations) {
    create_and_mask_2021(scen, sim, year_of_interest, shapefile_path)
  }
}

cat("\nAll done creating & masking 2021 TIF files!\n")



# ============================================================






