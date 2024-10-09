# Author: Markus Shiweda
# Co-Authors: Tamsin Woodman, Reinhard Prestele

# Function to install and load packages
install_if_needed <- function(pkg) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# Install and load CRAN packages
install_if_needed('devtools')
install_if_needed('FNN')
install_if_needed('terra') # Press no when RStudio asks if package should be compiled from source
install_if_needed('data.table')
install_if_needed('raster')
install_if_needed('rasterVis')
install_if_needed('rgee')

# Install and load LandScaleR from GitHub
if (!requireNamespace("LandScaleR", quietly = TRUE)) {
  devtools::install_github("TamsinWoodman/LandScaleR", build_vignettes = TRUE)
} else {
  message("LandScaleR is already installed.")
}

# Now load the package
if (requireNamespace("LandScaleR", quietly = TRUE)) {
  library(LandScaleR)
} else {
  stop("Failed to install or load the LandScaleR package.")
}




