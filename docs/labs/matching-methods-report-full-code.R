# ---- chunk 1 ----
# Declare analysis dependencies used across matching, weighting, and diagnostics.
required_packages <- c(
  "MatchIt",
  "WeightIt",
  "cobalt",
  "causaldata",
  "dplyr",
  "ggplot2"
)

# Identify packages that are not yet available in the current R library.
missing_packages <- required_packages[!vapply(
  required_packages,
  requireNamespace,
  logical(1),
  quietly = TRUE
)]

# Install only the missing packages to keep setup idempotent.
if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

# Attach packages for use in the remainder of the report.
invisible(lapply(required_packages, library, character.only = TRUE))


# ---- chunk 2 ----
# Load the NSW experimental benchmark and the observational MatchIt sample.
data("lalonde", package = "MatchIt")

# Standardize the NSW experiment while retaining its original package columns.
benchmark_dat <- causaldata::nsw_mixtape |>
  mutate(
    treat = as.integer(treat),
    outcome = re78,
    race = factor(
      case_when(
        black == 1L ~ "black",
        hisp == 1L ~ "hispan",
        TRUE ~ "white"
      ),
      levels = c("black", "hispan", "white")
    ),
    married = factor(marr, levels = c(0, 1), labels = c("not_married", "married")),
    nodegree = factor(nodegree, levels = c(0, 1), labels = c("has_degree", "no_degree"))
  )

# Standardize the MatchIt observational sample used for the adjustment methods.
dat <- lalonde |>
  mutate(
    treat = as.integer(treat),
    outcome = re78,
    married = factor(married, levels = c(0, 1), labels = c("not_married", "married")),
    nodegree = factor(nodegree, levels = c(0, 1), labels = c("has_degree", "no_degree"))
  )

# Store the adjustment set in one place for reusable reporting and checks.
design_covariates <- c(
  "age", "educ", "race", "married", "nodegree", "re74", "re75"
)

# Summarize how the two package datasets are being used in this report.
dataset_roles <- tibble(
  dataset = c("causaldata::nsw_mixtape", "MatchIt::lalonde"),
  role_in_report = c("Experimental benchmark", "Observational design sample"),
  treated_units = c(sum(benchmark_dat$treat == 1L), sum(dat$treat == 1L)),
  control_units = c(sum(benchmark_dat$treat == 0L), sum(dat$treat == 0L)),
  control_group = c("NSW randomized controls", "PSID comparison sample"),
  covariate_coding = c("black/hisp + marr", "race factor + married")
)

dataset_roles

# Quick schema check for treatment, outcome, and all design covariates.
dat |>
  select(treat, outcome, all_of(design_covariates)) |>
  glimpse()

# ---- chunk 3 ----
# Estimate the NSW experimental benchmark using treated and randomized controls only.
benchmark_fit <- lm(outcome ~ treat, data = benchmark_dat)
benchmark_att <- coef(summary(benchmark_fit))["treat", ]
experimental_estimate <- unname(benchmark_att["Estimate"])

