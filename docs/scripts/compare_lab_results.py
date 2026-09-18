"""Compare current R output with immutable, historically verified reference tables."""
import csv
import math
from pathlib import Path

BASELINES = Path(__file__).resolve().parents[1] / "labs/reproducibility/baselines"


def compare(actual: Path, method: str) -> int:
    expected = BASELINES / method / actual.name
    with actual.open() as stream:
        current = list(csv.DictReader(stream))
    with expected.open() as stream:
        reference = list(csv.DictReader(stream))
    assert len(current) == len(reference), f"{actual.name}: changed row support"
    count = 0
    for row, baseline in zip(current, reference):
        assert row.keys() == baseline.keys(), f"{actual.name}: changed columns"
        for key, value in row.items():
            target = baseline[key]
            try:
                x, y = float(value), float(target)
            except ValueError:
                assert value == target, f"{actual.name}: changed {key}"
            else:
                assert math.isfinite(x) and math.isfinite(y)
                assert abs(x-y) <= 1e-7 + 1e-6*abs(y), f"{actual.name}/{key}: {x} != {y}"
                count += 1
    return count
