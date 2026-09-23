# From Module 6 to applied practice

## The starting point

Evaluation Academy Module 6 establishes a common language for quasi-experimental
designs. For each method it asks five useful questions:

1. What is the method?
2. When should you use it?
3. When should you not use it?
4. What critical choices must evaluators make?
5. What are its key limitations?

This book keeps those questions visible, then adds the work needed to answer
them with real data. It assumes that you understand why an impact evaluation
needs a counterfactual and why random assignment is often unavailable, unethical,
or too late to introduce.

## What the book adds

| Module 6 foundation | Applied extension in this book |
|---|---|
| Recognise the main QED families | Translate an assignment rule and data structure into a defensible candidate design |
| Describe when a method may fit | State the estimand, comparison, identifying assumptions, and required support |
| Identify critical design choices | Make those choices explicitly in executable R workflows |
| Understand headline limitations | Run diagnostics, sensitivity checks, placebos, and alternative specifications |
| Select a method for a scenario | Compare methods using the same design questions and document why alternatives were rejected |
| Critically assess findings | Separate estimates, diagnostic evidence, uncertainty, and remaining threats in a design judgement |

The reports provide the conceptual bridge. The labs make the design choices
inspectable. The final HISP case shows why different comparisons applied to the
same policy question can produce different answers.

## How the methods correspond

- **Regression discontinuity** develops the Academy's threshold design into
  sharp and fuzzy estimands, local estimation, density and covariate checks,
  bandwidth sensitivity, and placebo analyses.
- **Difference-in-differences** moves from the four-cell contrast to staggered
  adoption, treatment-effect heterogeneity, group-time effects, event studies,
  and sensitivity to deviations from parallel trends.
- **Synthetic control** turns donor-pool intuition into a reproducible workflow
  covering pre-treatment fit, donor weights, placebo comparisons, augmentation,
  and design documentation.
- **Matching and weighting** compares exact matching, coarsened exact matching,
  and entropy balancing while keeping overlap, balance, estimand, and residual
  confounding central.
- **Interrupted time series** extends the Academy's pre-post material. Instead
  of treating one before/after difference as the effect, it models the
  pre-intervention trajectory, states a no-intervention counterfactual, and
  probes timing, functional form, serial dependence, and concurrent events.

## A boundary to keep in view

More analysis does not automatically create a stronger design. A sophisticated
estimator cannot repair an implausible comparison, missing overlap, a manipulable
cutoff, an unsuitable donor pool, or a time break confounded by another event.
The goal of the book is therefore a reasoned design assessment, not simply a
statistically significant coefficient.

## Next step

Use [Choosing a design](choosing-a-design.md) to turn a policy question and an
available dataset into a method shortlist.