# Summarize the randomized treated and control groups for later comparison.
benchmark_summary <- benchmark_dat |>
  group_by(treat) |>
  summarise(
    n = n(),
    mean_re78 = mean(outcome, na.rm = TRUE),
    mean_re74 = mean(re74, na.rm = TRUE),
    mean_re75 = mean(re75, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(group = if_else(treat == 1L, "NSW treated", "NSW controls")) |>
  select(group, n, mean_re78, mean_re74, mean_re75) |>
  mutate(across(-c(group, n), ~ round(.x, 3)))

benchmark_effect <- tibble(
  design = "Experimental benchmark (NSW RCT)",
  estimate = unname(benchmark_att["Estimate"]),
  std_error = unname(benchmark_att["Std. Error"]),
  t_value = unname(benchmark_att["t value"]),
  p_value = unname(benchmark_att["Pr(>|t|)"])
) |>
  mutate(across(c(estimate, std_error, t_value, p_value), ~ round(.x, 3)))

benchmark_summary
benchmark_effect

# ---- chunk 4 ----
# Summarize baseline group differences before any adjustment is applied.
pre_match_summary <- dat |>
  group_by(treat) |>
  summarise(
    n = n(),
    mean_outcome = mean(outcome, na.rm = TRUE),
    mean_age = mean(age, na.rm = TRUE),
    mean_educ = mean(educ, na.rm = TRUE),
    prop_married = mean(married == "married", na.rm = TRUE),
    prop_no_degree = mean(nodegree == "no_degree", na.rm = TRUE),
    mean_re74 = mean(re74, na.rm = TRUE),
    mean_re75 = mean(re75, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(group = if_else(treat == 1L, "Treated", "Control")) |>
  select(
    group, n, mean_outcome, mean_age, mean_educ,
    prop_married, prop_no_degree, mean_re74, mean_re75
  ) |>
  mutate(across(-c(group, n), ~ round(.x, 3)))

pre_match_summary

# ---- chunk 4 ----
# Build an unadjusted MatchIt object as the baseline design benchmark.
m_out0 <- matchit(
  treat ~ age + educ + race + married + nodegree + re74 + re75,
  data = dat,
  method = NULL,
  estimand = "ATT"
)

summary(m_out0, un = TRUE)

# ---- chunk 5 ----
# Produce a compact cobalt balance table for unadjusted diagnostics.
unadjusted_balance <- bal.tab(
  m_out0,
  un = TRUE,
  binary = "std",
  disp.v.ratio = TRUE,
  m.threshold = 0.1
)

unadjusted_balance

# ---- chunk 6 ----
# Visualize absolute standardized differences against the 0.1 threshold.
love.plot(
  m_out0,
  stats = "mean.diffs",
  abs = TRUE,
  binary = "std",
  thresholds = c(m = 0.1),
  var.order = "unadjusted"
)

# ---- chunk 7 ----
# Fit exact matching on a reduced discrete covariate set.
m_exact <- matchit(
  treat ~ race + married + nodegree + educ,
  data = dat,
  method = "exact",
  estimand = "ATT"
)

matched_exact <- match.data(m_exact)

# Report sample retention and subclass count after exact matching.
exact_retention <- tibble(
  metric = c(
    "Treated units in full sample",
    "Treated units retained",
    "Control units in full sample",
    "Control units retained",
    "Matched subclasses"
  ),
  value = c(
    sum(dat$treat == 1),
    sum(matched_exact$treat == 1),
    sum(dat$treat == 0),
    sum(matched_exact$treat == 0),
    n_distinct(matched_exact$subclass)
  )
)

exact_retention

# ---- chunk 8 ----
# Full MatchIt diagnostic for exact matching.
summary(m_exact, un = TRUE)

# ---- chunk 9 ----
# Evaluate exact-match balance, including omitted continuous diagnostics.
exact_balance <- bal.tab(
  m_exact,
  data = dat,
  un = TRUE,
  binary = "std",
  disp.v.ratio = TRUE,
  m.threshold = 0.1,
  addl = ~ age + re74 + re75
)

exact_balance

# ---- chunk 10 ----
# Plot exact-match imbalance before and after adjustment.
love.plot(
  m_exact,
  data = dat,
  stats = "mean.diffs",
  abs = TRUE,
  binary = "std",
  thresholds = c(m = 0.1),
  var.order = "unadjusted",
  addl = ~ age + re74 + re75
)

# ---- chunk 11 ----
# Estimate the ATT using match weights from the exact-matched sample.
fit_exact <- lm(outcome ~ treat, data = matched_exact, weights = weights)

# Extract and format the treatment effect for the summary table.
exact_effect <- {
  exact_coef <- coef(summary(fit_exact))["treat", ]
  tibble(
    method = "Exact matching",
    estimate = unname(exact_coef["Estimate"]),
    std_error = unname(exact_coef["Std. Error"]),
    p_value = unname(exact_coef["Pr(>|t|)"])
  )
} |>
  mutate(across(c(estimate, std_error, p_value), ~ round(.x, 3)))

exact_effect

# ---- chunk 12 ----
# Baseline CEM using MatchIt's default coarsening rules.
m_cem_default <- matchit(
  treat ~ age + educ + race + married + nodegree + re74 + re75,
  data = dat,
  method = "cem",
  estimand = "ATT"
)

# Materialize the retained matched sample for summary counts.
matched_cem_default <- match.data(m_cem_default)

# Custom coarsening that relaxes the default enough to retain more treated units.
cem_cutpoints <- list(
  age = "q5",
  educ = 4,
  re74 = "q4",
  re75 = "q4"
)

# Refit CEM with analyst-specified bins for key numeric covariates.
m_cem <- matchit(
  treat ~ age + educ + race + married + nodegree + re74 + re75,
  data = dat,
  method = "cem",
  estimand = "ATT",
  cutpoints = cem_cutpoints
)

# Extract the final CEM-adjusted sample used later for estimation.
matched_cem <- match.data(m_cem)

# Compute balance diagnostics for the default and custom specifications.
cem_default_balance <- bal.tab(
  m_cem_default,
  un = TRUE,
  binary = "std",
  disp.v.ratio = TRUE,
  m.threshold = 0.1
)

cem_balance <- bal.tab(
  m_cem,
  un = TRUE,
  binary = "std",
  disp.v.ratio = TRUE,
  m.threshold = 0.1
)

# Put retention and worst adjusted imbalance side by side for comparison.
cem_comparison <- tibble(
  specification = c("Default CEM", "Documented custom cutpoints"),
  treated_retained = c(
    sum(matched_cem_default$treat == 1),
    sum(matched_cem$treat == 1)
  ),
  control_retained = c(
    sum(matched_cem_default$treat == 0),
    sum(matched_cem$treat == 0)
  ),
  matched_subclasses = c(
    n_distinct(matched_cem_default$subclass),
    n_distinct(matched_cem$subclass)
  ),
  max_abs_adjusted_smd = c(
    max(abs(cem_default_balance$Balance$Diff.Adj), na.rm = TRUE),
    max(abs(cem_balance$Balance$Diff.Adj), na.rm = TRUE)
  )
) |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))

cem_comparison

# ---- chunk 13 ----
# Build plotting data that separates retained and unmatched units by design.
cem_retention_plot_data <- bind_rows(
  tibble(
    specification = "Default CEM",
    group = "Treated",
    status = c("Retained", "Unmatched"),
    n = c(
      sum(matched_cem_default$treat == 1),
      sum(dat$treat == 1) - sum(matched_cem_default$treat == 1)
    )
  ),
  tibble(
    specification = "Default CEM",
    group = "Control",
    status = c("Retained", "Unmatched"),
    n = c(
      sum(matched_cem_default$treat == 0),
      sum(dat$treat == 0) - sum(matched_cem_default$treat == 0)
    )
  ),
  tibble(
    specification = "Documented custom cutpoints",
    group = "Treated",
    status = c("Retained", "Unmatched"),
    n = c(
      sum(matched_cem$treat == 1),
      sum(dat$treat == 1) - sum(matched_cem$treat == 1)
    )
  ),
  tibble(
    specification = "Documented custom cutpoints",
    group = "Control",
    status = c("Retained", "Unmatched"),
    n = c(
      sum(matched_cem$treat == 0),
      sum(dat$treat == 0) - sum(matched_cem$treat == 0)
    )
  )
)

# Visualize the retention tradeoff for treated and control units.
ggplot(cem_retention_plot_data, aes(x = specification, y = n, fill = status)) +
  geom_col() +
  facet_wrap(~ group) +
  labs(
    x = NULL,
    y = "Number of units",
    fill = NULL
  )

# ---- chunk 14 ----
# Full MatchIt summary for the default CEM specification.
summary(m_cem_default, un = TRUE)

# ---- chunk 15 ----
# Full MatchIt summary for the custom CEM specification.
summary(m_cem, un = TRUE)

# ---- chunk 16 ----
# Plot absolute standardized mean differences against the 0.1 threshold.
plot(summary(m_cem, un = TRUE), abs = TRUE, threshold = 0.1)

# ---- chunk 17 ----
# Compare unmatched and matched density overlays for key continuous covariates.
plot(
  m_cem,
  type = "density",
  interactive = FALSE,
  which.xs = c("age", "educ", "re74", "re75")
)

# ---- chunk 18 ----
# Compare unmatched and matched empirical CDFs for the same covariates.
plot(
  m_cem,
  type = "ecdf",
  interactive = FALSE,
  which.xs = c("age", "educ", "re74", "re75")
)

# ---- chunk 19 ----
# Compact cobalt balance table for the final custom CEM design.
cem_balance

# ---- chunk 20 ----
# Estimate the ATT in the matched sample using the CEM weights.
fit_cem <- lm(outcome ~ treat, data = matched_cem, weights = weights)

# Pull the treatment coefficient into a compact reporting table.
cem_effect <- {
  cem_coef <- coef(summary(fit_cem))["treat", ]
  tibble(
    method = "Coarsened exact matching",
    estimate = unname(cem_coef["Estimate"]),
    std_error = unname(cem_coef["Std. Error"]),
    p_value = unname(cem_coef["Pr(>|t|)"])
  )
} |>
  mutate(across(c(estimate, std_error, p_value), ~ round(.x, 3)))

cem_effect

# ---- chunk 21 ----
# Compare default entropy balancing against a tuned second-moment variant.
w_ebal_default <- weightit(
  treat ~ age + educ + race + married + nodegree + re74 + re75,
  data = dat,
  method = "ebal",
  estimand = "ATT"
)

w_ebal_moments <- weightit(
  treat ~ age + educ + race + married + nodegree + re74 + re75,
  data = dat,
  method = "ebal",
  estimand = "ATT",
  moments = c(age = 2, re74 = 2, re75 = 2)
)

# Cache model summaries used for ESS and weight diagnostics.
ebal_default_summary <- summary(w_ebal_default)
ebal_moments_summary <- summary(w_ebal_moments)

# Check mean and selected squared-term balance under each specification.
ebal_default_tuning_balance <- bal.tab(
  w_ebal_default,
  un = TRUE,
  binary = "std",
  addl = ~ I(age^2) + I(re74^2) + I(re75^2)
)

ebal_moments_tuning_balance <- bal.tab(
  w_ebal_moments,
  un = TRUE,
  binary = "std",
  addl = ~ I(age^2) + I(re74^2) + I(re75^2)
)

# Define the squared terms tracked in the tuning comparison table.
second_moment_terms <- c("I(age^2)", "I(re74^2)", "I(re75^2)")

# Summarize the balance-versus-information tradeoff across specifications.
ebal_tuning_comparison <- tibble(
  specification = c(
    "Default means only",
    "Tuned squares for age and prior earnings"
  ),
  control_ess = c(
    ebal_default_summary$effective.sample.size["Weighted", "Control"],
    ebal_moments_summary$effective.sample.size["Weighted", "Control"]
  ),
  max_control_weight = c(
    max(w_ebal_default$weights[dat$treat == 0]),
    max(w_ebal_moments$weights[dat$treat == 0])
  ),
  max_abs_adj_smd_means = c(
    max(abs(ebal_default_tuning_balance$Balance[setdiff(rownames(ebal_default_tuning_balance$Balance), second_moment_terms), "Diff.Adj"]), na.rm = TRUE),
    max(abs(ebal_moments_tuning_balance$Balance[setdiff(rownames(ebal_moments_tuning_balance$Balance), second_moment_terms), "Diff.Adj"]), na.rm = TRUE)
  ),
  max_abs_adj_smd_selected_squares = c(
    max(abs(ebal_default_tuning_balance$Balance[second_moment_terms, "Diff.Adj"]), na.rm = TRUE),
    max(abs(ebal_moments_tuning_balance$Balance[second_moment_terms, "Diff.Adj"]), na.rm = TRUE)
  )
) |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))

