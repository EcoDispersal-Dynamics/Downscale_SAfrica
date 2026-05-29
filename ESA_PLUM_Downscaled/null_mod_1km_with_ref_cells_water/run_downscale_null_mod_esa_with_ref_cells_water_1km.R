#!/usr/bin/env Rscript

# ================================================================
# ESA_PLUM_Downscaled: Null model downscaling at 1km (assign_ref_cells = TRUE, water-filled reference)
# - Uses ESA WorldCover 2021 1km water-filled raster so every coarse cell has coverage
# - Uses PLUM deltas as inputs
# - Iteratively updates reference each year
# - Restricted to scenarios: SSP2_RCP45, SSP3_RCP70, SSP4_RCP60
# - Regions: 4 x 2 grid (8 regions total)
# ================================================================

user_lib_path <- "/bg/home/shiweda-m/R/library"
system_lib_paths <- .libPaths()
if (dir.exists(user_lib_path)) {
  .libPaths(c(user_lib_path, system_lib_paths))
  cat("Using personal R library path:", user_lib_path, "\n")
} else {
  warning("Personal R library path not found. Using system libraries.")
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("ERROR: Please provide a scenario name and region ID\n")
  cat("Usage: Rscript run_downscale_null_mod_esa_with_ref_cells_water_1km.R <scenario_name> <region_id>\n")
  quit(status = 1)
}

scenario_name <- args[1]
region_id <- as.integer(args[2])

allowed_scenarios <- c("SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60")
if (!(scenario_name %in% allowed_scenarios)) {
  cat("ERROR: Only SSP2_RCP45, SSP3_RCP70, and SSP4_RCP60 are supported in this 1km ESA run.\n")
  quit(status = 1)
}

if (is.na(region_id) || region_id < 1 || region_id > 8) {
  cat("ERROR: region_id must be an integer between 1 and 8\n")
  quit(status = 1)
}

required_packages <- c("terra", "LandScaleR", "future")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(paste("Package", pkg, "is required but not installed."))
  }
  library(pkg, character.only = TRUE)
  cat("Loaded package:", pkg, "version:", as.character(packageVersion(pkg)), "\n")
}

cat("Using LandScaleR version:", as.character(packageVersion("LandScaleR")), "\n")

future::plan(future::multisession, workers = 12)
cat(paste("Using", future::nbrOfWorkers(), "workers\n"))

base_dir <- "/bg/data/kaza_elephant/Downscale_SAfrica"
esa_root <- file.path(base_dir, "ESA_PLUM_Downscaled")
module_root <- file.path(esa_root, "null_mod_1km_with_ref_cells_water")
log_dir <- file.path(module_root, "logs")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(log_dir, paste0(scenario_name, "_region", region_id, "_null_mod_1km_with_ref_cells_water_ESA_", timestamp, ".log"))
cat(paste0("=== ESA Null Model 1km (assign_ref_cells=TRUE) (", scenario_name, ", Region ", region_id, ") ===\n"), file = log_file)
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", file = log_file, append = TRUE)

log_msg <- function(msg) {
  ts <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  line <- paste(ts, msg)
  cat(line, "\n", file = log_file, append = TRUE)
  cat(line, "\n")
}

ensure_reference_cover <- function(ref_raster, label, write_path = NULL, fill_value = 80L) {
  na_count <- tryCatch({
    val <- terra::global(is.na(ref_raster), "sum", na.rm = TRUE)[[1]]
    if (is.na(val)) 0 else val
  }, error = function(e) {
    log_msg(paste("WARNING: Failed counting NA cells for", label, "-", conditionMessage(e)))
    return(0)
  })

  if (na_count == 0) {
    return(list(raster = ref_raster, path = write_path, filled = FALSE, na_count = 0))
  }

  log_msg(paste("Replacing", na_count, "NA cells in", label, "with water class", fill_value))
  filled_template <- terra::rast(ref_raster)
  filled_template[] <- fill_value
  filled <- tryCatch({
    terra::cover(ref_raster, filled_template)
  }, error = function(e) {
    log_msg(paste("ERROR: cover failed for", label, "-", conditionMessage(e)))
    return(ref_raster)
  })

  if (is.null(write_path)) {
    return(list(raster = filled, path = write_path, filled = TRUE, na_count = na_count))
  }

  tryCatch({
    terra::writeRaster(filled, write_path, overwrite = TRUE)
    log_msg(paste("Wrote filled reference to", write_path))
  }, error = function(e) {
    log_msg(paste("ERROR writing filled reference", write_path, "-", conditionMessage(e)))
  })

  list(raster = filled, path = write_path, filled = TRUE, na_count = na_count)
}

