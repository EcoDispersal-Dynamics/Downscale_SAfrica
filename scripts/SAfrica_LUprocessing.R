# SAfrica region TEMPERATE 
# Purpose: Process land use data for the South Africa region

# Load required libraries



# set relative path for the temperate shapefile for the South Africa region 
SAfrica_states_temperate_path <- "SAfrica_region/SAfrica_states_proj.shp"
SAfrica_states_temperate_path
SAfrica_states_temperate <- terra::vect(SAfrica_states_temperate_path)
SAfrica_states_temperate

# Visualise the polygons map temperate shape file


