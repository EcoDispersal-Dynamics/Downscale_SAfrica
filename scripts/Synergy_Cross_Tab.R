# ============================================================
# 0. Setup & Library Calls
# ============================================================
# In the HPC environment, set your working directory:
# (Or the HPC job script may do this for you)
base_dir <- getwd()

# Load libraries
library(terra)      # for raster manipulations
library(R.utils)    # for gunzip decompression

# ============================================================
# 1. Relative Paths for Data
# ============================================================
# Shapefile for sub-Saharan (or southern) Africa (relative path)
shapefile_path <- file.path(base_dir, 
                            "LU_ref_dataset", 
                            "SAfrica_region", 
                            "SAfrica_states_proj_final.shp")

# MODIS baseline for 2021 (if needed)
modis_raster_path <- file.path(base_dir, 
                               "LU_ref_dataset", 
                               "LU_ref_Modis_500m", 
                               "modis_ref_map_2.tif")

# Root folder containing PLUM data
plum_root_dir <- file.path(base_dir, 
                           "LU_ref_dataset", 
                           "LU_ref_PLUM_SSPs")

# Scenarios (adjust to your actual folder names)
scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP60")

# Simulations (s1..s10)
simulations <- paste0("s", 1:10)

# Output directory
plum_output_dir <- file.path(base_dir, "PLUM_2021_subS_WGS84_rasters")
dir.create(plum_output_dir, showWarnings = FALSE, recursive = TRUE)

# ============================================================
# 2. Load & Reproject the Shapefile to WGS84
# ============================================================
region <- vect(shapefile_path)
region_wgs84 <- project(region, "EPSG:4326")

# ============================================================
# 3. Function to Process LandCover.txt.gz
# ============================================================
processLandCover <- function(gz_file, region_shp, out_dir, scenario, sim, overwrite=FALSE) {
  
  # 1) Decompress
  base_gz  <- basename(gz_file)
  base_txt <- sub("\\.gz$", "", base_gz)   # e.g., "LandCover.txt"
  
  unzipped_file <- file.path(dirname(gz_file), base_txt)
  
  if (!file.exists(unzipped_file) || overwrite) {
    cat("Decompressing:", gz_file, "\n")
    gunzip(gz_file, destname = unzipped_file, overwrite = overwrite)
  } else {
    cat("Already decompressed:", unzipped_file, "\n")
  }
  
  # 2) Read table
  df <- read.table(unzipped_file, header=TRUE)
  # We assume col1=lon, col2=lat, col3=value:
  names(df)[1:3] <- c("lon","lat","value")
  
  # 3) Create SpatRaster in lat/lon (WGS84)
  r <- rast(df, type="xyz", crs="EPSG:4326")
  
  # 4) Crop & mask to region
  r_crop <- crop(r, region_shp)
  r_mask <- mask(r_crop, region_shp)
  
  # 5) Write final file
  out_name <- paste0(scenario, "_", sim, "_2021_LandCover_subS.tif")
  out_path <- file.path(out_dir, out_name)
  
  writeRaster(r_mask, out_path, overwrite=TRUE)
  cat("✅ Saved:", out_path, "\n")
}

# ============================================================
# 4. Main Loop Over Scenarios/Simulations (Just "2021" folder)
# ============================================================
for (scen in scenarios) {
  
  scenario_dir <- file.path(plum_root_dir, scen)
  if (!dir.exists(scenario_dir)) {
    cat("Scenario folder not found:", scenario_dir, "\n")
    next
  }
  
  for (sim in simulations) {
    sim_dir <- file.path(scenario_dir, sim, "2021")
    
    if (!dir.exists(sim_dir)) {
      cat("No '2021' folder for:", scen, sim, "\n")
      next
    }
    
    # Only process LandCover.txt.gz
    gz_file <- file.path(sim_dir, "LandCover.txt.gz")
    
    if (!file.exists(gz_file)) {
      cat("No LandCover.txt.gz in:", sim_dir, "\n")
      next
    }
    
    cat(sprintf("\n--- Processing: %s, %s, year=2021 ---\n", scen, sim))
    processLandCover(gz_file, 
                     region_shp = region_wgs84,
                     out_dir    = plum_output_dir,
                     scenario   = scen, 
                     sim        = sim,
                     overwrite  = FALSE)
  }
}

cat("\nAll done! LandCover rasters for 2021 have been created under:\n", plum_output_dir, "\n")
