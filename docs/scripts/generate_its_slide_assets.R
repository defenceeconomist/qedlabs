#!/usr/bin/env Rscript

# Generate deterministic teaching charts for the interrupted time series deck.

suppressPackageStartupMessages({
  library(ggplot2)
  library(nlme)
})

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- if (length(script_arg) == 1L) {
  normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)
} else {
  normalizePath("docs/scripts/generate_its_slide_assets.R", mustWork = TRUE)
}

output_dir <- file.path(dirname(dirname(script_path)), "slides", "assets")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

ink <- "#112620"
deep <- "#17372f"
accent <- "#c05a2a"
gold <- "#c59b3d"
blue <- "#24527a"
orange <- "#bf6b21"
soft <- "#f7f1e8"

deck_theme <- theme_minimal(base_size = 16) +
  theme(
    plot.background = element_rect(fill = soft, colour = NA),
    panel.background = element_rect(fill = soft, colour = NA),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "#d9d0c3", linewidth = 0.35),
    plot.title = element_text(colour = ink, face = "bold"),
    plot.subtitle = element_text(colour = "#4b615b"),
    axis.text = element_text(colour = ink),
    axis.title = element_text(colour = ink),
    legend.background = element_rect(fill = soft, colour = NA),
    legend.key = element_rect(fill = soft, colour = NA),
    legend.position = "bottom"
  )

save_plot <- function(filename, plot, width = 11, height = 5.5) {
  ggsave(
    filename = file.path(output_dir, filename),
    plot = plot,
    width = width,
    height = height,
    dpi = 180,
    bg = soft
  )
}

set.seed(20260730)

n_months <- 96L
interruption_time <- 61L

its_data <- data.frame(
  time = seq_len(n_months),
  date = seq(as.Date("2018-01-01"), by = "month", length.out = n_months)
)
its_data$intervention <- as.integer(its_data$time >= interruption_time)
its_data$time_after <- pmax(0L, its_data$time - interruption_time)
its_data$season_sin <- sin(2 * pi * its_data$time / 12)
its_data$season_cos <- cos(2 * pi * its_data$time / 12)
its_data$seasonal_component <-
  6 * its_data$season_sin + 2 * its_data$season_cos
its_data$ar1_error <- as.numeric(
  arima.sim(model = list(ar = 0.55), n = n_months, sd = 1)
)
its_data$admissions_rate <- 70 +
  0.08 * its_data$time -
  4 * its_data$intervention -
  0.10 * its_data$time_after +
  its_data$seasonal_component +
  its_data$ar1_error

policy_date <- its_data$date[interruption_time]

prepost_means <- aggregate(
  admissions_rate ~ intervention,
  data = its_data,
  FUN = mean
)
pre_mean <- prepost_means$admissions_rate[prepost_means$intervention == 0]
post_mean <- prepost_means$admissions_rate[prepost_means$intervention == 1]

prepost_plot <- ggplot(its_data, aes(date, admissions_rate)) +
  geom_line(colour = blue, linewidth = 0.65, alpha = 0.8) +
  geom_point(colour = blue, size = 1.35) +
  annotate(
    "segment",
    x = min(its_data$date),
    xend = policy_date - 31,
    y = pre_mean,
    yend = pre_mean,
    colour = gold,
    linewidth = 1.4
  ) +
  annotate(
    "segment",
    x = policy_date,
    xend = max(its_data$date),
    y = post_mean,
    yend = post_mean,
    colour = accent,
    linewidth = 1.4
  ) +
  geom_vline(xintercept = policy_date, linetype = "dashed", colour = accent) +
  annotate("text", x = as.Date("2020-07-01"), y = pre_mean + 2.2,
    label = "Pre-policy average", colour = deep, fontface = "bold") +
  annotate("text", x = as.Date("2024-07-01"), y = post_mean + 2.2,
    label = "Post-policy average", colour = deep, fontface = "bold") +
  labs(x = NULL, y = "Admissions per 100,000") +
  deck_theme

save_plot("its-prepost.png", prepost_plot)

