# ============================================================
# 0. Setup & Library Calls
# ============================================================
# 
# 
base_dir <- getwd()

# Load libraries
library(terra)      # for raster manipulations
library(R.utils)    # for gunzip decompression

# ============================================================
# 1. Relative Paths for Data
# ============================================================
# Shapefile for sub-Saharan (or southern) Africa (relative path)
shapefile_path <- file.path(base_dir, 
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

# Scenarios (Actual folder names)
scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")

# Simulations (s1..s10)
simulations <- paste0("s", 1:10)

# Output directory
plum_output_dir <- file.path(base_dir, "LU_ref_dataset", "PLUM_2021_subS_WGS84_rasters")
dir.create(plum_output_dir, showWarnings = FALSE, recursive = TRUE)

# ============================================================
# 2. Load & Reproject the Shapefile to WGS84
# ============================================================
region <- vect(shapefile_path)
region_wgs84 <- project(region, "EPSG:4326")

# ============================================================
# 3. Function to Process LandCover.txt.gz
# ============================================================
processLandCover <- function(gz_file, region_shp, out_dir, scenario, sim, overwrite=TRUE) {
  
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

# ============================================================
# 

# ============================================================
# Inspection of a Single Scenario/Simulation

plum_output_dir <- file.path(base_dir, "LU_ref_dataset", "PLUM_2021_subS_WGS84_rasters")

# Example scenario & simulation to inspect
scenario <- "SSP1_RCP26"
sim      <- "s10"

# Path to the clipped PLUM file
plum_file <- file.path(
  plum_output_dir, 
  paste0(scenario, "_", sim, "_2021_LandCover_subS.tif")
)
cat("Loading PLUM raster:", plum_file, "\n")

plum_r_1 <- rast(plum_file)
plot(plum_r_1)

# Suppose df has columns: Lon, Lat, Protection, TotalArea, Cropland, Pasture, ...
# We'll focus on these fraction columns (ignore "Protection","TotalArea","Lon","Lat")

# Suppose your fraction columns are named as follows in the raster:
fraction_cols <- c(
  "Cropland","Pasture","TimberForest","CarbonForest",
  "UnmanagedForest","OtherNatural","Photovoltaics",
  "Agrivoltaics","Barren","Urban"
)

# If needed, rename raster layers to match fraction_cols exactly
# (Uncomment if your layer names differ from the fraction_cols above)
# names(plum_r_1) <- fraction_cols

# ============================================================
# 2. Convert to a Data Frame
# ============================================================
# By default, na.rm=FALSE -> we keep all rows, including any NAs
df <- as.data.frame(plum_r_1, na.rm=FALSE)

# Print a quick sample
cat("\nFirst few rows of data frame:\n")
print(head(df))

# ============================================================
# 3. Compute Sum, Min, Max for Each Fraction Column
# ============================================================
# We'll create a matrix with rows = (Sum, Min, Max)
# and columns = each fraction layer

inspection_matrix <- sapply(fraction_cols, function(colname) {
  vals <- df[[colname]]
  c(
    Sum = sum(vals, na.rm=TRUE),
    Min = min(vals, na.rm=TRUE),
    Max = max(vals, na.rm=TRUE)
  )
})

# Convert to a more readable format (rows=stat, cols=layer)
inspection_matrix <- round(inspection_matrix, 6)  # optional rounding

cat("\nInspection Matrix (Sum, Min, Max):\n")
print(inspection_matrix)

# If you prefer to see it transposed (layer as rows):
cat("\nTransposed (layer-wise):\n")
print(t(inspection_matrix))

# ============================================================
# 4. Example: Bar Plot of Sums
# ============================================================
cat("\nPlotting total sum of each fraction column...\n")
barplot(inspection_matrix["Sum", ],
        names.arg = fraction_cols,
        las=2,              # rotate label text
        col="steelblue",
        main=paste("Total Values by Layer (", scenario, sim, "2021)"),
        ylab="Sum of pixel values")


# Path to the (already clipped) MODIS 2021 file
# If you haven't clipped it yet, use your original modis_ref_map_2.tif or the clipped version
modis_file <- file.path(base_dir, 
                        "LU_ref_dataset", 
                        "LU_ref_Modis_500m", 
                        "modis_ref_map_2.tif")
cat("Loading MODIS raster:", modis_file, "\n")
modis_r <- rast(modis_file)



# ============================================================
# 2. Inspect Classes / Values
# ============================================================
cat("\n--- PLUM Raster Summary ---\n")
print(plum_r)
cat("\nUnique PLUM Values:\n")
print(unique(values(plum_r)))

cat("\nFrequency Table for PLUM (top few rows):\n")
plum_freq <- freq(plum_r_1, digits=0)
head(plum_freq)

cat("\n--- MODIS Raster Summary ---\n")
print(modis_r)
cat("\nUnique MODIS Values:\n")
print(unique(values(modis_r)))

cat("\nFrequency Table for MODIS (top few rows):\n")
modis_freq <- freq(modis_r, digits=0)
head(modis_freq)

cat("\nDone! Please share these outputs for further review.\n")

summary(plum_r_1)

# ============================================================
# Area‐weighted disaggregation

# ============================================================
# 0. Setup & Libraries
# ============================================================
base_dir <- getwd()

library(terra)

# Paths
coarse_plum_dir <- file.path(base_dir, "LU_ref_dataset", "PLUM_2021_subS_WGS84_rasters")
modis_fine_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "modis_ref_map_2.tif")
disagg_dir      <- file.path(base_dir, "LU_ref_dataset", "PLUM_disaggregated_500m")

dir.create(disagg_dir, showWarnings=FALSE, recursive=TRUE)

# Scenarios
scenarios   <- c("SSP1_RCP26","SSP2_RCP45","SSP3_RCP70","SSP4_RCP60","SSP5_RCP85")
simulations <- paste0("s", 1:10)

# The fraction layers
plum_categories <- c("Cropland","Pasture","TimberForest","UnmanagedForest",
                     "OtherNatural","Barren","Urban")

# Load finer MODIS reference for geometry
cat("Loading MODIS 500m classification from:\n", modis_fine_path, "\n")
modis_fine <- rast(modis_fine_path)

# ============================================================
# 1. Function: row–col bounding approach
# ============================================================
disaggregateByRowCol <- function(plum_coarse, modis_fine, fraction_layers) {
  
  # Dimensions of coarse
  n_r_coarse <- nrow(plum_coarse)
  n_c_coarse <- ncol(plum_coarse)
  xres_coarse <- xres(plum_coarse)
  yres_coarse <- yres(plum_coarse)
  
  cat(sprintf("Coarse raster dimension: %d rows × %d cols\n", n_r_coarse, n_c_coarse))
  cat(sprintf("Coarse cell resolution: %.4f° x %.4f°\n", xres_coarse, yres_coarse))
  
  # Extract fraction array
  cat("Extracting fraction array...\n")
  frac_array <- as.array(plum_coarse[[fraction_layers]])
  dim_fa <- dim(frac_array)
  if (length(dim_fa) != 3) {
    stop("Expected a 3D array [nrow, ncol, #layers], got dim=", paste(dim_fa, collapse="x"))
  }
  cat("frac_array dimension =", paste(dim_fa, collapse=" × "), "\n")
  
  # Prepare empty fine raster
  cat("Creating empty fine raster...\n")
  plum_fine <- rast(modis_fine)
  plum_fine[] <- NA
  
  # Category lookup
  cat_ids <- seq_along(fraction_layers)
  catdf   <- data.frame(value=cat_ids, landuse=fraction_layers)
  
  # Start row-col loop
  cat("Starting row–column disaggregation...\n")
  
  for (row_i in seq_len(n_r_coarse)) {
    for (col_j in seq_len(n_c_coarse)) {
      
      # fraction vector for that cell
      frac_vector <- frac_array[row_i, col_j, ]
      if (all(is.na(frac_vector))) next
      
      sum_frac <- sum(frac_vector, na.rm=TRUE)
      if (sum_frac <= 0) next
      
      # bounding box of that coarse cell
      x_center <- xFromCol(plum_coarse, col_j)
      y_center <- yFromRow(plum_coarse, row_i)
      
      xMin <- x_center - xres_coarse/2
      xMax <- x_center + xres_coarse/2
      yMax <- y_center + yres_coarse/2
      yMin <- y_center - yres_coarse/2
      
      # row/col range in modis_fine
      # top row is rowFromY for yMax, bottom row is rowFromY for yMin
      row_top    <- rowFromY(modis_fine, yMax)
      row_bottom <- rowFromY(modis_fine, yMin)
      if (is.na(row_top) || is.na(row_bottom)) next
      
      # note row_top > row_bottom if yMax>yMin, but terra's row numbers go top=1, bottom=nrow
      r_min <- min(row_top, row_bottom, na.rm=TRUE)
      r_max <- max(row_top, row_bottom, na.rm=TRUE)
      if (r_min < 1 || r_min > nrow(modis_fine)) next
      if (r_max < 1 || r_max > nrow(modis_fine)) next
      if (r_min > r_max) next
      
      col_left  <- colFromX(modis_fine, xMin)
      col_right <- colFromX(modis_fine, xMax)
      if (is.na(col_left) || is.na(col_right)) next
      
      c_min <- min(col_left, col_right, na.rm=TRUE)
      c_max <- max(col_left, col_right, na.rm=TRUE)
      if (c_min < 1 || c_min > ncol(modis_fine)) next
      if (c_max < 1 || c_max > ncol(modis_fine)) next
      if (c_min > c_max) next
      
      # Now gather sub-pixel cells from (r_min..r_max, c_min..c_max)
      row_seq <- seq.int(r_min, r_max)
      col_seq <- seq.int(c_min, c_max)
      
      # total sub-pixels
      N_sub <- length(row_seq)*length(col_seq)
      # build the vector of cell indices
      subpix_idx <- vector("integer", N_sub)
      
      k <- 1
      for (rr in row_seq) {
        for (cc in col_seq) {
          subpix_idx[k] <- cellFromRowCol(modis_fine, rr, cc)
          k <- k+1
        }
      }
      
      # random assignment
      normed <- frac_vector / sum_frac
      assign_counts <- round(N_sub * normed)
      shortfall <- N_sub - sum(assign_counts)
      
      if (shortfall != 0) {
        for (jj in seq_len(abs(shortfall))) {
          pick <- sample(seq_along(assign_counts), 1)
          assign_counts[pick] <- assign_counts[pick] + sign(shortfall)
        }
      }
      
      # shuffle subpix_idx
      subpix_idx_shuffled <- sample(subpix_idx)
      
      start_idx <- 1
      for (cat_i in seq_along(fraction_layers)) {
        count_cat <- assign_counts[cat_i]
        if (count_cat <= 0) next
        
        end_idx <- start_idx + count_cat - 1
        these_cells <- subpix_idx_shuffled[start_idx:end_idx]
        plum_fine[these_cells] <- cat_i
        start_idx <- end_idx + 1
      }
    }
  }
  
  # define levels
  levels(plum_fine) <- list(catdf)
  cat("Finished disaggregating.\n")
  return(plum_fine)
}

# ============================================================
# 2) Main Loop Over Scenarios & Simulations
# ============================================================
for (scen in scenarios) {
  for (sim in simulations) {
    coarse_file <- file.path(coarse_plum_dir, paste0(scen,"_", sim, "_2021_LandCover_subS.tif"))
    if (!file.exists(coarse_file)) {
      cat("No coarse file found for:", scen, sim, "\n")
      next
    }
    
    out_name <- paste0(scen, "_", sim, "_2021_LandCover_500m_disagg.tif")
    out_path <- file.path(disagg_dir, out_name)
    
    cat("\n============================================\n")
    cat("Disaggregating:", coarse_file, "\n")
    plum_coarse <- rast(coarse_file)
    
    # disaggregate
    plum_disagg <- disaggregateByRowCol(plum_coarse, modis_fine, plum_categories)
    
    # save
    writeRaster(plum_disagg, out_path, overwrite=TRUE)
    cat("✅ Saved disaggregated PLUM at:", out_path, "\n")
  }
}

cat("\nAll done! Check your 'PLUM_disaggregated_500m' folder.\n")

# ============================================================
# 





# ============================================================
# 0) Setup
# ============================================================
base_dir <- getwd()

library(terra)

# The main root folder where scenario/sim subfolders are
plum_root_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs")

# Scenarios & simulations you want to check
scenarios   <- c("SSP1_RCP26","SSP2_RCP45","SSP3_RCP70","SSP4_RCP60","SSP5_RCP85")
simulations <- paste0("s", 1:5)
year_of_interest <- 2021


# Fraction columns in your TIF
fraction_cols <- c(
  "Cropland","Pasture","TimberForest","CarbonForest",
  "UnmanagedForest","OtherNatural","Photovoltaics",
  "Agrivoltaics","Barren","Urban"
)

# ============================================================
# 1) Loop Over Each Scenario & Sim
# ============================================================
for (scenario in scenarios) {
  for (sim in simulations) {
    
    # The masked TIF name, e.g. "SSP1_RCP26_s1_2020_MultiLayer_masked.tif"
    masked_name <- paste0(scenario, "_", sim, "_", year_of_interest, "_MultiLayer_masked.tif")
    masked_path <- file.path(plum_root_dir, scenario, sim, as.character(year_of_interest), masked_name)
    
    cat("\n-----------------------------------------------------\n")
    cat("Scenario:", scenario, ", Simulation:", sim, ", Year:", year_of_interest, "\n")
    cat("Looking for masked TIF at:", masked_path, "\n")
    
    if (!file.exists(masked_path)) {
      cat("File not found. Skipping...\n")
      next
    }
    
    # Load the masked TIF
    masked_r <- rast(masked_path)
    
    # Convert to data frame
    df <- as.data.frame(masked_r, na.rm=FALSE)
    
    # Print first rows
    cat("First few rows of the masked data frame:\n")
    print(head(df))
    
    # Summaries for each fraction column
    inspection_matrix <- sapply(fraction_cols, function(colname) {
      if (!colname %in% names(df)) {
        return(c(Sum=NA, Min=NA, Max=NA))
      }
      vals <- df[[colname]]
      c(
        Sum = sum(vals, na.rm=TRUE),
        Min = min(vals, na.rm=TRUE),
        Max = max(vals, na.rm=TRUE)
      )
    })
    
    cat("\nInspection Matrix (Sum, Min, Max):\n")
    print(round(inspection_matrix, 6))
    
    cat("\nTransposed (layer-wise):\n")
    print(t(round(inspection_matrix, 6)))
    
    # Quick barplot of sums
    sums <- inspection_matrix["Sum", ]
    sums[is.na(sums)] <- 0  # if some fraction col wasn't found
    
    barplot(sums,
            names.arg=fraction_cols,
            las=2,
            col="steelblue",
            main=paste("Total Values (cropped) -", scenario, sim, year_of_interest),
            ylab="Sum of pixel values")
    
    cat("-----------------------------------------------------\n")
  }
}

cat("\n✅ Done inspecting 2020 masked TIFs!\n")







# ============================================================
# Compare year=2021 for two runs: (SSP1_RCP26, s1) vs (SSP5_RCP85, s5)
# ============================================================

library(terra)

base_dir <- getwd()
plum_root_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs")

# The fraction columns we typically focus on:
fraction_cols <- c(
  "Cropland","Pasture","TimberForest","CarbonForest",
  "UnmanagedForest","OtherNatural","Photovoltaics",
  "Agrivoltaics","Barren","Urban"
)

# --------------------------
# 1) Load & Summarize a function
# --------------------------
summarize_masked_raster <- function(scenario, sim, year) {
  
  # Path to the masked TIF
  masked_name  <- paste0(scenario, "_", sim, "_", year, "_MultiLayer_masked.tif")
  masked_path  <- file.path(plum_root_dir, scenario, sim, as.character(year), masked_name)
  
  if(!file.exists(masked_path)) {
    cat("No masked raster found at:", masked_path, "\n")
    return(NULL)
  }
  
  r <- rast(masked_path)
  df <- as.data.frame(r, na.rm = FALSE)  # keep all rows, including NA
  # Summaries
  sums <- sapply(fraction_cols, function(col_nm) sum(df[[col_nm]], na.rm=TRUE))
  
  # Return both the path and sums
  list(
    path = masked_path,
    sums = sums
  )
}

# --------------------------
# 2) Run the function for the two runs
# --------------------------
res_s1 <- summarize_masked_raster("SSP1_RCP26", "s1", 2021)
res_s5 <- summarize_masked_raster("SSP5_RCP85", "s5", 2021)

if (is.null(res_s1) || is.null(res_s5)) {
  stop("One or both masked rasters not found. Please check the paths.")
}

cat("\n--- Inspection for SSP1_RCP26 - s1 - 2021 ---\n",
    "Path:", res_s1$path, "\n",
    "Sums:\n"); print(res_s1$sums)
cat("\n--- Inspection for SSP5_RCP85 - s5 - 2021 ---\n",
    "Path:", res_s5$path, "\n",
    "Sums:\n"); print(res_s5$sums)

# --------------------------
# 3) Plot two barplots
# --------------------------
opar <- par(no.readonly=TRUE)
par(mfrow=c(1,2), mar=c(8,4,4,1))  # 2 plots side by side, more bottom margin for labels

# We can plot them with the same y-limit for easier comparison
max_val <- max( c(res_s1$sums, res_s5$sums) )

barplot(res_s1$sums,
        names.arg   = fraction_cols,
        las         = 2,        # vertical labels
        ylim        = c(0, max_val),
        main        = "SSP1_RCP26, s1 (2021)",
        col         = "steelblue")

barplot(res_s5$sums,
        names.arg   = fraction_cols,
        las         = 2,
        ylim        = c(0, max_val),
        main        = "SSP5_RCP85, s5 (2021)",
        col         = "tomato")

par(opar)  # restore original par settings







library(terra)


base_dir <- getwd()
plum_root_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs")

# Example scenario/sim/year:
scenario <- "SSP1_RCP26"
sim      <- "s1"
year     <- 2021

# Construct path to your masked TIF
masked_name  <- paste0(scenario, "_", sim, "_", year, "_MultiLayer_masked.tif")
masked_path  <- file.path(plum_root_dir, scenario, sim, as.character(year), masked_name)
musked_path  # Check the path
# Load the raster
r_masked <- rast(masked_path)

# Suppose you want to visualize the "Cropland" layer:
# (Make sure the layer name or index matches what is in your raster)
if (! "Cropland" %in% names(r_masked)) {
  stop("No 'Cropland' layer found. Check layer names with `names(r_masked)`.")
}

# Single-layer plot
plot(r_masked[["Cropland"]],
     main = paste("Cropland:", scenario, sim, year),
     col  = hcl.colors(50, "Reds", rev=TRUE)) 





plot(r_masked, nc=3) 


value_unit <- "million hectares"
cat("Values in raster are in:", value_unit, "\n")

print(crs(r_masked))
summary(r_masked)



#=============================================================


# Crop to align extend
library(terra)

# === 0. Setup ===
base_dir <- getwd()
plum_root_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs")

# Reference MODIS raster clearly defined
modis_r <- rast(file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m",
                          "MODIS_LandCover_2021_SouthernAfrica.tif"))

