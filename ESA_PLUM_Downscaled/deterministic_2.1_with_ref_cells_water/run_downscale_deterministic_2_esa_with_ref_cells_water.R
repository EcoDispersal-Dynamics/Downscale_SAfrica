#!/usr/bin/env Rscript

# ================================================================
# ESA_PLUM_Downscaled: deterministic_2.1 standalone runner
# - Uses ESA WorldCover 2021 water-filled raster for complete coverage
# - Iteratively updates the reference each year
# - Supports all five SSP scenarios
# - Regions: 4 x 2 grid (8 regions total)
# - Fixed variant: kernel_radius = 2, synergy_table_id = 1
# ================================================================

user_lib_path <- "/bg/home/shiweda-m/R/library"
system_lib_paths <- .libPaths()
if (dir.exists(user_lib_path)) {
  .libPaths(c(user_lib_path, system_lib_paths))
  cat("Using personal R library path:", user_lib_path, "\n")
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("ERROR: Provide scenario_name and region_id\n")
  cat("Usage: Rscript run_downscale_deterministic_2_esa_with_ref_cells_water.R <scenario_name> <region_id>\n")
  quit(status = 1)
}

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
if (!length(script_arg)) {
  stop("Unable to locate runner script path.")
}

script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/", mustWork = TRUE))

scenario_name <- args[1]
region_id <- suppressWarnings(as.integer(args[2]))
kernel_radius <- 2L
synergy_table_id <- 1L
variant_label <- sprintf("deterministic_%d.%d", kernel_radius, synergy_table_id)
allowed_scenarios <- c("SSP1_RCP26", "SSP2_RCP45", "SSP3_RCP70", "SSP4_RCP60", "SSP5_RCP85")
allowed_years <- sprintf("%d_%d", 2021:2031, 2022:2032)
if (!(scenario_name %in% allowed_scenarios)) {
  cat("ERROR: Scenario must be one of", paste(allowed_scenarios, collapse = ", "), "\n")
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
module_root <- script_dir
log_dir <- file.path(module_root, "logs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(log_dir, paste0(scenario_name, "_region", region_id, "_", variant_label, "_with_ref_cells_water_ESA_", timestamp, ".log"))
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
    return(0)
  })

  if (na_count == 0) {
    return(list(raster = ref_raster, path = write_path, filled = FALSE, na_count = 0))
  }

  log_line(paste("Replacing", na_count, "NA cells in", label, "with water class", fill_value))
  filled_template <- terra::rast(ref_raster)
  filled_template[] <- fill_value
  filled <- tryCatch({
    terra::cover(ref_raster, filled_template)
  }, error = function(e) {
    log_line(paste("ERROR: cover failed for", label, "-", conditionMessage(e)))
    return(ref_raster)
  })

  if (is.null(write_path)) {
    return(list(raster = filled, path = write_path, filled = TRUE, na_count = na_count))
  }

  tryCatch({
    terra::writeRaster(filled, write_path, overwrite = TRUE)
    log_line(paste("Wrote filled reference to", write_path))
  }, error = function(e) {
    log_line(paste("ERROR writing filled reference", write_path, "-", conditionMessage(e)))
  })

  list(raster = filled, path = write_path, filled = TRUE, na_count = na_count)
}

extract_year_str <- function(file_path) {
  ym <- regexpr("_([0-9]{4}_[0-9]{4})_", file_path, perl = TRUE)
  if (ym > 0) {
    substr(file_path, ym + 1, ym + 9)
  } else {
    NA_character_
  }
}

log_line(paste(
  "Standalone ESA deterministic run for",
  scenario_name,
  "region",
  region_id,
  "variant",
  variant_label,
  "(kernel_radius=",
  kernel_radius,
  ", synergy_table_id=",
  synergy_table_id,
  ")"
))

