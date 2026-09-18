# Resolve either a repository checkout or an extracted lab bundle, without network access.
qed_data_directory <- function() {
  candidates <- c("data", "../data", "../../labs/data", "docs/labs/data", "labs/data")
  matches <- candidates[file.exists(file.path(candidates, "manifest.json"))]
  if (!length(matches)) stop("Local lab data are missing. Extract the complete lab ZIP and keep its data folder beside the notebook or Quarto document.", call.=FALSE)
  normalizePath(matches[[1]], mustWork=TRUE)
}
qed_data <- function(name, directory=qed_data_directory()) {
  required <- c("jsonlite", "digest")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly=TRUE)]
  if (length(missing)) stop("Install the documented R environment before running: ", paste(missing, collapse=", "), call.=FALSE)
  manifest <- jsonlite::fromJSON(file.path(directory, "manifest.json"), simplifyVector=FALSE)
  spec <- manifest[[name]]
  if (is.null(spec)) stop("Unknown bundled dataset: ", name, call.=FALSE)
  path <- file.path(directory, spec$file)
  if (!file.exists(path)) stop("Missing bundled data file: ", path, call.=FALSE)
  if (!identical(digest::digest(file=path, algo="sha256"), spec$sha256))
    stop("Data checksum mismatch: ", path, call.=FALSE)
  for (file in names(spec$additional_sha256)) {
    extra <- file.path(directory, file)
    if (!file.exists(extra)) stop("Missing bundled data file: ", extra, call.=FALSE)
    if (!identical(digest::digest(file=extra, algo="sha256"), spec$additional_sha256[[file]]))
      stop("Data checksum mismatch: ", extra, call.=FALSE)
  }
  result <- readRDS(path)
  if (NROW(result) != spec$rows) stop("Unexpected data dimensions: ", name, call.=FALSE)
  result
}
