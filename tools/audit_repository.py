#!/usr/bin/env python3
"""Dependency-free structural audit for the public reproducibility package."""

from __future__ import annotations

import argparse
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
warnings: list[str] = []


def read_csv(relative: str) -> list[dict[str, str]]:
    with (ROOT / relative).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def check(condition: bool, message: str) -> None:
    print(f"[{'PASS' if condition else 'FAIL'}] {message}")
    if not condition:
        failures.append(message)


def warn(message: str) -> None:
    print(f"[KNOWN LIMITATION] {message}")
    warnings.append(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="fail on documented scientific limitations")
    args = parser.parse_args()

    required = [
        "README.md", "MANIFEST.md", "AUDIT_REPORT.md", "CONSISTENCY_MATRIX.csv",
        "data/fea_4096/Force_Table_1_7.csv",
        "statistics/raw_run_metrics.csv",
        "benchmark/CEC2019/run_cec2019_comparison.m",
        "benchmark/SPD-DN-NSGA-II/SPD_DN_NSGAII_Optimized.m",
        "maxwell/Project.aedt",
    ]
    check(all((ROOT / item).is_file() for item in required), "required release artifacts exist")

    fea = read_csv("data/fea_4096/Force_Table_1_7.csv")
    keys = ("de [mm]", "g [mm]", "Nn []", "Nc []")
    tuples = {tuple(row[key] for key in keys) for row in fea}
    check(len(fea) == 4096 and len(tuples) == 4096, "FEA factorial has 4,096 unique design rows")
    check(all(len({row[key] for row in fea}) == 8 for key in keys), "each FEA input has eight levels")

    train_keys = {tuple(float(row[key]) for key in keys) for row in fea}
    intermediate = 0
    for name in ("de1", "Nc1", "Nn1"):
        rows = read_csv(f"data/intermediate_grid_168/{name}.csv")
        intermediate += sum(tuple(float(row[key]) for key in keys) not in train_keys for row in rows)
    check(intermediate == 168, "intermediate-grid archive yields 168 off-training-grid rows")

    sweep = read_csv("data/offgrid_airgap_7/g_sweep_de11_Nn14_Nc14_predictions.csv")
    new_rows = [row for row in sweep if row["FEA_source"] == "new intermediate simulation"]
    check(len(sweep) == 15 and len(new_rows) == 7, "air-gap sweep contains 15 locations and seven new FEA cases")

    direct = read_csv("data/pareto_fea_validation_16/published_validation_points_16.csv")
    check(len(direct) == 16 and Counter(row["boundary"] for row in direct) == {"rho_F": 8, "kappa_F": 8},
          "published direct-validation transcription contains 16 rows (8+8)")

    raw = read_csv("statistics/raw_run_metrics.csv")
    counts: defaultdict[tuple[str, str, str], int] = defaultdict(int)
    for row in raw:
        if row["algorithm"] in {"NSGA-II", "DN-NSGA-II", "SPD-DN-NSGA-II"}:
            counts[(row["algorithm"], row["metric"], row["problem"])] += 1
    core = [key for key in counts if key[1] in {"rPSP", "rHV", "IGDX", "IGDF"}]
    check(len(core) == 3 * 4 * 22 and all(counts[key] == 31 for key in core),
          "core benchmark archive has 31 runs for 3 algorithms x 4 metrics x 22 problems")

    aedt = (ROOT / "maxwell/Project.aedt").read_text(encoding="utf-8", errors="ignore")
    check("VariableProp('I', 'UD', '', '5A')" in aedt, "Maxwell project defines the manuscript current I=5 A")

    ablation = read_csv("ablation/paper_run_level.csv")
    stale = [row for row in ablation if int(float(row["FEvals"])) != 10000]
    if stale:
        warn(f"archived ablation has {len(stale)} rows with FEvals != 10000; full corrected rerun is required")
    warn("raw rHV archive reproduces different suite statistics from the manuscript; see AUDIT_REPORT.md")
    warn("PMBRA optimization runner/checkpoint, unrounded 16-row FEA export, solver logs, and timing raw data are absent")

    print(f"\nStructural failures: {len(failures)}; documented limitations: {len(warnings)}")
    if failures:
        return 1
    return 2 if args.strict and warnings else 0


if __name__ == "__main__":
    sys.exit(main())
