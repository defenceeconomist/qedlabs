#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(fixest)
  library(bacondecomp)
  library(did)
})

required_packages <- c("wooldridge", "causaldata", "HonestDiD")
missing_packages <- required_packages[!vapply(
  required_packages,
  requireNamespace,
  logical(1),
  quietly = TRUE
)]
if (length(missing_packages) > 0) {
  stop(
    "Install required packages before generating DiD slide assets: ",
    paste(missing_packages, collapse = ", ")
  )
}

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- if (length(script_arg)) {
  normalizePath(sub("^--file=", "", script_arg[[1]]))
} else {
  normalizePath("docs/scripts/generate_did_slide_assets.R")
}
asset_dir <- file.path(dirname(dirname(script_path)), "slides", "assets")
dir.create(asset_dir, recursive = TRUE, showWarnings = FALSE)

palette <- c(
  blue = "#24527a",
  orange = "#bf6b21",
  red = "#a23b3b",
  purple = "#7a5195",
  green = "#0f6a57",
  gold = "#c59b3d",
  grey = "#5f6368",
  light_grey = "#d8ddd9",
  dark = "#303030"
)

workshop_theme <- theme_minimal(base_size = 16) +
  theme(
    plot.title = element_text(face = "bold", colour = palette[["dark"]]),
    plot.subtitle = element_text(colour = palette[["grey"]]),
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.margin = margin(12, 16, 12, 12)
  )

save_asset <- function(plot, filename, width = 11, height = 6) {
  output_path <- file.path(asset_dir, filename)
  ggsave(
    filename = output_path,
    plot = plot,
    width = width,
    height = height,
    dpi = 200,
    bg = "white"
  )
  stopifnot(file.exists(output_path), file.info(output_path)$size > 10000)
}

# Canonical 2x2 DiD: Kentucky workers' compensation -------------------------

data("injury", package = "wooldridge")

injury_ky <- wooldridge::injury |>
  filter(ky == 1) |>
  transmute(
    log_duration = ldurat,
    after_change = afchnge,
    high_earner = highearn
  )

cell_means <- injury_ky |>
  group_by(after_change, high_earner) |>
  summarise(
    mean_log_duration = mean(log_duration),
    standard_error = sd(log_duration) / sqrt(n()),
    claims = n(),
    .groups = "drop"
  ) |>
  mutate(
    period = factor(
      after_change,
      levels = c(0, 1),
      labels = c("Before 1980", "After 1980")
    ),
    group = factor(
      high_earner,
      levels = c(0, 1),
      labels = c("Low earners", "High earners")
    ),
    lower_95 = mean_log_duration - 1.96 * standard_error,
    upper_95 = mean_log_duration + 1.96 * standard_error
  )

cell_value <- function(after_value, high_value) {
  cell_means |>
    filter(
      after_change == after_value,
      high_earner == high_value
    ) |>
    pull(mean_log_duration)
}

treated_before <- cell_value(0, 1)
treated_after <- cell_value(1, 1)
control_before <- cell_value(0, 0)
control_after <- cell_value(1, 0)
control_change <- control_after - control_before
did_manual <- (treated_after - treated_before) - control_change

kentucky_fit <- feols(
  log_duration ~ high_earner * after_change,
  data = injury_ky,
  vcov = "hetero"
)
did_regression <- coef(kentucky_fit)[["high_earner:after_change"]]

stopifnot(
  nrow(injury_ky) == 5626L,
  nrow(cell_means) == 4L,
  all(cell_means$claims > 0),
  abs(did_manual - did_regression) < 1e-10
)

four_cells_plot <- ggplot(
  cell_means,
  aes(period, mean_log_duration, colour = group, group = group)
) +
  geom_line(linewidth = 1.2) +
  geom_pointrange(
    aes(ymin = lower_95, ymax = upper_95),
    linewidth = 0.8,
    size = 0.9
  ) +
  scale_colour_manual(values = c(
    "Low earners" = palette[["orange"]],
    "High earners" = palette[["blue"]]
  )) +
  labs(
    title = "Four observed means produce the canonical DiD contrast",
    subtitle = sprintf(
      "Interaction estimate: %.3f log points; exact change: %.1f%%",
      did_manual,
      100 * (exp(did_manual) - 1)
    ),
    x = NULL,
    y = "Mean log benefit duration",
    colour = NULL
  ) +
  workshop_theme
save_asset(four_cells_plot, "did-kentucky-four-cells.png")

counterfactual_after <- treated_before + control_change
counterfactual_data <- data.frame(
  period = factor(
    c("Before 1980", "After 1980"),
    levels = c("Before 1980", "After 1980")
  ),
  mean_log_duration = c(treated_before, counterfactual_after)
)

