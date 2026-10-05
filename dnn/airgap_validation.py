from __future__ import annotations

import os
import random
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
os.environ.setdefault("TF_DETERMINISTIC_OPS", "1")
os.environ.setdefault("TF_ENABLE_ONEDNN_OPTS", "0")

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.preprocessing import StandardScaler


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "offgrid_airgap_7"
LATEX_OUT = ROOT / "figures" / "Fig6_data"
OUT.mkdir(parents=True, exist_ok=True)
LATEX_OUT.mkdir(parents=True, exist_ok=True)

FEATURES = ["de [mm]", "g [mm]", "Nn []", "Nc []"]
TARGET = "Force1.Force_y [kNewton]"
SEEDS = [7, 21, 42, 84, 126]

DE_MM = 11.0
NN = 14.0
NC = 14.0
MODEL_DEPTH_M = 1.0
G_VALUES = np.round(np.arange(0.30, 1.0001, 0.05), 2)

# FEA results at the seven newly simulated intermediate gaps.
# Values are force-per-unit-depth magnitudes in kN/m for a 1 m model depth.
NEW_FEA_QF_KN_PER_M = {
    0.35: 29.40038,
    0.45: 26.98964,
    0.55: 24.45335,
    0.65: 21.62897,
    0.75: 19.04032962,
    0.85: 16.50170487,
    0.95: 14.01722267,
}


def build_dnn(seed: int) -> tf.keras.Model:
    random.seed(seed)
    np.random.seed(seed)
    tf.keras.utils.set_random_seed(seed)
    model = tf.keras.Sequential(
        [
            tf.keras.layers.Input(shape=(4,)),
            tf.keras.layers.Dense(64, activation="relu"),
            tf.keras.layers.Dense(32, activation="relu"),
            tf.keras.layers.Dense(16, activation="relu"),
            tf.keras.layers.Dense(1, activation="linear"),
        ]
    )
    model.compile(optimizer=tf.keras.optimizers.Adam(
        learning_rate=1e-3, beta_1=0.9, beta_2=0.999, epsilon=1e-7
    ), loss="mse")
    return model