log_msg(paste("Scenario:", scenario_name))
log_msg(paste("Region:", region_id))
log_msg("Simulation: null_model_1km_with_ref_cells_water (ESA reference)")

custom_temp <- file.path(module_root, "temp_r_files", paste0(scenario_name, "_region", region_id))
dir.create(custom_temp, showWarnings = FALSE, recursive = TRUE)
Sys.setenv(TMPDIR = custom_temp)
terra::terraOptions(memfrac = 0.75, tempdir = custom_temp)
log_msg(paste("Terra memfrac=0.75 tempdir=", custom_temp))

output_dir <- file.path(module_root, "output", scenario_name, paste0("region", region_id))
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
log_msg(paste("Output dir:", output_dir))

esa_waterfilled_path <- file.path(base_dir, "ESA_WorldCover/processed/processed_1km/ESA_WorldCover_2021_aligned_1km_waterfilled.tif")
esa_fixed_path <- file.path(base_dir, "ESA_WorldCover/processed/processed_1km/ESA_WorldCover_2021_aligned_1km_fixed.tif")

if (file.exists(esa_waterfilled_path)) {
  esa_ref_path <- esa_waterfilled_path
  log_msg(paste("ESA 1km water-filled reference detected:", esa_ref_path))
} else if (file.exists(esa_fixed_path)) {
  esa_ref_path <- esa_fixed_path
  log_msg("WARNING: Running without water-filled ESA reference; expect assign_ref_cells fallbacks.")
} else {
  log_msg("ERROR: ESA 1km reference not found.")
  quit(status = 1)
}

full_ref <- terra::rast(esa_ref_path)
log_msg(paste("ESA reference loaded:", esa_ref_path))

vals <- unique(terra::values(full_ref))
vals <- vals[!is.na(vals) & vals != 0]
vals <- sort(vals)
if (length(vals) > 0) {
  cats_df <- data.frame(ID = vals, name = paste0("LC", vals))
  try({ terra::cats(full_ref, 1) <- cats_df }, silent = TRUE)
}

full_ext <- terra::ext(full_ref)
x_range <- full_ext[2] - full_ext[1]
y_range <- full_ext[4] - full_ext[3]
x_div <- 4
y_div <- 2
regions <- list()
for (y in 1:y_div) for (x in 1:x_div) {
  idx <- (y - 1) * x_div + x
  xmin <- full_ext[1] + (x - 1) * x_range / x_div
  xmax <- full_ext[1] + x * x_range / x_div
  ymin <- full_ext[3] + (y - 1) * y_range / y_div
  ymax <- full_ext[3] + y * y_range / y_div
  regions[[idx]] <- c(xmin, xmax, ymin, ymax)
}

region_extent <- terra::ext(regions[[region_id]])
log_msg(paste("Region extent:", paste(region_extent, collapse = ", ")))

log_msg("Cropping ESA reference to region")
region_ref <- terra::crop(full_ref, region_extent)
region_ref_cover <- ensure_reference_cover(region_ref, paste0("initial region ref (region ", region_id, ")"))
region_ref <- region_ref_cover$raster

initial_ref_path <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_initial_ref_map_1km.tif"))
terra::writeRaster(region_ref, initial_ref_path, overwrite = TRUE)
log_msg(paste("Saved initial ref:", initial_ref_path))

existing_outputs <- list.files(
  output_dir,
  pattern = paste0(scenario_name, "_region", region_id, "_.*_1km_Discrete_Time1\\.tif$"),
  full.names = TRUE
)
start_year_index <- 1
current_ref_path <- initial_ref_path
if (length(existing_outputs) > 0) {
  existing_outputs <- sort(existing_outputs)
  latest_output <- existing_outputs[length(existing_outputs)]
  log_msg(paste("Found previous output:", basename(latest_output)))
  year_pattern <- "_([0-9]{4}_[0-9]{4})_"
  ym <- regexpr(year_pattern, latest_output, perl = TRUE)
  current_ref_path <- if (ym > 0) latest_output else initial_ref_path
}

plum_input_dir <- file.path(base_dir, "PLUM_Africa_Data/processed_data", scenario_name)
plum_pattern <- paste0(scenario_name, "_.*_africa\\.tif$")
plum_files <- sort(list.files(plum_input_dir, pattern = plum_pattern, full.names = TRUE))
if (length(plum_files) == 0) {
  log_msg(paste("ERROR: No PLUM files in", plum_input_dir))
  quit(status = 1)
}
log_msg(paste("Found", length(plum_files), "PLUM files"))

