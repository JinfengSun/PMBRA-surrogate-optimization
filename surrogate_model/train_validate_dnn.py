from __future__ import annotations

import json
import os
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
os.environ.setdefault("TF_DETERMINISTIC_OPS", "1")

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import tensorflow as tf
from scipy.interpolate import RBFInterpolator
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import KFold, train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import PolynomialFeatures, StandardScaler

from dnn_model import build_dnn


ROOT = Path(__file__).resolve().parents[1]
TRAIN_DATA = ROOT / "data" / "public"
VALIDATION_DATA = ROOT / "data" / "private"
OUT = ROOT / "surrogate_model" / "results"
OUT.mkdir(parents=True, exist_ok=True)

FEATURES = ["de [mm]", "g [mm]", "Nn []", "Nc []"]
TARGET = "Force1.Force_y [kNewton]"
SEEDS = [7, 21, 42, 84, 126]
HOLDOUT_SEED = 42
STACK_THICKNESS_MM = 0.2


def metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, float]:
    err = np.asarray(y_pred).ravel() - np.asarray(y_true).ravel()
    result = {
        "MAE_kN": float(mean_absolute_error(y_true, y_pred)),
        "RMSE_kN": float(mean_squared_error(y_true, y_pred) ** 0.5),
        "MaxAE_kN": float(np.max(np.abs(err))),
        "R2": float(r2_score(y_true, y_pred)),
        "Bias_kN": float(np.mean(err)),
    }
    result.update({
        "MAE_N_at_1m_depth": result["MAE_kN"] * 1000.0,
        "RMSE_N_at_1m_depth": result["RMSE_kN"] * 1000.0,
        "MaxAE_N_at_1m_depth": result["MaxAE_kN"] * 1000.0,
    })
    return result


def load_external(train: pd.DataFrame) -> pd.DataFrame:
    pieces = []
    for filename, axis in [("de1.csv", "de"), ("Nc1.csv", "Nc"), ("Nn1.csv", "Nn")]:
        d = pd.read_csv(VALIDATION_DATA / filename)
        d = d.rename(columns={"Force1.Force_y [kNewton]": TARGET})
        d["source"] = filename
        d["sweep_axis"] = axis
        train_keys = set(map(tuple, train[FEATURES].to_numpy()))
        is_off_grid = [tuple(row) not in train_keys for row in d[FEATURES].to_numpy()]
        d = d.loc[is_off_grid, FEATURES + [TARGET, "source", "sweep_axis"]]
        pieces.append(d)
    return pd.concat(pieces, ignore_index=True)


