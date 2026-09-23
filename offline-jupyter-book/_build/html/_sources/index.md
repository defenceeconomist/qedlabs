# Quasi-Experimental Design Labs

*An applied, self-study extension to Evaluation Academy Module 6*

This book turns the concepts introduced in the Evaluation Task Force's
[Quasi-Experimental Designs module](https://www.gov.uk/government/publications/etf-evaluation-academy-20-resources)
into reproducible design practice. It is an independent learning resource, not
an official replacement for the Academy materials.

The Academy module introduces regression discontinuity, difference-in-differences,
synthetic control, matching, and pre-post designs. This book goes further: you
will specify an estimand, inspect the assignment process, build a credible
comparison, test the design's implications, run the analysis in R, and explain
what the evidence can and cannot support.

## Start here

1. Read [From Module 6 to applied practice](academy-extension.md) to see what
   prior knowledge the book assumes and what it adds.
2. Use [Choosing a design](choosing-a-design.md) before opening a method report.
3. Follow [How to study this book](study-guide.md) for a core, full, or
   method-specific route.
4. Open [Running the offline book](offline-setup.md) when you are ready to run a notebook.

If you already know which method you need, open its **Guide** in the navigation.
Each guide gives the entry conditions, recommended sequence, and a completion
check before linking to the report and labs.

## What you should be able to do

By the end of a route through the book, you should be able to:

- identify the assignment mechanism and the comparison that identifies the effect;
- state the target population, treatment, outcome, timing, and estimand;
- distinguish assumptions from diagnostic evidence;
- choose a method from the policy and data context rather than from software availability;
- run and interrogate a reproducible R analysis; and
- write a design judgement that reports limitations as clearly as estimates.

## Suggested first route

For a compact survey, read [Choosing a design](choosing-a-design.md), then the
five method guides and each method's foundations lab. Finish with the
[HISP cross-method capstone](notebooks/hisp-ie-practice-lab.ipynb), which compares
the answers produced by several evaluation designs.

For deeper study, add the methods report and diagnostic or extension labs in
each section. The sequence is deliberate: **design first, estimation second,
diagnostics before conclusions**.

## Run the book

From the extracted book folder:

```bash
./serve.sh
```

Open the local address printed by `serve.sh`; reading does not require package
installation. To work through the notebooks, run `./lab.sh`. Its first run
prepares the isolated Python and R environments automatically. To reproduce all
results and rebuild the site, run `./build.sh`, which also sets up automatically
when needed.

When the book is running on the Mac mini, open the
[Caddy-served luke-mac-mini copy](http://luke-mac-mini.local/qedlabs-book/)
from the local network.

```{note}
All data and runtime assets needed for the exercises are local. External links
provide optional context and are not required to use or rebuild the book.
```

## Included materials

- **Five methods reports** connecting identification, estimation, diagnostics,
  and reporting.
- **20 executable R notebooks** with cached figures and results.
- **Three writing-only pages**: two synthetic-control design worksheets and its
  narrative report.
- **16 pinned teaching datasets** with provenance and integrity metadata.
- A folder-local Python environment and R library created by `setup.sh`.
- A prebuilt static site under `_build/html/`.