if (length(existing_outputs) > 0) {
  get_year_str <- function(path) {
    ym <- regexpr("_([0-9]{4}_[0-9]{4})_", path, perl = TRUE)
    if (ym > 0) substr(path, ym + 1, ym + 9) else NA_character_
  }
  plum_years <- vapply(plum_files, get_year_str, character(1))
  latest_output <- sort(existing_outputs)[length(existing_outputs)]
  last_year <- get_year_str(latest_output)

  if (!is.na(last_year)) {
    idx <- which(plum_years == last_year)
    if (length(idx) == 1) {
      start_year_index <- idx + 1
      log_msg(paste("Resuming after", last_year, "=> start index:", start_year_index))
    }
  }

  if (start_year_index == 1) {
    for (i in 1:length(plum_files)) {
      ystr <- plum_years[i]
      if (is.na(ystr)) next
      out_file <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_", ystr, "_1km_Discrete_Time1.tif"))
      if (file.exists(out_file)) start_year_index <- i + 1
    }
  }

  if (start_year_index > length(plum_files)) {
    log_msg("All years already processed. Nothing to do.")
    quit(status = 0)
  }
}

build_synergy <- function(plum_layer_names, modis_classes) {
  allocations <- list(
    Cropland        = c("LC40" = 0.9, "LC30" = 0.1),
    Pasture         = c("LC30" = 0.7, "LC20" = 0.2, "LC60" = 0.1),
    TimberForest    = c("LC10" = 0.7, "LC20" = 0.3, "LC95" = 0.1),
    UnmanagedForest = c("LC10" = 0.8, "LC20" = 0.2),
    OtherNatural    = c("LC20" = 0.6, "LC30" = 0.2, "LC90" = 0.1, "LC60" = 0.1),
    Barren          = c("LC60" = 0.8, "LC100" = 0.05, "LC70" = 0.05, "LC30" = 0.01),
    Urban           = c("LC50" = 1.0)
  )
  allocations <- allocations[names(allocations) %in% plum_layer_names]
  M <- matrix(0, nrow = length(plum_layer_names), ncol = length(modis_classes),
              dimnames = list(plum_layer_names, modis_classes))
  for (cat in names(allocations)) {
    valid_modis <- intersect(names(allocations[[cat]]), modis_classes)
    if (length(valid_modis) > 0) {
      M[cat, valid_modis] <- allocations[[cat]][valid_modis]
    } else {
      w <- rep(1 / length(modis_classes), length(modis_classes))
      names(w) <- modis_classes
      M[cat, ] <- w
    }
  }
  rs <- rowSums(M)
  for (i in which(rs == 0)) {
    M[i, ] <- 1 / ncol(M)
  }
  for (i in 1:nrow(M)) {
    s <- sum(M[i, ], na.rm = TRUE)
    if (s > 0) M[i, ] <- M[i, ] / s
  }
  M
}

match_LC_classes <- NULL
assign_ref_true_attempts <- 0L
assign_ref_true_success <- 0L

