#!/usr/bin/env Rscript

# Independent numerical QA for the package-free synthetic-control solver used
# in the book. Synth is a reference implementation used only by this script.

args <- commandArgs(trailingOnly = TRUE)
repo_dir <- if (length(args)) normalizePath(args[[1]], mustWork = TRUE) else normalizePath("../..", mustWork = TRUE)
qa_dir <- file.path(repo_dir, "qa", "synthetic-control-equivalence")
results_dir <- file.path(qa_dir, "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("Synth", quietly = TRUE)) {
  stop("This QA runner requires Synth as the reference implementation.")
}

simplex_weights <- function(theta) c(theta, 1 - sum(theta))

fit_package_free <- function(X1, X0, Z1, Z0) {
  design_target <- rbind(X1, Z1)
  design_donors <- rbind(X0, Z0)
  row_scale <- apply(cbind(design_target, design_donors), 1, sd)
  row_scale[!is.finite(row_scale) | row_scale == 0] <- 1
  scaled_target <- design_target[, 1] / row_scale
  scaled_donors <- design_donors / row_scale
  donor_count <- ncol(scaled_donors)

  loss <- function(theta) {
    weights <- simplex_weights(theta)
    mean((scaled_target - as.numeric(scaled_donors %*% weights))^2)
  }

  gradient <- function(theta) {
    weights <- simplex_weights(theta)
    residual <- scaled_target - as.numeric(scaled_donors %*% weights)
    donor_differences <- scaled_donors[, -donor_count, drop = FALSE] -
      scaled_donors[, donor_count]
    -2 * colMeans(donor_differences * residual)
  }

  constraint_matrix <- rbind(
    diag(donor_count - 1),
    rep(-1, donor_count - 1)
  )
  constraint_boundary <- c(rep(0, donor_count - 1), -1)

  fit <- constrOptim(
    theta = rep(1 / donor_count, donor_count - 1),
    f = loss,
    grad = gradient,
    ui = constraint_matrix,
    ci = constraint_boundary,
    method = "BFGS",
    control = list(maxit = 5000, reltol = 1e-12)
  )
  weights <- simplex_weights(fit$par)

  list(
    weights = weights,
    objective = loss(fit$par),
    convergence = fit$convergence,
    design_target = design_target,
    design_donors = design_donors
  )
}

fit_reference <- function(package_free, Z1, Z0) {
  predictor_count <- nrow(package_free$design_target)
  Synth::synth(
    X1 = package_free$design_target,
    X0 = package_free$design_donors,
    Z1 = Z1,
    Z0 = Z0,
    custom.v = rep(1 / predictor_count, predictor_count),
    Margin.ipop = 1e-06,
    Sigf.ipop = 8,
    Bound.ipop = 100,
    verbose = FALSE
  )
}

unit_values <- function(data, id_column, id, time_column, years, value_column) {
  rows <- data[data[[id_column]] == id, , drop = FALSE]
  rows[[value_column]][match(years, rows[[time_column]])]
}

toy_design <- function(repo_dir) {
  data <- readRDS(file.path(repo_dir, "docs", "labs", "data", "synth.data.rds"))
  treated <- 7
  donors <- c(29, 2, 13, 17, 32, 38)
  predictor_years <- 1984:1989
  pre_years <- 1984:1990
  plot_years <- 1984:1996

  predictors <- function(id) {
    rows <- data[data$unit.num == id, , drop = FALSE]
    c(
      X1 = mean(rows$X1[rows$year %in% predictor_years]),
      X2 = mean(rows$X2[rows$year %in% predictor_years]),
      X3 = mean(rows$X3[rows$year %in% predictor_years]),
      Y_1985 = rows$Y[match(1985, rows$year)],
      Y_1990 = rows$Y[match(1990, rows$year)]
    )
  }

  X1 <- matrix(predictors(treated), ncol = 1)
  X0 <- vapply(donors, predictors, numeric(nrow(X1)))
  Z1 <- matrix(unit_values(data, "unit.num", treated, "year", pre_years, "Y"), ncol = 1)
  Z0 <- vapply(donors, function(id) unit_values(data, "unit.num", id, "year", pre_years, "Y"), numeric(length(pre_years)))
  Y1 <- unit_values(data, "unit.num", treated, "year", plot_years, "Y")
  Y0 <- vapply(donors, function(id) unit_values(data, "unit.num", id, "year", plot_years, "Y"), numeric(length(plot_years)))

  rownames(X1) <- rownames(X0) <- names(predictors(treated))
  colnames(X0) <- colnames(Z0) <- as.character(donors)
  list(name = "Toy mechanics", X1 = X1, X0 = X0, Z1 = Z1, Z0 = Z0, Y1 = Y1, Y0 = Y0, time = plot_years, donor = as.character(donors), post = plot_years > 1990)
}

