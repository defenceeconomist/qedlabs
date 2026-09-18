# Numerical Regression Baselines

These R output tables were retained from the successful paired-language validation
on 18 September 2026, before the Python teaching notebooks were removed.
They are fixed reference results, not regenerated automatically by the current tests.

The R-only validators execute the current offline notebooks and compare their
exports with these tables using absolute tolerance 1e-7 plus relative tolerance
1e-6. They check row keys, columns and all finite numeric values. DiD includes
the HonestDiD sensitivity grid; RDD includes estimates, inference, support,
bandwidths, density, placebo and donut checks.

The historical RDD environment and comparison summary remain in
`../rdd-verified-results.json`. Data snapshots and their original-file checksums
are documented in `../../data/manifest.json`. Updating a baseline requires an
explicit methodological review, not merely rerunning the generator.
