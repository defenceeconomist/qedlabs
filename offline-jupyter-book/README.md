# Offline QED Labs Jupyter Book

This folder is a transferable, executable Jupyter Book for the five QED methods
reports and 18 teaching labs. It is structured as an independent, applied
self-study extension to Evaluation Academy Module 6: learners move from design
selection through method reports, foundations, diagnostics, extensions, and a
cross-method capstone. It targets Linux x86_64 with Python 3.12 and R 4.5.1 and
requires network access only to PyPI and CRAN while dependencies are installed.

Reading the prebuilt book needs no R environment and no package installation:

```bash
./serve.sh
```

Run `./lab.sh` to work through the notebooks. On its first run it calls
`setup.sh` automatically, checks the prerequisites, and creates the isolated
Python and R environments. The destination must provide Python 3.12, R 4.5.1,
C/C++/Fortran compilers, and GNU Make. The [setup guide](offline-setup.md) gives
the exact Ubuntu/Debian library command; `setup.sh` reports anything missing in
one pass. Rust and CMake are not required.

Maintainers can use `./build.sh` for an executing rebuild, `./verify.sh` for
integrity/offline checks, and `./package.sh` to create the transfer archive.

The book's narrative pages and method guides are maintained in this folder. The
canonical teaching sources remain in `../docs/labs/` in the parent repository;
the generated notebook snapshots should not be edited directly. Maintainers can
refresh them with `python3 scripts/sync_sources.py` and then update
`checksums.sha256` with `python3 scripts/update_checksums.py`.
