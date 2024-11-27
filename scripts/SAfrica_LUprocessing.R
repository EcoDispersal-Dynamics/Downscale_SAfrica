# Author: Markus Shiweda
# Co-Authors: Tamsin Woodman, Reinhard Prestele

# Sub-Africa region TEMPERATE 
# Purpose: Download and Process land use data for the South Africa region
# Date: 2024-09-20



# Set the base directory
base_dir <- getwd()
base_dir


# Set relative path for the region shapefile for the South Africa region
path_SAfrica_states_proj_final_shp <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")
path_SAfrica_states_proj_final_shp
# Load the shapefile
SAfrica_states_proj_final_shp <- vect(path_SAfrica_states_proj_final_shp)
SAfrica_states_proj_final_shp

# Check the current CRS of the shapefile, EPSG:4326 (WGS84) is required
# to download GEE LUC images
cat("Current CRS of the shapefile:\n")
print(crs(SAfrica_states_proj_final_shp))


# # Reproject the shapefile to EPSG:4326 (WGS84) if it is not already in that CRS
# if (crs(SAfrica_states_proj_final_shp) != "EPSG:4326") {
#   cat("Reprojecting shapefile to EPSG:4326...\n")
#   SAfrica_states_proj_final_4326 <- project(SAfrica_states_proj_final, "EPSG:4326")
# } else {
#   cat("Shapefile is already in EPSG:4326.\n")
#   SAfrica_states_proj_final_4326 <- SAfrica_states_proj_final
# }

# View the contents of the shapefile
plot(SAfrica_states_proj_final_shp, main = "Sub-Saharan Africa region template")


# Convert the attribute table to a data frame and display it
attribute_table <- as.data.frame(SAfrica_states_proj_final_shp)
print(head(attribute_table))  # Display the first few rows of the attribute table

# Check if country name column exists
if ("CNTRY_NAME" %in% names(attribute_table)) {
  cat("CountryName column exists in the attribute table.\n")
} else {
  cat("CountryName column not found.\n")
}

# Filter the shapefile for a specific country (e.g., Angola) to test
country_name <- "Angola"
country_shapefile <- SAfrica_states_proj_final_shp[SAfrica_states_proj_final_shp$CNTRY_NAME == country_name, ]

# Plot the specific country's polygon
plot(country_shapefile, main = paste("Region for:", country_name))

# # Loop through each country by name
# # 'unique()' extracts all the unique country names from the 'CNTRY_NAME' column, which is the attribute field for country names
# for (country in unique(SAfrica_states_proj_final_shp$CNTRY_NAME)) {
#   
#   # Filter shapefile by country
#   # This creates a subset of the shapefile, selecting only the polygon(s) that correspond to the current 'country' in the loop
#   country_shp <- SAfrica_states_proj_final_shp[SAfrica_states_proj_final_shp$CNTRY_NAME == country, ]
#   
#   # Save or process the country's data here
#   # 'plot()' visualizes the shapefile of the current country on the map
#   # 'main' sets the title of the plot, dynamically changing with the country name in the loop
#   plot(country_shp, main = paste("Country:", country))
# }

# Create musking rasters for the sub-Saharan region
#
# Set the resolution levels (0.5 degrees, 500m, 100m, 10m)
resolutions <- c(0.5, 500, 100, 10)  # degrees and meters

# Create a folder to save MUSK rasters if it doesn't exist
musk_folder <- file.path(base_dir,"SAfrica_region", "MUSK")
if (!dir.exists(musk_folder)) {
  dir.create(musk_folder)
}

# Create the raster masks at each resolution level
for (res in resolutions) {
  
  # For resolutions less than 1, treat as degrees; otherwise as meters
  if (res < 1) {
    # Raster at 0.5 degrees resolution
    musk_raster <- rast(SAfrica_states_proj_final_shp, res = res)
  } else {
    # Raster at meter-level resolution (e.g., 500m, 100m, 10m)
    musk_raster <- rast(SAfrica_states_proj_final_shp, resolution = res)
  }
  
  # Assign the OBJECTID to the raster cells
  musk_raster <- rasterize(SAfrica_states_proj_final_shp, musk_raster, field = "OBJECTID")
  
  # Save the raster
  musk_raster_file <- file.path(musk_folder, paste0("MUSK_", res, ifelse(res < 1, "deg", "m"), ".tif"))
  writeRaster(musk_raster, musk_raster_file, overwrite = TRUE)
  
  # Print progress
  cat("Created and saved MUSK raster at", res, ifelse(res < 1, "degrees", "meters"), "resolution.\n")
}