for (year_index in start_year_index:length(plum_files)) {
  plum_file <- plum_files[year_index]
  ym <- regexpr("_([0-9]{4}_[0-9]{4})_", plum_file, perl = TRUE)
  year_str <- if (ym > 0) substr(plum_file, ym + 1, ym + 9) else paste0("year", year_index)
  log_msg("=======================================")
  log_msg(paste("Processing year:", year_str, "(", basename(plum_file), ")"))
  log_msg("=======================================")

  full_plum <- terra::rast(plum_file)
  region_plum <- terra::crop(full_plum, region_extent)
  region_plum_path <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_plum_", year_str, "_1km.tif"))
  terra::writeRaster(region_plum, region_plum_path, overwrite = TRUE)
  log_msg(paste("Saved regional PLUM:", region_plum_path))

  region_ref <- terra::rast(current_ref_path)
  filled_ref_path <- file.path(custom_temp, paste0(scenario_name, "_region", region_id, "_", year_str, "_ref_filled_1km.tif"))
  cover_result <- ensure_reference_cover(region_ref, paste0("ref for year ", year_str), write_path = filled_ref_path)
  region_ref <- cover_result$raster
  ref_path_for_run <- if (!is.null(cover_result$path) && cover_result$filled) cover_result$path else current_ref_path

  modis_values <- tryCatch({
    cf <- terra::cats(region_ref, 1)
    if (!is.null(cf) && nrow(cf) > 0) {
      as.integer(cf$ID)
    } else {
      v <- unique(terra::values(region_ref))
      v <- v[!is.na(v)]
      as.integer(v)
    }
  }, error = function(e) {
    v <- unique(terra::values(region_ref))
    v <- v[!is.na(v)]
    as.integer(v)
  })
  if (length(modis_values) == 0) {
    log_msg("WARNING: Region reference has only NA; writing empty output and continuing")
    empty_out <- region_ref
    out_path <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_", year_str, "_1km_Discrete_Time1.tif"))
    terra::writeRaster(empty_out, out_path, overwrite = TRUE)
    current_ref_path <- out_path
    next
  }
  modis_classes <- paste0("LC", modis_values)
  log_msg(paste("Region ESA classes:", paste(sort(modis_classes), collapse = ", ")))

  if (is.null(match_LC_classes)) {
    plum_layer_names <- names(region_plum)
    match_LC_classes <- build_synergy(plum_layer_names, modis_classes)
    synergy_file <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_synergy_water_1km.rds"))
    saveRDS(match_LC_classes, synergy_file)
    log_msg(paste("Saved synergy:", synergy_file))
  }

  output_prefix <- paste0(scenario_name, "_region", region_id, "_", year_str, "_1km")
  run_downscale <- function(assign_flag) {
    LandScaleR::downscaleLC(
      ref_map_file_name   = ref_path_for_run,
      LC_deltas_file_list = list(region_plum_path),
      LC_deltas_type      = "proportions",
      ref_map_type        = "discrete",
      cell_size_unit      = "m",
      match_LC_classes    = match_LC_classes,
      kernel_radius       = 2,
      simulation_type     = "null_model",
      discrete_output_map = TRUE,
      random_seed         = 42,
      output_dir_path     = output_dir,
      output_file_prefix  = output_prefix,
      assign_ref_cells    = assign_flag
    )

    discrete_pattern <- paste0(output_prefix, ".*Discrete_Time1\\.tif$")
    discrete_files <- list.files(output_dir, pattern = discrete_pattern, full.names = TRUE)
    if (length(discrete_files) > 0) {
      discrete_files <- sort(discrete_files)
      new_ref <- discrete_files[length(discrete_files)]
      log_msg(paste(
        "Updated next-year ref to:",
        basename(new_ref),
        paste0("(assign_ref_cells=", assign_flag, ")")
      ))
      return(list(success = TRUE, ref_path = new_ref, assign_flag = assign_flag))
    }

    log_msg("WARNING: No discrete output found after downscaling")
    list(success = TRUE, ref_path = current_ref_path, assign_flag = assign_flag)
  }

  log_msg("Running LandScaleR::downscaleLC (null_model, assign_ref_cells=TRUE)...")
  assign_ref_true_attempts <- assign_ref_true_attempts + 1L
  attempt <- tryCatch(run_downscale(TRUE), error = function(e) {
    list(success = FALSE, error = e)
  })

  if (!attempt$success) {
    msg <- conditionMessage(attempt$error)
    log_msg(paste("ERROR during downscaling with assign_ref_cells=TRUE:", msg))

    fallback <- tryCatch({
      log_msg("Falling back to assign_ref_cells=FALSE for this year")
      log_msg("Running LandScaleR::downscaleLC (null_model, assign_ref_cells=FALSE)...")
      run_downscale(FALSE)
    }, error = function(e) {
      list(success = FALSE, error = e)
    })

    if (!fallback$success) {
      log_msg(paste("ERROR during fallback downscaling:", conditionMessage(fallback$error)))
      log_msg("Skipping remaining processing for this year due to repeated errors")
      next
    }

    current_ref_path <- fallback$ref_path
  } else {
    assign_ref_true_success <- assign_ref_true_success + 1L
    current_ref_path <- attempt$ref_path
  }

  log_msg(paste("Completed year:", year_str))
}

if (assign_ref_true_attempts > 0) {
  log_msg(paste(
    "assign_ref_cells=TRUE succeeded",
    assign_ref_true_success,
    "of",
    assign_ref_true_attempts,
    "attempts (fallbacks:",
    assign_ref_true_attempts - assign_ref_true_success, ")"
  ))
} else {
  log_msg("assign_ref_cells=TRUE did not run for this region (no eligible years)")
}

log_msg(paste("All years processed.", "Log:", log_file))