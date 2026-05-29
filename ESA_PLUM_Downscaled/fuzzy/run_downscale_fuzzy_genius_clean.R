#!/usr/bin/env Rscript

user_lib_path <- "/bg/home/shiweda-m/R/library"
system_lib_paths <- .libPaths()
if (dir.exists(user_lib_path)) {
  .libPaths(c(user_lib_path, system_lib_paths))
  cat("Using personal R library path:", user_lib_path, "\n")
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("ERROR: Provide scenario_name and region_id\n")
  cat("Usage: Rscript run_downscale_fuzzy_genius_clean.R <scenario_name> <region_id>\n")
  quit(status = 1)
}

scenario_name <- args[1]
region_id <- as.integer(args[2])
allowed_scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
if (!(scenario_name %in% allowed_scenarios)) {
  cat("ERROR: Only SSP1_RCP26, SSP2_RCP45, SSP3_RCP70, SSP4_RCP60, and SSP5_RCP85 are supported.\n")
  quit(status = 1)
}
if (is.na(region_id) || region_id < 1 || region_id > 8) {
  cat("ERROR: region_id must be in 1..8\n")
  quit(status = 1)
}

required_packages <- c("terra", "LandScaleR", "future")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(paste("Missing package:", pkg))
  }
  library(pkg, character.only = TRUE)
  cat(pkg, "version", as.character(packageVersion(pkg)), "\n")
}

future::plan(future::multisession, workers = 8)

