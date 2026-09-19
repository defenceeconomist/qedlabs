#!/usr/bin/env Rscript
# Execute each new report and its existing guide in separate environments.
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value=TRUE)[1]))
docs <- dirname(dirname(script))
run_document <- function(relative) {
  path <- file.path(docs, relative)
  old <- setwd(dirname(path))
  on.exit(setwd(old))
  code <- tempfile(fileext=".R")
  figures <- tempfile(fileext=".pdf")
  on.exit(unlink(c(code, figures)), add=TRUE)
  knitr::purl(basename(path), output=code, quiet=TRUE)
  env <- new.env(parent=globalenv())
  pdf(figures)
  on.exit(dev.off(), add=TRUE)
  sys.source(code, envir=env)
  env
}
same <- function(x, y) stopifnot(isTRUE(all.equal(x, y, tolerance=1e-8)))
its_report <- run_document("labs/interrupted-time-series-methods-report.qmd")
its_guide <- run_document("notes/other-methods/how-to-do-interrupted-time-series.qmd")
same(coef(its_report$fit), coef(its_guide$fit))
same(vcov(its_report$fit), vcov(its_guide$fit))
same(its_report$effects$percent, its_guide$effects$percent)
did_report <- run_document("labs/difference-in-differences-methods-report.qmd")
did_guide <- run_document("notes/did/how-to-do-difference-in-differences.qmd")
same(unname(did_report$manual), unname(did_guide$did_manual))
same(did_report$att$att, did_guide$att$att)
same(did_report$overall$overall.att, did_guide$overall$overall.att)
same(did_report$dynamic$att.egt, did_guide$dynamic$att.egt)
rdd_report <- run_document("labs/regression-discontinuity-methods-report.qmd")
rdd_guide <- run_document("notes/rdd/how-to-do-regression-discontinuity.qmd")
for (name in c("fixed", "automatic", "fuzzy")) {
  same(rdd_report[[name]]$coef, rdd_guide[[name]]$coef)
  same(rdd_report[[name]]$ci, rdd_guide[[name]]$ci)
}
message("All three reports agree with their existing practical guides.")
