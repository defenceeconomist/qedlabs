#!/usr/bin/env Rscript

# Generate deterministic teaching charts for the interrupted time-series deck.
# The case is wholly synthetic and represents a public housing-repairs service.

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
muted <- "#6f7f79"

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

simulate_repairs <- function(seed = 48127L) {
  set.seed(seed)
  n_months <- 132L
  announcement_time <- 85L
  implementation_time <- 88L
  time <- seq_len(n_months)
  date <- seq(as.Date("2014-01-01"), by = "month", length.out = n_months)
  announcement <- as.integer(time == announcement_time)
  implemented <- as.integer(time >= implementation_time)
  time_after <- pmax(0L, time - implementation_time)
  transition <- as.integer(time %in% implementation_time:(implementation_time + 2L))
  season_sin <- sin(2 * pi * time / 12)
  season_cos <- cos(2 * pi * time / 12)
  demand_pressure <- 100 + 0.10 * time + 5 * season_sin +
    as.numeric(arima.sim(list(ar = 0.45), n = n_months, sd = 1.3))
  weather_pressure <- 50 + 6 * season_cos +
    as.numeric(arima.sim(list(ar = 0.25), n = n_months, sd = 1.2))
  service_noise <- as.numeric(arima.sim(list(ar = 0.60), n = n_months, sd = 10))
  programme_effect <- 70 * implemented + 1.1 * time_after - 25 * transition

  completed <- pmax(1L, round(
    735 + 0.30 * time + 20 * season_cos + 0.9 * (demand_pressure - 100) +
      programme_effect + service_noise
  ))
  withdrawn <- pmax(1L, round(72 + 5 * season_sin + rnorm(n_months, 0, 3)))
  transferred <- pmax(1L, round(28 + rnorm(n_months, 0, 2)))
  closures <- completed + withdrawn + transferred
  new_requests <- pmax(1L, round(
    875 + 0.55 * time + 17 * season_sin + 1.2 * (demand_pressure - 100) +
      rnorm(n_months, 0, 8)
  ))
  scope_change <- ifelse(time == implementation_time, -620L, 0L)

  open_cases <- integer(n_months)
  open_cases[[1]] <- 4400L
  for (index in 2:n_months) {
    open_cases[[index]] <- open_cases[[index - 1L]] +
      new_requests[[index]] - closures[[index]] + scope_change[[index]]
  }

  eligible_properties <- round(24500 + 9 * time - 1100 * implemented)
  published_open_cases <- open_cases
  published_open_cases[[50]] <- round(open_cases[[50]] * 0.38)
  lag_open_cases <- c(NA, head(open_cases, -1L))
  closure_rate <- 1000 * closures / lag_open_cases

  data.frame(
    time,
    date,
    announcement,
    implemented,
    time_after,
    transition,
    season_sin,
    season_cos,
    demand_pressure,
    weather_pressure,
    completed,
    withdrawn,
    transferred,
    closures,
    new_requests,
    scope_change,
    open_cases,
    published_open_cases,
    eligible_properties,
    lag_open_cases,
    closure_rate
  )
}

repairs <- simulate_repairs()
announcement_date <- repairs$date[repairs$announcement == 1L]
implementation_date <- repairs$date[min(which(repairs$implemented == 1L))]

stopifnot(
  nrow(repairs) == 132L,
  identical(repairs$closures, repairs$completed + repairs$withdrawn + repairs$transferred),
  all(repairs$time_after[repairs$date == implementation_date] == 0L),
  all(repairs$open_cases[-1L] == repairs$open_cases[-nrow(repairs)] +
    repairs$new_requests[-1L] - repairs$closures[-1L] + repairs$scope_change[-1L])
)

timeline <- data.frame(
  date = c(announcement_date, implementation_date, implementation_date + 62, as.Date("2024-01-01")),
  event = c("Programme announced", "Operational rollout", "Transition ends", "Extreme context period"),
  y = c(1.00, 0.72, 0.44, 0.16)
)

