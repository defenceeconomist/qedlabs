# QED Labs Notes

Release-aligned baseline: current `main` before this notes update (`913a6c0`, "added footer link").

There are no repository tags or GitHub release refs at the time this file was added, so the latest major release state is treated as the current published Quarto site on `main`.

## Current Site Shape

QED Labs is a Quarto website under `docs/` for quasi-experimental design teaching material. The current major site structure has three primary routes:

- `docs/notes/`: method overviews and source notes.
- `docs/labs/`: applied exercises, reports, and benchmark workflows.
- `docs/slides/`: short teaching decks plus presenter scripts.

The homepage frames the site around a design-first workflow: start from the evaluation design, then choose and implement an estimator.

## Content Baseline

The current major release covers:

- Matching and weighting: overview notes, teaching data, source notes, matching labs, and a long-form matching methods report.
- Synthetic control: overview notes, teaching data, source notes, method reports, mechanics labs, Proposition 99, Basque Country, Kansas augmentation, donor-pool planning, and slide decks.
- Other methods: difference-in-differences, regression discontinuity, method comparison, and method-choice guidance.
- Navigation aids: a notes link graph generated before rendering from `docs/scripts/extract_link_graph.py`.

## Maintenance Rules

- Keep `README.md` focused on repository setup and publishing.
- Use this file for release-aligned editorial notes, site structure decisions, and maintenance context.
- When adding a new method family, update all three surfaces if applicable: notes, labs, and slides.
- When changing note links, render the site so `docs/data/notes_link_graph_payload.json` stays aligned with the Notes section.
- Prefer adding source-specific pages under the relevant method group rather than flattening everything into the overview page.

## Render

```bash
quarto render docs
```

The Quarto pre-render hook refreshes the Notes link graph payload.
