# QED Labs

The goals of QED Labs is to compile and disseminate guidance on running quasi-experimental designs.

## Evidence Base Docker Access

This repo can connect to the shared Evidence Base Docker network and export processed source data from Redis and Qdrant.

The helper compose file uses the existing external Docker network:

- default network: `mcp-evidencebase_default`
- override with: `EVIDENCEBASE_NETWORK=<network-name>`

Example usage:

```bash
scripts/fetch_evidencebase_source.sh evaluation gertler_ch8.pdf
```

This writes the exported files under `data/evidencebase/<collection>/<source-stem>/`.

## Site Structure

A Quarto site now lives under `docs/` with three top-level sections:

- `notes`
- `reports`
- `labs`

Current content includes:

- matching and weighting notes plus migrated matching labs
- synthetic-control notes plus report and lab skeletons
- additional notes on difference-in-differences and regression discontinuity

Render it with:

```bash
quarto render docs
```