# Scenarios and simulations explicitly set (s1:s10 clearly)
scenarios   <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
simulations <- paste0("s", 1:10)
year_of_interest <- 2021

# === 1. Loop Over Each Scenario & Simulation ===
for (scenario in scenarios) {
  for (sim in simulations) {
    
    # Original masked raster path clearly constructed
    masked_name <- paste0(scenario, "_", sim, "_", year_of_interest, "_MultiLayer_masked.tif")
    masked_path <- file.path(plum_root_dir, scenario, sim, as.character(year_of_interest), masked_name)
    
    # Check file existence
    if (!file.exists(masked_path)) {
      cat("⚠️ File NOT found, skipping:", masked_path, "\n")
      next
    }
    
    cat("✅ Processing:", masked_name, "\n")
    
    # Load the masked raster
    masked_r <- rast(masked_path)
    
    # Crop clearly to MODIS extent
    cropped_r <- crop(masked_r, modis_r)
    
    # New file name clearly created (replace '_masked' with '_cropped')
    cropped_name <- sub("_masked.tif$", "_cropped.tif", masked_name)
    cropped_path <- file.path(dirname(masked_path), cropped_name)
    
    # Write the cropped raster clearly
    writeRaster(cropped_r, cropped_path, overwrite=TRUE)
    
    cat("   ➡️ Cropped raster saved at:", cropped_path, "\n\n")
  }
}