# Plot one of the created rasters for visual inspection (e.g., the 500m one)
plot(musk_raster, main = "MUSK Raster at Selected Resolution")
#-------------------------------------------------------------------------------

# # ee_clean_user_credentials()
# # ee_Authenticate()  # Authenticate with Google Earth Engine. An rgee function
# # rgee::ee_clean_user_credentials()
# rgee::ee_clean_user_credentials()
# reticulate::use_python("C:/Users/shiweda-m/AppData/Local/Programs/Python/Python312/python.exe", 
#                        required = TRUE)
# rgee::ee_Authenticate()
# 
# rgee::ee_Initialize(email = "shiwedamark@gmail.com", drive = FALSE)

#-------------------------------------------------------------------------------

# If GEE initialization was successifull, I would proceed to download the 
# MODIS land cover data 
# Load MODIS MCD12Q1 dataset for 2021
modis_lc <- ee$ImageCollection('MODIS/061/MCD12Q1')$
  filter(ee$Filter$date('2021-01-01', '2021-12-31'))$
  first()$
  select('LC_Type1')

# Filter by country region
modis_lc_country <- modis_lc$clip(SAfrica_states_proj_final)

# Export or download the raster data
modis_task <- ee_image_to_drive(
  image = modis_lc_country,
  description = 'MODIS_LandCover_2021',
  scale = 500,
  region = SAfrica_states_proj_final$geometry(),
  fileFormat = 'GeoTIFF'
)
modis_task$start()

#-------------------------------------------------------------------------------
#
# I will use the following Java code to download the MODIS land cover data 
# in GEE code editor directly since the GEE initialisation failed to work in R
# I will download one LUC image for the entire region, 
# This raster has a table generated with country codes to allow for
# parallel processing and downscale simulations of the data with LandScale in R

// Step 1: Inspect the shapefile attributes
print("Region shapefile properties:", regionShapefile.propertyNames());

// Step 2: Check if 'OBJECTID' exists
print("OBJECTID properties:", regionShapefile.aggregate_array('OBJECTID'));

// Step 3: Create a unique ID raster using the 'OBJECTID' property directly
var countryIDRaster = regionShapefile.reduceToImage({
  properties: ['OBJECTID'],  // Use 'OBJECTID' as the unique property for each country
  reducer: ee.Reducer.first()
});

// Step 4: Define visualization parameters using the 'OBJECTID'
var visParams = {
  min: 1,  // Minimum OBJECTID value
  max: 26,  // Maximum OBJECTID value (assuming there are 26 unique countries)
  palette: [
    'red', 'blue', 'green', 'yellow', 'purple', 'cyan', 'magenta', 'orange',
    'brown', 'pink', 'teal', 'lime', 'navy', 'maroon', 'olive', 'coral',
    'gold', 'gray', 'turquoise', 'indigo', 'orchid', 'sienna', 'violet',
    'khaki', 'plum', 'chartreuse'
  ]
};

// Step 5: Display the raster on the map
Map.centerObject(regionShapefile, 5);  // Adjust the zoom level as needed
Map.addLayer(countryIDRaster, visParams, 'Country OBJECTID Raster');

// Step 6: Download the MODIS Land Cover dataset clipped to the region
var modis_lc = ee.ImageCollection('MODIS/061/MCD12Q1')
.filter(ee.Filter.date('2021-01-01', '2021-12-31'))
.first()
.select('LC_Type1');  // Select only the land cover type band

// Clip the MODIS dataset to the entire region shapefile
var modis_lc_clipped = modis_lc.clip(regionShapefile);

// Step 7: Display the land cover raster on the map
var landCoverVisParams = {
  min: 1,
  max: 17,  // Based on MODIS land cover classification scheme (1-17)
  palette: [
    '05450a', '086a10', '54a708', '78d203', '009900', 'c6b044', 'dcd159',
    'dade48', 'fbff13', 'b6ff05', '27ff87', 'c24f44', 'a5a5a5', 'ff6d4c',
    '69fff8', 'f9ffa4', '1c0dff'
  ]
};

// Step 8: Add the clipped MODIS land cover layer to the map
Map.addLayer(modis_lc_clipped, landCoverVisParams, 'MODIS Land Cover 2021');

// Step 9: Create a dictionary to keep track of the unique countries and their geometries
var countryGeometries = regionShapefile.reduceToVectors({
  geometryType: 'polygon',
  reducer: ee.Reducer.first(),
  scale: 500,
  geometry: true
});

// Display the geometries
Map.addLayer(countryGeometries, {}, 'Country Geometries');


#-------------------------------------------------------------------------------




