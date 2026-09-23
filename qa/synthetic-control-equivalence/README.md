# Synthetic-control equivalence QA

The standalone report verifies that the book's base-R synthetic-control solver
reproduces `Synth` when both solve the same standardized, equal-row-weighted
optimization problem.

- Read `synthetic-control-equivalence-report.html` for the signed-off result.
- Inspect `synthetic-control-equivalence-report.qmd` for report-generation code.
- Run `run-equivalence.R` in an isolated environment containing `Synth` to
  regenerate the machine-readable files under `results/`.

`Synth` is a QA-only reference dependency. It is not added to the book lockfile
or runtime environment.