custom_temp <- file.path(module_root, "temp_r_files", paste0(scenario_name, "_region", region_id))
dir.create(custom_temp, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(TMPDIR = custom_temp)
terra::terraOptions(memfrac = 0.8, tempdir = custom_temp)
log_line(paste("Terra memfrac=0.8 tempdir=", custom_temp))

output_dir <- file.path(module_root, "output", scenario_name, paste0("region", region_id))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
log_line(paste("Output dir:", output_dir))

esa_waterfilled_path <- file.path(base_dir, "ESA_WorldCover/processed/processed_1km/ESA_WorldCover_2021_aligned_1km_waterfilled.tif")
esa_fixed_path <- file.path(base_dir, "ESA_WorldCover/processed/processed_1km/ESA_WorldCover_2021_aligned_1km_fixed.tif")

if (file.exists(esa_waterfilled_path)) {
  esa_ref_path <- esa_waterfilled_path
  log_line(paste("ESA water-filled reference detected:", esa_ref_path))
} else if (file.exists(esa_fixed_path)) {
  esa_ref_path <- esa_fixed_path
} else {
  esa_ref_path <- file.path(base_dir, "ESA_WorldCover/processed/processed_1km/ESA_WorldCover_2021_aligned_1km.tif")
}

if (!file.exists(esa_ref_path)) {
  log_line(paste("ERROR: ESA reference not found:", esa_ref_path))
  quit(status = 1)
}
full_ref <- terra::rast(esa_ref_path)
log_line(paste("ESA reference loaded:", esa_ref_path))

vals <- unique(terra::values(full_ref))
vals <- vals[!is.na(vals) & vals != 0]
vals <- sort(vals)
if (length(vals) > 0) {
  cats_df <- data.frame(ID = vals, name = paste0("LC", vals))
  try({ terra::cats(full_ref, 1) <- cats_df }, silent = TRUE)
}

if (esa_ref_path != esa_waterfilled_path && !file.exists(esa_fixed_path)) {
  try({ terra::writeRaster(full_ref, esa_fixed_path, overwrite = TRUE) }, silent = TRUE)
  if (file.exists(esa_fixed_path)) log_line(paste("Wrote fixed ESA reference:", esa_fixed_path))
}

full_ext <- terra::ext(full_ref)
x_range <- full_ext[2] - full_ext[1]
y_range <- full_ext[4] - full_ext[3]
x_div <- 4; y_div <- 2
regions <- list()
for (y in 1:y_div) for (x in 1:x_div) {
  idx <- (y - 1) * x_div + x
  xmin <- full_ext[1] + (x - 1) * x_range / x_div
  xmax <- full_ext[1] + x * x_range / x_div
  ymin <- full_ext[3] + (y - 1) * y_range / y_div
  ymax <- full_ext[3] + y * y_range / y_div
  regions[[idx]] <- c(xmin, xmax, ymin, ymax)
}
reg_ext <- terra::ext(regions[[region_id]])
log_line(paste("Region extent:", paste(reg_ext, collapse = ", ")))

region_ref <- terra::crop(full_ref, reg_ext)
region_ref_cover <- ensure_reference_cover(region_ref, paste0("initial region ref (region ", region_id, ")"))
region_ref <- region_ref_cover$raster

initial_ref <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_initial_ref_map_water.tif"))
terra::writeRaster(region_ref, initial_ref, overwrite = TRUE)
log_line(paste("Saved initial ref:", initial_ref))

existing_outputs <- list.files(output_dir, pattern = paste0(scenario_name, "_region", region_id, "_.*_1km_Discrete_Time1\\.tif$"), full.names = TRUE)
start_year_index <- 1
current_ref <- initial_ref
if (length(existing_outputs) > 0) {
  existing_outputs <- sort(existing_outputs)
  current_ref <- existing_outputs[length(existing_outputs)]
  log_line(paste("Resuming from:", basename(current_ref)))
  plum_dir_check <- file.path(base_dir, "PLUM_Africa_Data/processed_data", scenario_name)
  plum_files_check <- sort(list.files(plum_dir_check, pattern = paste0(scenario_name, "_.*_africa\\.tif$"), full.names = TRUE))
  plum_years_check <- vapply(plum_files_check, extract_year_str, character(1))
  plum_files_check <- plum_files_check[!is.na(plum_years_check) & plum_years_check %in% allowed_years]
  if (length(plum_files_check) > 0) {
    for (i in seq_along(plum_files_check)) {
      ystr <- extract_year_str(plum_files_check[i])
      candidate <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_", ystr, "_1km_Discrete_Time1.tif"))
      if (file.exists(candidate)) start_year_index <- i + 1
    }
    if (start_year_index > length(plum_files_check)) {
      log_line("All eligible years already processed. Nothing to do.")
      quit(status = 0)
    }
  }
}

plum_dir <- file.path(base_dir, "PLUM_Africa_Data/processed_data", scenario_name)
plum_files_all <- sort(list.files(plum_dir, pattern = paste0(scenario_name, "_.*_africa\\.tif$"), full.names = TRUE))
if (length(plum_files_all) == 0) {
  log_line(paste("ERROR: No PLUM files in", plum_dir))
  quit(status = 1)
}

plum_years <- vapply(plum_files_all, extract_year_str, character(1))
plum_files <- plum_files_all[!is.na(plum_years) & plum_years %in% allowed_years]
if (length(plum_files) == 0) {
  log_line("ERROR: No eligible PLUM files found for 2021_2022 through 2031_2032")
  quit(status = 1)
}
log_line(paste("Found", length(plum_files), "eligible PLUM files"))

if (length(existing_outputs) > 0) {
  log_line(paste("Resuming from year index", start_year_index))
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
  allocations <- allocations[names(allocations) %in% plum_layer_names]
  synergy <- matrix(0, nrow = length(plum_layer_names), ncol = length(esa_classes),
                    dimnames = list(plum_layer_names, esa_classes))
  for (cat in names(allocations)) {
    valid <- intersect(names(allocations[[cat]]), esa_classes)
    if (length(valid) > 0) {
      synergy[cat, valid] <- allocations[[cat]][valid]
    } else {
      synergy[cat, ] <- 1 / length(esa_classes)
    }
  }
  row_sums <- rowSums(synergy)
  for (i in seq_along(row_sums)) {
    if (row_sums[i] == 0) {
      synergy[i, ] <- 1 / ncol(synergy)
    } else {
      synergy[i, ] <- synergy[i, ] / row_sums[i]
    }
  }
  synergy
}

match_LC_classes <- NULL
assign_ref_true_attempts <- 0L
assign_ref_true_success <- 0L

for (year_index in start_year_index:length(plum_files)) {
  plum_file <- plum_files[year_index]
  year_str <- extract_year_str(plum_file)
  if (is.na(year_str)) {
    year_str <- paste0("year", year_index)
  }
  log_line("=======================================")
  log_line(paste("Processing year:", year_str, "(", basename(plum_file), ")"))
  log_line("=======================================")

  full_plum <- terra::rast(plum_file)
  region_plum <- terra::crop(full_plum, reg_ext)
  region_plum_path <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_plum_", year_str, "_1km.tif"))
  terra::writeRaster(region_plum, region_plum_path, overwrite = TRUE)
  log_line(paste("Saved regional PLUM:", region_plum_path))

  region_ref <- terra::rast(current_ref)
  filled_ref_path <- file.path(custom_temp, paste0(scenario_name, "_region", region_id, "_", year_str, "_ref_filled_1km.tif"))
  cover_result <- ensure_reference_cover(region_ref, paste0("ref for year ", year_str), write_path = filled_ref_path)
  region_ref <- cover_result$raster
  ref_path_for_run <- if (!is.null(cover_result$path) && cover_result$filled) cover_result$path else current_ref
  esa_values <- tryCatch({
    cf <- terra::cats(region_ref, 1)
    if (!is.null(cf) && nrow(cf) > 0) {
      as.integer(cf$ID)
    } else {
      vals <- unique(terra::values(region_ref)); vals <- vals[!is.na(vals)]; as.integer(vals)
    }
  }, error = function(e) {
    vals <- unique(terra::values(region_ref)); vals <- vals[!is.na(vals)]; as.integer(vals)
  })
  if (length(esa_values) == 0) {
    log_line("WARNING: Region reference has only NA; writing empty output")
    empty_path <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_", year_str, "_1km_Discrete_Time1.tif"))
    terra::writeRaster(region_ref, empty_path, overwrite = TRUE)
    current_ref <- empty_path
    next
  }
  esa_classes <- paste0("LC", esa_values)
  log_line(paste("Region ESA classes:", paste(sort(esa_classes), collapse = ", ")))

  if (is.null(match_LC_classes)) {
    plum_names <- names(region_plum)
    match_LC_classes <- build_synergy(plum_names, esa_classes)
    synergy_file <- file.path(output_dir, paste0(scenario_name, "_region", region_id, "_synergy_table", synergy_table_id, ".rds"))
    saveRDS(match_LC_classes, synergy_file)
    log_line(paste("Saved synergy:", synergy_file))
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
      kernel_radius       = kernel_radius,
      simulation_type     = "deterministic",
      discrete_output_map = TRUE,
      random_seed         = 42,
      output_dir_path     = output_dir,
      output_file_prefix  = output_prefix,
      assign_ref_cells    = assign_flag
    )

    discrete_files <- list.files(output_dir, pattern = paste0(output_prefix, ".*Discrete_Time1\\.tif$"), full.names = TRUE)
    if (length(discrete_files) > 0) {
      discrete_files <- sort(discrete_files)
      new_ref <- discrete_files[length(discrete_files)]
      log_line(paste(
        "Updated reference for next year:",
        basename(new_ref),
        paste0("(assign_ref_cells=", assign_flag, ")")
      ))
      return(list(success = TRUE, ref_path = new_ref, assign_flag = assign_flag))
    }

    log_line("WARNING: No discrete output found after downscaling")
    list(success = TRUE, ref_path = current_ref, assign_flag = assign_flag)
  }

  log_line("Calling LandScaleR::downscaleLC (deterministic, assign_ref_cells=TRUE)")
  assign_ref_true_attempts <- assign_ref_true_attempts + 1L
  attempt <- tryCatch(run_downscale(TRUE), error = function(e) {
    list(success = FALSE, error = e)
  })

  if (!attempt$success) {
    msg <- conditionMessage(attempt$error)
    log_line(paste("ERROR during downscaling with assign_ref_cells=TRUE:", msg))

    fallback <- tryCatch({
      log_line("Falling back to assign_ref_cells=FALSE for this year")
      log_line("Calling LandScaleR::downscaleLC (deterministic, assign_ref_cells=FALSE)")
      run_downscale(FALSE)
    }, error = function(e) {
      list(success = FALSE, error = e)
    })

    if (!fallback$success) {
      log_line(paste("ERROR during fallback downscaling:", conditionMessage(fallback$error)))
      log_line("Skipping remaining processing for this year due to repeated errors")
      next
    }

    current_ref <- fallback$ref_path
  } else {
    assign_ref_true_success <- assign_ref_true_success + 1L
    current_ref <- attempt$ref_path
  }

  log_line(paste("Completed year:", year_str))
}

if (assign_ref_true_attempts > 0) {
  log_line(paste(
    "assign_ref_cells=TRUE succeeded",
    assign_ref_true_success,
    "of",
    assign_ref_true_attempts,
    "attempts (fallbacks:",
    assign_ref_true_attempts - assign_ref_true_success, ")"
  ))
} else {
  log_line("assign_ref_cells=TRUE did not run for this region (no eligible years)")
}

log_line(paste("Standalone ESA deterministic run completed for", variant_label))
