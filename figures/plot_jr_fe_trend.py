from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "figures" / "generated" / "jr_fe_trend"
OUT.parent.mkdir(parents=True, exist_ok=True)


def main():
    tau = np.linspace(0.0, 1.0, 1001)
    jr = np.cos(0.5 * np.pi * tau) ** 4
    marks = np.array([0.0, 0.25, 0.50, 0.75, 1.0])
    mark_values = np.cos(0.5 * np.pi * marks) ** 4

    plt.rcParams.update(
        {
            "font.family": "serif",
            "font.serif": ["Times New Roman", "DejaVu Serif"],
            "mathtext.fontset": "stix",
            "font.size": 9.2,
            "axes.labelsize": 9.5,
            "axes.titlesize": 10.0,
            "xtick.labelsize": 8.5,
            "ytick.labelsize": 8.5,
            "legend.fontsize": 8.5,
        }
    )

    fig, ax = plt.subplots(figsize=(4.25, 2.75), constrained_layout=True)
    color = "#1f5a94"
    ax.plot(tau, jr, color=color, linewidth=2.2, label=r"$JR=\cos^4(\pi\tau/2)$")
    ax.fill_between(tau, 0, jr, color=color, alpha=0.10)
    ax.scatter(marks, mark_values, s=26, color="#c43c39", edgecolor="white", linewidth=0.7, zorder=3)

    offsets = [(5, -15), (3, 7), (4, 7), (4, 7), (-23, 7)]
    labels = ["1.000", "0.729", "0.250", "0.021", "0.000"]
    for x, y, label, offset in zip(marks, mark_values, labels, offsets):
        ax.annotate(label, (x, y), xytext=offset, textcoords="offset points", fontsize=7.8, color="#7e2523")

    ax.axvline(0.5, color="#777777", linewidth=0.8, linestyle="--", alpha=0.75)
    ax.text(0.12, 0.82, "High SPD participation", transform=ax.transAxes, color=color, fontsize=8.2)
    ax.text(0.58, 0.43, "SPD participation\nprogressively reduced", transform=ax.transAxes,
            color="#4d4d4d", fontsize=8.2, ha="center")
    ax.text(0.995, 0.12, "GA remains active", transform=ax.transAxes, color="#4d4d4d",
            fontsize=8.0, ha="right")

    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1.05)
    ax.set_xticks(marks)
    ax.set_yticks(np.linspace(0, 1, 6))
    ax.set_xlabel(r"Consumed FE progress, $\tau(FE)=(FE-N)/(MaxFE-N)$")
    ax.set_ylabel(r"SPD jumping rate, $JR$")
    ax.set_title("FE-adaptive participation of the supplementary SPD branch")
    ax.grid(True, color="#d9d9d9", linewidth=0.6, alpha=0.8)
    ax.spines[["top", "right"]].set_visible(False)
    ax.legend(loc="upper right", frameon=False, handlelength=2.5)

    fig.savefig(OUT.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(OUT.with_suffix(".png"), dpi=300, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()