base_dir <- "/bg/data/kaza_elephant/Downscale_SAfrica"
module_root <- file.path(base_dir, "ESA_PLUM_Downscaled", "fuzzy")
log_dir <- file.path(module_root, "logs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(log_dir, paste0(scenario_name, "_region", region_id, "_fuzzy_esa_1km_", timestamp, ".log"))
log_line <- function(msg) {
  ts <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  cat(ts, msg, "\n", file = log_file, append = TRUE)
  cat(ts, msg, "\n")
}

ensure_reference_cover <- function(ref_raster, label, write_path = NULL, fill_value = 80L) {
  na_count <- tryCatch({
    val <- terra::global(is.na(ref_raster), "sum", na.rm = TRUE)[[1]]
    if (is.na(val)) 0 else val
  }, error = function(e) {
    log_line(paste("WARNING: Failed counting NA cells for", label, "-", conditionMessage(e)))
    0
  })

  if (na_count == 0) {
    return(list(raster = ref_raster, path = write_path, filled = FALSE, na_count = 0))
  }

  log_line(paste("Replacing", na_count, "NA cells in", label, "with water class", fill_value))
  fill_raster <- terra::rast(ref_raster)
  fill_raster[] <- fill_value
  filled <- terra::cover(ref_raster, fill_raster)

  if (!is.null(write_path)) {
    terra::writeRaster(filled, write_path, overwrite = TRUE)
    log_line(paste("Wrote filled reference to", write_path))
  }

  list(raster = filled, path = write_path, filled = TRUE, na_count = na_count)
}

build_regions <- function(reference_raster) {
  full_extent <- terra::ext(reference_raster)
  x_range <- full_extent[2] - full_extent[1]
  y_range <- full_extent[4] - full_extent[3]
  regions <- vector("list", 8)
  for (y in 1:2) {
    for (x in 1:4) {
      idx <- (y - 1) * 4 + x
      xmin <- full_extent[1] + (x - 1) * x_range / 4
      xmax <- full_extent[1] + x * x_range / 4
      ymin <- full_extent[3] + (y - 1) * y_range / 2
      ymax <- full_extent[3] + y * y_range / 2
      regions[[idx]] <- c(xmin, xmax, ymin, ymax)
    }
  }
  regions
}

build_synergy <- function(plum_layer_names, esa_classes) {
  allocations <- list(
    Cropland        = c("LC40" = 0.9, "LC30" = 0.1),
    Pasture         = c("LC30" = 0.7, "LC20" = 0.2, "LC60" = 0.1),
    TimberForest    = c("LC10" = 0.7, "LC20" = 0.3, "LC95" = 0.1),
    UnmanagedForest = c("LC10" = 0.8, "LC20" = 0.2),
    OtherNatural    = c("LC20" = 0.6, "LC30" = 0.2, "LC90" = 0.1, "LC60" = 0.1),
    Barren          = c("LC60" = 0.8, "LC100" = 0.05, "LC70" = 0.05, "LC30" = 0.01),
    Urban           = c("LC50" = 1.0)
  )

  valid_allocations <- allocations[names(allocations) %in% plum_layer_names]
  synergy <- matrix(
    0,
    nrow = length(plum_layer_names),
    ncol = length(esa_classes),
    dimnames = list(plum_layer_names, esa_classes)
  )

  for (category in names(valid_allocations)) {
    valid_classes <- intersect(names(valid_allocations[[category]]), esa_classes)
    if (length(valid_classes) > 0) {
      synergy[category, valid_classes] <- valid_allocations[[category]][valid_classes]
    } else {
      synergy[category, ] <- 1 / length(esa_classes)
    }
  }

  row_sums <- rowSums(synergy)
  for (i in seq_len(nrow(synergy))) {
    if (row_sums[i] == 0) {
      synergy[i, ] <- 1 / ncol(synergy)
    } else {
      synergy[i, ] <- synergy[i, ] / row_sums[i]
    }
  }

  synergy
}

log_line(paste("ESA fuzzy 1 km run for", scenario_name, "region", region_id))
log_line("Simulation type: fuzzy")
log_line("Workers: 8")

custom_temp <- file.path(module_root, "temp_r_files", paste0(scenario_name, "_region", region_id))
dir.create(custom_temp, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(TMPDIR = custom_temp)
terra::terraOptions(memfrac = 0.8, tempdir = custom_temp)
log_line(paste("Terra memfrac=0.8 tempdir=", custom_temp))

output_dir <- file.path(module_root, "output", scenario_name, paste0("region", region_id))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
log_line(paste("Output dir:", output_dir))

esa_waterfilled_path <- file.path(base_dir, "ESA_WorldCover", "processed", "processed_1km", "ESA_WorldCover_2021_aligned_1km_waterfilled.tif")
esa_fixed_path <- file.path(base_dir, "ESA_WorldCover", "processed", "processed_1km", "ESA_WorldCover_2021_aligned_1km_fixed.tif")
esa_default_path <- file.path(base_dir, "ESA_WorldCover", "processed", "processed_1km", "ESA_WorldCover_2021_aligned_1km.tif")

if (file.exists(esa_waterfilled_path)) {
  esa_ref_path <- esa_waterfilled_path
} else if (file.exists(esa_fixed_path)) {
  esa_ref_path <- esa_fixed_path
} else {
  esa_ref_path <- esa_default_path
}

if (!file.exists(esa_ref_path)) {
  log_line(paste("ERROR: ESA reference not found:", esa_ref_path))
  quit(status = 1)
}

full_ref <- terra::rast(esa_ref_path)
log_line(paste("ESA reference loaded:", esa_ref_path))

region_extent <- terra::ext(build_regions(full_ref)[[region_id]])
log_line(paste("Region extent:", paste(region_extent, collapse = ", ")))

initial_region_ref <- terra::crop(full_ref, region_extent)
cover_result <- ensure_reference_cover(initial_region_ref, paste0("initial region ref ", region_id))
initial_region_ref <- cover_result$raster

initial_ref_path <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_initial_ref_map_water.tif"))
terra::writeRaster(initial_region_ref, initial_ref_path, overwrite = TRUE)
log_line(paste("Saved initial ref:", initial_ref_path))

existing_outputs <- sort(list.files(
  output_dir,
  pattern = paste0(scenario_name, "_region", region_id, "_.*_Discrete_Time1\\.tif$"),
  full.names = TRUE
))
start_year_index <- 1
current_ref_path <- initial_ref_path

plum_dir <- file.path(base_dir, "PLUM_Africa_Data", "processed_data", scenario_name)
plum_files <- sort(list.files(plum_dir, pattern = paste0(scenario_name, "_.*_africa\\.tif$"), full.names = TRUE))
if (length(plum_files) == 0) {
  log_line(paste("ERROR: No PLUM files found in", plum_dir))
  quit(status = 1)
}

plum_files <- plum_files[vapply(plum_files, function(path) {
  ym <- regexpr("_([0-9]{4}_[0-9]{4})_", path, perl = TRUE)
  if (ym < 0) {
    return(FALSE)
  }
  substr(path, ym + 1, ym + 9) >= "2021_2022"
}, logical(1))]
log_line(paste("Found", length(plum_files), "PLUM files from 2021_2022 onward"))

if (length(existing_outputs) > 0) {
  current_ref_path <- existing_outputs[length(existing_outputs)]
  log_line(paste("Resuming from:", basename(current_ref_path)))
  for (i in seq_along(plum_files)) {
    ym <- regexpr("_([0-9]{4}_[0-9]{4})_", plum_files[i], perl = TRUE)
    if (ym > 0) {
      year_str <- substr(plum_files[i], ym + 1, ym + 9)
      expected_output <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_", year_str, "_Discrete_Time1.tif"))
      if (file.exists(expected_output)) {
        start_year_index <- i + 1
      }
    }
  }
  if (start_year_index > length(plum_files)) {
    log_line("All years already processed. Nothing to do.")
    quit(status = 0)
  }
}

run_fuzzy_downscale <- function(ref_path, region_plum_path, match_lc_classes, output_prefix, assign_ref_cells) {
  LandScaleR::downscaleLC(
    ref_map_file_name   = ref_path,
    LC_deltas_file_list = list(region_plum_path),
    LC_deltas_type      = "proportions",
    ref_map_type        = "discrete",
    cell_size_unit      = "m",
    match_LC_classes    = match_lc_classes,
    kernel_radius       = 1,
    simulation_type     = "fuzzy",
    discrete_output_map = TRUE,
    fuzzy_multiplier    = 1,
    random_seed         = 42,
    output_dir_path     = output_dir,
    output_file_prefix  = output_prefix,
    assign_ref_cells    = assign_ref_cells
  )
}

assign_ref_true_attempts <- 0L
assign_ref_true_success <- 0L

for (year_index in start_year_index:length(plum_files)) {
  plum_file <- plum_files[year_index]
  ym <- regexpr("_([0-9]{4}_[0-9]{4})_", plum_file, perl = TRUE)
  year_str <- if (ym > 0) substr(plum_file, ym + 1, ym + 9) else paste0("year", year_index)

  log_line("=======================================")
  log_line(paste("Processing year:", year_str, "(", basename(plum_file), ")"))
  log_line("=======================================")

  region_plum <- terra::crop(terra::rast(plum_file), region_extent)
  region_plum_path <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_plum_", year_str, ".tif"))
  terra::writeRaster(region_plum, region_plum_path, overwrite = TRUE)
  log_line(paste("Saved regional PLUM:", region_plum_path))

  year_ref <- terra::rast(current_ref_path)
  filled_ref_path <- file.path(custom_temp, paste0(scenario_name, "_region", region_id, "_", year_str, "_ref_filled.tif"))
  year_cover_result <- ensure_reference_cover(year_ref, paste0("reference for ", year_str), write_path = filled_ref_path)
  year_ref <- year_cover_result$raster
  ref_path_for_run <- if (!is.null(year_cover_result$path) && year_cover_result$filled) year_cover_result$path else current_ref_path

  ref_freq <- terra::freq(year_ref, value = TRUE)
  ref_values <- if (is.null(ref_freq) || nrow(ref_freq) == 0) numeric(0) else ref_freq[[1]]
  ref_values <- sort(unique(ref_values[!is.na(ref_values) & ref_values != 0]))
  esa_classes <- paste0("LC", ref_values)
  log_line(paste("ESA classes in region:", paste(esa_classes, collapse = ", ")))

  match_lc_classes <- build_synergy(names(region_plum), esa_classes)
  synergy_path <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_", year_str, "_synergy.rds"))
  saveRDS(match_lc_classes, synergy_path)
  log_line(paste("Saved synergy table:", synergy_path))

  output_prefix <- paste0(scenario_name, "_region", region_id, "_", year_str)
  assign_ref_true_attempts <- assign_ref_true_attempts + 1L
  true_error <- NULL

  tryCatch({
    run_fuzzy_downscale(ref_path_for_run, region_plum_path, match_lc_classes, output_prefix, TRUE)
    assign_ref_true_success <- assign_ref_true_success + 1L
    log_line("Fuzzy downscaling succeeded with assign_ref_cells=TRUE")
  }, error = function(e) {
    true_error <<- e
    log_line(paste("assign_ref_cells=TRUE failed:", conditionMessage(e)))
  })

  if (!is.null(true_error)) {
    run_fuzzy_downscale(ref_path_for_run, region_plum_path, match_lc_classes, output_prefix, FALSE)
    log_line("Fuzzy downscaling succeeded with assign_ref_cells=FALSE fallback")
  }

  discrete_files <- sort(list.files(
    output_dir,
    pattern = paste0(output_prefix, ".*_Discrete_Time1\\.tif$"),
    full.names = TRUE
  ))
  if (length(discrete_files) == 0) {
    log_line(paste("ERROR: No discrete output generated for", year_str))
    quit(status = 1)
  }

  current_ref_path <- discrete_files[length(discrete_files)]
  log_line(paste("Updated reference for next year to:", basename(current_ref_path)))
}

log_line(paste("assign_ref_cells=TRUE succeeded", assign_ref_true_success, "times out of", assign_ref_true_attempts))
log_line("All years fuzzy processing completed.")