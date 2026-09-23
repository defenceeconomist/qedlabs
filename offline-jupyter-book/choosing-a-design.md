# Choosing a design

Choose a quasi-experimental design from the assignment process and the available
comparison, not from the estimator you already know.

## Start with six declarations

Before selecting a method, write down:

1. **Intervention:** what changes, for whom, and at what time?
2. **Outcome:** what decision-relevant result will be measured, and when?
3. **Assignment:** what determines exposure or eligibility?
4. **Counterfactual:** whose or which outcome can represent what would otherwise
   have happened?
5. **Estimand:** whose effect is being estimated, at what horizon, and on what scale?
6. **Data:** which units, periods, assignment variables, outcomes, and pre-treatment
   covariates are actually observed?

If these declarations are vague, method selection is premature.

## Design map

| Candidate | Strongest design cue | Minimum useful structure | Central identifying claim | Main warning |
|---|---|---|---|---|
| Regression discontinuity | Treatment changes at a known threshold | Outcome and assignment score around the cutoff | Potential outcomes are continuous at the cutoff; units cannot precisely manipulate assignment | The effect is local and the cutoff may trigger other changes |
| Difference-in-differences | Some units change treatment while credible comparators do not | Treated and comparison units before and after treatment | Without treatment, their outcomes would have followed parallel trends | Anticipation, spillovers, changing composition, or heterogeneous timing can invalidate standard estimates |
| Synthetic control | One or a few aggregate units are treated | Long pre-period for the treated unit and a credible donor pool | A weighted donor combination can represent the untreated path | Poor pre-fit, contaminated donors, or weak comparative evidence undermine the result |
| Matching or weighting | Treatment and comparison units overlap on rich pre-treatment characteristics | Treatment, outcome, and confounders observed for both groups | Conditional on observed covariates, treatment assignment is as good as random | Unobserved confounding remains; balance does not prove identification |
| Interrupted time series | A population-wide intervention starts at a known time | Many observations before and after the intervention | The model captures the untreated trajectory and no coincident event explains the break | A simple pre-post contrast confuses intervention effects with trend, seasonality, and other shocks |

## A practical decision sequence

1. **Is assignment governed by a threshold that you observe precisely?** Start
   with [Regression discontinuity](guides/regression-discontinuity.md).
2. **Do treated and untreated units have repeated outcomes around a policy change?**
   Start with [Difference-in-differences](guides/difference-in-differences.md).
3. **Is treatment concentrated in one or a few aggregate units with a long
   pre-period and several credible donors?** Start with
   [Synthetic control](guides/synthetic-control.md).
4. **Do you have only a post-treatment outcome but rich pre-treatment covariates
   and genuine overlap?** Consider [Matching and weighting](guides/matching-weighting.md).
5. **Is there no defensible untreated comparison, but there is a long outcome
   series and a clearly timed intervention?** Consider
   [Interrupted time series](guides/interrupted-time-series.md).

These are screening questions, not automatic rules. Several designs may be
feasible. Prefer the design whose identifying claim is most credible for the
policy context, and use alternative designs as triangulation only when their
estimands and assumptions are made explicit.

## Stop conditions

Pause before estimation when:

- treatment or eligibility cannot be reconstructed reliably;
- the comparison is affected by the intervention or a related policy;
- the target effect changes silently across candidate methods;
- pre-treatment support is too weak to assess the identifying claim;
- outcome timing does not match the intervention's plausible response period; or
- the available sample cannot support the intended level of inference.

Record the limitation and redesign the evaluation or narrow the claim. Do not
use a more complex model to conceal a missing comparison.

## Next step

Open the relevant method guide, then use [How to study this book](study-guide.md)
to choose the depth of study.
