# QED Labs Notes

Release-aligned baseline: current `main` before this notes update (`913a6c0`, "added footer link").

There are no repository tags or GitHub release refs at the time this file was added, so the latest major release state is treated as the current published Quarto site on `main`.

## Current Site Shape

QED Labs is a Quarto website under `docs/` for quasi-experimental design teaching material. The site has two primary routes:

- `docs/notes/`: method overviews and source notes.
- `docs/labs/`: teaching decks, presenter notes, applied exercises, reports, and benchmark workflows grouped by method.

Deck and presenter-note sources remain in `docs/slides/` so their existing URLs stay stable. The former Slides overview is a Quarto alias for Labs, and slide pages use the Labs sidebar.

The homepage frames the site around a design-first workflow: start from the evaluation design, then choose and implement an estimator.

## Content Baseline

The current major release covers:

- Matching and weighting: overview notes, teaching data, source notes, matching labs, and a long-form matching methods report.
- Synthetic control: overview notes, teaching data, source notes, method reports, mechanics labs, Proposition 99, Basque Country, Kansas augmentation, donor-pool planning, and slide decks.
- Interrupted time series: a Seatbelts-based method overview and core deck, presenter script, two real-data workshops on mechanics and design robustness, and one compact synthetic counterfactual-validation lab, all with generated R notebooks.
- Other method notes: difference-in-differences, regression discontinuity, method comparison, and method-choice guidance.
- Navigation aids: a notes link graph generated before rendering from `docs/scripts/extract_link_graph.py`.

## Maintenance Rules

- Keep `README.md` focused on repository setup and publishing.
- Use this file for release-aligned editorial notes, site structure decisions, and maintenance context.
- When adding a new method family, update Notes and Labs; include any teaching decks and presenter notes in the matching Labs method group.
- When changing note links, render the site so `docs/data/notes_link_graph_payload.json` stays aligned with the Notes section.
- Prefer adding source-specific pages under the relevant method group rather than flattening everything into the overview page.

## Render

```bash
quarto render docs
```

The Quarto pre-render hook refreshes the Notes link graph payload.


## DiD teaching expansion — 18 September 2026

- Thirteen source-specific notes connect foundational texts to staggered estimation, inference, pre-testing, sensitivity, and imputation.
- Three paired R/Python labs share checksum-verified upstream data. Python notebook generation is explicit through `notebook-language: python`; existing R sources default to R.
- The introductory deck contains 22 main slides including the cover, with a 45–60 minute script and optional appendix.
- Reproduction runs are separate from Quarto's display-only lab rendering. See the public reproduction record for tested dependencies, estimates, and the Python universal-base bootstrap limitation.
- The first-edition Mixtape URL moved to `mixtape-1ed.netlify.app`; its 2021 chapter notes must not be silently re-labelled as notes on The Remix.

## Regression discontinuity reading expansion — 18 September 2026

- Replaced the placeholder overview with sharp/fuzzy estimands, identification, local estimation, inference, diagnostics and reporting guidance.
- Added six source-specific notes from the Research Library Evaluation texts, plus a reading map and source identifier record.
- The connected MCP endpoint was unavailable; evidence was retrieved through the local library's read-only APIs. Edition, PDF/HTML locator and extraction caveats are explicit.
- Kept the existing regression-discontinuity overview URL and added a dedicated sidebar section. This is a notes expansion; existing DiD labs and slides are unchanged.

## Regression discontinuity labs — 18 September 2026

- Added three paired R/Python exercises: sharp transfer RD, design diagnostics, and fuzzy veteran-status/home-ownership RD. Six downloadable notebooks are generated from display-only Quarto pages.
- Both languages load identical immutable `causaldata` `.rda` files with SHA-256 verification. The manifest records score orientation, sample restrictions and covariate missingness.
- Isolated Python/R locks, setup instructions and `docs/scripts/validate_rdd_labs.py` support independent reproduction. All six notebooks ran from fresh kernels with cold downloads; 362 matched numerical values passed absolute `1e-7` plus relative `1e-6` tolerance.
- Checkpoints distinguish conventional and bias-corrected results. Density/covariate checks do not certify identification; fuzzy inference remains conditional on the coarse quarterly score model and IV assumptions.
- Full comparison outputs and environment versions are in `docs/labs/reproducibility/rdd-verified-results.json`. GitHub publication continues through the existing workflow.

## Bibliography and reading layout refactor - 18 September 2026

- `evaluation-bibliography.bib` is the only bibliography, inherited from the Quarto project by HTML, RevealJS, and PDF outputs. It includes uncited entries from the retired local files.
- Duplicate SCM citation keys were migrated: `AbadieGard03` to `abadie2003economic`, `AbadieDiamondHainmueller10` to `abadie2010synthetic`, `Abadie_Using_Synthetic_Controls_2021` to `abadie2021using`, and `BenMichael_Feller_Rothstein_2021_AugmentedSCM` to `benmichael2021augmented`.
- Distinct chapters, editions, and package/manual references remain separate, including entries that share a book DOI. Supplementary source URLs were retained; the root L'Hour author spelling was preserved and the Abadie-Imbens journal whitespace normalized.
- Run `python3 docs/scripts/validate_bibliography.py` and `python3 docs/scripts/test_validate_bibliography.py` to check citation resolution, duplicate keys, and project inheritance. The publication workflow runs both checks.
- Overview pages share compact resource rows, with method descriptions and related downloads grouped together. Website typography and reading widths are centralized in the HTML stylesheet; presentation themes and statistical code are unchanged.
- Validation found eight existing `/resolver.html` source links in matching and SCM reading notes. They refer to a library resolver that is not part of this site; their source provenance has been preserved pending a confirmed replacement endpoint.

## Offline R labs and practical guides - 18 September 2026

- Supersedes the paired-language distribution described above: the 18 labs and worksheets now provide R-only Jupyter notebooks, standalone Quarto documents, and complete offline ZIPs. Former Python HTML pages redirect to their R equivalents; Python remains only build/validation tooling.
- All 16 required teaching datasets are committed under `docs/labs/data/`, with hashes, variable documentation and distribution notices. HISP's original CSV, Stata file and replication script were recovered from commit `3152e4d`. Existing package-source snapshots preserve original-file hashes where available.
- The data loader has no online fallback. Missing packages stop execution with setup guidance rather than triggering installation. Data updates are deliberate maintainer operations; site builds never fetch or regenerate data.
- Generated documents embed cited metadata from the root bibliography. Pandoc converts notebook citations and Markdown structurally; figure dimensions are translated to IRkernel settings. Empty-output notebooks remain deterministic and are checked against their canonical lab pages.
- Added executable practical articles on ITS, canonical/modern DiD, and sharp/fuzzy RD. Their examples use the local snapshots and link to the relevant exercises and reading maps.
- Validation: all 16 executable labs ran in fresh R kernels and all 18 standalone documents rendered with outbound networking blocked except loopback. The two SCM planning worksheets have no executable cells. R-only DiD and RDD numerical regressions match the original verified reference tables, including the DiD sensitivity extension and RDD negative tests.
- The full 92-source site rendered without citation warnings, including four RevealJS decks and both bibliography-affected PDF reports. Static checks covered 105 HTML outputs and all 54 per-lab download targets. Browser checks covered 24 views at 375, 768 and 1440 pixels, the Notes graph, redirects, mobile navigation and actual Quarto downloads. Representative clean/executed notebooks were also checked in JupyterLab.
- CI installs software before entering a loopback-only network namespace for notebook and standalone-document checks. The existing Pages workflow still publishes only on `main`; feature-branch delivery does not deploy.
