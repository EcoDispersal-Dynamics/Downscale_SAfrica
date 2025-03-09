# # Load libraries
# library(terra)
# library(LandScaleR)

# -----------------------------------------------------------------------------
# *Setup Directories & File Paths
base_dir <- getwd()
country_name <- "Angola"

# Define the path to the classified MODIS reference map (version 8)
country_ref_map_file <- file.path(base_dir, "LU_ref_dataset", "LU_ref_Modis_500m",
                                  "by_country", paste0(country_name, "_modis_ref_map_8.tif"))

# 🗺️ Load Reference Map (Ensure it exists)
if (!file.exists(country_ref_map_file)) {
  stop("❌ ERROR: MODIS reference map not found at: ", country_ref_map_file)
}
ref_map <- rast(country_ref_map_file)  # Use 'ref_map' consistently
plot(ref_map, main = "Classified MODIS Reference Map - Version 8")

# 🏷️ Extract Levels & Classes
ref_levels <- levels(ref_map)[[1]]
modis_classes <- ref_levels$name
cat("✅ MODIS Classes Extracted:\n", modis_classes, "\n")

# -----------------------------------------------------------------------------
# 🌱 **Load PLUM Raster & Create Matching Matrix**
plum_raster_path <- file.path(
  base_dir, "LU_ref_dataset", "LU_ref_PLUM_SSPs", "SSP1_RCP26",
  "SSP1_RCP26_fraction", "SSP1_RCP26_fraction_croped",
  paste0(country_name, "_SSP1_RCP26_LUC_fractions_2021_2022.tif")
)

if (!file.exists(plum_raster_path)) {
  stop("❌ ERROR: PLUM raster not found at: ", plum_raster_path)
}
angola_plum_raster <- rast(plum_raster_path)
plum_layer_names <- names(angola_plum_raster)

# Initialize matching matrix
match_LC_classes <- matrix(
  0,
  nrow = length(plum_layer_names),
  ncol = length(modis_classes),
  dimnames = list(plum_layer_names, modis_classes)
)

# 🛠️ **Populate Matching Matrix**
allocations <- list(
  Cropland       = c("LC12" = 0.5, "LC14" = 0.5),
  Pasture        = c("LC6"  = 0.1, "LC7"  = 0.2, "LC8"  = 0.1, "LC9"  = 0.2,  
                     "LC10" = 0.2, "LC11" = 0.1, "LC16" = 0.1),
  TimberForest   = c("LC1"  = 0.1, "LC2"  = 0.2, "LC4"  = 0.2, "LC5"  = 0.1,  
                     "LC6"  = 0.1, "LC7"  = 0.1, "LC8"  = 0.1, "LC9"  = 0.1),
  UnmanagedForest= c("LC1"  = 0.1, "LC2"  = 0.2, "LC4"  = 0.3, "LC5"  = 0.2,  
                     "LC6"  = 0.2),
  OtherNatural   = c("LC12" = 0.5, "LC14" = 0.2, "LC17" = 0.3),
  Barren         = c("LC6"  = 0.2, "LC7"  = 0.2, "LC8"  = 0.2, "LC9"  = 0.4),  
  Urban          = c("LC13" = 1)
)

# Apply allocations
for (category in names(allocations)) {
  match_LC_classes[category, names(allocations[[category]])] <- allocations[[category]]
}
cat("✅ Updated Matching Matrix:\n")
print(match_LC_classes)

# -----------------------------------------------------------------------------
# 📂 **Setup for Downscaling**
plum_raster_dir <- dirname(plum_raster_path)  # Use existing PLUM directory
downscale_output_dir <- file.path(base_dir, "LU_downscalled_dataset", "LU_PLUM_Modis_500m",
                                  "downscale_SSP1_RCP26", "Downscale_by_country", country_name, "Angola_script_7")

if (!dir.exists(downscale_output_dir)) {
  dir.create(downscale_output_dir, recursive = TRUE)
}

# 📜 **List PLUM transition maps**
country_LUC_map_files <- list.files(
  path = plum_raster_dir,
  pattern = paste0("^", country_name, "_SSP1_RCP26_LUC_fractions_\\d{4}_\\d{4}\\.tif$"),
  full.names = TRUE
)
country_LUC_map_files <- sort(country_LUC_map_files)

if (length(country_LUC_map_files) == 0) {
  stop("❌ ERROR: No PLUM transition maps found in: ", plum_raster_dir)
}

# -----------------------------------------------------------------------------
# 🏗️ **Downscaling Process with Reference Map Updates**
downscaleLC_with_progress <- function(ref_map_file_name, LC_deltas_file_list, ...) {
  start_time <- Sys.time()
  cat(sprintf("🚀 Starting downscaling at: %s\n", start_time))
  
  log_file <- file.path(base_dir, "downscaling_log.txt")
  cat(sprintf("Processing started at: %s\n", start_time), file = log_file, append = TRUE)
  
  current_ref_map <- ref_map_file_name
  
  for (i in seq_along(LC_deltas_file_list)) {
    file <- LC_deltas_file_list[i]
    years <- gsub(".*_(\\d{4}_\\d{4})\\.tif$", "\\1", file)
    
    cat(sprintf("📌 [%d/%d] Processing: %s at %s\n", i, length(LC_deltas_file_list), file, Sys.time()))
    
    if (!file.exists(file)) {
      warning(sprintf("⚠️ WARNING: Missing transition map, skipping: %s\n", file))
      next
    }
    
    ram_before <- sum(gc()[, 2])
    
    # ✅ **Ensure match_LC_classes only contains valid classes**
    valid_classes <- colnames(match_LC_classes) %in% levels(ref_map)[[1]]$name
    match_LC_classes <- match_LC_classes[, valid_classes, drop = FALSE]
    
    # 📌 **Define expected output filename**
    discrete_output_file <- file.path(
      downscale_output_dir, 
      paste0(country_name, "_MODIS_PLUM_500m_s1_", years, "_Discrete_Time", i, ".tif")
    )
    
    # 🔥 **Run Downscaling**
    downscaleLC(
      ref_map_file_name   = current_ref_map,
      LC_deltas_file_list = list(file),
      output_file_prefix  = paste0(country_name, "_MODIS_PLUM_500m_s1_", years),
      ...
    )
    
    # ✅ **Update Reference Map**
    if (file.exists(discrete_output_file)) {
      cat(sprintf("✅ Updating reference map for next iteration: %s\n", discrete_output_file))
      current_ref_map <- discrete_output_file
    } else {
      warning(sprintf("⚠️ WARNING: Expected reference map not found: %s. Using last available map.", discrete_output_file))
    }
  }
  
  cat(sprintf("🏁 Downscaling completed at: %s\n", Sys.time()))
}

# -----------------------------------------------------------------------------
# 🚀 **Run the Downscaling Function**
downscaleLC_with_progress(
  ref_map_file_name = country_ref_map_file,
  LC_deltas_file_list = country_LUC_map_files,
  LC_deltas_type = "proportions",
  ref_map_type = "discrete",
  cell_size_unit = "m",
  assign_ref_cells = FALSE,
  match_LC_classes = match_LC_classes,
  kernel_radius = 1,
  simulation_type = "deterministic",
  discrete_output_map = TRUE,
  random_seed = 44,
  output_dir_path = downscale_output_dir
)
