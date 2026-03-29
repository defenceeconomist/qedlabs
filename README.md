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

## Notes Site

A Quarto notes scaffold now lives under `docs/` for the main quasi-experimental design topics:

- matching and weighting
- difference-in-differences
- synthetic control
- regression discontinuity

Render it with:

```bash
quarto render docs
```