its_formula <- admissions_rate ~
  time + intervention + time_after + season_sin + season_cos

ols_fit <- lm(its_formula, data = its_data)
gls_fit <- gls(
  its_formula,
  data = its_data,
  correlation = corAR1(form = ~ time),
  method = "REML"
)

counterfactual_data <- transform(its_data, intervention = 0L, time_after = 0L)
its_data$fitted_policy <- as.numeric(predict(gls_fit, newdata = its_data))
its_data$counterfactual <- as.numeric(
  predict(gls_fit, newdata = counterfactual_data)
)

trajectory_data <- rbind(
  data.frame(
    date = its_data$date,
    series = "Observed-policy trajectory",
    value = its_data$fitted_policy
  ),
  data.frame(
    date = its_data$date,
    series = "Estimated no-policy trajectory",
    value = its_data$counterfactual
  )
)

counterfactual_plot <- ggplot(its_data, aes(date, admissions_rate)) +
  geom_point(colour = "#4b615b", size = 1.1, alpha = 0.55) +
  geom_line(
    data = trajectory_data,
    aes(y = value, colour = series, linetype = series),
    linewidth = 1.05
  ) +
  geom_vline(xintercept = policy_date, linetype = "dashed", colour = accent) +
  scale_colour_manual(values = c(
    "Observed-policy trajectory" = blue,
    "Estimated no-policy trajectory" = orange
  )) +
  scale_linetype_manual(values = c(
    "Observed-policy trajectory" = "solid",
    "Estimated no-policy trajectory" = "longdash"
  )) +
  labs(x = NULL, y = "Admissions per 100,000", colour = NULL, linetype = NULL) +
  deck_theme

save_plot("its-counterfactual.png", counterfactual_plot)

shape_time <- 1:72
shape_interruption <- 37L
shape_indicator <- as.integer(shape_time >= shape_interruption)
shape_after <- pmax(0, shape_time - shape_interruption)
shape_baseline <- 50 + 0.05 * shape_time

shape_data <- rbind(
  data.frame(time = shape_time, shape = "Immediate", outcome =
    shape_baseline - 5 * shape_indicator),
  data.frame(time = shape_time, shape = "Gradual", outcome =
    shape_baseline - 0.22 * shape_after),
  data.frame(time = shape_time, shape = "Immediate + gradual", outcome =
    shape_baseline - 4 * shape_indicator - 0.14 * shape_after),
  data.frame(time = shape_time, shape = "Temporary", outcome =
    shape_baseline - 6 * exp(-shape_after / 6) * shape_indicator)
)
shape_data$shape <- factor(
  shape_data$shape,
  levels = c("Immediate", "Gradual", "Immediate + gradual", "Temporary")
)

effect_shapes_plot <- ggplot(shape_data, aes(time, outcome)) +
  geom_line(colour = blue, linewidth = 1) +
  geom_vline(xintercept = shape_interruption, linetype = "dashed", colour = accent) +
  facet_wrap(~ shape, nrow = 1) +
  labs(x = "Time", y = "Outcome") +
  deck_theme +
  theme(
    strip.text = element_text(face = "bold", colour = ink),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank()
  )

save_plot("its-effect-shapes.png", effect_shapes_plot, width = 12, height = 4.4)

effect_at_horizon <- function(h) {
  beta_hat <- coef(gls_fit)
  beta_vcov <- vcov(gls_fit)
  weights <- c(intervention = 1, time_after = h)
  relevant_vcov <- beta_vcov[names(weights), names(weights), drop = FALSE]
  estimate <- sum(weights * beta_hat[names(weights)])
  standard_error <- sqrt(
    as.numeric(t(weights) %*% relevant_vcov %*% weights)
  )
  data.frame(
    horizon = factor(
      paste0(h, ifelse(h == 0, " (immediate)", " months")),
      levels = c("0 (immediate)", "12 months", "24 months")
    ),
    estimate = estimate,
    lower = estimate - qnorm(0.975) * standard_error,
    upper = estimate + qnorm(0.975) * standard_error
  )
}

