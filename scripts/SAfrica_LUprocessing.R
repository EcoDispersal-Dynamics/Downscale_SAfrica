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

# Filter the shapefile for a specific country (e.g., Angola)
country_name <- "Angola"
country_shapefile <- SAfrica_states_proj_final_shp[SAfrica_states_proj_final_shp$CNTRY_NAME == country_name, ]

# Plot the specific country's polygon
plot(country_shapefile, main = paste("Region for:", country_name))

# Loop through each country by name
# 'unique()' extracts all the unique country names from the 'CNTRY_NAME' column, which is the attribute field for country names
for (country in unique(SAfrica_states_proj_final_shp$CNTRY_NAME)) {
  
  # Filter shapefile by country
  # This creates a subset of the shapefile, selecting only the polygon(s) that correspond to the current 'country' in the loop
  country_shp <- SAfrica_states_proj_final_shp[SAfrica_states_proj_final_shp$CNTRY_NAME == country, ]
  
  # Save or process the country's data here
  # 'plot()' visualizes the shapefile of the current country on the map
  # 'main' sets the title of the plot, dynamically changing with the country name in the loop
  plot(country_shp, main = paste("Country:", country))
  
  # Adding Google Earth Engine code to download raster data for each country’s polygon region
}

#-------------------------------------------------------------------------------

# ee_clean_user_credentials()
# ee_Authenticate()  # Authenticate with Google Earth Engine. An rgee function
ee_Authenticate()
ee_Initialize()   # Initialize Google Earth Engine. An rgee function


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







