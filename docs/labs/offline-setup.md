# Running a QED Lab Offline

Extract the complete lab ZIP into a writable directory. Keep its Quarto document,
R Jupyter notebook and `data/` folder together. The notebook and document load
only local files, check dataset hashes, and never install packages or fetch data.
Individual document downloads need the matching data ZIP extracted beside them.

## Prepare the software once

Software installation is separate from running a lab and may need internet access.
Use R 4.5.1, Quarto, JupyterLab or Jupyter Notebook, and the IRkernel R kernel.
The first analysis cell lists the lab-specific packages. Install those plus
`digest`, `jsonlite`, `knitr`, `rmarkdown` and `IRkernel` in advance.
Register the kernel with `IRkernel::installspec()` from R, then select **R** in Jupyter.

The DiD and RDD setup pages on the website link the tested R lockfiles. For the
Kansas lab, use `augsynth` at commit `7a90ea48877fae7925a72cb50bc03a315bc7c042`.
The repository's `docs/scripts/setup_lab_environment.R` prepares the combined
teaching environment; it is a setup tool, not part of notebook execution.

## Run

In Jupyter, open the `.ipynb`, select R, restart the kernel and run all cells.
Outputs are intentionally empty in the distributed notebook. The two SCM design
worksheets contain writing prompts rather than executable analyses.

To render the `.qmd`, run `quarto render NAME.qmd` in the extracted directory.
It embeds its cited references and needs no website checkout. External reading
links are optional; they are not data sources used during execution.

## Data integrity

`data/manifest.json` records dataset sources, variable names and checksums.
`data/provenance/` retains documentation and license notices. These teaching
snapshots are not interchangeable with similarly named datasets from other packages.
Do not change an expected checksum to bypass an error. Restore the supplied file.

HISP's original Stata script is included for provenance. Run the R lab, not that
script: the historical Stata script contains its own online package installers.