counterfactual_plot <- ggplot() +
  geom_line(
    data = filter(cell_means, group == "Low earners"),
    aes(period, mean_log_duration, group = group, colour = "Observed low earners"),
    linewidth = 1.05
  ) +
  geom_point(
    data = filter(cell_means, group == "Low earners"),
    aes(period, mean_log_duration, colour = "Observed low earners"),
    size = 3
  ) +
  geom_line(
    data = filter(cell_means, group == "High earners"),
    aes(period, mean_log_duration, group = group, colour = "Observed high earners"),
    linewidth = 1.05
  ) +
  geom_point(
    data = filter(cell_means, group == "High earners"),
    aes(period, mean_log_duration, colour = "Observed high earners"),
    size = 3
  ) +
  geom_line(
    data = counterfactual_data,
    aes(period, mean_log_duration, group = 1, colour = "High-earner counterfactual"),
    linewidth = 1.05,
    linetype = "dashed"
  ) +
  geom_point(
    data = counterfactual_data[2, ],
    aes(period, mean_log_duration, colour = "High-earner counterfactual"),
    size = 3,
    shape = 1,
    stroke = 1.2
  ) +
  annotate(
    "segment",
    x = 2,
    xend = 2,
    y = counterfactual_after,
    yend = treated_after,
    arrow = arrow(length = grid::unit(0.14, "inches")),
    colour = palette[["red"]],
    linewidth = 1
  ) +
  annotate(
    "text",
    x = 2,
    y = mean(c(counterfactual_after, treated_after)),
    label = "DiD",
    hjust = -0.35,
    colour = palette[["red"]],
    fontface = "bold"
  ) +
  scale_colour_manual(values = c(
    "Observed low earners" = palette[["orange"]],
    "Observed high earners" = palette[["blue"]],
    "High-earner counterfactual" = palette[["purple"]]
  )) +
  scale_y_continuous(expand = expansion(mult = c(0.08, 0.16))) +
  coord_cartesian(clip = "off") +
  labs(
    title = "Parallel trends supplies the missing high-earner outcome",
    subtitle = "The low-earner change is added to the high-earner baseline",
    x = NULL,
    y = "Mean log benefit duration",
    colour = NULL
  ) +
  workshop_theme
save_asset(counterfactual_plot, "did-kentucky-counterfactual.png")

# Staggered adoption: castle-doctrine panel -------------------------------

castle_panel <- causaldata::castle |>
  select(sid, year, post, l_homicide) |>
  arrange(sid, year) |>
  group_by(sid) |>
  mutate(
    first_treat = if (any(post == 1)) min(year[post == 1]) else 0L,
    event_time = if_else(first_treat == 0L, -1000L, year - first_treat)
  ) |>
  ungroup()

state_order <- castle_panel |>
  distinct(sid, first_treat) |>
  arrange(first_treat == 0, first_treat, sid) |>
  mutate(state_rank = row_number())

castle_plot_data <- castle_panel |>
  left_join(select(state_order, sid, state_rank), by = "sid") |>
  mutate(status = if_else(post == 1, "Treated", "Untreated"))

stopifnot(
  !anyDuplicated(castle_panel[c("sid", "year")]),
  n_distinct(castle_panel$sid) == 50L,
  !any(castle_panel |>
    group_by(sid) |>
    summarise(reversal = any(diff(post) < 0), .groups = "drop") |>
    pull(reversal)),
  any(castle_panel$first_treat == 0L),
  n_distinct(castle_panel$first_treat[castle_panel$first_treat > 0]) > 1L
)

adoption_plot <- ggplot(
  castle_plot_data,
  aes(year, state_rank, fill = status)
) +
  geom_tile(colour = "white", linewidth = 0.25) +
  scale_fill_manual(values = c(
    "Untreated" = "#e7e0d5",
    "Treated" = palette[["red"]]
  )) +
  scale_x_continuous(breaks = sort(unique(castle_panel$year))) +
  labs(
    title = "Castle-doctrine adoption creates multiple treatment cohorts",
    subtitle = "Each row is one state; never-treated states remain untreated throughout",
    x = NULL,
    y = "States ordered by first treatment year",
    fill = NULL
  ) +
  workshop_theme +
  theme(panel.grid = element_blank(), axis.text.y = element_blank())
save_asset(adoption_plot, "did-castle-adoption.png", width = 11, height = 6.2)

