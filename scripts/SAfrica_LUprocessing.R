# SAfrica region TEMPERATE 
# Purpose: Process land use data for the South Africa region

# Load required libraries
# install.packages("raster")
# install.packages("terra")
library(raster)
library(terra)


# set relative path for the temperate shapefile for the South Africa region 
SAfrica_states_temperate_path <- "SAfrica_region/SAfrica_states_temperate.shp"
SAfrica_states_temperate_path
SAfrica_states_temperate <- terra::vect(SAfrica_states_temperate_path)



