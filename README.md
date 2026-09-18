# Quasi-Experimental Design Labs

The goals of Quasi-Experimental Design Labs is to compile and disseminate guidance on running quasi-experimental designs.

## Site Structure

A Quarto site now lives under `docs/` with three top-level sections:

- `notes`
- `labs`
- `slides`

Current content includes:

- matching and weighting notes plus migrated matching labs
- synthetic-control notes plus lab and slide skeletons
- interrupted-time-series notes, Seatbelts-based slides and presenter script, and three focused runnable labs
- difference-in-differences knowledge base, paired R/Python labs, and introductory slides
- additional notes on regression discontinuity

Render it with:

```bash
quarto render docs
```

## Run The Labs In JupyterLab With R

Runnable lab pages have downloadable notebooks linked from the
[Labs overview](https://defenceeconomist.github.io/qedlabs/labs/). Most notebooks use the Jupyter `ir` kernel and install missing lab-specific R
packages when they are first run. The DiD sequence also includes Python notebooks;
use its pinned environments for reproducible execution.

Install JupyterLab and register the R kernel once:

```bash
python3 -m pip install jupyterlab
R -e 'install.packages("IRkernel", repos = "https://cloud.r-project.org"); IRkernel::installspec()'
jupyter lab
```

The HISP notebook needs the external replication data described on its lab
page. Set the data directory before launching JupyterLab so the R kernel
inherits it:

```bash
HISP_IE_DATA_DIR=/absolute/path/to/hisp_ie_in_practice jupyter lab
```

The committed notebooks are generated from the Quarto lab sources. Refresh
them after changing a lab, or check that they are current, with:

```bash
python3 docs/scripts/generate_lab_notebooks.py
python3 docs/scripts/generate_lab_notebooks.py --check
```

## GitHub Pages

The site now publishes from GitHub Actions on pushes to `main`.

- The workflow renders `docs/_site/`.
- It uploads the rendered site as a regular Actions artifact named `site`.
- It deploys that same build to GitHub Pages.

Local rendering stays unchanged:

```bash
quarto render docs
```

## Difference-in-Differences collection

Start with [the reading map](docs/notes/did/difference-in-differences-sources.qmd),
[application catalogue](docs/notes/did/difference-in-differences-applications.qmd),
and [introductory deck](docs/slides/did.qmd).

The [DiD setup and reproduction record](docs/labs/difference-in-differences-reproducibility.qmd)
contains isolated Python 3.11 and R 4.5.1 setup instructions, dependency locks,
verified estimates, and documented software limitations. Generate notebooks from
Quarto sources, then run:

```bash
python docs/scripts/test_generate_lab_notebooks.py
python docs/scripts/validate_did_labs.py --extensions
```

Validation launches fresh kernels and compares equivalent R/Python estimates;
a successful website render alone does not execute these labs.