cat("\n🎉 All rasters cropped successfully!\n")






#============================================================

# Second test with column and class names that are not needed removed
library(terra)
library(foreach)
library(doParallel)
library(data.table)

# === Setup ===
base_dir <- getwd()
modis_path <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", 
                        "MODIS_LandCover_2021_SouthernAfrica.tif")
plum_root <- file.path(base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs")
output_root <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables")

scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
simulations <- paste0("s", seq(2, 10, 2))  # s2, s4, s6, s8, s10
year <- 2021

drop_plum <- c("cell_area", "cell_area_calc", "Protection", 
               "CarbonForest", "Agrivoltaics", "Photovoltaics")

# === Parallel setup ===
num_cores <- max(1, parallel::detectCores(logical = TRUE) - 1)
cl <- makeCluster(num_cores)
registerDoParallel(cl)
cat("🚀 Using", num_cores, "cores\n")

# === Parallel synergy matrix builder ===
foreach(scenario = scenarios, .packages = c("terra", "data.table")) %:%
  foreach(sim = simulations, .packages = c("terra", "data.table")) %dopar% {
    
    # Build PLUM path
    plum_path <- file.path(plum_root, scenario, sim, as.character(year),
                           paste0(scenario, "_", sim, "_", year, "_MultiLayer_cropped.tif"))
    if (!file.exists(plum_path)) {
      cat("⚠️ Skipping missing file:", plum_path, "\n")
      return(NULL)
    }
    
    # Load MODIS and PLUM
    modis_r <- rast(modis_path)
    plum_r <- rast(plum_path)
    
    # Drop unwanted PLUM layers
    keep_layers <- setdiff(names(plum_r), drop_plum)
    plum_r <- plum_r[[keep_layers]]
    
    # Convert PLUM to polygon zones
    plum_zones <- as.polygons(plum_r[[1]], dissolve = FALSE)
    plum_zones$zone_id <- 1:ncell(plum_r)
    
    # Zonal MODIS counts inside PLUM cells
    modis_extract <- terra::extract(modis_r, plum_zones, fun = table, exact = TRUE)
    
    # Combine PLUM + MODIS fractions
    plum_df <- as.data.frame(plum_r, cells = TRUE, na.rm = FALSE)
    plum_df$zone_id <- 1:nrow(plum_df)
    merged_df <- merge(plum_df, modis_extract, by.x = "zone_id", by.y = "ID", all = FALSE)
    
    # Identify MODIS classes
    modis_class_cols <- setdiff(names(merged_df), c("zone_id", "cell", names(plum_r)))
    
    # Build synergy matrix
    synergy <- matrix(0,
                      nrow = length(names(plum_r)),
                      ncol = length(modis_class_cols),
                      dimnames = list(names(plum_r), modis_class_cols))
    
    for (p_col in names(plum_r)) {
      for (m_col in modis_class_cols) {
        synergy[p_col, m_col] <- sum(merged_df[[p_col]] * merged_df[[m_col]], na.rm = TRUE)
      }
    }
    
    # Normalize row-wise
    synergy_frac <- synergy / rowSums(synergy)
    
    # Prepare output
    output_dir <- file.path(output_root, scenario)
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    
    file_base <- paste0(scenario, "_", sim, "_", year, "_SynergyFrac")
    write.csv(round(synergy_frac, 6),
              file = file.path(output_dir, paste0(file_base, ".csv")),
              row.names = TRUE)
    
    saveRDS(synergy_frac,
            file = file.path(output_dir, paste0(file_base, ".rds")))
    
    cat("✅ Done:", scenario, sim, "\n")
    return(TRUE)
  }

stopCluster(cl)
cat("\n🎉 All synergy tables regenerated cleanly with correct structure.\n")


#============================================================


# Combine all synergy tables into a global synergy table for each scenario.


library(data.table)

# === Setup ===
base_dir <- getwd()
synergy_dir <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables")
scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
simulations <- paste0("s", seq(2, 10, 2))  # s2, s4, s6, s8, s10
year <- 2021

# === Aggregation loop ===
for (scenario in scenarios) {
  cat("\n📊 Aggregating scenario:", scenario, "\n")
  
  synergy_list <- list()
  scenario_dir <- file.path(synergy_dir, scenario)
  
  for (sim in simulations) {
    rds_path <- file.path(scenario_dir, paste0(scenario, "_", sim, "_", year, "_SynergyFrac.rds"))
    if (!file.exists(rds_path)) {
      cat("⚠️ Missing:", rds_path, "\n")
      next
    }
    synergy_list[[sim]] <- readRDS(rds_path)
    cat("✅ Loaded:", sim, "\n")
  }
  
  if (length(synergy_list) == 0) {
    cat("❌ No synergy matrices found for", scenario, "\n")
    next
  }
  
  # === Element-wise sum ===
  summed_matrix <- Reduce(`+`, synergy_list)
  
  # === Normalize row-wise ===
  normalized_matrix <- summed_matrix / rowSums(summed_matrix)
  
  # === Save output ===
  output_base <- paste0(scenario, "_GlobalSynergy_", year)
  output_csv  <- file.path(scenario_dir, paste0(output_base, ".csv"))
  output_rds  <- file.path(scenario_dir, paste0(output_base, ".rds"))
  
  write.csv(round(normalized_matrix, 6), output_csv, row.names = TRUE)
  saveRDS(normalized_matrix, output_rds)
  
  cat("✅ Global synergy table saved:\n   -", output_csv, "\n   -", output_rds, "\n")
}

cat("\n🎉 All global synergy tables aggregated and saved!\n")



# ============================================================

# Investigate the synergy tables for each scenario to see
# how consistent are they with each other


library(data.table)

# Start by renaming the MODIS layer names in the synergy tables to LC1...LC17
base_dir <- getwd()
synergy_root <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables")
scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
simulations <- paste0("s", seq(2, 10, 2))  # s2, s4, ..., s10
year <- 2021

# Mapping MODIS numeric classes to LC1...LC17
modis_map <- setNames(paste0("LC", 1:17), as.character(1:17))  # key = "1", value = "LC1"

# === Renaming loop ===
for (scenario in scenarios) {
  scenario_dir <- file.path(synergy_root, scenario)
  
  for (sim in simulations) {
    rds_path <- file.path(scenario_dir, paste0(scenario, "_", sim, "_", year, "_SynergyFrac.rds"))
    
    if (!file.exists(rds_path)) {
      cat("⚠️ File not found, skipping:", rds_path, "\n")
      next
    }
    
    # Load RDS
    synergy <- readRDS(rds_path)
    
    # Rename MODIS columns if numeric
    old_cols <- colnames(synergy)
    new_cols <- ifelse(old_cols %in% names(modis_map), modis_map[old_cols], old_cols)
    colnames(synergy) <- new_cols
    
    # Save to new RDS with suffix
    renamed_path <- sub("_SynergyFrac.rds", "_SynergyFrac_Renamed.rds", rds_path)
    saveRDS(synergy, renamed_path)
    
    cat("✅ Renamed MODIS columns and saved:\n   -", renamed_path, "\n")
  }
}

cat("\n🎉 MODIS column renaming complete for all synergy matrices.\n")

# ============================================================


# Rename the MODIS columns in the global synergy tables as well


# === Rename MODIS columns in global synergy tables ===
modis_map <- setNames(paste0("LC", 1:17), as.character(1:17))

for (scenario in c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")) {
  path <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables", scenario,
                    paste0(scenario, "_GlobalSynergy_2021.rds"))
  
  if (!file.exists(path)) {
    cat("⚠️ Missing:", path, "\n")
    next
  }
  
  synergy <- readRDS(path)
  colnames(synergy) <- ifelse(colnames(synergy) %in% names(modis_map),
                              modis_map[colnames(synergy)],
                              colnames(synergy))
  
  new_path <- sub(".rds", "_Renamed.rds", path)
  saveRDS(synergy, new_path)
  cat("✅ Global synergy renamed and saved:", new_path, "\n")
}