ebal_tuning_comparison

# ---- chunk 22 ----
# Set the default entropy-balancing design as the final weighting specification.
w_ebal <- w_ebal_default

ebal_summary <- ebal_default_summary

# Attach analysis weights to the working dataset for diagnostics.
dat_ebal <- dat |>
  mutate(ebal_weight = w_ebal$weights)

# Report retained sample sizes, ESS, and weight dispersion indicators.
ebal_weight_diagnostics <- tibble(
  metric = c(
    "Treated units",
    "Control units",
    "Treated effective sample size",
    "Control effective sample size",
    "Maximum control weight",
    "Control coefficient of variation"
  ),
  value = c(
    sum(dat$treat == 1),
    sum(dat$treat == 0),
    ebal_summary$effective.sample.size["Weighted", "Treated"],
    ebal_summary$effective.sample.size["Weighted", "Control"],
    max(dat_ebal$ebal_weight[dat_ebal$treat == 0]),
    unname(ebal_summary$coef.of.var["control"])
  )
) |>
  mutate(value = round(value, 3))

ebal_weight_diagnostics

# ---- chunk 23 ----
# Print the WeightIt summary for the retained entropy-balancing design.
ebal_summary

# ---- chunk 24 ----
# Generate compact post-weighting balance diagnostics.
ebal_balance <- bal.tab(
  w_ebal,
  un = TRUE,
  binary = "std",
  disp.v.ratio = TRUE,
  m.threshold = 0.1
)