timeline_plot <- ggplot(timeline, aes(date, y)) +
  annotate(
    "segment",
    x = min(repairs$date), xend = max(repairs$date), y = 0.58, yend = 0.58,
    colour = muted,
    linewidth = 1
  ) +
  geom_segment(aes(xend = date, yend = 0.58), colour = gold, linewidth = 0.8) +
  geom_point(colour = accent, size = 4) +
  geom_text(aes(label = event), hjust = 0, nudge_x = 45, colour = ink, fontface = "bold") +
  coord_cartesian(ylim = c(0, 1.12), clip = "off") +
  labs(x = NULL, y = NULL) +
  deck_theme +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), panel.grid = element_blank())
save_plot("its-timeline.png", timeline_plot, height = 4.4)

stock_flow_long <- rbind(
  data.frame(date = repairs$date, series = "Open cases (stock)", value = repairs$open_cases),
  data.frame(date = repairs$date, series = "New requests (flow)", value = repairs$new_requests),
  data.frame(date = repairs$date, series = "Closures (flow)", value = repairs$closures)
)
stock_flow_plot <- ggplot(stock_flow_long, aes(date, value, colour = series)) +
  geom_line(linewidth = 0.8) +
  geom_vline(xintercept = implementation_date, linetype = "dashed", colour = accent) +
  facet_wrap(~ series, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c(
    "Open cases (stock)" = deep,
    "New requests (flow)" = orange,
    "Closures (flow)" = blue
  )) +
  labs(x = NULL, y = NULL, colour = NULL) +
  deck_theme + theme(legend.position = "none")
save_plot("its-stock-flow.png", stock_flow_plot, height = 7.2)

count_rate_data <- data.frame(
  date = rep(repairs$date, 2),
  measure = rep(c("Closure count", "Closures per 1,000 open cases"), each = nrow(repairs)),
  value = c(repairs$closures, repairs$closure_rate)
)
count_rate_plot <- ggplot(count_rate_data, aes(date, value)) +
  geom_line(colour = blue, linewidth = 0.8, na.rm = TRUE) +
  geom_vline(xintercept = implementation_date, linetype = "dashed", colour = accent) +
  facet_wrap(~ measure, ncol = 1, scales = "free_y") +
  labs(x = NULL, y = NULL) + deck_theme
save_plot("its-count-rate.png", count_rate_plot, height = 6.6)

prepost <- aggregate(closure_rate ~ implemented, data = repairs, FUN = mean, na.rm = TRUE)
prepost_plot <- ggplot(repairs, aes(date, closure_rate)) +
  geom_line(colour = blue, linewidth = 0.65, alpha = 0.85, na.rm = TRUE) +
  geom_hline(yintercept = prepost$closure_rate[prepost$implemented == 0], colour = gold, linewidth = 1.2) +
  geom_hline(yintercept = prepost$closure_rate[prepost$implemented == 1], colour = accent, linewidth = 1.2) +
  geom_vline(xintercept = implementation_date, linetype = "dashed", colour = accent) +
  labs(x = NULL, y = "Closures per 1,000 open cases") + deck_theme
save_plot("its-prepost.png", prepost_plot)

raw_plot <- ggplot(repairs, aes(date, closure_rate)) +
  geom_line(colour = blue, linewidth = 0.7, na.rm = TRUE) +
  geom_point(colour = blue, size = 1.1, na.rm = TRUE) +
  geom_vline(xintercept = announcement_date, linetype = "dotted", colour = gold) +
  geom_vline(xintercept = implementation_date, linetype = "dashed", colour = accent) +
  labs(x = NULL, y = "Closures per 1,000 open cases") + deck_theme
save_plot("its-raw-series.png", raw_plot)

analysis <- subset(repairs, is.finite(closure_rate))
its_formula <- closure_rate ~ time + announcement + implemented + time_after + season_sin + season_cos
ols_fit <- lm(its_formula, data = analysis)
gls_fit <- gls(its_formula, data = analysis, correlation = corAR1(form = ~ time), method = "REML")
counterfactual <- transform(analysis, announcement = 0L, implemented = 0L, time_after = 0L)
analysis$fitted_programme <- as.numeric(predict(gls_fit, newdata = analysis))
analysis$no_programme <- as.numeric(predict(gls_fit, newdata = counterfactual))
trajectory <- rbind(
  data.frame(date = analysis$date, series = "Fitted programme path", value = analysis$fitted_programme),
  data.frame(date = analysis$date, series = "Estimated no-programme path", value = analysis$no_programme)
)
counterfactual_plot <- ggplot(analysis, aes(date, closure_rate)) +
  geom_point(colour = muted, size = 1, alpha = 0.55) +
  geom_line(data = trajectory, aes(y = value, colour = series, linetype = series), linewidth = 1) +
  geom_vline(xintercept = implementation_date, linetype = "dashed", colour = accent) +
  scale_colour_manual(values = c("Fitted programme path" = blue, "Estimated no-programme path" = orange)) +
  scale_linetype_manual(values = c("Fitted programme path" = "solid", "Estimated no-programme path" = "longdash")) +
  labs(x = NULL, y = "Closures per 1,000 open cases", colour = NULL, linetype = NULL) + deck_theme