support_table <- castle_panel |>
  distinct(sid, year, first_treat) |>
  group_by(year) |>
  summarise(
    never_treated = sum(first_treat == 0L),
    not_yet_treated = sum(first_treat > year),
    already_treated = sum(first_treat > 0L & first_treat <= year),
    .groups = "drop"
  )

support_long <- bind_rows(
  transmute(support_table, year, status = "Never treated", states = never_treated),
  transmute(support_table, year, status = "Not yet treated", states = not_yet_treated),
  transmute(support_table, year, status = "Already treated", states = already_treated)
)
support_long$status <- factor(
  support_long$status,
  levels = c("Never treated", "Not yet treated", "Already treated")
)

stopifnot(
  all(rowSums(support_table[c(
    "never_treated",
    "not_yet_treated",
    "already_treated"
  )]) == n_distinct(castle_panel$sid))
)

support_plot <- ggplot(
  support_long,
  aes(year, states, colour = status)
) +
  geom_line(linewidth = 1.15) +
  geom_point(size = 2.4) +
  scale_colour_manual(values = c(
    "Never treated" = palette[["green"]],
    "Not yet treated" = palette[["gold"]],
    "Already treated" = palette[["red"]]
  )) +
  scale_x_continuous(breaks = sort(unique(castle_panel$year))) +
  scale_y_continuous(limits = c(0, 50), breaks = seq(0, 50, by = 10)) +
  labs(
    title = "Untreated comparison support shrinks as adoption spreads",
    subtitle = "Never-treated states remain available; not-yet-treated states disappear from the control pool",
    x = NULL,
    y = "Number of states",
    colour = NULL
  ) +
  workshop_theme
save_asset(support_plot, "did-castle-support.png")

twfe_fit <- feols(
  l_homicide ~ post | sid + year,
  data = castle_panel,
  vcov = ~ sid
)

bacon_parts <- bacondecomp::bacon(
  l_homicide ~ post,
  data = as.data.frame(castle_panel),
  id_var = "sid",
  time_var = "year",
  quietly = TRUE
)
bacon_reconstruction <- sum(bacon_parts$estimate * bacon_parts$weight)

stopifnot(
  abs(sum(bacon_parts$weight) - 1) < 1e-8,
  abs(coef(twfe_fit)[["post"]] - bacon_reconstruction) < 1e-8,
  all(c(
    "Earlier vs Later Treated",
    "Later vs Earlier Treated",
    "Treated vs Untreated"
  ) %in% bacon_parts$type)
)

bacon_plot <- ggplot(
  bacon_parts,
  aes(estimate, weight, colour = type)
) +
  geom_point(alpha = 0.9, size = 3) +
  geom_vline(
    xintercept = coef(twfe_fit)[["post"]],
    linetype = "dashed",
    colour = palette[["dark"]]
  ) +
  scale_colour_manual(values = c(
    "Earlier vs Later Treated" = palette[["gold"]],
    "Later vs Earlier Treated" = palette[["red"]],
    "Treated vs Untreated" = palette[["green"]]
  )) +
  labs(
    title = "The Bacon decomposition exposes every 2×2 comparison",
    subtitle = sprintf(
      "Weighted average and static TWFE both equal %.3f log points",
      bacon_reconstruction
    ),
    x = "2×2 DiD estimate",
    y = "TWFE weight",
    colour = NULL
  ) +
  workshop_theme
save_asset(bacon_plot, "did-bacon-decomposition.png", width = 11.5, height = 6.2)

conventional_event_fit <- feols(
  l_homicide ~ i(event_time, ref = c(-1000, -1)) | sid + year,
  data = castle_panel,
  vcov = ~ sid
)

sun_abraham_castle_fit <- feols(
  l_homicide ~ sunab(first_treat, year, ref.p = -1) | sid + year,
  data = castle_panel,
  vcov = ~ sid
)

extract_event_terms <- function(model, estimator) {
  estimates <- coef(model)
  standard_errors <- se(model)
  data.frame(
    estimator = estimator,
    event_time = as.integer(sub(".*::", "", names(estimates))),
    estimate = unname(estimates),
    standard_error = unname(standard_errors)
  ) |>
    mutate(
      lower_95 = estimate - 1.96 * standard_error,
      upper_95 = estimate + 1.96 * standard_error
    ) |>
    filter(event_time >= -5, event_time <= 4)
}

castle_event_comparison <- bind_rows(
  extract_event_terms(conventional_event_fit, "Conventional TWFE"),
  extract_event_terms(sun_abraham_castle_fit, "Sun–Abraham")
)

