#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
  library(nlme)
})

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- if (length(script_arg)) {
  normalizePath(sub("^--file=", "", script_arg[[1]]))
} else {
  normalizePath("docs/scripts/generate_its_slide_assets.R")
}
asset_dir <- file.path(dirname(dirname(script_path)), "slides", "assets")
lab_data_dir <- file.path(dirname(dirname(script_path)), "labs", "data")
source(file.path(lab_data_dir, "load-data.R"))
dir.create(asset_dir, recursive = TRUE, showWarnings = FALSE)

palette <- c(
  blue = "#24527a",
  orange = "#bf6b21",
  red = "#a23b3b",
  purple = "#7a5195",
  grey = "#5f6368",
  dark = "#303030"
)

workshop_theme <- theme_minimal(base_size = 15) +
  theme(
    plot.title = element_text(face = "bold", colour = palette[["dark"]]),
    plot.subtitle = element_text(colour = palette[["grey"]]),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

save_asset <- function(plot, filename, width = 11, height = 6) {
  ggsave(
    filename = file.path(asset_dir, filename),
    plot = plot,
    width = width,
    height = height,
    dpi = 180,
    bg = "white"
  )
}

Seatbelts <- qed_data("Seatbelts", lab_data_dir)
seatbelts <- as.data.frame(Seatbelts)
seatbelts$time <- seq_len(nrow(seatbelts))
seatbelts$date <- seq(as.Date("1969-01-01"), by = "month", length.out = nrow(seatbelts))
seatbelts$post_time <- ifelse(
  seatbelts$law == 1,
  seatbelts$time - min(seatbelts$time[seatbelts$law == 1]),
  0
)
seatbelts$season_sin <- sin(2 * pi * seatbelts$time / 12)
seatbelts$season_cos <- cos(2 * pi * seatbelts$time / 12)
intervention_date <- min(seatbelts$date[seatbelts$law == 1])

its_formula <- log(front) ~ time + law + post_time + season_sin + season_cos
ols_fit <- lm(its_formula, data = seatbelts)
gls_fit <- gls(
  its_formula,
  data = seatbelts,
  correlation = corAR1(form = ~ time),
  method = "REML"
)

raw_plot <- ggplot(seatbelts, aes(date, front)) +
  geom_line(linewidth = 0.75, colour = palette[["blue"]]) +
  geom_vline(xintercept = intervention_date, linetype = "dashed", colour = palette[["red"]]) +
  annotate(
    "text",
    x = as.Date("1983-01-01"),
    y = max(seatbelts$front),
    label = "Compulsory front-seat belt wearing",
    hjust = 1.03,
    vjust = 1.2,
    colour = palette[["red"]]
  ) +
  labs(
    title = "Front-seat casualties fell around February 1983",
    subtitle = "Monthly passengers killed or seriously injured, Great Britain",
    x = NULL,
    y = "Monthly count"
  ) +
  workshop_theme
save_asset(raw_plot, "its-seatbelts-raw.png")

period_means <- aggregate(front ~ law, seatbelts, mean)
period_means$xmin <- c(min(seatbelts$date), intervention_date)
period_means$xmax <- c(intervention_date, max(seatbelts$date))
period_means$period <- c("Before law", "Law in effect")

prepost_plot <- ggplot(seatbelts, aes(date, front)) +
  geom_line(linewidth = 0.55, colour = "#b7c7d6") +
  geom_segment(
    data = period_means,
    aes(x = xmin, xend = xmax, y = front, yend = front, colour = period),
    linewidth = 1.4
  ) +
  geom_vline(xintercept = intervention_date, linetype = "dashed", colour = palette[["red"]]) +
  scale_colour_manual(values = c("Before law" = palette[["orange"]], "Law in effect" = palette[["blue"]])) +
  labs(
    title = "Two averages discard the trajectory",
    subtitle = "The periods differ in trend, season, and length",
    x = NULL,
    y = "Monthly count",
    colour = NULL
  ) +
  workshop_theme
save_asset(prepost_plot, "its-seatbelts-prepost.png")

seatbelts$fitted_observed <- exp(predict(gls_fit, newdata = seatbelts))
no_law <- transform(seatbelts, law = 0, post_time = 0)
seatbelts$fitted_no_law <- exp(predict(gls_fit, newdata = no_law))

counterfactual_plot <- ggplot(seatbelts, aes(date)) +
  geom_line(aes(y = front, colour = "Observed"), linewidth = 0.55) +
  geom_line(aes(y = fitted_observed, colour = "Fitted with law"), linewidth = 0.9) +
  geom_line(
    aes(y = fitted_no_law, colour = "Projected no-law path"),
    linewidth = 0.9,
    linetype = "dashed"
  ) +
  geom_vline(xintercept = intervention_date, linetype = "dotted") +
  scale_colour_manual(values = c(
    "Observed" = palette[["dark"]],
    "Fitted with law" = palette[["blue"]],
    "Projected no-law path" = palette[["orange"]]
  )) +
  labs(
    title = "ITS compares observed outcomes with a projected untreated path",
    x = NULL,
    y = "Monthly count",
    colour = NULL
  ) +
  workshop_theme
save_asset(counterfactual_plot, "its-seatbelts-counterfactual.png")

shape_time <- 1:48
shape_intervention <- 25
shape_data <- do.call(rbind, list(
  data.frame(shape = "Immediate", time = shape_time, effect = ifelse(shape_time >= shape_intervention, -12, 0)),
  data.frame(shape = "Gradual", time = shape_time, effect = pmin(0, -0.8 * pmax(0, shape_time - shape_intervention))),
  data.frame(shape = "Immediate + gradual", time = shape_time, effect = ifelse(shape_time >= shape_intervention, -8, 0) - 0.4 * pmax(0, shape_time - shape_intervention)),
  data.frame(shape = "Temporary", time = shape_time, effect = ifelse(shape_time %in% shape_intervention:(shape_intervention + 5), -12, 0))
))
shape_data$shape <- factor(
  shape_data$shape,
  levels = c("Immediate", "Gradual", "Immediate + gradual", "Temporary")
)

effect_shapes_plot <- ggplot(shape_data, aes(time, effect)) +
  geom_hline(yintercept = 0, colour = "#c7c7c7") +
  geom_vline(xintercept = shape_intervention, linetype = "dashed", colour = palette[["red"]]) +
  geom_line(linewidth = 1, colour = palette[["blue"]]) +
  facet_wrap(~ shape, nrow = 1) +
  labs(title = "Delivery knowledge should determine the effect shape", x = "Time", y = "Intervention effect") +
  workshop_theme
save_asset(effect_shapes_plot, "its-effect-shapes.png", width = 12, height = 4.8)

acf_frame <- function(values, model_name) {
  acf_result <- acf(values, plot = FALSE, lag.max = 18)
  data.frame(
    lag = as.numeric(acf_result$lag)[-1],
    autocorrelation = as.numeric(acf_result$acf)[-1],
    model = model_name
  )
}

acf_data <- rbind(
  acf_frame(residuals(ols_fit), "OLS residuals"),
  acf_frame(residuals(gls_fit, type = "normalized"), "Normalized AR(1) residuals")
)
acf_data$model <- factor(
  acf_data$model,
  levels = c("OLS residuals", "Normalized AR(1) residuals")
)

residual_plot <- ggplot(acf_data, aes(lag, autocorrelation)) +
  geom_hline(yintercept = 0, colour = "#777777") +
  geom_segment(aes(xend = lag, y = 0, yend = autocorrelation), linewidth = 0.8, colour = palette[["blue"]]) +
  facet_wrap(~ model, nrow = 1) +
  labs(
    title = "Dependence belongs in the error model",
    x = "Lag (months)",
    y = "Residual autocorrelation"
  ) +
  workshop_theme
save_asset(residual_plot, "its-seatbelts-residual-acf.png", width = 10, height = 4.8)

indexed_outcomes <- do.call(rbind, lapply(c("front", "drivers", "rear"), function(name) {
  data.frame(
    date = seatbelts$date,
    series = c(front = "Front-seat passengers", drivers = "Car drivers", rear = "Rear-seat passengers")[[name]],
    index = 100 * seatbelts[[name]] / seatbelts[[name]][[1]]
  )
}))

outcomes_plot <- ggplot(indexed_outcomes, aes(date, index, colour = series)) +
  geom_line(linewidth = 0.7) +
  geom_vline(xintercept = intervention_date, linetype = "dashed", colour = palette[["red"]]) +
  scale_colour_manual(values = c(
    "Front-seat passengers" = palette[["blue"]],
    "Car drivers" = palette[["purple"]],
    "Rear-seat passengers" = palette[["orange"]]
  )) +
  labs(
    title = "Alternative outcomes add design information",
    subtitle = "Indexed to January 1969 = 100; rear-seat casualties are informative but not a clean control",
    x = NULL,
    y = "Index",
    colour = NULL
  ) +
  workshop_theme
save_asset(outcomes_plot, "its-seatbelts-outcomes.png")

model_formulas <- list(
  "Level only" = log(front) ~ time + law + season_sin + season_cos,
  "Level + trend" = its_formula,
  "Distance + petrol" = log(front) ~ time + law + post_time + log(kms) + PetrolPrice + season_sin + season_cos
)
robustness <- do.call(rbind, lapply(names(model_formulas), function(name) {
  fit <- gls(
    model_formulas[[name]],
    data = seatbelts,
    correlation = corAR1(form = ~ time),
    method = "ML"
  )
  term <- summary(fit)$tTable["law", ]
  data.frame(
    specification = name,
    estimate = 100 * (exp(term[["Value"]]) - 1),
    lower = 100 * (exp(term[["Value"]] - 1.96 * term[["Std.Error"]]) - 1),
    upper = 100 * (exp(term[["Value"]] + 1.96 * term[["Std.Error"]]) - 1)
  )
}))

robustness_plot <- ggplot(robustness, aes(estimate, reorder(specification, estimate))) +
  geom_vline(xintercept = 0, colour = "#777777") +
  geom_errorbar(
    aes(xmin = lower, xmax = upper),
    width = 0.12,
    orientation = "y",
    colour = palette[["blue"]]
  ) +
  geom_point(size = 3.2, colour = palette[["red"]]) +
  labs(
    title = "Sensitivity changes the magnitude more than the direction",
    subtitle = "Estimated immediate percentage change in front-seat casualties",
    x = "Percent change",
    y = NULL
  ) +
  workshop_theme
save_asset(robustness_plot, "its-seatbelts-robustness.png", width = 9, height = 5)

simulate_service <- function(seed = 48127L) {
  set.seed(seed)
  n_months <- 120L
  implementation_time <- 85L
  time <- seq_len(n_months)
  date <- seq(as.Date("2014-01-01"), by = "month", length.out = n_months)
  implemented <- as.integer(time >= implementation_time)
  season_sin <- sin(2 * pi * time / 12)
  season_cos <- cos(2 * pi * time / 12)
  context <- 100 + 0.10 * time + 4 * season_sin + as.numeric(arima.sim(list(ar = 0.45), n = n_months, sd = 1.2))
  pre_range <- range(context[time < implementation_time])
  supported_post <- time >= implementation_time & time <= 108L
  context[supported_post] <- pmin(pmax(context[supported_post], pre_range[[1]]), pre_range[[2]])
  context[time >= 109L] <- context[time >= 109L] + 35
  untreated <- 120 + 0.18 * time + 7 * season_cos + 0.9 * (context - 100) +
    as.numeric(arima.sim(list(ar = 0.35), n = n_months, sd = 2.2))
  transition <- as.integer(time %in% implementation_time:(implementation_time + 2L))
  effect <- 18 * implemented + 0.35 * pmax(0, time - implementation_time) - 6 * transition
  data.frame(time, date, implemented, season_sin, season_cos, context, outcome = untreated + effect)
}

service <- simulate_service()
candidate_models <- c("Seasonal naive", "Trend + season", "Context + trend")
origins <- c(48L, 60L, 72L)
horizons <- c(3L, 6L, 12L)

forecast_candidate <- function(name, training, future) {
  if (name == "Seasonal naive") {
    lookup <- setNames(training$outcome, training$time)
    unname(lookup[as.character(future$time - 12L)])
  } else if (name == "Trend + season") {
    predict(lm(outcome ~ time + season_sin + season_cos, training), future)
  } else {
    predict(lm(outcome ~ time + season_sin + season_cos + context, training), future)
  }
}

validation <- do.call(rbind, lapply(candidate_models, function(name) {
  do.call(rbind, lapply(origins, function(origin) {
    training <- subset(service, time <= origin)
    future <- subset(service, time > origin & time <= origin + 12L)
    prediction <- forecast_candidate(name, training, future)
    do.call(rbind, lapply(horizons, function(horizon) {
      errors <- future$outcome[seq_len(horizon)] - prediction[seq_len(horizon)]
      data.frame(model = name, horizon, nrmse = sqrt(mean(errors^2)) / sd(training$outcome))
    }))
  }))
}))
validation <- aggregate(nrmse ~ model + horizon, validation, mean)

validation_plot <- ggplot(validation, aes(horizon, nrmse, colour = model)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = horizons) +
  scale_colour_manual(values = c(
    "Seasonal naive" = palette[["purple"]],
    "Trend + season" = palette[["orange"]],
    "Context + trend" = palette[["blue"]]
  )) +
  labs(
    title = "Select the untreated model on untreated data",
    subtitle = "Mean normalized RMSE across identical pre-programme origins",
    x = "Forecast horizon (months)",
    y = "Normalized RMSE",
    colour = NULL
  ) +
  workshop_theme
save_asset(validation_plot, "its-validation.png", width = 9, height = 5.4)

message("Wrote ITS slide assets to ", asset_dir)