# ============================================================

# Similarity Analysis per Scenario iteration sample
# Investigate the synergy tables for each scenario iteration (simulations s2, s4, ..., s10)
# 
# 

library(data.table)
library(ggplot2)
library(reshape2)
library(stats)

# === Setup ===
base_dir <- getwd()
synergy_root <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables")
scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
simulations <- paste0("s", seq(2, 10, 2))
year <- 2021

# === Functions ===
rmse <- function(x, y) sqrt(mean((x - y)^2))
cosine_sim <- function(x, y) sum(x * y) / (sqrt(sum(x^2)) * sqrt(sum(y^2)))

# === Loop through each scenario ===
for (scenario in scenarios) {
  cat("\n🔍 Analyzing scenario:", scenario, "\n")
  scenario_dir <- file.path(synergy_root, scenario)
  all_matrices <- list()
  
  # --- Load simulations ---
  for (sim in simulations) {
    path <- file.path(scenario_dir, paste0(scenario, "_", sim, "_", year, "_SynergyFrac_Renamed.rds"))
    if (file.exists(path)) {
      m <- readRDS(path)
      all_matrices[[sim]] <- as.vector(as.matrix(m))
    } else {
      cat("⚠️ Missing:", path, "\n")
    }
  }
  
  # --- Load global ---
  global_path <- file.path(scenario_dir, paste0(scenario, "_GlobalSynergy_", year, "_Renamed.rds"))
  if (file.exists(global_path)) {
    all_matrices[["global"]] <- as.vector(as.matrix(readRDS(global_path)))
  } else {
    cat("❌ Missing global matrix:", global_path, "\n")
    next
  }
  
  sim_names <- names(all_matrices)
  n <- length(sim_names)
  if (n < 2) {
    cat("⚠️ Not enough matrices found, skipping.\n")
    next
  }
  
  # --- Init similarity matrices ---
  rmse_mat <- matrix(NA, n, n, dimnames = list(sim_names, sim_names))
  cosine_mat <- matrix(NA, n, n, dimnames = list(sim_names, sim_names))
  corr_mat <- matrix(NA, n, n, dimnames = list(sim_names, sim_names))
  
  # --- Compute metrics ---
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      x <- all_matrices[[i]]
      y <- all_matrices[[j]]
      rmse_mat[i, j] <- rmse(x, y)
      cosine_mat[i, j] <- cosine_sim(x, y)
      corr_mat[i, j] <- cor(x, y, use = "complete.obs")
    }
  }
  
  # === Save outputs ===
  metrics_list <- list(
    RMSE = rmse_mat,
    CosineSimilarity = cosine_mat,
    Correlation = corr_mat
  )
  
  out_rds <- file.path(scenario_dir, paste0(scenario, "_SimilarityMetrics_", year, ".rds"))
  out_csv <- file.path(scenario_dir, paste0(scenario, "_SimilarityMetrics_", year, ".csv"))
  saveRDS(metrics_list, out_rds)
  
  # Save correlation matrix as CSV (example only)
  fwrite(as.data.table(corr_mat, keep.rownames = "Sim"), out_csv)
  
  cat("✅ Metrics saved:\n -", out_rds, "\n -", out_csv, "\n")
  
  # === Visualizations ===
  # Heatmap
  corr_long <- melt(corr_mat)
  names(corr_long) <- c("Sim1", "Sim2", "Correlation")
  
  p <- ggplot(corr_long, aes(Sim1, Sim2, fill = Correlation)) +
    geom_tile(color = "white") +
    scale_fill_gradient2(low = "red", high = "steelblue", mid = "white", midpoint = 0.85,
                         limits = c(0, 1), name = "Pearson r") +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    ggtitle(paste("Similarity Heatmap -", scenario))
  
  ggsave(file.path(scenario_dir, paste0(scenario, "_SimilarityHeatmap_", year, ".png")),
         p, width = 7, height = 6)
  
  # Dendrogram (clustering on correlation distance)
  dist_mat <- as.dist(1 - corr_mat)
  hc <- hclust(dist_mat, method = "average")
  
  png(file.path(scenario_dir, paste0(scenario, "_ClusteringDendrogram_", year, ".png")),
      width = 800, height = 600)
  plot(hc, main = paste("Clustering -", scenario),
       xlab = "", sub = "", ylab = "1 - Correlation Distance")
  dev.off()
  
  cat("📈 Plots saved.\n")
}