ebal_balance

# ---- chunk 25 ----
# Plot weighted absolute standardized differences after entropy balancing.
love.plot(
  w_ebal,
  stats = "mean.diffs",
  abs = TRUE,
  binary = "std",
  thresholds = c(m = 0.1),
  var.order = "unadjusted"
)

# ---- chunk 26 ----
# Inspect the weight distribution and implied information concentration.
plot(ebal_summary)

# ---- chunk 27 ----
# Fit ATT outcome model with variance estimation that accounts for weight fitting.
fit_ebal <- lm_weightit(
  outcome ~ treat,
  data = dat,
  weightit = w_ebal
)

# Extract and format the entropy-balancing treatment effect.
ebal_effect <- {
  ebal_coef <- coef(summary(fit_ebal))["treat", ]
  tibble(
    method = "Entropy balancing",
    estimate = unname(ebal_coef["Estimate"]),
    std_error = unname(ebal_coef["Std. Error"]),
    p_value = unname(ebal_coef[4])
  )
} |>
  mutate(across(c(estimate, std_error, p_value), ~ round(.x, 3)))

ebal_effect

# ---- chunk 28 ----
# Fit several plausible CEM variants to stress-test the chosen cutpoints.
fit_cem_spec <- function(label, cutpoints = NULL) {
  cem_args <- c(
    list(
      formula = treat ~ age + educ + race + married + nodegree + re74 + re75,
      data = dat,
      method = "cem",
      estimand = "ATT"
    ),
    if (is.null(cutpoints)) list() else list(cutpoints = cutpoints)
  )

  cem_obj <- do.call(matchit, cem_args)
  cem_data <- match.data(cem_obj)
  cem_bal <- bal.tab(
    cem_obj,
    un = TRUE,
    binary = "std",
    m.threshold = 0.1
  )
  cem_fit <- lm(outcome ~ treat, data = cem_data, weights = weights)

  tibble(
    specification = label,
    treated_retained = sum(cem_data$treat == 1),
    control_retained = sum(cem_data$treat == 0),
    treated_share = sum(cem_data$treat == 1) / sum(dat$treat == 1),
    max_abs_adjusted_smd = max(abs(cem_bal$Balance$Diff.Adj), na.rm = TRUE),
    att = unname(coef(summary(cem_fit))["treat", "Estimate"])
  )
}