stopifnot(
  all(c("Conventional TWFE", "Sun–Abraham") %in%
    castle_event_comparison$estimator),
  any(castle_event_comparison$event_time < 0),
  any(castle_event_comparison$event_time >= 0),
  all(is.finite(castle_event_comparison$estimate))
)

castle_event_plot <- ggplot(
  castle_event_comparison,
  aes(event_time, estimate, colour = estimator)
) +
  geom_hline(yintercept = 0, colour = palette[["grey"]]) +
  geom_vline(xintercept = -1, linetype = "dashed", colour = palette[["grey"]]) +
  geom_errorbar(
    aes(ymin = lower_95, ymax = upper_95),
    width = 0.12,
    position = position_dodge(width = 0.18),
    alpha = 0.7
  ) +
  geom_line(position = position_dodge(width = 0.18), linewidth = 0.85) +
  geom_point(position = position_dodge(width = 0.18), size = 2.5) +
  scale_colour_manual(values = c(
    "Conventional TWFE" = palette[["red"]],
    "Sun–Abraham" = palette[["blue"]]
  )) +
  scale_x_continuous(breaks = -5:4) +
  labs(
    title = "Estimator choice changes the staggered event-study profile",
    subtitle = "Both use event time -1 as the reference; their implicit comparisons differ",
    x = "Years relative to adoption",
    y = "Estimated log-homicide effect",
    colour = NULL
  ) +
  workshop_theme
save_asset(castle_event_plot, "did-castle-event-study.png", width = 11.5, height = 6.3)

# Modern multi-period DiD: mpdta ------------------------------------------

data("mpdta", package = "did")
set.seed(20260809)

att_never <- att_gt(
  yname = "lemp",
  tname = "year",
  idname = "countyreal",
  gname = "first.treat",
  xformla = ~ 1,
  data = mpdta,
  control_group = "nevertreated",
  anticipation = 0,
  base_period = "universal",
  est_method = "dr",
  bstrap = TRUE,
  biters = 499,
  cband = TRUE,
  clustervars = "countyreal",
  print_details = FALSE
)

group_time_data <- data.frame(
  group = att_never$group,
  year = att_never$t,
  att = att_never$att,
  standard_error = att_never$se
) |>
  filter(is.finite(att), group <= year)

stopifnot(
  nrow(mpdta) == 2500L,
  n_distinct(mpdta$countyreal) == 500L,
  inherits(att_never, "MP"),
  nrow(group_time_data) > 0,
  any(group_time_data$att < 0)
)

group_time_plot <- ggplot(
  group_time_data,
  aes(factor(year), factor(group), fill = att)
) +
  geom_tile(colour = "white", linewidth = 1) +
  geom_text(aes(label = sprintf("%.3f", att)), size = 4.4) +
  scale_fill_gradient2(
    low = palette[["blue"]],
    mid = "white",
    high = palette[["red"]],
    midpoint = 0
  ) +
  labs(
    title = "Group-time ATT keeps cohort and calendar time visible",
    subtitle = "Each cell is ATT(g,t) using never-treated counties as controls",
    x = "Calendar year",
    y = "First treatment year",
    fill = "ATT"
  ) +
  workshop_theme +
  theme(panel.grid = element_blank())
save_asset(group_time_plot, "did-mpdta-group-time.png", width = 10.5, height = 5.8)

aggregate_dynamic <- aggte(att_never, type = "dynamic", na.rm = TRUE)

sun_abraham_mpdta_fit <- feols(
  lemp ~ sunab(first.treat, year, ref.p = -1) | countyreal + year,
  data = mpdta,
  vcov = ~ countyreal
)

callaway_terms <- data.frame(
  event_time = aggregate_dynamic$egt,
  estimate = aggregate_dynamic$att.egt,
  standard_error = aggregate_dynamic$se.egt,
  estimator = "Callaway–Sant'Anna"
)
sun_abraham_terms <- data.frame(
  event_time = as.integer(sub(".*::", "", names(coef(sun_abraham_mpdta_fit)))),
  estimate = unname(coef(sun_abraham_mpdta_fit)),
  standard_error = unname(se(sun_abraham_mpdta_fit)),
  estimator = "Sun–Abraham"
)

modern_event_comparison <- bind_rows(callaway_terms, sun_abraham_terms) |>
  filter(
    is.finite(estimate),
    is.finite(standard_error),
    event_time >= -4,
    event_time <= 3
  ) |>
  mutate(
    lower_95 = estimate - 1.96 * standard_error,
    upper_95 = estimate + 1.96 * standard_error
  )

stopifnot(
  all(c("Callaway–Sant'Anna", "Sun–Abraham") %in%
    modern_event_comparison$estimator),
  any(modern_event_comparison$event_time < 0),
  any(modern_event_comparison$event_time >= 0),
  all(is.finite(modern_event_comparison$estimate))
)

