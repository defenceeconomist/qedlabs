# Quasi-Experimental Design Labs

A Quarto academic reference with two main sections:

- **Notes:** method overviews, practical R guides, and source-based reading.
- **Labs:** 18 R labs and worksheets, with five core reports, teaching decks, and presenter notes grouped by method.

The practical guides cover interrupted time series, difference-in-differences,
and sharp/fuzzy regression discontinuity. Existing slide URLs remain under
`docs/slides/`; the former Slides overview redirects to Labs.

## Offline Lab Downloads

Every lab has a downloadable Quarto document, an R Jupyter notebook, and a complete
ZIP containing both documents and all its data. All 16 teaching datasets are
committed under `docs/labs/data/` and linked from the site's data catalogue.
This includes HISP's original CSV, Stata file and replication script.

Extract a complete ZIP and keep `data/` beside the documents. Select the **R**
kernel in Jupyter and run cells in order, or run `quarto render NAME.qmd`.
Individual document downloads work with the all-data ZIP extracted beside them.
The two SCM planning worksheets have writing prompts rather than executable code.

Lab execution does not download data or install software. Prepare R 4.5.1, Quarto,
Jupyter and the R packages before going offline:

```bash
python3 -m pip install jupyterlab PyYAML nbformat nbclient
Rscript docs/scripts/setup_lab_environment.R
Rscript -e 'IRkernel::installspec()'
```

The setup script may use the network; the labs do not. Method-specific tested R
lockfiles remain in `docs/labs/reproducibility/`. Detailed prerequisites are in
[offline setup](docs/labs/offline-setup.md). Python remains a build/validation
tool, but no Python teaching notebooks or Python analysis kernel are required.

## Generation and Validation

The website labs are the canonical teaching sources. Generated downloads must not
be edited directly. They contain generated references from the sole maintained
bibliography, `evaluation-bibliography.bib`.

```bash
python3 docs/scripts/generate_lab_notebooks.py
python3 docs/scripts/generate_lab_notebooks.py --check
python3 docs/scripts/test_generate_lab_notebooks.py
python3 docs/scripts/validate_bibliography.py
python3 docs/scripts/test_validate_bibliography.py
python3 docs/scripts/validate_offline_labs.py --execute --render
python3 docs/scripts/validate_did_labs.py
python3 docs/scripts/validate_rdd_labs.py
Rscript docs/scripts/validate_method_reports.R
quarto render docs
python3 docs/scripts/validate_site.py
```

Pandoc is required for structured citation conversion. The scripts use Quarto's
bundled Pandoc; set `PANDOC` to a standalone executable if needed. Validation
executes extracted bundles in fresh R kernels and retains logs under the ignored
`.qedlabs-validation/` directory. The CI execution step uses a network namespace
with only loopback available. Numerical baselines preserve the original verified
results; tests do not refresh them automatically.

The ITS, DiD, and RDD core reports render to HTML and PDF. Their executable
examples are checked against the existing practical guides by
`validate_method_reports.R`, which also runs in CI's network-disabled step.
They are reference reports, not additional notebook labs. RDD slide figures are
generated from bundled data with `Rscript docs/scripts/generate_rdd_slide_assets.R`.
Regenerate and inspect those four assets when changing the associated examples;
site rendering does not regenerate slide assets automatically.

Data snapshots are not regenerated during builds. To deliberately update them,
prepare the pinned source files and package versions, run
`docs/scripts/vendor_lab_data.R`, and review provenance, checksums and results.
Retain source notices and investigate redistribution conditions before adding data.

## Publishing

GitHub Actions renders the site and PDF reports and publishes GitHub Pages on
pushes to `main`. Feature-branch pushes do not publish. The workflow and existing
URLs are retained; no separate hosting service is used.