cat("\n🎉 All similarity metrics computed and plots saved for all scenarios.\n")



# ============================================================



library(png)
library(grid)
library(gridExtra)

# Base setup
base_dir <- getwd()
scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
year <- 2021

# Load PNGs into raster image grobs
image_grobs <- lapply(scenarios, function(scen) {
  path <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables", scen,
                    paste0(scen, "_ClusteringDendrogram_", year, ".png"))
  if (!file.exists(path)) stop("Missing dendrogram image:", path)
  rasterGrob(readPNG(path), interpolate = TRUE)
})

# Arrange into 3 + 2 layout
png("All_Dendrograms_3x2.png", width = 1600, height = 900)
grid.arrange(
  grobs = image_grobs,
  layout_matrix = rbind(c(1, 2, 3),
                        c(4, 5, NA))  # 3 on top row, 2 below (centered)
)
dev.off()





# ============================================================

# Full summary table with closest to global
summary_df <- data.frame(
  Scenario = c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85"),
  Best_Simulation = c("s6", "s6", "s4", "s4", "s6"),
  Most_Dissimilar_Simulation = c("s8", "s10", "s6", "s10", "s8"),
  Closest_to_Global = c("s6", "s6", "s4", "s6", "s6")  # Based on correlation or lowest RMSE
)

