#!/usr/bin/env python3
"""Execute the three offline R DiD notebooks and check verified numerical results."""
import argparse
import json
from pathlib import Path
from compare_lab_results import compare
from validate_offline_labs import ROOT, check_data, execute

EXPORTS = {
    "foundations": 'write.csv(data.frame(estimate=did_manual), "r-foundations.csv", row.names=FALSE)',
    "staggered-diagnostics": '''write.csv(data.frame(estimate=coef(twfe_fit)[["post"]]), "r-twfe.csv", row.names=FALSE)
write.csv(data.frame(event=as.integer(sub(".*::", "", names(coef(sun_abraham_fit)))), estimate=unname(coef(sun_abraham_fit))), "r-sa.csv", row.names=FALSE)
write.csv(bacon_summary, "r-bacon.csv", row.names=FALSE)''',
    "modern-estimators": '''write.csv(data.frame(cohort=att_never$group, time=att_never$t, estimate=att_never$att), "r-gt.csv", row.names=FALSE)
write.csv(data.frame(estimate=aggregate_simple$overall.att), "r-simple.csv", row.names=FALSE)
write.csv(sensitivity_results, "r-sensitivity.csv", row.names=FALSE)''',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".qedlabs-validation/did-offline")
    parser.add_argument("--extensions", action="store_true", help="retained for compatibility; the R sensitivity extension always runs")
    args = parser.parse_args()
    check_data()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / "summary.json").unlink(missing_ok=True)
    results = {}
    for name, export in EXPORTS.items():
        stem = f"difference-in-differences-{name}-lab"
        execute(stem, out, export=export)
        for path in (out / stem).glob("r-*.csv"):
            results[path.name] = compare(path, "did")
    (out / "summary.json").write_text(json.dumps(results, indent=2)+"\n")
    print(results)


if __name__ == "__main__":
    main()
