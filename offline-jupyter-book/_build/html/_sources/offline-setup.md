# Offline setup

## Supported system

- Linux x86_64
- Python 3.12
- R 4.5.1
- C, C++, Fortran, and Rust/Cargo 1.78 or newer compilers, GNU Make, and common
  development libraries; Rust is required by CRAN's `clarabel`/`HonestDiD` stack
- Network access to PyPI and CRAN during `setup.sh` only

Quarto, Node, npm, conda, GitHub access, and external data downloads are not
required.

## Install the isolated environments

Run once after extracting or moving the folder:

```bash
./setup.sh
```

This creates `.venv/` and `.r-library/` inside the book folder. It installs the
hash-locked Python environment from PyPI, restores the R lock from CRAN, installs
the vendored `augsynth` source locally, and writes a relocatable R kernelspec into
the Python environment. Its launcher resolves `.r-library/` relative to its own
location, so the completed folder can move without embedding its old path.

## Read, run, and rebuild

```bash
./serve.sh       # read the prebuilt HTML book
./lab.sh         # run or edit notebooks in JupyterLab
./build.sh       # execute changed notebooks and rebuild HTML
./verify.sh      # audit checksums, pages, links, and remote assets
```

The book uses Jupyter Book's execution cache. Delete `_build/.jupyter_cache/` before
`./build.sh` only when you deliberately want to force every executable notebook
to run again.

## Transfer

Run `./package.sh` after a successful build. It creates
`dist/qedlabs-offline-jupyter-book-linux-x86_64.tar.gz` and a matching SHA-256
file. The archive includes sources, data, vendored inputs, and prebuilt HTML but
excludes machine-specific environments and caches.