cem_robustness <- bind_rows(
  fit_cem_spec("Default MatchIt coarsening"),
  fit_cem_spec("Main report cutpoints", cem_cutpoints),
  fit_cem_spec(
    "Looser q4/q3 bins",
    list(age = "q4", educ = 3, re74 = "q4", re75 = "q4")
  ),
  fit_cem_spec(
    "Sturges-rule bins",
    list(age = "sturges", educ = 4, re74 = "sturges", re75 = "sturges")
  )
) |>
  mutate(
    treated_share = round(treated_share, 3),
    max_abs_adjusted_smd = round(max_abs_adjusted_smd, 3),
    att = round(att, 3)
  )

cem_robustness

# ---- chunk 29 ----
# Visualize how alternative cutpoints trade retained treated share against balance.
ggplot(
  cem_robustness,
  aes(x = treated_share, y = max_abs_adjusted_smd, label = specification)
) +
  geom_hline(yintercept = 0.1, linetype = "dashed") +
  geom_point(size = 2.8) +
  geom_text(nudge_y = 0.01, check_overlap = TRUE, size = 3) +
  labs(
    x = "Retained treated share",
    y = "Maximum absolute adjusted SMD"
  ) +
  coord_cartesian(ylim = c(0, max(cem_robustness$max_abs_adjusted_smd) + 0.03))

