# Optional online software setup. Lab execution never invokes this script.
packages <- c("IRkernel", "knitr", "rmarkdown", "digest", "jsonlite", "MatchIt",
  "WeightIt", "cobalt", "dplyr", "ggplot2", "fixest", "did", "bacondecomp",
  "haven", "readr", "broom", "sandwich", "boot", "nlme", "tibble", "tidyr",
  "rdrobust", "rddensity", "remotes")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly=TRUE)]
if (length(missing)) install.packages(missing, repos="https://cloud.r-project.org")
if (!requireNamespace("augsynth", quietly=TRUE))
  remotes::install_github("ebenmichael/augsynth@7a90ea48877fae7925a72cb50bc03a315bc7c042", upgrade="never")