save_plot("its-counterfactual.png", counterfactual_plot)

shape_time <- 1:72
shape_interruption <- 37L
shape_indicator <- as.integer(shape_time >= shape_interruption)
shape_after <- pmax(0, shape_time - shape_interruption)
shape_baseline <- 50 + 0.05 * shape_time
shape_data <- rbind(
  data.frame(time = shape_time, shape = "Immediate", outcome = shape_baseline + 5 * shape_indicator),
  data.frame(time = shape_time, shape = "Gradual", outcome = shape_baseline + 0.22 * shape_after),
  data.frame(time = shape_time, shape = "Immediate + gradual", outcome = shape_baseline + 4 * shape_indicator + 0.14 * shape_after),
  data.frame(time = shape_time, shape = "Temporary", outcome = shape_baseline + 6 * exp(-shape_after / 6) * shape_indicator)
)
shape_data$shape <- factor(shape_data$shape, levels = c("Immediate", "Gradual", "Immediate + gradual", "Temporary"))
effect_shapes_plot <- ggplot(shape_data, aes(time, outcome)) +
  geom_line(colour = blue, linewidth = 1) +
  geom_vline(xintercept = shape_interruption, linetype = "dashed", colour = accent) +
  facet_wrap(~ shape, nrow = 1) +
  labs(x = "Time", y = "Outcome") + deck_theme +
  theme(strip.text = element_text(face = "bold", colour = ink), axis.text.x = element_blank(), axis.ticks.x = element_blank())
save_plot("its-effect-shapes.png", effect_shapes_plot, width = 12, height = 4.4)

effect_at_horizon <- function(h) {
  beta_hat <- coef(gls_fit)
  beta_vcov <- vcov(gls_fit)
  weights <- c(implemented = 1, time_after = h)
  relevant <- beta_vcov[names(weights), names(weights), drop = FALSE]
  estimate <- sum(weights * beta_hat[names(weights)])
  standard_error <- sqrt(as.numeric(t(weights) %*% relevant %*% weights))
  data.frame(
    horizon = factor(paste0(h, ifelse(h == 0, " (immediate)", " months")), levels = c("0 (immediate)", "6 months", "12 months")),
    estimate,
    lower = estimate - qnorm(0.975) * standard_error,
    upper = estimate + qnorm(0.975) * standard_error
  )
}
horizon_data <- do.call(rbind, lapply(c(0, 6, 12), effect_at_horizon))
horizon_plot <- ggplot(horizon_data, aes(horizon, estimate)) +
  geom_hline(yintercept = 0, colour = muted, linewidth = 0.5) +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.12, colour = deep, linewidth = 0.9) +
  geom_point(colour = accent, size = 4) +
  labs(x = NULL, y = "Estimated change per 1,000 open cases") + deck_theme
save_plot("its-horizon-effects.png", horizon_plot, width = 8.5, height = 5.2)

seasonality_plot <- ggplot(repairs, aes(date)) +
  geom_line(aes(y = closure_rate), colour = muted, linewidth = 0.55, na.rm = TRUE) +
  geom_line(aes(y = 210 + 12 * season_cos), colour = accent, linewidth = 1.05) +
  geom_vline(xintercept = implementation_date, linetype = "dashed", colour = deep) +
  labs(x = NULL, y = "Closures per 1,000 open cases") + deck_theme
save_plot("its-seasonality.png", seasonality_plot)

png(file.path(output_dir, "its-residual-acf.png"), width = 1800, height = 820, res = 180, bg = soft)
old_par <- par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3.5, 1.5), bg = soft, fg = ink, col.axis = ink, col.lab = ink, col.main = ink)
acf(residuals(ols_fit), main = "OLS residuals", xlab = "Lag (months)", col = blue)
acf(residuals(gls_fit, type = "normalized"), main = "Normalized AR(1) GLS residuals", xlab = "Lag (months)", col = accent)
par(old_par)
dev.off()