# ---- chunk 30 ----
# Compare entropy-balancing designs with progressively tighter moment constraints.
fit_ebal_spec <- function(label, extra_args = list()) {
  ebal_args <- c(
    list(
      formula = treat ~ age + educ + race + married + nodegree + re74 + re75,
      data = dat,
      method = "ebal",
      estimand = "ATT"
    ),
    extra_args
  )

  ebal_obj <- do.call(weightit, ebal_args)
  ebal_sum <- summary(ebal_obj)
  ebal_bal <- bal.tab(
    ebal_obj,
    un = TRUE,
    binary = "std",
    addl = ~ I(age^2) + I(educ^2) + I(re74^2) + I(re75^2)
  )
  ebal_fit <- lm_weightit(outcome ~ treat, data = dat, weightit = ebal_obj)
  squared_terms <- c("I(age^2)", "I(educ^2)", "I(re74^2)", "I(re75^2)")
  mean_terms <- setdiff(rownames(ebal_bal$Balance), squared_terms)

  tibble(
    specification = label,
    control_ess = ebal_sum$effective.sample.size["Weighted", "Control"],
    max_control_weight = max(ebal_obj$weights[dat$treat == 0]),
    max_abs_adjusted_smd_means = max(abs(ebal_bal$Balance[mean_terms, "Diff.Adj"]), na.rm = TRUE),
    max_abs_adjusted_smd_squares = max(abs(ebal_bal$Balance[squared_terms, "Diff.Adj"]), na.rm = TRUE),
    att = unname(coef(summary(ebal_fit))["treat", "Estimate"])
  )
}

ebal_robustness <- bind_rows(
  fit_ebal_spec("Means only"),
  fit_ebal_spec(
    "Age and earnings squares",
    list(moments = c(age = 2, re74 = 2, re75 = 2))
  ),
  fit_ebal_spec(
    "All continuous squares",
    list(moments = c(age = 2, educ = 2, re74 = 2, re75 = 2))
  )
) |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))

ebal_robustness