proposition_design <- function(repo_dir) {
  data <- readRDS(file.path(repo_dir, "docs", "labs", "data", "smoking.rds"))
  treated <- "California"
  excluded <- c("Alaska", "Hawaii", "Maryland", "Massachusetts", "Michigan", "New Jersey", "New York", "Washington", "District of Columbia")
  data <- data[data$year <= 2000 & !data$state %in% excluded, , drop = FALSE]
  donors <- setdiff(unique(data$state), treated)
  pre_years <- 1970:1988
  plot_years <- 1970:2000

  predictors <- function(id) {
    rows <- data[data$state == id, , drop = FALSE]
    c(
      lnincome = mean(rows$lnincome[rows$year %in% 1980:1988], na.rm = TRUE),
      retprice = mean(rows$retprice[rows$year %in% 1980:1988], na.rm = TRUE),
      age15to24 = mean(rows$age15to24[rows$year %in% 1980:1988], na.rm = TRUE),
      beer = mean(rows$beer[rows$year %in% 1984:1988], na.rm = TRUE),
      cigsale_1975 = rows$cigsale[match(1975, rows$year)],
      cigsale_1980 = rows$cigsale[match(1980, rows$year)],
      cigsale_1988 = rows$cigsale[match(1988, rows$year)]
    )
  }

  X1 <- matrix(predictors(treated), ncol = 1)
  X0 <- vapply(donors, predictors, numeric(nrow(X1)))
  Z1 <- matrix(unit_values(data, "state", treated, "year", pre_years, "cigsale"), ncol = 1)
  Z0 <- vapply(donors, function(id) unit_values(data, "state", id, "year", pre_years, "cigsale"), numeric(length(pre_years)))
  Y1 <- unit_values(data, "state", treated, "year", plot_years, "cigsale")
  Y0 <- vapply(donors, function(id) unit_values(data, "state", id, "year", plot_years, "cigsale"), numeric(length(plot_years)))

  rownames(X1) <- rownames(X0) <- names(predictors(treated))
  colnames(X0) <- colnames(Z0) <- donors
  list(name = "Proposition 99", X1 = X1, X0 = X0, Z1 = Z1, Z0 = Z0, Y1 = Y1, Y0 = Y0, time = plot_years, donor = donors, post = plot_years > 1988)
}

