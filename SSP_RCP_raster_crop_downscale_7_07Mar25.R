# -----------------------------------------------------------------------------
# Load libraries
library(terra)
library(LandScaleR)

# -----------------------------------------------------------------------------
# PART 1: RECLASSIFY THE ORIGINAL MODIS REFERENCE MAP
# Setup base directory and country name
base_dir <- getwd()
country_name <- "Angola"

# Define the path to the original MODIS reference map (version 2)
angola_modis_raster_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                                      "by_country", "Angola_modis_ref_map_2.tif")
angola_modis_raster <- rast(angola_modis_raster_path)

# Optional: Inspect the original raster
plot(angola_modis_raster, main = "Original MODIS Reference Map")
print(unique(angola_modis_raster))
print(names(angola_modis_raster))
print(levels(angola_modis_raster))

# --- Update Levels ---
# Extract the original levels (attribute table)
orig_levels <- levels(angola_modis_raster)[[1]]
cat("Original Levels:\n")
print(orig_levels)

# Remove rows with value 3 (Deciduous_Needleleaf_Forests) and value 15 (Snow_and_Ice)
new_levels <- orig_levels[ !orig_levels$value %in% c(3, 15), ]

# Reassign new sequential values (new_value from 1 to nrow(new_levels))
new_levels$new_value <- seq_len(nrow(new_levels))

# Rename classes: assign new names as "LC1", "LC2", ..., "LC15"
new_levels$name <- paste0("LC", new_levels$new_value)
cat("Updated Levels with new LC names:\n")
print(new_levels)

# --- Create a Reclassification Matrix ---
# For each retained level, classify pixels within [old_value - 0.5, old_value + 0.5]
reclass_mat <- matrix(nrow = nrow(new_levels), ncol = 3)
for(i in seq_len(nrow(new_levels))){
  old_val <- new_levels$value[i]
  new_val <- new_levels$new_value[i]
  reclass_mat[i, ] <- c(old_val - 0.5, old_val + 0.5, new_val)
}
cat("Reclassification Matrix:\n")
print(reclass_mat)

# Reclassify the raster using terra's classify function
angola_modis_raster_new <- classify(angola_modis_raster, rcl = reclass_mat, include.lowest = TRUE)

# Update the raster's levels with the new LC names
levels(angola_modis_raster_new) <- list(new_levels[, c("new_value", "name")])
cat("New Levels in Reclassified Raster:\n")
print(levels(angola_modis_raster_new))

# Optional: Inspect the unique pixel values (will show only numbers)
print("Unique values in the reclassified raster:")
print(unique(values(angola_modis_raster_new)))

# Save the new MODIS reference map as version 6 (with levels already named LC1 - LC15)
output_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country", "Angola_modis_ref_map_7.tif")
writeRaster(angola_modis_raster_new, output_path, overwrite = TRUE)
cat("Angola_modis_ref_map_6.tif has been saved with updated LC-level names.\n")