# ---- chunk 31 ----
# Summarize how concentrated the control-side weighting becomes under entropy balancing.
control_weights <- sort(dat_ebal$ebal_weight[dat_ebal$treat == 0], decreasing = TRUE)
control_weight_share <- tibble(
  top_controls = c(1, 5, 10, 20),
  control_weight_share = sapply(
    top_controls,
    function(k) sum(control_weights[seq_len(k)]) / sum(control_weights)
  )
) |>
  mutate(control_weight_share = round(control_weight_share, 3))

control_weight_share

# ---- chunk 32 ----
# Stress-test the entropy-balancing estimate by trimming the largest control weights.
compute_ess <- function(weights) {
  sum(weights)^2 / sum(weights^2)
}

trim_caps <- c(
  "Original weights" = Inf,
  "Cap at 99th control percentile" = as.numeric(quantile(control_weights, 0.99)),
  "Cap at 95th control percentile" = as.numeric(quantile(control_weights, 0.95))
)

ebal_trim_sensitivity <- bind_rows(lapply(names(trim_caps), function(label) {
  trimmed_weights <- dat_ebal$ebal_weight

  if (is.finite(trim_caps[[label]])) {
    trimmed_weights[dat$treat == 0] <- pmin(
      trimmed_weights[dat$treat == 0],
      trim_caps[[label]]
    )
  }

  trim_balance <- bal.tab(
    treat ~ age + educ + race + married + nodegree + re74 + re75,
    data = dat,
    weights = trimmed_weights,
    method = "weighting",
    estimand = "ATT",
    un = TRUE,
    binary = "std"
  )
  trim_fit <- lm(outcome ~ treat, data = dat, weights = trimmed_weights)

  tibble(
    diagnostic = label,
    control_ess = compute_ess(trimmed_weights[dat$treat == 0]),
    max_control_weight = max(trimmed_weights[dat$treat == 0]),
    max_abs_adjusted_smd = max(abs(trim_balance$Balance$Diff.Adj), na.rm = TRUE),
    att = unname(coef(summary(trim_fit))["treat", "Estimate"])
  )
})) |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))

ebal_trim_sensitivity

# ---- chunk 33 ----
# Compare worst-case imbalance and threshold exceedances across all methods.
comparison_balance <- tibble(
  method = c(
    "Unadjusted sample",
    "Exact matching",
    "Coarsened exact matching",
    "Entropy balancing"
  ),
  max_abs_smd = c(
    max(abs(unadjusted_balance$Balance$Diff.Un), na.rm = TRUE),
    max(abs(exact_balance$Balance$Diff.Adj), na.rm = TRUE),
    max(abs(cem_balance$Balance$Diff.Adj), na.rm = TRUE),
    max(abs(ebal_balance$Balance$Diff.Adj), na.rm = TRUE)
  ),
  covariates_over_0_1 = c(
    sum(abs(unadjusted_balance$Balance$Diff.Un) > 0.1, na.rm = TRUE),
    sum(abs(exact_balance$Balance$Diff.Adj) > 0.1, na.rm = TRUE),
    sum(abs(cem_balance$Balance$Diff.Adj) > 0.1, na.rm = TRUE),
    sum(abs(ebal_balance$Balance$Diff.Adj) > 0.1, na.rm = TRUE)
  )
) |>
  mutate(max_abs_smd = round(max_abs_smd, 3))

comparison_balance

