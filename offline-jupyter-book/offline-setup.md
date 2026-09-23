# Running the offline book

## Read without installing packages

The archive includes the complete rendered book. From the extracted folder, run:

```bash
./serve.sh
```

Open the address printed in the terminal. This does not install R, Python
packages, or any notebook dependencies. If a web server is unavailable, open
`_build/html/index.html` directly.

## Run the exercises

Run one command:

```bash
./lab.sh
```

The first run starts `setup.sh` automatically. It checks the system, creates
`.venv/` and `.r-library/` inside the book folder, installs the locked
dependencies, registers the R kernel, and then opens JupyterLab. Later runs
start JupyterLab immediately.

Setup needs:

- Linux x86_64
- Python 3.12
- R 4.5.1
- C, C++, and Fortran compilers and GNU Make
- Network access to PyPI and CRAN during the first setup only

On Ubuntu or Debian, install the remaining system libraries once with:

```bash
sudo apt-get install build-essential curl gfortran libcurl4-openssl-dev \
  libfontconfig1-dev libfreetype-dev libnode-dev libx11-dev \
  libzmq3-dev pandoc
```

`setup.sh` reports all missing tools or Debian packages together and prints the
corresponding install command.

Quarto, Node, npm, conda, CMake, Rust/Cargo, GitHub access, and external data
downloads are not required. Classical synthetic-control exercises use explicit
base-R simplex optimisation, and the DiD sensitivity extension uses a transparent
calibrated-bias screen rather than a conic-optimisation stack.

The book contains 23 notebook pages: 20 executable R notebooks and three
writing-only synthetic-control pages. Narrative guides provide the learning
route; the five methods reports appear before the labs in their respective
sections, and the HISP exercise closes the book as a cross-method capstone.

## Other commands

```bash
./setup.sh       # prepare the environments without opening JupyterLab
./build.sh       # set up if needed, execute notebooks, and rebuild HTML
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