# Print
print(summary_df)
# Save summary as PNG image



# ============================================================


# =============================
# Expert-Constrained Normalization (Full Workflow)
# =============================

library(data.table)
library(terra)

# === Parameters ===
base_dir <- getwd()
country_synergy_dir <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables", "by_country")
modis_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country")
output_dir <- file.path(country_synergy_dir, "Normalised_ExpertWeighted")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
year <- 2021
interval <- 0.1
cutoff <- 0.001
round_digits <- 1

# === Expert-Allowed MODIS per PLUM Class ===
allowed_modis <- list(
  Cropland = c("LC12", "LC14"),
  Pasture = c("LC6", "LC7", "LC8", "LC9"),
  TimberForest = c("LC1", "LC2", "LC4", "LC5"),
  UnmanagedForest = c("LC1", "LC2", "LC4", "LC5", "LC6"),
  OtherNatural = c("LC6", "LC10", "LC11", "LC14", "LC17"),
  Barren = c("LC15", "LC16"),
  Urban = c("LC13")
)

# === Helper to generate country-specific synergy ===
generate_country_synergy <- function(global_matrix, local_modis_classes) {
  available <- intersect(colnames(global_matrix), local_modis_classes)
  if (length(available) == 0) return(NULL)
  subset <- global_matrix[, available, drop=FALSE]
  normed <- sweep(subset, 1, rowSums(subset), FUN = "/")
  return(normed)
}

# === Logical Expert Normalization Function with enforced expert priority ===
normalize_synergy_logical <- function(matrix, original_matrix, allowed, present_modis, interval = 0.1, cutoff = 0.001) {
  all_modis <- intersect(colnames(matrix), present_modis)
  all_columns <- colnames(matrix)
  
  out <- t(sapply(rownames(matrix), function(rowname) {
    expert_allowed <- intersect(allowed[[rowname]], all_modis)
    row <- matrix[rowname, ]
    
    # Zero out all disallowed
    row[setdiff(names(row), expert_allowed)] <- 0
    row[row < cutoff] <- 0
    
    total <- sum(row)
    if (total > 0) {
      row_norm <- row / total
      rounded <- round(row_norm / interval) * interval
      diff <- 1 - sum(rounded)
      if (abs(diff) >= interval / 2 && any(rounded > 0)) {
        max_idx <- which.max(rounded)
        rounded[max_idx] <- rounded[max_idx] + diff
      }
      padded <- rep(0, length(all_columns))
      names(padded) <- all_columns
      padded[names(rounded)] <- rounded
      return(round(padded, round_digits))
    }
    
    # === Fallback ===
    fallback_row <- rep(0, length(all_columns))
    names(fallback_row) <- all_columns
    
    fallback_primary <- if (length(expert_allowed) > 0) expert_allowed[1] else all_columns[1]
    fallback_row[fallback_primary] <- 0.7
    
    original_row <- original_matrix[rowname, setdiff(all_columns, fallback_primary)]
    original_row <- sort(original_row, decreasing = TRUE)
    top_classes <- names(original_row)[1:min(3, length(original_row))]
    proportions <- c(0.3, 0.2, 0.1)[1:length(top_classes)]
    fallback_row[top_classes] <- proportions
    
    return(round(fallback_row, round_digits))
  }))
  
  colnames(out) <- colnames(matrix)
  rownames(out) <- rownames(matrix)
  return(out)
}

