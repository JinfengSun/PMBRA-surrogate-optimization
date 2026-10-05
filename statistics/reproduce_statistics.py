"""Rebuild the paper's statistics from separately supplied run-level metrics."""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import friedmanchisquare, mannwhitneyu, rankdata, wilcoxon

ROOT = Path(__file__).resolve().parent
INPUT = ROOT / "raw_run_metrics.csv"
OUT = ROOT / "reproduced_results"
CORE = ["NSGA-II", "DN-NSGA-II", "SPD-DN-NSGA-II"]
PAIRWISE_BASELINES = ["NSGA-II", "DN-NSGA-II", "MMO-DE-CSCD"]
METRICS = ["rPSP", "rHV", "IGDX", "IGDF"]
PROBLEMS = [
    "MMF1", "MMF2", "MMF3", "MMF4", "MMF5", "MMF6", "MMF7", "MMF8",
    "MMF9", "MMF10", "MMF11", "MMF12", "MMF13", "MMF14", "MMF15",
    "MMF1_z", "MMF1_e", "MMF14_a", "MMF15_a", "SYM_PART_simple",
    "SYM_PART_rotated", "Omni_test",
]
MMO_ELIGIBLE = [
    "MMF1", "MMF2", "MMF3", "MMF4", "MMF5", "MMF6", "MMF7", "MMF8",
    "MMF9", "MMF10", "MMF11", "MMF12", "MMF1_z", "MMF1_e",
    "SYM_PART_simple", "SYM_PART_rotated",
]


def holm(values):
    values = np.asarray(values, float)
    adjusted = np.full(values.shape, np.nan)
    finite = np.flatnonzero(np.isfinite(values))
    order = finite[np.argsort(values[finite])]
    running = 0.0
    for rank, index in enumerate(order):
        running = max(running, (len(order) - rank) * values[index])
        adjusted[index] = min(1.0, running)
    return adjusted


def a12_smaller(a, b):
    return float(((a[:, None] < b).sum() + 0.5 * (a[:, None] == b).sum()) / (a.size * b.size))


def values(raw, algorithm, metric, problem):
    x = raw.loc[
        raw.algorithm.eq(algorithm) & raw.metric.eq(metric) & raw.problem.eq(problem),
        "value",
    ].to_numpy(float)
    # Preserve +/-Inf as observed worst/best values; remove only missing runs.
    return x[~np.isnan(x)]


def main():
    raw = pd.read_csv(INPUT)
    OUT.mkdir(parents=True, exist_ok=True)
    pairwise = []
    friedman_rows = []
    posthoc = []

    for metric in METRICS:
        # Native-dimensional rHV is available for every problem, including the
        # four three-objective cases.  The external MMO-DE-CSCD comparison is
        # restricted to the 16 two-variable cases documented in protocol.json.
        for baseline in PAIRWISE_BASELINES:
            eligible = PROBLEMS if baseline in CORE else MMO_ELIGIBLE
            block = []
            for problem in eligible:
                proposed = values(raw, CORE[2], metric, problem)
                control = values(raw, baseline, metric, problem)
                p = mannwhitneyu(proposed, control, alternative="two-sided").pvalue
                block.append({
                    "comparison": f"{CORE[2]} vs {baseline}", "metric": metric,
                    "problem": problem, "n_proposed": proposed.size,
                    "n_baseline": control.size, "median_proposed": np.median(proposed),
                    "median_baseline": np.median(control), "p_raw": p,
                    "A12_probability_proposed_better": a12_smaller(proposed, control),
                })
            for row, adjusted in zip(block, holm([x["p_raw"] for x in block])):
                row["p_holm"] = adjusted
                row["outcome"] = "tie" if adjusted >= 0.05 else (
                    "win" if row["median_proposed"] < row["median_baseline"] else "loss"
                )
                pairwise.append(row)

        eligible = PROBLEMS
        medians = {
            alg: np.array([np.median(values(raw, alg, metric, p)) for p in eligible])
            for alg in CORE
        }
        statistic, p_value = friedmanchisquare(*(medians[a] for a in CORE))
        ranks = np.vstack([rankdata([medians[a][i] for a in CORE]) for i in range(len(eligible))])
        friedman_rows.append({
            "metric": metric, "n_problems": len(eligible),
            "friedman_chi2": statistic, "p_value": p_value,
            **{f"mean_rank_{alg}": ranks[:, i].mean() for i, alg in enumerate(CORE)},
        })
        block = []
        for baseline in CORE[:2]:
            test = wilcoxon(medians[CORE[2]], medians[baseline], alternative="two-sided")
            block.append({"metric": metric, "comparison": f"{CORE[2]} vs {baseline}",
                          "statistic": test.statistic, "p_raw": test.pvalue})
        for row, adjusted in zip(block, holm([x["p_raw"] for x in block])):
            row["p_holm"] = adjusted
            posthoc.append(row)

    pairwise = pd.DataFrame(pairwise)
    win_tie_loss = pairwise.groupby(
        ["comparison", "metric", "outcome"]
    ).size().unstack(fill_value=0).reset_index()
    friedman = pd.DataFrame(friedman_rows)
    posthoc = pd.DataFrame(posthoc)

    pairwise.to_csv(OUT / "mann_whitney_holm_tests.csv", index=False)
    win_tie_loss.to_csv(OUT / "win_tie_loss.csv", index=False)
    friedman.to_csv(OUT / "friedman_across_problems.csv", index=False)
    posthoc.to_csv(OUT / "posthoc_wilcoxon_across_problems.csv", index=False)

    for folder in ["mann_whitney", "holm", "vargha_delaney"]:
        (ROOT / folder).mkdir(exist_ok=True)
        pairwise.to_csv(ROOT / folder / "mann_whitney_holm_tests.csv", index=False)
    for folder in ["holm", "wilcoxon"]:
        (ROOT / folder).mkdir(exist_ok=True)
        posthoc.to_csv(ROOT / folder / "posthoc_wilcoxon_across_problems.csv", index=False)
    (ROOT / "friedman").mkdir(exist_ok=True)
    friedman.to_csv(ROOT / "friedman" / "friedman_across_problems.csv", index=False)
    win_tie_loss.to_csv(ROOT / "win_tie_loss.csv", index=False)

    figure_dir = ROOT.parent / "figures" / "Fig9_data"
    figure_dir.mkdir(parents=True, exist_ok=True)
    friedman.to_csv(figure_dir / "friedman_across_problems.csv", index=False)
    posthoc.to_csv(figure_dir / "posthoc_wilcoxon_across_problems.csv", index=False)
    win_tie_loss.to_csv(figure_dir / "win_tie_loss.csv", index=False)


if __name__ == "__main__":
    main()
