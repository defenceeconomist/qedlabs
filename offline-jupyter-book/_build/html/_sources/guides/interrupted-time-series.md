# Interrupted time series guide

## Use this section when

A clearly timed intervention affects an entire population or system, no credible
untreated comparison is available, and many comparable outcome observations exist
before and after the change.

## From pre-post to a defensible time-series design

Module 6 introduces pre-post analysis and its vulnerability to trends and
concurrent events. This section makes the untreated trajectory explicit. It adds
segmented regression, effects at named horizons, counterfactual plots, seasonality
and serial-dependence checks, alternative outcomes and specifications, false dates,
and pre-period forecast validation.

## Recommended sequence

1. **Methods report:** define the intervention, outcome, estimand, and missing
   comparison.
2. **Foundations:** compare a simple before/after difference with a segmented
   time-series model.
3. **Design and robustness:** examine alternative outcomes, controls, functional
   forms, and false intervention dates.
4. **Counterfactual validation:** compare candidate untreated models on held-out
   pre-intervention periods before forecasting programme months.

## Completion check

You should be able to explain why a pre-post difference is not itself a credible
counterfactual, report level and slope changes at meaningful horizons, inspect
serial dependence and seasonality, identify concurrent-event threats, and stop
forecasting when the observed data move beyond pre-intervention support.