horizon_data <- do.call(rbind, lapply(c(0, 12, 24), effect_at_horizon))

horizon_plot <- ggplot(horizon_data, aes(horizon, estimate)) +
  geom_hline(yintercept = 0, colour = "#8d948f", linewidth = 0.5) +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.12,
    colour = deep, linewidth = 0.9) +
  geom_point(colour = accent, size = 4) +
  geom_text(aes(label = sprintf("%.1f", estimate)), vjust = -1.2,
    colour = ink, fontface = "bold", size = 5) +
  labs(x = NULL, y = "Estimated change in admissions per 100,000") +
  deck_theme

save_plot("its-horizon-effects.png", horizon_plot, width = 8.5, height = 5.2)

raw_plot <- ggplot(its_data, aes(date, admissions_rate)) +
  geom_line(colour = blue, linewidth = 0.7) +
  geom_point(colour = blue, size = 1.25) +
  geom_vline(xintercept = policy_date, linetype = "dashed", colour = accent) +
  annotate("text", x = policy_date + 120, y = max(its_data$admissions_rate) - 1,
    label = "Policy begins", hjust = 0, colour = accent, fontface = "bold") +
  labs(x = NULL, y = "Admissions per 100,000") +
  deck_theme

save_plot("its-raw-series.png", raw_plot)

seasonality_plot <- ggplot(its_data, aes(date)) +
  geom_line(aes(y = admissions_rate), colour = "#7b8782", linewidth = 0.55) +
  geom_line(aes(y = 72 + seasonal_component), colour = accent, linewidth = 1.05) +
  geom_vline(xintercept = policy_date, linetype = "dashed", colour = deep) +
  annotate("text", x = as.Date("2019-07-01"), y = 79,
    label = "Annual seasonal component", colour = accent, fontface = "bold") +
  labs(x = NULL, y = "Admissions per 100,000") +
  deck_theme

save_plot("its-seasonality.png", seasonality_plot)

png(
  file.path(output_dir, "its-residual-acf.png"),
  width = 1800,
  height = 820,
  res = 180,
  bg = soft
)
old_par <- par(
  mfrow = c(1, 2),
  mar = c(4.5, 4.5, 3.5, 1.5),
  bg = soft,
  fg = ink,
  col.axis = ink,
  col.lab = ink,
  col.main = ink,
  family = "sans"
)
acf(residuals(ols_fit), main = "OLS residuals", xlab = "Lag (months)", col = blue)
acf(
  residuals(gls_fit, type = "normalized"),
  main = "Normalized AR(1) GLS residuals",
  xlab = "Lag (months)",
  col = accent
)
par(old_par)
dev.off()

set.seed(20260802)
comparison_noise <- as.numeric(
  arima.sim(model = list(ar = 0.55), n = n_months, sd = 0.8)
)
comparison_outcome <- 65 +
  0.05 * its_data$time +
  5 * its_data$season_sin +
  1.5 * its_data$season_cos +
  comparison_noise +
  5 * its_data$intervention

treated_shared_outcome <- its_data$admissions_rate + 5 * its_data$intervention

controlled_data <- rbind(
  data.frame(date = its_data$date, series = "Treated", outcome = treated_shared_outcome),
  data.frame(date = its_data$date, series = "Comparison", outcome = comparison_outcome)
)

controlled_plot <- ggplot(controlled_data, aes(date, outcome, colour = series)) +
  geom_line(linewidth = 0.8) +
  geom_vline(xintercept = policy_date, linetype = "dashed", colour = accent) +
  scale_colour_manual(values = c("Comparison" = orange, "Treated" = blue)) +
  annotate("text", x = policy_date + 120, y = max(controlled_data$outcome) - 1,
    label = "Shared +5 shock", hjust = 0, colour = accent, fontface = "bold") +
  labs(x = NULL, y = "Admissions per 100,000", colour = NULL) +
  deck_theme

save_plot("its-controlled-shock.png", controlled_plot)

message("Wrote ITS slide assets to ", output_dir)
