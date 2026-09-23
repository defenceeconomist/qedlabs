# Matching and weighting guide

## Use this section when

Treated and comparison units overlap on a rich set of pre-treatment covariates
that plausibly capture the common causes of treatment and outcome, but a stronger
assignment-based design is unavailable.

## What this adds to Module 6

The section treats matching and weighting as design-stage preprocessing rather
than an automatic cure for selection. It compares exact matching, coarsened exact
matching, and entropy balancing while tracking estimand, overlap, covariate
balance, retained sample, effective sample size, and sensitivity to specification.

## Recommended sequence

1. **Methods report:** connect potential outcomes and conditional exchangeability
   to concrete design choices.
2. **LaLonde foundations:** compare matching and weighting specifications on a
   canonical training example.
3. **Black politicians application:** adapt the workflow to a contextual case.
4. **NSW–CPS benchmark:** compare observational answers with an experimental
   benchmark and examine where adjustment succeeds or fails.

## Completion check

You should be able to define the target estimand before constructing weights,
identify unsupported observations, interpret balance and effective sample size
together, explain why observed balance cannot rule out hidden confounding, and
prefer a stronger design when one is feasible.
