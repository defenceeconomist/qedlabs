# Bundled data and provenance

All notebook execution uses the local files listed below. `manifest.json` records
source metadata, variables, dimensions, and expected hashes. `load-data.R` verifies
each dataset before returning it.

[Download the complete machine-readable manifest](data/manifest.json).

| Dataset | File | Rows | Origin |
|---|---|---:|---|
| `lalonde` | [Download](data/lalonde.rds) | 614 | https://kosukeimai.github.io/MatchIt/, https://github.com/kosukeimai/MatchIt |
| `black_politicians` | [Download](data/black_politicians.rds) | 5,593 | https://github.com/NickCH-K/causaldata |
| `nsw_mixtape` | [Download](data/nsw_mixtape.rds) | 445 | https://github.com/NickCH-K/causaldata |
| `cps_mixtape` | [Download](data/cps_mixtape.rds) | 15,992 | https://github.com/NickCH-K/causaldata |
| `Seatbelts` | [Download](data/Seatbelts.rds) | 192 | https://cran.r-project.org/package=datasets |
| `synth.data` | [Download](data/synth.data.rds) | 168 | https://web.stanford.edu/~jhain/ |
| `smoking` | [Download](data/smoking.rds) | 1,209 | https://cran.r-project.org/package=tidysynth |
| `kansas` | [Download](data/kansas.rds) | 5,250 | https://cran.r-project.org/package=augsynth |
| `injury` | [Download](data/injury.rds) | 7,150 | https://raw.githubusercontent.com/cran/wooldridge/5c16676c8c8e6685985d98661c55088c878902be/data/injury.RData |
| `castle` | [Download](data/castle.rds) | 550 | https://raw.githubusercontent.com/cran/causaldata/6d25e70297812a2e89a1a20e3bc24b32f6d3fbaf/data/castle.rda |
| `mpdta` | [Download](data/mpdta.rds) | 2,500 | https://raw.githubusercontent.com/cran/did/453a1be859411edc1c8933891940cb3a570d7095/data/mpdta.rda |
| `gov_transfers` | [Download](data/gov_transfers.rds) | 1,948 | https://github.com/NickCH-K/causaldata |
| `gov_transfers_density` | [Download](data/gov_transfers_density.rds) | 52,549 | https://github.com/NickCH-K/causaldata |
| `mortgages` | [Download](data/mortgages.rds) | 214,144 | https://github.com/NickCH-K/causaldata |
| `hisp` | [Download](data/hisp.rds) | 19,827 | https://www.worldbank.org/en/programs/sief-trust-fund/publication/impact-evaluation-in-practice |
| `service` | [Download](data/service.rds) | 120 | QED Labs: simulate_service() in interrupted-time-series-counterfactual-validation-lab.qmd |

## Integrity and licences

Run `./verify.sh` to verify the book-level `checksums.sha256` file and the
dataset hashes embedded in `data/manifest.json`. Redistribution notices and
upstream licences are retained in the bundled `data/provenance/` directory.

The HISP snapshot also retains its original Stata file and replication script
for provenance. The notebooks execute the R lab and do not run that script.