# === Regenerate raw country synergy tables ===
rebuild_raw_country_synergy <- function() {
  synergy_root <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables")
  modis_country_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country")
  shapefile_path <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")
  region <- vect(shapefile_path)
  region_wgs84 <- project(region, "EPSG:4326")
  country_names <- sort(unique(region_wgs84$CNTRY_NAME))
  
  for (scenario in scenarios) {
    global_path <- file.path(synergy_root, scenario, paste0(scenario, "_GlobalSynergy_2021_Renamed.rds"))
    if (!file.exists(global_path)) next
    
    global_synergy <- readRDS(global_path)
    
    for (country in country_names) {
      modis_path <- file.path(modis_country_dir, paste0(country, "_modis_ref_map_8.tif"))
      if (!file.exists(modis_path)) next
      
      modis_r <- rast(modis_path)
      modis_classes <- paste0("LC", na.omit(unique(values(modis_r))))
      country_synergy <- generate_country_synergy(global_synergy, modis_classes)
      if (is.null(country_synergy)) next
      
      out_dir <- file.path(synergy_root, "by_country", country)
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      fwrite(as.data.table(round(country_synergy, 6), keep.rownames = "PLUM_Class"),
             file.path(out_dir, paste0(scenario, "_CountrySynergy_2021.csv")))
      saveRDS(country_synergy, file.path(out_dir, paste0(scenario, "_CountrySynergy_2021.rds")))
    }
  }
}

# === Run regeneration ===
rebuild_raw_country_synergy()

# === Normalize each synergy table using full matrix ===
countries <- setdiff(list.dirs(country_synergy_dir, FALSE, FALSE),
                     c("Normalised", "Normalised_ExpertWeighted"))

for (country in countries) {
  modis_r <- rast(file.path(modis_dir, paste0(country, "_modis_ref_map_8.tif")))
  present_classes <- paste0("LC", na.omit(unique(values(modis_r))))
  
  for (scenario in scenarios) {
    input_path <- file.path(country_synergy_dir, country,
                            paste0(scenario, "_CountrySynergy_2021.csv"))
    
    if (!file.exists(input_path)) {
      cat("⚠️ Missing synergy file for", country, scenario, "- skipping\n")
      next
    }
    
    synergy_raw <- fread(input_path, data.table = FALSE)
    rownames(synergy_raw) <- synergy_raw[, 1]
    synergy_raw <- synergy_raw[, -1, drop = FALSE]
    
    synergy_matrix <- as.matrix(synergy_raw)
    original_matrix <- synergy_matrix
    
    synergy_final <- tryCatch({
      normalize_synergy_logical(
        synergy_matrix, original_matrix, allowed_modis,
        present_classes, interval, cutoff)
    }, error = function(e) {
      cat("⚠️ Error normalizing synergy for", country, scenario, ":", e$message, "\n")
      return(NULL)
    })
    
    if (is.null(synergy_final)) next
    
    out_country_dir <- file.path(output_dir, country)
    dir.create(out_country_dir, recursive = TRUE, showWarnings = FALSE)
    write.csv(synergy_final, file.path(out_country_dir, paste0(country, "_", scenario, "_Expert_Weighted.csv")), row.names = TRUE)
    saveRDS(synergy_final, file.path(out_country_dir, paste0(country, "_", scenario, "_Expert_Weighted.rds")))
  }
}

cat("\n🎯 Expert-constrained synergy tables processed successfully with logical fallback for sparse classes.\n")








# Optionacodetools::

# =============================
# Expert-Constrained Normalization (Full Workflow)
# =============================

library(data.table)
library(terra)

# === Parameters ===
base_dir <- getwd()
country_synergy_dir <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables", "by_country")
modis_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country")
output_dir <- file.path(country_synergy_dir, "Normalised_ExpertWeighted")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
year <- 2021
interval <- 0.1
cutoff <- 0.001
round_digits <- 1

# === Expert-Allowed MODIS per PLUM Class ===
allowed_modis <- list(
  Cropland = c("LC12", "LC14"),
  Pasture = c("LC6", "LC7", "LC8", "LC9"),
  TimberForest = c("LC1", "LC2", "LC4", "LC5"),
  UnmanagedForest = c("LC1", "LC2", "LC4", "LC5", "LC6"),
  OtherNatural = c("LC6", "LC10", "LC11", "LC14", "LC17"),
  Barren = c("LC15", "LC16"),
  Urban = c("LC13")
)

# === Helper to generate country-specific synergy ===
generate_country_synergy <- function(global_matrix, local_modis_classes) {
  available <- intersect(colnames(global_matrix), local_modis_classes)
  if (length(available) == 0) return(NULL)
  subset <- global_matrix[, available, drop=FALSE]
  normed <- sweep(subset, 1, rowSums(subset), FUN = "/")
  return(normed)
}

# === Logical Expert Normalization Function with enforced expert priority ===
normalize_synergy_logical <- function(matrix, original_matrix, allowed, present_modis, interval = 0.1, cutoff = 0.001) {
  all_modis <- intersect(colnames(matrix), present_modis)
  all_columns <- colnames(matrix)
  
  out <- t(sapply(rownames(matrix), function(rowname) {
    expert_allowed <- intersect(allowed[[rowname]], all_modis)
    row <- matrix[rowname, ]
    
    # Zero out all disallowed
    row[setdiff(names(row), expert_allowed)] <- 0
    row[row < cutoff] <- 0
    
    total <- sum(row)
    if (total > 0) {
      row_norm <- row / total
      rounded <- round(row_norm / interval) * interval
      diff <- 1 - sum(rounded)
      if (abs(diff) >= interval / 2 && any(rounded > 0)) {
        max_idx <- which.max(rounded)
        rounded[max_idx] <- rounded[max_idx] + diff
      }
      padded <- rep(0, length(all_columns))
      names(padded) <- all_columns
      padded[names(rounded)] <- rounded
      return(round(padded, round_digits))
    }
    
    # === Fallback ===
    fallback_row <- rep(0, length(all_columns))
    names(fallback_row) <- all_columns
    
    fallback_primary <- if (length(expert_allowed) > 0) expert_allowed[1] else all_columns[1]
    fallback_row[fallback_primary] <- 0.7
    
    original_row <- original_matrix[rowname, setdiff(all_columns, fallback_primary)]
    original_row <- sort(original_row, decreasing = TRUE)
    top_classes <- names(original_row)[1:min(3, length(original_row))]
    proportions <- c(0.3, 0.2, 0.1)[1:length(top_classes)]
    fallback_row[top_classes] <- proportions
    
    return(round(fallback_row, round_digits))
  }))
  
  colnames(out) <- colnames(matrix)
  rownames(out) <- rownames(matrix)
  return(out)
}

