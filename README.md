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
- additional notes on difference-in-differences and regression discontinuity

Render it with:

```bash
quarto render docs
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

.