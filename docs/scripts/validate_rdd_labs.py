#!/usr/bin/env python3
"""Execute offline R RD labs, negative tests and historical numerical checks."""
import argparse
import json
from pathlib import Path
from compare_lab_results import compare
from validate_offline_labs import ROOT, check_data, execute

TABLES = {
    "foundations": ["results", "metrics"],
    "diagnostics": ["density_results", "covariates", "sensitivity", "placebos", "donuts"],
    "fuzzy": ["iv_results", "fuzzy_results", "stages"],
}
FAILURES = '''
expect_failure <- function(expression, message) {
  failure <- tryCatch({force(expression); NULL}, error=function(e) conditionMessage(e))
  stopifnot(!is.null(failure), grepl(message, failure, fixed=TRUE))
}
expect_failure(require_support(seq(-0.009,-0.001,length.out=30),0.01), "Insufficient")
expect_failure(require_support(rep(c(-0.005,0.005),30),0.01), "Insufficient")
name <- names(jsonlite::fromJSON(file.path(qed_data_directory(), "manifest.json")))[1]
spec <- jsonlite::fromJSON(file.path(qed_data_directory(), "manifest.json"), simplifyVector=FALSE)[[name]]
path <- file.path(qed_data_directory(), spec$file)
bytes <- readBin(path, "raw", n=file.info(path)$size)
writeBin(charToRaw("corrupt fixture"), path)
expect_failure(qed_data(name), "checksum mismatch")
unlink(path)
expect_failure(qed_data(name), "Missing bundled data")
writeBin(bytes, path)
invisible(qed_data(name))
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".qedlabs-validation/rdd-offline")
    args = parser.parse_args()
    check_data()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / "summary.json").unlink(missing_ok=True)
    results = {}
    for name, tables in TABLES.items():
        export = FAILURES
        if name == "fuzzy":
            export += '\nexpect_failure(safe_wald(0.1,0), "Unusable first stage")\n'
        for table in tables:
            export += f'write.csv({table}, "r-{name}-{table}.csv", row.names=FALSE)\n'
        stem = f"regression-discontinuity-{name}-lab"
        execute(stem, out, export=export)
        for table in tables:
            filename = f"r-{name}-{table}.csv"
            results[filename] = compare(out / stem / filename, "rdd")
    (out / "summary.json").write_text(json.dumps(results, indent=2)+"\n")
    print(results)


if __name__ == "__main__":
    main()