# === Regenerate raw country synergy tables ===
rebuild_raw_country_synergy <- function() {
  synergy_root <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables")
  modis_country_dir <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m", "by_country")
  shapefile_path <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")
  region <- vect(shapefile_path)
  region_wgs84 <- project(region, "EPSG:4326")
  country_names <- sort(unique(region_wgs84$CNTRY_NAME))
  
  for (scenario in scenarios) {
    global_path <- file.path(synergy_root, scenario, paste0(scenario, "_GlobalSynergy_2021_Renamed.rds"))
    if (!file.exists(global_path)) next
    
    global_synergy <- readRDS(global_path)
    
    for (country in country_names) {
      modis_path <- file.path(modis_country_dir, paste0(country, "_modis_ref_map_8.tif"))
      if (!file.exists(modis_path)) next
      
      modis_r <- rast(modis_path)
      modis_classes <- paste0("LC", na.omit(unique(values(modis_r))))
      country_synergy <- generate_country_synergy(global_synergy, modis_classes)
      if (is.null(country_synergy)) next
      
      out_dir <- file.path(synergy_root, "by_country", country)
      dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
      fwrite(as.data.table(round(country_synergy, 6), keep.rownames = "PLUM_Class"),
             file.path(out_dir, paste0(scenario, "_CountrySynergy_2021.csv")))
      saveRDS(country_synergy, file.path(out_dir, paste0(scenario, "_CountrySynergy_2021.rds")))
    }
  }
}

# === Run regeneration ===
rebuild_raw_country_synergy()

# === Normalize each synergy table using full matrix ===
countries <- setdiff(list.dirs(country_synergy_dir, FALSE, FALSE),
                     c("Normalised", "Normalised_ExpertWeighted"))

for (country in countries) {
  modis_r <- rast(file.path(modis_dir, paste0(country, "_modis_ref_map_8.tif")))
  present_classes <- paste0("LC", na.omit(unique(values(modis_r))))
  
  for (scenario in scenarios) {
    input_path <- file.path(country_synergy_dir, country,
                            paste0(scenario, "_CountrySynergy_2021.csv"))
    
    if (!file.exists(input_path)) {
      cat("⚠️ Missing synergy file for", country, scenario, "- skipping\n")
      next
    }
    
    synergy_raw <- fread(input_path, data.table = FALSE)
    rownames(synergy_raw) <- synergy_raw[, 1]
    synergy_raw <- synergy_raw[, -1, drop = FALSE]
    
    synergy_matrix <- as.matrix(synergy_raw)
    original_matrix <- synergy_matrix
    
    synergy_final <- tryCatch({
      normalize_synergy_logical(
        synergy_matrix, original_matrix, allowed_modis,
        present_classes, interval, cutoff)
    }, error = function(e) {
      cat("⚠️ Error normalizing synergy for", country, scenario, ":", e$message, "\n")
      return(NULL)
    })
    
    if (is.null(synergy_final)) next
    
    out_country_dir <- file.path(output_dir, country)
    dir.create(out_country_dir, recursive = TRUE, showWarnings = FALSE)
    write.csv(synergy_final, file.path(out_country_dir, paste0(country, "_", scenario, "_Expert_Weighted.csv")), row.names = TRUE)
    saveRDS(synergy_final, file.path(out_country_dir, paste0(country, "_", scenario, "_Expert_Weighted.rds")))
  }
}

cat("\n🎯 Expert-constrained synergy tables processed successfully with logical fallback for sparse classes.\n")



# ==============================================================================


# =============================
# Minimum Representation Rule (MRR) Adjustment Code
# =============================

library(data.table)

# === Parameters ===
base_dir <- getwd()
input_dir <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables", "by_country", "Normalised_ExpertWeighted")
output_dir <- file.path(base_dir, "LU_ref_dataset", "Synergy_Tables", "by_country_final_synergy")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
mrr_value <- 0.1

# === Get country list from shapefile ===
library(terra)
shapefile_path <- file.path(base_dir, "SAfrica_region", "SAfrica_states_proj_final.shp")
region <- vect(shapefile_path)
region_wgs84 <- project(region, "EPSG:4326")
countries <- sort(unique(region_wgs84$CNTRY_NAME))

# === Apply MRR per country/scenario ===
for (country in countries) {
  for (scenario in scenarios) {
    input_path <- file.path(input_dir, country, paste0(country, "_", scenario, "_Expert_Weighted.csv"))
    if (!file.exists(input_path)) {
      cat("\u26a0\ufe0f Missing:", input_path, "\n")
      next
    }
    
    synergy <- fread(input_path, data.table = FALSE)
    rownames(synergy) <- synergy[, 1]
    synergy <- synergy[, -1, drop = FALSE]
    
    adjusted_matrix <- synergy
    used_rows <- character(0)
    
    for (col in colnames(synergy)) {
      col_values <- synergy[, col]
      if (all(col_values == 0)) {
        ranked_rows <- rownames(synergy)[order(rowSums(synergy), decreasing = TRUE)]
        top_row_candidates <- setdiff(ranked_rows, used_rows)
        
        if (length(top_row_candidates) == 0) {
          cat("\u26a0\ufe0f No available row to adjust for", col, "in", country, scenario, "\n")
          next
        }
        
        top_row <- top_row_candidates[1]
        used_rows <- c(used_rows, top_row)
        
        adjusted_matrix[top_row, ] <- adjusted_matrix[top_row, ] * (1 - mrr_value)
        adjusted_matrix[top_row, col] <- mrr_value
        
        adjusted_matrix[top_row, ] <- round(adjusted_matrix[top_row, ], 1)
      }
    }
    
    out_country_dir <- file.path(output_dir, country)
    dir.create(out_country_dir, recursive = TRUE, showWarnings = FALSE)
    
    write.csv(adjusted_matrix, file.path(out_country_dir, paste0(country, "_", scenario, "_Final_Synergy.csv")), row.names = TRUE)
    saveRDS(adjusted_matrix, file.path(out_country_dir, paste0(country, "_", scenario, "_Final_Synergy.rds")))
    
    cat("\u2705 Saved MRR-adjusted table for", country, scenario, "\n")
  }
}

cat("\n\ud83c\udf1f MRR adjustments complete for all country synergy tables.\n")

# =============================



