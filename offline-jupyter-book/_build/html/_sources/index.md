# Quasi-Experimental Design Labs

This self-contained Jupyter Book contains 18 teaching labs covering matching and
weighting, difference-in-differences, regression discontinuity, synthetic control,
and interrupted time series.

The book is designed for a restricted Linux system whose only permitted package
repositories are CRAN and PyPI. All teaching data are bundled locally, the one
non-CRAN R package is vendored with its licence and checksum, and the generated
HTML uses no remote runtime assets.

## Quick start

From the extracted book folder:

```bash
./setup.sh
./serve.sh
```

Open the local address printed by `serve.sh`. To work through the notebooks,
run `./lab.sh`. To reproduce all results and rebuild the site, run `./build.sh`.

When the book is running on the Mac mini, open the
[Caddy-served luke-mac-mini copy](http://luke-mac-mini.local/qedlabs-book/)
from the local network.

```{note}
External links provide optional background reading. They are not used to load
data, execute notebooks, render mathematics, or build this book.
```

## Contents

- **16 executable R notebooks** with cached figures and results.
- **2 writing-only synthetic-control worksheets**.
- **16 pinned teaching datasets**, their provenance, and integrity metadata.
- A folder-local Python environment and R library created by `setup.sh`.
- A prebuilt static site under `_build/html/`.
