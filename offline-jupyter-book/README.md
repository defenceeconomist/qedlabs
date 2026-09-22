# Offline QED Labs Jupyter Book

This folder is a transferable, executable Jupyter Book for the QED teaching
labs. It targets Linux x86_64 with Python 3.12 and R 4.5.1 and requires network
access only to PyPI and CRAN while dependencies are installed.

The destination must already provide C, C++, Fortran, and Rust compilers plus
GNU Make and common development headers; `setup.sh` checks these prerequisites.

```bash
./setup.sh
./serve.sh
```

Use `./lab.sh` for JupyterLab, `./build.sh` for an executing rebuild,
`./verify.sh` for integrity/offline checks, and `./package.sh` to create the
transfer archive.

The canonical teaching sources remain in `../docs/labs/` in the parent
repository. Maintainers can refresh this snapshot with
`python3 scripts/sync_sources.py` and then update `checksums.sha256` with
`python3 scripts/update_checksums.py`.