# ---- chunk 34 ----
# Compare retention and information remaining under each design.
comparison_information <- tibble(
  method = c(
    "Exact matching",
    "Coarsened exact matching",
    "Entropy balancing"
  ),
  treated_units_used = c(
    sum(matched_exact$treat == 1),
    sum(matched_cem$treat == 1),
    sum(dat$treat == 1)
  ),
  control_units_used = c(
    sum(matched_exact$treat == 0),
    sum(matched_cem$treat == 0),
    sum(dat$treat == 0)
  ),
  treated_share_of_full_sample = c(
    sum(matched_exact$treat == 1) / sum(dat$treat == 1),
    sum(matched_cem$treat == 1) / sum(dat$treat == 1),
    1
  ),
  control_share_of_full_sample = c(
    sum(matched_exact$treat == 0) / sum(dat$treat == 0),
    sum(matched_cem$treat == 0) / sum(dat$treat == 0),
    1
  ),
  control_effective_sample_size = c(
    NA_real_,
    NA_real_,
    ebal_summary$effective.sample.size["Weighted", "Control"]
  )
) |>
  mutate(
    treated_share_of_full_sample = round(treated_share_of_full_sample, 3),
    control_share_of_full_sample = round(control_share_of_full_sample, 3),
    control_effective_sample_size = round(control_effective_sample_size, 3)
  )

comparison_information

# ---- chunk 35 ----
# Helper to extract a consistent treatment-effect row from model summaries.
extract_treat_effect <- function(model, method) {
  coef_table <- coef(summary(model))
  # Robustly locate the p-value column across lm/lm_weightit summary formats.
  p_value_col <- grep("^Pr\\(", colnames(coef_table), value = TRUE)

  if (length(p_value_col) == 0) {
    p_value_col <- tail(colnames(coef_table), 1)
  } else {
    p_value_col <- p_value_col[1]
  }

  treat_row <- coef_table["treat", ]

  # Return one standardized row for downstream comparison tables.
  tibble(
    method = method,
    estimate = unname(treat_row["Estimate"]),
    std_error = unname(treat_row["Std. Error"]),
    conf_low = unname(treat_row["Estimate"] - 1.96 * treat_row["Std. Error"]),
    conf_high = unname(treat_row["Estimate"] + 1.96 * treat_row["Std. Error"]),
    p_value = unname(treat_row[p_value_col])
  )
}

# Bind method-specific effect rows and append design-context metadata.
treatment_effect_summary <- bind_rows(
  extract_treat_effect(benchmark_fit, "Experimental benchmark (NSW RCT)"),
  extract_treat_effect(fit_exact, "Exact matching"),
  extract_treat_effect(fit_cem, "Coarsened exact matching"),
  extract_treat_effect(fit_ebal, "Entropy balancing")
) |>
  mutate(
    treated_units_used = c(
      sum(benchmark_dat$treat == 1),
      sum(matched_exact$treat == 1),
      sum(matched_cem$treat == 1),
      sum(dat$treat == 1)
    ),
    control_basis = c(
      paste(sum(benchmark_dat$treat == 0), "NSW randomized controls"),
      paste(sum(matched_exact$treat == 0), "matched controls"),
      paste(sum(matched_cem$treat == 0), "matched controls"),
      paste(
        sum(dat$treat == 0),
        "controls; ESS",
        round(ebal_summary$effective.sample.size["Weighted", "Control"], 3)
      )
    ),
    design_note = c(
      "Estimated on causaldata::nsw_mixtape only",
      "Residual imbalance remains on re74",
      "Best balance among matched samples, but strongest pruning",
      "Preserves all treated units, but relies on concentrated control weights"
    ),
    gap_vs_benchmark = estimate - experimental_estimate
  ) |>
  mutate(across(c(estimate, std_error, conf_low, conf_high, p_value, gap_vs_benchmark), ~ round(.x, 3)))

treatment_effect_summary |>
  rename(
    `Std. error` = std_error,
    `95% CI low` = conf_low,
    `95% CI high` = conf_high,
    `P-value` = p_value,
    `Treated units used` = treated_units_used,
    `Control basis` = control_basis,
    `Design note` = design_note,
    `Gap vs benchmark` = gap_vs_benchmark
  ) |>
  knitr::kable()

# ---- chunk 36 ----
# Capture the R session state for reproducibility.
sessionInfo()