modern_event_plot <- ggplot(
  modern_event_comparison,
  aes(event_time, estimate, colour = estimator)
) +
  geom_hline(yintercept = 0, colour = palette[["grey"]]) +
  geom_vline(xintercept = -1, linetype = "dashed", colour = palette[["grey"]]) +
  geom_errorbar(
    aes(ymin = lower_95, ymax = upper_95),
    width = 0.12,
    position = position_dodge(width = 0.18),
    alpha = 0.7
  ) +
  geom_line(position = position_dodge(width = 0.18), linewidth = 0.85) +
  geom_point(position = position_dodge(width = 0.18), size = 2.5) +
  scale_colour_manual(values = c(
    "Callaway–Sant'Anna" = palette[["green"]],
    "Sun–Abraham" = palette[["purple"]]
  )) +
  scale_x_continuous(breaks = -4:3) +
  labs(
    title = "Modern estimators can differ without a coding error",
    subtitle = "Cohort weights, comparison groups, and support determine the aggregated path",
    x = "Periods relative to treatment",
    y = "Estimated effect on log teen employment",
    colour = NULL
  ) +
  workshop_theme
save_asset(modern_event_plot, "did-modern-event-comparison.png", width = 11.5, height = 6.3)

sensitivity_sample <- mpdta |>
  filter(first.treat %in% c(0, 2006)) |>
  mutate(treated_2006 = as.integer(first.treat == 2006))

cohort_event_fit <- feols(
  lemp ~ i(year, treated_2006, ref = 2005) | countyreal + year,
  data = sensitivity_sample,
  vcov = ~ countyreal
)

event_coefficients <- coef(cohort_event_fit)
event_covariance <- vcov(cohort_event_fit)
term_year <- as.integer(sub(
  "year::([0-9]+).*",
  "\\1",
  names(event_coefficients)
))
term_order <- order(term_year)
event_coefficients <- event_coefficients[term_order]
event_covariance <- event_covariance[term_order, term_order, drop = FALSE]
term_year <- term_year[term_order]

sensitivity_results <- HonestDiD::createSensitivityResults_relativeMagnitudes(
  betahat = event_coefficients,
  sigma = event_covariance,
  numPrePeriods = 2,
  numPostPeriods = 2,
  Mbarvec = seq(0.5, 2, by = 0.5),
  gridPoints = 100,
  seed = 20260809
)
original_interval <- HonestDiD::constructOriginalCS(
  betahat = event_coefficients,
  sigma = event_covariance,
  numPrePeriods = 2,
  numPostPeriods = 2
)

stopifnot(
  identical(term_year, c(2003L, 2004L, 2006L, 2007L)),
  nrow(sensitivity_results) == 4L,
  all(sensitivity_results$lb <= sensitivity_results$ub),
  nrow(original_interval) == 1L
)

sensitivity_plot_data <- bind_rows(
  data.frame(
    Mbar = 0,
    lb = as.numeric(original_interval$lb),
    ub = as.numeric(original_interval$ub),
    interval = "Original parallel-trends interval"
  ),
  transmute(
    sensitivity_results,
    Mbar,
    lb,
    ub,
    interval = "Robust interval"
  )
) |>
  mutate(midpoint = (lb + ub) / 2)

sensitivity_plot <- ggplot(
  sensitivity_plot_data,
  aes(Mbar, midpoint, colour = interval)
) +
  geom_hline(yintercept = 0, colour = palette[["grey"]]) +
  geom_errorbar(aes(ymin = lb, ymax = ub), width = 0.08, linewidth = 1) +
  geom_point(size = 3) +
  scale_colour_manual(values = c(
    "Original parallel-trends interval" = palette[["blue"]],
    "Robust interval" = palette[["red"]]
  )) +
  scale_x_continuous(breaks = seq(0, 2, by = 0.5)) +
  labs(
    title = "Sensitivity makes the tolerated trend violation explicit",
    subtitle = "2006 cohort versus never-treated counties; first post-treatment effect",
    x = "Allowed post/pre violation ratio (M-bar)",
    y = "Confidence interval",
    colour = NULL
  ) +
  workshop_theme
save_asset(sensitivity_plot, "did-honest-sensitivity.png", width = 10.5, height = 6)

message(
  "Wrote nine DiD slide assets to ",
  asset_dir,
  "; Kentucky DiD = ",
  round(did_manual, 6),
  "; castle TWFE = ",
  round(bacon_reconstruction, 6)
)
