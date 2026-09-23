# How to study this book

The book is modular, but each method follows the same learning cycle.

## The method cycle

1. **Guide:** confirm that the assignment process, data, and target effect fit
   the method.
2. **Report:** understand the estimand, assumptions, critical choices, diagnostics,
   and reporting standard.
3. **Foundations lab:** reproduce the core comparison and explain it in plain language.
4. **Diagnostics or application lab:** look for evidence that weakens the design.
5. **Extension:** study the modern estimator, alternative specification, or more
   demanding design problem.
6. **Design judgement:** state what is credible, what remains uncertain, and what
   evidence would change the conclusion.

Run cells in order. Read the prose before changing code, and interpret plots and
tables before looking at worked answers.

## Choose a route

### Core route

Use this route for a practical survey of all methods:

- [Choosing a design](choosing-a-design.md);
- each method guide;
- the first foundations or mechanics lab in each method section; and
- the [HISP cross-method capstone](notebooks/hisp-ie-practice-lab.ipynb).

### Full route

For each method, read the guide and report, complete every executable lab, and
write the requested design assessment before reading the worked answer. Complete
the synthetic-control planning worksheets even though they contain no code.

### Method-specific route

When supporting a live evaluation, begin with [Choosing a design](choosing-a-design.md),
then complete one method section from guide to final extension. Return to the
design map before treating an estimate as conclusive.

## What to hand back

For every applied route, produce a short design memo containing:

- the policy question and decision the evaluation will inform;
- treatment, outcome, population, timing, comparison, and estimand;
- the assignment process and identifying assumptions;
- the primary specification and why it was chosen;
- diagnostic and sensitivity evidence;
- the estimate with uncertainty and an interpretation on the outcome scale;
- limitations, external-validity boundaries, and unresolved threats; and
- a reproducible reference to the data and code used.

## Running the exercises

Read the cached book with `./serve.sh`. Use `./lab.sh` when you want to execute
or edit notebooks. The [offline setup](offline-setup.md) page explains the local
environments, rebuild, verification, and transfer workflow. The
[data catalogue](data.md) records the bundled datasets and provenance.