def main() -> None:
    train = pd.read_csv(TRAIN_DATA / "Force Table 1_7.csv")
    X = train[FEATURES].to_numpy(dtype=np.float32)
    y = train[TARGET].to_numpy(dtype=np.float32)
    external = load_external(train)
    X_ext = external[FEATURES].to_numpy(dtype=np.float32)
    y_ext = external[TARGET].to_numpy(dtype=np.float32)

    # Reproducible 80/20 hold-out matching the split stated in the paper.
    all_indices = np.arange(len(X))
    train_idx, test_idx = train_test_split(
        all_indices, test_size=0.20, random_state=HOLDOUT_SEED, shuffle=True
    )
    holdout_scaler = StandardScaler().fit(X[train_idx])
    holdout_model = build_dnn(HOLDOUT_SEED)
    holdout_history = holdout_model.fit(
        holdout_scaler.transform(X[train_idx]),
        y[train_idx],
        validation_split=0.10,
        epochs=150,
        batch_size=32,
        verbose=0,
        shuffle=True,
    )
    holdout_prediction = holdout_model.predict(
        holdout_scaler.transform(X[test_idx]), verbose=0
    ).ravel()
    holdout_record = {
        "model": "DNN",
        "split_seed": HOLDOUT_SEED,
        "training_rows_before_internal_validation": len(train_idx),
        "test_rows": len(test_idx),
        **metrics(y[test_idx], holdout_prediction),
        "final_train_MSE_kN2": float(holdout_history.history["loss"][-1]),
        "final_internal_validation_MSE_kN2": float(holdout_history.history["val_loss"][-1]),
    }
    pd.DataFrame([holdout_record]).to_csv(
        OUT / "holdout_metrics.csv", index=False, encoding="utf-8-sig"
    )
    holdout_table = train.iloc[test_idx][FEATURES + [TARGET]].copy()
    holdout_table["prediction_kN"] = holdout_prediction
    holdout_table["error_kN"] = holdout_prediction - y[test_idx]
    holdout_table["abs_error_N_at_1m_depth"] = np.abs(holdout_table["error_kN"]) * 1000.0
    holdout_table.to_csv(OUT / "holdout_predictions.csv", index=False, encoding="utf-8-sig")
    np.savez(
        OUT / "holdout_split_indices.npz",
        train_indices=train_idx,
        test_indices=test_idx,
    )
    tf.keras.backend.clear_session()

    fold_records = []
    fold_predictions = []
    kfold = KFold(n_splits=5, shuffle=True, random_state=20260826)
    for fold, ((train_idx, test_idx), seed) in enumerate(zip(kfold.split(X), SEEDS), start=1):
        scaler = StandardScaler().fit(X[train_idx])
        model = build_dnn(seed)
        history = model.fit(
            scaler.transform(X[train_idx]),
            y[train_idx],
            validation_split=0.10,
            epochs=150,
            batch_size=32,
            verbose=0,
            shuffle=True,
        )
        pred = model.predict(scaler.transform(X[test_idx]), verbose=0).ravel()
        rec = {"model": "DNN", "fold": fold, "seed": seed, **metrics(y[test_idx], pred)}
        rec["final_train_MSE_kN2"] = float(history.history["loss"][-1])
        rec["final_validation_MSE_kN2"] = float(history.history["val_loss"][-1])
        fold_records.append(rec)
        part = train.iloc[test_idx][FEATURES + [TARGET]].copy()
        part["prediction_kN"] = pred
        part["error_kN"] = pred - y[test_idx]
        part["abs_error_kN"] = np.abs(part["error_kN"])
        part["fold"] = fold
        fold_predictions.append(part)
        tf.keras.backend.clear_session()

        poly = make_pipeline(StandardScaler(), PolynomialFeatures(degree=3, include_bias=False), Ridge(alpha=1e-6))
        poly.fit(X[train_idx], y[train_idx])
        poly_pred = poly.predict(X[test_idx])
        fold_records.append({"model": "Cubic polynomial", "fold": fold, "seed": seed, **metrics(y[test_idx], poly_pred)})

        x_scaler = StandardScaler().fit(X[train_idx])
        rbf = RBFInterpolator(x_scaler.transform(X[train_idx]), y[train_idx], kernel="thin_plate_spline", neighbors=128)
        rbf_pred = rbf(x_scaler.transform(X[test_idx]))
        fold_records.append({"model": "Local RBF", "fold": fold, "seed": seed, **metrics(y[test_idx], rbf_pred)})

    fold_df = pd.DataFrame(fold_records)
    cv_pred = pd.concat(fold_predictions, ignore_index=True)
    cv_pred.to_csv(OUT / "dnn_cv_predictions.csv", index=False, encoding="utf-8-sig")
    fold_df.to_csv(OUT / "cv_fold_metrics.csv", index=False, encoding="utf-8-sig")

    summary = (
        fold_df.groupby("model")[["MAE_kN", "RMSE_kN", "MaxAE_kN", "MAE_N_at_1m_depth", "RMSE_N_at_1m_depth", "MaxAE_N_at_1m_depth", "R2", "Bias_kN"]]
        .agg(["mean", "std"])
        .reset_index()
    )
    summary.columns = ["_".join(filter(None, map(str, col))).rstrip("_") for col in summary.columns]
    summary.to_csv(OUT / "cv_summary.csv", index=False, encoding="utf-8-sig")

    stratified = []
    for g, part in cv_pred.groupby("g [mm]"):
        stratified.append({"group_type": "air_gap", "group": str(g), "n": len(part), **metrics(part[TARGET], part["prediction_kN"])})
    boundary_mask = np.zeros(len(cv_pred), dtype=bool)
    for feature in FEATURES:
        boundary_mask |= cv_pred[feature].isin([train[feature].min(), train[feature].max()]).to_numpy()
    for name, mask in [("boundary", boundary_mask), ("interior", ~boundary_mask)]:
        part = cv_pred.loc[mask]
        stratified.append({"group_type": "domain", "group": name, "n": len(part), **metrics(part[TARGET], part["prediction_kN"])})
    pd.DataFrame(stratified).to_csv(OUT / "dnn_stratified_metrics.csv", index=False, encoding="utf-8-sig")

    ext_predictions = external.copy()
    dnn_ext_preds = []
    for seed in SEEDS:
        scaler = StandardScaler().fit(X)
        model = build_dnn(seed)
        model.fit(scaler.transform(X), y, validation_split=0.10, epochs=150, batch_size=32, verbose=0, shuffle=True)
        pred = model.predict(scaler.transform(X_ext), verbose=0).ravel()
        ext_predictions[f"DNN_seed_{seed}"] = pred
        dnn_ext_preds.append(pred)
        tf.keras.backend.clear_session()
    ext_predictions["DNN_ensemble_prediction_kN"] = np.mean(dnn_ext_preds, axis=0)

    poly = make_pipeline(StandardScaler(), PolynomialFeatures(degree=3, include_bias=False), Ridge(alpha=1e-6))
    poly.fit(X, y)
    ext_predictions["Polynomial_prediction_kN"] = poly.predict(X_ext)
    x_scaler = StandardScaler().fit(X)
    rbf = RBFInterpolator(x_scaler.transform(X), y, kernel="thin_plate_spline", neighbors=128)
    ext_predictions["RBF_prediction_kN"] = rbf(x_scaler.transform(X_ext))
    ext_predictions.to_csv(OUT / "external_offgrid_predictions.csv", index=False, encoding="utf-8-sig")

    ext_records = []
    for model_name, col in [
        ("DNN ensemble", "DNN_ensemble_prediction_kN"),
        ("Cubic polynomial", "Polynomial_prediction_kN"),
        ("Local RBF", "RBF_prediction_kN"),
    ]:
        ext_records.append({"model": model_name, "sweep_axis": "All", "n": len(external), **metrics(y_ext, ext_predictions[col])})
        for axis, part in ext_predictions.groupby("sweep_axis"):
            ext_records.append({"model": model_name, "sweep_axis": axis, "n": len(part), **metrics(part[TARGET], part[col])})
    ext_metrics = pd.DataFrame(ext_records)
    ext_metrics.to_csv(OUT / "external_offgrid_metrics.csv", index=False, encoding="utf-8-sig")

    # Convert the unit-depth surrogate error to device force for the N_s span
    # represented by the final candidate tables. Numerically, kN/m * mm = N.
    selected_ns_min, selected_ns_max = 188, 300
    dnn_cv = summary.loc[summary["model"] == "DNN"].iloc[0]
    dnn_external = ext_metrics.loc[
        (ext_metrics["model"] == "DNN ensemble")
        & (ext_metrics["sweep_axis"] == "All")
    ].iloc[0]
    scaled_rows = []
    for source, mae_kn, rmse_kn in [
        ("five-fold CV mean", float(dnn_cv["MAE_kN_mean"]), float(dnn_cv["RMSE_kN_mean"])),
        ("external off-grid", float(dnn_external["MAE_kN"]), float(dnn_external["RMSE_kN"])),
    ]:
        for ns in (selected_ns_min, selected_ns_max):
            stack_mm = ns * STACK_THICKNESS_MM
            scaled_rows.append({
                "validation_source": source,
                "N_s": ns,
                "stack_depth_mm": stack_mm,
                "MAE_N": mae_kn * stack_mm,
                "RMSE_N": rmse_kn * stack_mm,
            })
    pd.DataFrame(scaled_rows).to_csv(
        OUT / "device_level_error_bounds_N.csv", index=False, encoding="utf-8-sig"
    )

    fig, ax = plt.subplots(figsize=(6.4, 5.2), constrained_layout=True)
    ax.scatter(cv_pred[TARGET], cv_pred["prediction_kN"], s=9, alpha=0.45, edgecolors="none")
    lim = [min(cv_pred[TARGET].min(), cv_pred["prediction_kN"].min()), max(cv_pred[TARGET].max(), cv_pred["prediction_kN"].max())]
    ax.plot(lim, lim, "k--", lw=1.2)
    ax.set(xlabel="FEA force (kN)", ylabel="Cross-validated DNN prediction (kN)")
    ax.grid(alpha=0.2)
    fig.savefig(OUT / "dnn_cv_true_vs_predicted.png", dpi=300)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(7.2, 4.8), constrained_layout=True)
    plot_data = [ext_predictions.loc[ext_predictions.sweep_axis == a, "DNN_ensemble_prediction_kN"] - ext_predictions.loc[ext_predictions.sweep_axis == a, TARGET] for a in ["de", "Nc", "Nn"]]
    ax.boxplot(plot_data, tick_labels=[r"$d_e$ sweep", r"$N_c$ sweep", r"$N_n$ sweep"], showmeans=True)
    ax.axhline(0, color="k", lw=1)
    ax.set_ylabel("Prediction error (kN)")
    ax.grid(axis="y", alpha=0.2)
    fig.savefig(OUT / "dnn_external_offgrid_errors.png", dpi=300)
    plt.close(fig)

    manifest = {
        "training_dataset": "Force Table 1_7.csv",
        "training_rows": len(train),
        "external_files": ["de1.csv", "Nc1.csv", "Nn1.csv"],
        "external_offgrid_rows": len(external),
        "features": FEATURES,
        "target": TARGET,
        "cross_validation": "5-fold shuffled KFold, random_state=20260826",
        "holdout": "80/20 shuffled split, random_state=42; indices saved in holdout_split_indices.npz",
        "dnn_seeds": SEEDS,
        "dnn_architecture": "4-64-32-16-1; ReLU hidden layers; linear output; Adam (learning rate 0.001, beta_1 0.9, beta_2 0.999, epsilon 1e-7); MSE; 150 epochs; batch size 32; shuffle enabled; no regularization or early stopping",
        "preprocessing": "StandardScaler fitted only on each training partition; target not standardized",
        "determinism": "CUDA disabled; TF_DETERMINISTIC_OPS=1; Python, NumPy, and TensorFlow seeds set per run",
        "force_unit_conversion": "The 2-D Maxwell target corresponds to a 1 m model depth. Direct kN errors are multiplied by 1000 for N at 1 m depth. Device-level error in N equals the numerical kN/m error multiplied by stack depth N_s*0.2 mm.",
        "hardware_mode": "CPU (CUDA disabled for reproducibility)",
        "software": {"python": os.sys.version, "tensorflow": tf.__version__, "numpy": np.__version__, "pandas": pd.__version__},
    }
    (OUT / "protocol.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(summary.to_string(index=False))
    print("\nExternal off-grid validation:\n", ext_metrics.to_string(index=False))


if __name__ == "__main__":
    main()