compare_design <- function(design) {
  message("Comparing ", design$name)
  package_free <- fit_package_free(design$X1, design$X0, design$Z1, design$Z0)
  repeat_fit <- fit_package_free(design$X1, design$X0, design$Z1, design$Z0)
  reference <- fit_reference(package_free, design$Z1, design$Z0)

  w_reference <- as.numeric(reference$solution.w)
  w_base <- as.numeric(package_free$weights)
  path_reference <- as.numeric(design$Y0 %*% w_reference)
  path_base <- as.numeric(design$Y0 %*% w_base)
  gap_reference <- design$Y1 - path_reference
  gap_base <- design$Y1 - path_base

  summary <- data.frame(
    scenario = design$name,
    donor_count = length(design$donor),
    max_abs_weight_difference = max(abs(w_base - w_reference)),
    weight_rmse = sqrt(mean((w_base - w_reference)^2)),
    reference_pre_mspe = mean(as.numeric(design$Z1 - design$Z0 %*% w_reference)^2),
    package_free_pre_mspe = mean(as.numeric(design$Z1 - design$Z0 %*% w_base)^2),
    relative_pre_mspe_difference = abs(mean(as.numeric(design$Z1 - design$Z0 %*% w_base)^2) - mean(as.numeric(design$Z1 - design$Z0 %*% w_reference)^2)) / max(mean(as.numeric(design$Z1 - design$Z0 %*% w_reference)^2), .Machine$double.eps),
    max_abs_path_difference = max(abs(path_base - path_reference)),
    path_rmse = sqrt(mean((path_base - path_reference)^2)),
    reference_mean_post_gap = mean(gap_reference[design$post]),
    package_free_mean_post_gap = mean(gap_base[design$post]),
    abs_mean_post_gap_difference = abs(mean(gap_base[design$post]) - mean(gap_reference[design$post])),
    reference_weight_sum_error = abs(sum(w_reference) - 1),
    package_free_weight_sum_error = abs(sum(w_base) - 1),
    reference_min_weight = min(w_reference),
    package_free_min_weight = min(w_base),
    repeatability_max_abs_weight_difference = max(abs(w_base - repeat_fit$weights)),
    package_free_convergence = package_free$convergence,
    stringsAsFactors = FALSE
  )

  weights <- data.frame(
    scenario = design$name,
    donor = design$donor,
    reference_weight = w_reference,
    package_free_weight = w_base,
    absolute_difference = abs(w_base - w_reference),
    stringsAsFactors = FALSE
  )

  paths <- data.frame(
    scenario = design$name,
    time = design$time,
    treated = design$Y1,
    reference_synthetic = path_reference,
    package_free_synthetic = path_base,
    reference_gap = gap_reference,
    package_free_gap = gap_base,
    absolute_path_difference = abs(path_base - path_reference),
    post = design$post,
    stringsAsFactors = FALSE
  )

  list(summary = summary, weights = weights, paths = paths, reference = reference, package_free = package_free)
}

set.seed(20260923)
comparisons <- lapply(list(toy_design(repo_dir), proposition_design(repo_dir)), compare_design)
summary_results <- do.call(rbind, lapply(comparisons, `[[`, "summary"))
weight_results <- do.call(rbind, lapply(comparisons, `[[`, "weights"))
path_results <- do.call(rbind, lapply(comparisons, `[[`, "paths"))

acceptance <- transform(
  summary_results,
  pass_constraints = package_free_convergence == 0 &
    package_free_weight_sum_error < 1e-10 & package_free_min_weight > -1e-10,
  pass_repeatability = repeatability_max_abs_weight_difference < 1e-12,
  pass_numerical_equivalence = relative_pre_mspe_difference < 0.01 &
    max_abs_path_difference < 0.25 & abs_mean_post_gap_difference < 0.05
)
acceptance$overall_pass <- with(
  acceptance,
  pass_constraints & pass_repeatability & pass_numerical_equivalence
)

write.csv(summary_results, file.path(results_dir, "summary.csv"), row.names = FALSE)
write.csv(acceptance, file.path(results_dir, "acceptance.csv"), row.names = FALSE)
write.csv(weight_results, file.path(results_dir, "weights.csv"), row.names = FALSE)
write.csv(path_results, file.path(results_dir, "paths.csv"), row.names = FALSE)
saveRDS(comparisons, file.path(results_dir, "comparison-objects.rds"))
writeLines(capture.output(sessionInfo()), file.path(results_dir, "session-info.txt"))

input_paths <- c(
  "docs/labs/data/synth.data.rds",
  "docs/labs/data/smoking.rds"
)
input_hashes <- vapply(
  file.path(repo_dir, input_paths),
  function(path) strsplit(system2("sha256sum", path, stdout = TRUE), " ", fixed = TRUE)[[1]][1],
  character(1)
)
write.csv(
  data.frame(file = input_paths, sha256 = unname(input_hashes)),
  file.path(results_dir, "inputs.csv"),
  row.names = FALSE
)

tool_names <- c("cmake", "cargo", "rustc")
write.csv(
  data.frame(tool = tool_names, available = nzchar(Sys.which(tool_names))),
  file.path(results_dir, "build-tools.csv"),
  row.names = FALSE
)

print(acceptance, digits = 8)
if (!all(acceptance$overall_pass)) stop("At least one equivalence scenario failed its acceptance criteria.")
