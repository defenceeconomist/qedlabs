args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: setup.R BOOK_DIR R_LIBRARY")

book_dir <- normalizePath(args[[1]], mustWork = TRUE)
r_library <- normalizePath(args[[2]], mustWork = TRUE)
.libPaths(c(r_library, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

if (!requireNamespace("renv", quietly = TRUE) ||
    as.character(packageVersion("renv")) != "1.2.4") {
  # Install from the normal CRAN index while 1.2.4 is current. If CRAN later
  # advances, replace it with the exact archived source release.
  install.packages("renv", lib = r_library)
  if (as.character(packageVersion("renv")) != "1.2.4") {
    install.packages(
      "https://cran.r-project.org/src/contrib/Archive/renv/renv_1.2.4.tar.gz",
      repos = NULL,
      type = "source",
      lib = r_library
    )
  }
}

renv::restore(
  project = book_dir,
  lockfile = file.path(book_dir, "renv.lock"),
  library = r_library,
  exclude = "augsynth",
  prompt = FALSE
)

archive <- file.path(
  book_dir,
  "vendor",
  "augsynth-7a90ea48877fae7925a72cb50bc03a315bc7c042.tar.gz"
)
if (!file.exists(archive)) stop("Missing vendored augsynth archive: ", archive)
augsynth_sha256 <- "af6f7d84002b185b4672d7c0dfb85f0a6f9edab96b72fccc75e516543c32811e"
if (digest::digest(file = archive, algo = "sha256") != augsynth_sha256) {
  stop("Vendored augsynth archive checksum mismatch")
}
augsynth_marker <- file.path(r_library, ".augsynth-source-sha256")
augsynth_in_local_library <- FALSE
if (requireNamespace("augsynth", quietly = TRUE)) {
  installed_path <- normalizePath(find.package("augsynth"), mustWork = TRUE)
  augsynth_in_local_library <- startsWith(installed_path, paste0(r_library, .Platform$file.sep))
}
if (!augsynth_in_local_library ||
    as.character(packageVersion("augsynth")) != "0.2.0" ||
    !file.exists(augsynth_marker) ||
    !identical(readLines(augsynth_marker, warn = FALSE), augsynth_sha256)) {
  install.packages(archive, repos = NULL, type = "source", lib = r_library)
  writeLines(augsynth_sha256, augsynth_marker)
}

required <- c(
  "IRkernel", "digest", "jsonlite", "MatchIt", "WeightIt", "cobalt",
  "causaldata", "dplyr", "ggplot2", "fixest", "did", "bacondecomp",
  "haven", "readr", "broom", "sandwich", "boot", "nlme", "tibble",
  "tidyr", "rdrobust", "rddensity", "purrr", "augsynth",
  "dagitty", "ggdag", "knitr"
)
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing R packages after restore: ", paste(missing, collapse = ", "))

cat("R environment ready in", r_library, "\n")
