# Run deliberately when updating teaching snapshots, never during a site build.
# Package libraries and pinned source files must already be available locally.
args <- commandArgs(TRUE)
if (length(args) != 2L) stop("Usage: Rscript vendor_lab_data.R DID_SOURCE_DIR RDD_SOURCE_DIR")
target <- "docs/labs/data"
dir.create(target, recursive=TRUE, showWarnings=FALSE)
dir.create(file.path(target, "provenance"), showWarnings=FALSE)
specs <- list(
  lalonde="MatchIt", black_politicians="causaldata", nsw_mixtape="causaldata",
  cps_mixtape="causaldata", Seatbelts="datasets", synth.data="Synth",
  smoking="tidysynth", kansas="augsynth", injury="wooldridge", castle="causaldata",
  mpdta="did", gov_transfers="causaldata", gov_transfers_density="causaldata",
  mortgages="causaldata"
)
records <- list()
for (name in names(specs)) {
  package <- specs[[name]]
  e <- new.env()
  pinned <- if (name %in% c("injury", "castle", "mpdta")) {
    file.path(args[1], paste0(name, if (name == "injury") ".RData" else ".rda"))
  } else if (name %in% c("gov_transfers", "gov_transfers_density", "mortgages")) {
    file.path(args[2], paste0(name, ".rda"))
  } else NULL
  if (is.null(pinned)) data(list=name, package=package, envir=e) else load(pinned, envir=e)
  object <- e[[name]]
  stopifnot(!is.null(object))
  filename <- paste0(name, ".rds")
  saveRDS(object, file.path(target, filename), version=2, compress="xz")
  description <- packageDescription(package)
  documentation <- utils:::.getHelpFile(do.call(utils::help, list(topic=name, package=package)))
  tools::Rd2txt(documentation, out=file.path(target, "provenance", paste0(name, ".txt")), options=list(underline_titles=FALSE))
  notice <- file.path(find.package(package), "LICENSE")
  if (file.exists(notice)) file.copy(notice, file.path(target, "provenance", paste0(package, "-LICENSE")), overwrite=TRUE)
  records[[name]] <- list(file=filename, sha256=digest::digest(file=file.path(target, filename), algo="sha256"),
    rows=NROW(object), columns=colnames(object), class=class(object), package=package,
    package_version=description$Version, license=description$License,
    source=if (is.null(description$URL)) paste0("https://cran.r-project.org/package=", package) else description$URL,
    original_sha256=if (!is.null(pinned)) digest::digest(file=pinned, algo="sha256") else NULL,
    variables=lapply(as.data.frame(object), function(x) list(class=class(x), missing=sum(is.na(x)))))
}
jsonlite::write_json(records, file.path(target,"manifest.json"), pretty=TRUE, auto_unbox=TRUE, null="null")

# The HISP bundle was previously tracked in this repository. Recover exact bytes.
dir.create(file.path(target, "hisp"), showWarnings=FALSE)
for (file in c("evaluation.csv", "evaluation.dta", "HISP Book replication.do")) {
  status <- system2("git", c("show", shQuote(paste0("3152e4d:docs/data/hisp_ie_in_practice/", file))),
                    stdout=file.path(target, "hisp", file))
  stopifnot(status == 0)
}
hisp <- readr::read_csv(file.path(target, "hisp/evaluation.csv"), show_col_types=FALSE)
labels <- haven::read_dta(file.path(target, "hisp/evaluation.dta"))
writeLines(c("HISP: Impact Evaluation in Practice, second edition",
  "Original variables (labels retained from evaluation.dta):",
  vapply(names(labels), function(name) paste0(name, ": ", attr(labels[[name]],"label")), character(1))),
  file.path(target, "provenance/hisp.txt"))
saveRDS(as.data.frame(hisp), file.path(target, "hisp.rds"), version=2, compress="xz")
records$hisp <- list(file="hisp.rds", sha256=digest::digest(file=file.path(target,"hisp.rds"),algo="sha256"),
  rows=nrow(hisp), columns=names(hisp), class="data.frame",
  source="https://www.worldbank.org/en/programs/sief-trust-fund/publication/impact-evaluation-in-practice",
  source_revision="Repository commit 3152e4d; original HISP second-edition teaching bundle",
  license="World Bank accompanying teaching materials; retain attribution and original disclaimer; no additional license asserted",
  additional_files=c("hisp/evaluation.csv", "hisp/evaluation.dta", "hisp/HISP Book replication.do"),
  variables=lapply(hisp, function(x) list(class=class(x), missing=sum(is.na(x)))))

script <- tempfile(fileext=".R")
knitr::purl("docs/labs/interrupted-time-series-counterfactual-validation-lab.qmd", output=script, quiet=TRUE)
expressions <- parse(script)
e <- new.env()
for (expression in expressions) {
  if (is.call(expression) && identical(expression[[1]], as.name("<-")) &&
      identical(expression[[2]], as.name("simulate_service"))) eval(expression, e)
}
service <- e$simulate_service()
writeLines(c("Seeded service simulation: 48127L",
  "120 monthly observations, January 2014 to December 2023.",
  "Implementation begins January 2021. untreated_outcome is known simulation truth,",
  "not an observed real-world counterfactual. programme_effect is added to it to",
  "form observed_outcome. context changes support in the last year.",
  "See simulate_service() in the counterfactual-validation lab for all equations."),
  file.path(target, "provenance/service.txt"))
saveRDS(service, file.path(target,"service.rds"), version=2, compress="xz")
records$service <- list(file="service.rds", sha256=digest::digest(file=file.path(target,"service.rds"),algo="sha256"),
  rows=nrow(service), columns=names(service), class="data.frame", seed=48127L,
  source="QED Labs: simulate_service() in interrupted-time-series-counterfactual-validation-lab.qmd",
  license="Repository-authored synthetic teaching data; no real people or records",
  variables=lapply(service, function(x) list(class=class(x), missing=sum(is.na(x)))))
for (method in c("did", "rdd")) {
  original <- jsonlite::fromJSON(paste0("docs/labs/reproducibility/",method,"-data-manifest.json"), simplifyVector=FALSE)
  for (name in intersect(names(records), names(original))) {
    if (!is.null(original[[name]]$url)) records[[name]]$source <- original[[name]]$url
    if (!is.null(original[[name]]$sha256)) stopifnot(identical(records[[name]]$original_sha256, original[[name]]$sha256))
  }
}
for (name in names(records)) {
  files <- records[[name]]$additional_files
  if (length(files)) records[[name]]$additional_sha256 <- setNames(lapply(files, function(file)
    digest::digest(file=file.path(target,file),algo="sha256")), files)
}
for (license in c("GPL-2", "GPL-3", "MIT")) {
  source <- file.path(R.home("share"), "licenses", license)
  if (file.exists(source)) file.copy(source, file.path(target,"provenance",license), overwrite=TRUE)
}
jsonlite::write_json(records, file.path(target,"manifest.json"), pretty=TRUE, auto_unbox=TRUE, null="null")