set.seed(90210)
comparison_noise <- as.numeric(arima.sim(list(ar = 0.55), n = nrow(repairs), sd = 5))
shared_shock <- 18 * repairs$implemented
comparison_rate <- 185 + 0.10 * repairs$time + 9 * repairs$season_cos + comparison_noise + shared_shock
treated_rate <- repairs$closure_rate + shared_shock
controlled <- rbind(
  data.frame(date = repairs$date, series = "Programme area", value = treated_rate),
  data.frame(date = repairs$date, series = "Comparison area", value = comparison_rate)
)
controlled_plot <- ggplot(controlled, aes(date, value, colour = series)) +
  geom_line(linewidth = 0.8, na.rm = TRUE) +
  geom_vline(xintercept = implementation_date, linetype = "dashed", colour = accent) +
  scale_colour_manual(values = c("Programme area" = blue, "Comparison area" = orange)) +
  labs(x = NULL, y = "Closures per 1,000 open cases", colour = NULL) + deck_theme
save_plot("its-controlled-shock.png", controlled_plot)

validation_data <- data.frame(
  model = factor(rep(c("Seasonal naive", "Trend + season", "AR(2) + season", "Context + trend"), each = 3),
    levels = c("Seasonal naive", "Trend + season", "AR(2) + season", "Context + trend")),
  horizon = factor(rep(c("3 months", "6 months", "12 months"), 4), levels = c("3 months", "6 months", "12 months")),
  normalized_rmse = c(1, 1, 1, 0.86, 0.91, 1.06, 0.80, 0.84, 0.94, 0.83, 0.89, 1.02)
)
validation_plot <- ggplot(validation_data, aes(horizon, normalized_rmse, colour = model, group = model)) +
  geom_hline(yintercept = 1, linetype = "dotted", colour = muted) +
  geom_line(linewidth = 1) + geom_point(size = 3) +
  scale_colour_manual(values = c(muted, orange, blue, accent)) +
  labs(x = NULL, y = "RMSE relative to seasonal naive", colour = NULL) + deck_theme
save_plot("its-validation.png", validation_plot, width = 9.4, height = 5.3)

support <- data.frame(
  period = c("Pre-rollout training", "Primary impact window", "Unsupported extension"),
  minimum = c(91, 94, 82),
  maximum = c(116, 119, 143)
)
support$period <- factor(support$period, levels = rev(support$period))
support_plot <- ggplot(support, aes(y = period)) +
  geom_segment(aes(x = minimum, xend = maximum, yend = period), linewidth = 7, colour = blue, lineend = "round") +
  geom_vline(xintercept = c(91, 116), linetype = "dotted", colour = muted) +
  geom_point(aes(x = minimum), colour = deep, size = 3) +
  geom_point(aes(x = maximum), colour = accent, size = 3) +
  labs(x = "Contextual predictor range", y = NULL) + deck_theme
save_plot("its-support-audit.png", support_plot, width = 9.5, height = 4.7)

robustness <- data.frame(
  check = factor(c("Primary", "Announcement date", "Shorter baseline", "Omit anomaly", "Scope-adjusted stock", "Exclude transition"),
    levels = rev(c("Primary", "Announcement date", "Shorter baseline", "Omit anomaly", "Scope-adjusted stock", "Exclude transition"))),
  estimate = c(28, 10, 25, 29, 20, 26),
  lower = c(17, -4, 11, 18, 8, 12),
  upper = c(39, 24, 39, 40, 32, 40)
)
robustness_plot <- ggplot(robustness, aes(estimate, check)) +
  geom_vline(xintercept = 0, colour = muted) +
  geom_errorbar(aes(xmin = lower, xmax = upper), width = 0.15, colour = deep, linewidth = 0.8, orientation = "y") +
  geom_point(colour = accent, size = 3) +
  labs(x = "Illustrative 6-month effect", y = NULL) + deck_theme
save_plot("its-robustness.png", robustness_plot, width = 9.5, height = 5.6)

message("Wrote interrupted time-series slide assets to ", output_dir)