def main() -> None:
    train = pd.read_csv(ROOT / "data" / "fea_4096" / "Force_Table_1_7.csv")
    x_train = train[FEATURES].to_numpy(dtype=np.float32)
    y_train = train[TARGET].to_numpy(dtype=np.float32)

    sweep = pd.DataFrame(
        {
            "de [mm]": DE_MM,
            "g [mm]": G_VALUES,
            "Nn []": NN,
            "Nc []": NC,
        }
    )
    x_sweep = sweep[FEATURES].to_numpy(dtype=np.float32)

    scaler = StandardScaler().fit(x_train)
    x_train_scaled = scaler.transform(x_train)
    x_sweep_scaled = scaler.transform(x_sweep)

    seed_predictions = []
    for seed in SEEDS:
        model = build_dnn(seed)
        model.fit(
            x_train_scaled,
            y_train,
            validation_split=0.10,
            epochs=150,
            batch_size=32,
            verbose=0,
            shuffle=True,
        )
        prediction = model.predict(x_sweep_scaled, verbose=0).ravel()
        sweep[f"DNN_seed_{seed}_Force_y_kN"] = prediction
        seed_predictions.append(prediction)
        tf.keras.backend.clear_session()

    prediction_matrix = np.vstack(seed_predictions)
    sweep["DNN_ensemble_Force_y_kN"] = prediction_matrix.mean(axis=0)
    sweep["DNN_ensemble_std_kN"] = prediction_matrix.std(axis=0, ddof=1)
    sweep["DNN_qF_kN_per_m"] = (
        np.abs(sweep["DNN_ensemble_Force_y_kN"]) / MODEL_DEPTH_M
    )

    fea = pd.read_csv(ROOT / "data" / "intermediate_grid_168" / "de1.csv")
    fea = fea[
        np.isclose(fea["de [mm]"], DE_MM)
        & np.isclose(fea["Nn []"], NN)
        & np.isclose(fea["Nc []"], NC)
        & (fea["g [mm]"] >= 0.30 - 1e-9)
        & (fea["g [mm]"] <= 1.00 + 1e-9)
    ].copy()
    fea["g_key"] = fea["g [mm]"].round(2)
    fea_map = fea.set_index("g_key")[TARGET]

    sweep["FEA_Force_y_kN"] = sweep["g [mm]"].map(fea_map)
    sweep["FEA_qF_kN_per_m"] = (
        np.abs(sweep["FEA_Force_y_kN"]) / MODEL_DEPTH_M
    )
    sweep["FEA_source"] = np.where(
        sweep["FEA_qF_kN_per_m"].notna(),
        "data/intermediate_grid_168/de1.csv",
        "new intermediate simulation",
    )
    for gap, qf_value in NEW_FEA_QF_KN_PER_M.items():
        row = np.isclose(sweep["g [mm]"], gap)
        sweep.loc[row, "FEA_qF_kN_per_m"] = qf_value
        # Retain the established Maxwell convention: force acts along -y.
        sweep.loc[row, "FEA_Force_y_kN"] = -qf_value * MODEL_DEPTH_M

    known = sweep["FEA_qF_kN_per_m"].notna()
    mape = np.mean(
        np.abs(
            (sweep.loc[known, "DNN_qF_kN_per_m"]
             - sweep.loc[known, "FEA_qF_kN_per_m"])
            / sweep.loc[known, "FEA_qF_kN_per_m"]
        )
    ) * 100.0

    csv_path = OUT / "g_sweep_de11_Nn14_Nc14_predictions.csv"
    figure_csv_path = LATEX_OUT / "g_sweep_de11_Nn14_Nc14_predictions.csv"
    sweep.to_csv(csv_path, index=False, encoding="utf-8-sig")
    sweep.to_csv(figure_csv_path, index=False, encoding="utf-8-sig")

    # Match the visual style and aspect ratio of the existing Fig. 6 slices.
    fig, ax = plt.subplots(figsize=(12.0, 7.0))
    ax.plot(
        sweep.loc[known, "g [mm]"],
        sweep.loc[known, "FEA_qF_kN_per_m"],
        color="#1f77b4",
        linestyle="-",
        marker="o",
        markersize=6,
        linewidth=2.5,
        label=r"True | $d_e$=11.0, $N_c$=14.0, $N_n$=14.0",
    )
    ax.plot(
        sweep["g [mm]"],
        sweep["DNN_qF_kN_per_m"],
        color="#1f77b4",
        linestyle="-.",
        marker="x",
        markersize=6,
        linewidth=2.0,
        label=rf"Pred | MAPE={mape:.2f}\%",
    )

    ax.set_xlabel(r"Air-gap length $g$ [mm]", fontsize=14)
    ax.set_ylabel(r"Force per unit model depth $q_F$ [kN/m]", fontsize=14)
    ax.set_title(
        r"Comparison of Predicted and FEA Force-per-Unit-Depth Trend on $g$",
        fontsize=14,
        pad=16,
    )
    ax.set_xticks(G_VALUES)
    ax.tick_params(axis="both", labelsize=11)
    ax.grid(True, linestyle="--", linewidth=0.8, alpha=0.65)
    ax.legend(loc="upper left", fontsize=10)
    fig.tight_layout()

    pdf_path = LATEX_OUT / "comparison_of_predicted_and_true_force_trend_on_g_qF.pdf"
    png_path = OUT / "comparison_of_predicted_and_true_force_trend_on_g_qF.png"
    fig.savefig(pdf_path, bbox_inches="tight")
    fig.savefig(png_path, dpi=300, bbox_inches="tight")
    plt.close(fig)

    print(sweep[[
        "g [mm]",
        "DNN_qF_kN_per_m",
        "DNN_ensemble_std_kN",
        "FEA_qF_kN_per_m",
        "FEA_source",
    ]].to_string(index=False))
    print(f"\nMAPE on all 15 sweep points: {mape:.4f}%")
    print(f"CSV: {csv_path}")
    print(f"Figure data CSV: {figure_csv_path}")
    print(f"PDF: {pdf_path}")
    print(f"PNG: {png_path}")


if __name__ == "__main__":
    main()
