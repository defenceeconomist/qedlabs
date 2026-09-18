#!/usr/bin/env python3
"""Execute paired DiD notebooks and compare equivalent point estimates.

Run from the repository root in the documented Python/R environment.
Outputs (executed notebooks, CSVs, summary) go to an ignored build directory.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import json
import nbformat
from nbclient import NotebookClient
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]

def execute(stem: str, out: Path, export: str, extension: bool = False) -> None:
    nb = nbformat.read(ROOT / 'docs/labs/notebooks' / (stem + '.ipynb'), as_version=4)
    if 'modern-estimators-lab' in stem and not extension:
        start = next(i for i, c in enumerate(nb.cells) if c.cell_type == 'markdown' and '## Optional Extension:' in c.source)
        nb.cells = nb.cells[:start]
    nb.cells.append(nbformat.v4.new_code_cell(export))
    print('Executing', stem, 'extension' if extension else 'core', flush=True)
    try:
        NotebookClient(nb, timeout=600, resources={'metadata': {'path': str(out)}},
                       kernel_name=nb.metadata.kernelspec.name).execute()
    finally:
        nbformat.write(nb, out / (stem + ('-extension' if extension else '') + '.ipynb'))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / '.qedlabs-validation')
    parser.add_argument('--extensions', action='store_true', help='also run HonestDiD in a fresh R kernel')
    args = parser.parse_args(); out = args.output.resolve(); out.mkdir(parents=True, exist_ok=True)
    exports = {
        'foundations': ('write.csv(data.frame(estimate=did_manual), "r-foundations.csv", row.names=FALSE)',
                        'pd.DataFrame({"estimate": [did_manual]}).to_csv("python-foundations.csv", index=False)'),
        'staggered-diagnostics': ('''write.csv(data.frame(estimate=coef(twfe_fit)[["post"]]), "r-twfe.csv", row.names=FALSE)
write.csv(data.frame(event=as.integer(sub(".*::", "", names(coef(sun_abraham_fit)))), estimate=unname(coef(sun_abraham_fit))), "r-sa.csv", row.names=FALSE)
write.csv(bacon_summary, "r-bacon.csv", row.names=FALSE)''',
                                  '''pd.DataFrame({"estimate": [twfe.coef()["post"]]}).to_csv("python-twfe.csv", index=False)
pd.DataFrame({"event": sa.index, "estimate": sa["Estimate"]}).to_csv("python-sa.csv", index=False)'''),
        'modern-estimators': ('''write.csv(data.frame(cohort=att_never$group, time=att_never$t, estimate=att_never$att), "r-gt.csv", row.names=FALSE)
write.csv(data.frame(estimate=aggregate_simple$overall.att), "r-simple.csv", row.names=FALSE)''',
                              '''gt.reset_index().rename(columns={"ATT": "estimate"})[["cohort", "time", "estimate"]].to_csv("python-gt.csv", index=False)
aggregations["simple"].rename(columns={"ATT": "estimate"})[["estimate"]].to_csv("python-simple.csv", index=False)'''),
    }
    for suffix, (r_export, python_export) in exports.items():
        execute(f'difference-in-differences-{suffix}-lab', out, r_export)
        execute(f'difference-in-differences-{suffix}-python-lab', out, python_export)
    checks = {}
    for name, keys in [('foundations', []), ('twfe', []), ('sa', ['event']), ('gt', ['cohort', 'time']), ('simple', [])]:
        r = pd.read_csv(out / f'r-{name}.csv'); p = pd.read_csv(out / f'python-{name}.csv')
        if keys:
            both = r.merge(p, on=keys, suffixes=('_r', '_p'), how='outer', indicator=True)
            assert both['_merge'].eq('both').all(), f'{name}: support differs'
            x, y = both.estimate_r.to_numpy(), both.estimate_p.to_numpy()
        else:
            x, y = r.estimate.to_numpy(), p.estimate.to_numpy()
        error = float(np.max(np.abs(x-y)))
        assert np.allclose(x, y, atol=1e-7, rtol=1e-6), f'{name}: point estimates differ by {error}'
        checks[name] = {'max_absolute_difference': error, 'estimates_compared': len(x)}
    if args.extensions:
        execute('difference-in-differences-modern-estimators-lab', out,
                'write.csv(sensitivity_results, "r-sensitivity.csv", row.names=FALSE)', extension=True)
    (out / 'summary.json').write_text(json.dumps(checks, indent=2) + '\n')
    print(json.dumps(checks, indent=2))

if __name__ == '__main__':
    main()
