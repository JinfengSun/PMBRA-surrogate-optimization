from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LinearRegression, Ridge
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import KFold
from sklearn.neighbors import KNeighborsRegressor
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import PolynomialFeatures, StandardScaler
from sklearn.tree import DecisionTreeRegressor


ROOT = Path(__file__).resolve().parents[1]
TRAIN_DATA = ROOT / "data" / "public"
VALIDATION_DATA = ROOT / "data" / "private"
OUT = ROOT / "surrogate_model" / "comparison_results"
OUT.mkdir(parents=True, exist_ok=True)

FEATURES = ["de [mm]", "g [mm]", "Nn []", "Nc []"]
TARGET = "Force1.Force_y [kNewton]"


def metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, float]:
    error = np.asarray(y_pred).ravel() - np.asarray(y_true).ravel()
    return {
        "MAE_kN": float(mean_absolute_error(y_true, y_pred)),
        "RMSE_kN": float(mean_squared_error(y_true, y_pred) ** 0.5),
        "MaxAE_kN": float(np.max(np.abs(error))),
        "R2": float(r2_score(y_true, y_pred)),
        "Bias_kN": float(np.mean(error)),
    }


def model_factories() -> dict[str, callable]:
    # The model list and hyperparameters are fixed before examining results.
    return {
        "Linear regression": lambda seed: make_pipeline(StandardScaler(), LinearRegression()),
        "Ridge regression": lambda seed: make_pipeline(StandardScaler(), Ridge(alpha=1.0)),
        "Quadratic polynomial": lambda seed: make_pipeline(
            StandardScaler(),
            PolynomialFeatures(degree=2, include_bias=False),
            Ridge(alpha=1e-6),
        ),
        "Shallow decision tree": lambda seed: DecisionTreeRegressor(
            max_depth=8, min_samples_leaf=8, random_state=seed
        ),
        "kNN regression": lambda seed: make_pipeline(
            StandardScaler(), KNeighborsRegressor(n_neighbors=8, weights="distance", p=2)
        ),
    }


def load_external(train: pd.DataFrame) -> pd.DataFrame:
    training_keys = set(map(tuple, train[FEATURES].to_numpy()))
    pieces = []
    for filename, axis in [("de1.csv", "de"), ("Nc1.csv", "Nc"), ("Nn1.csv", "Nn")]:
        frame = pd.read_csv(VALIDATION_DATA / filename)
        keep = [tuple(row) not in training_keys for row in frame[FEATURES].to_numpy()]
        frame = frame.loc[keep, FEATURES + [TARGET]].copy()
        frame["sweep_axis"] = axis
        frame["source"] = filename
        pieces.append(frame)
    return pd.concat(pieces, ignore_index=True)


def main() -> None:
    data = pd.read_csv(TRAIN_DATA / "Force Table 1_7.csv")
    external = load_external(data)
    x = data[FEATURES].to_numpy(dtype=float)
    y = data[TARGET].to_numpy(dtype=float)
    x_external = external[FEATURES].to_numpy(dtype=float)
    y_external = external[TARGET].to_numpy(dtype=float)

    fold_rows = []
    fold_predictions = []
    splitter = KFold(n_splits=5, shuffle=True, random_state=20260826)
    splits = list(splitter.split(x))
    for model_name, factory in model_factories().items():
        for fold, (train_index, test_index) in enumerate(splits, start=1):
            model = factory(20260826 + fold)
            model.fit(x[train_index], y[train_index])
            prediction = model.predict(x[test_index])
            fold_rows.append({"model": model_name, "fold": fold, **metrics(y[test_index], prediction)})
            part = data.iloc[test_index][FEATURES + [TARGET]].copy()
            part["model"] = model_name
            part["fold"] = fold
            part["prediction_kN"] = prediction
            fold_predictions.append(part)

    fold_metrics = pd.DataFrame(fold_rows)
    fold_metrics.to_csv(OUT / "simple_models_cv_fold_metrics.csv", index=False, encoding="utf-8-sig")
    pd.concat(fold_predictions, ignore_index=True).to_csv(
        OUT / "simple_models_cv_predictions.csv", index=False, encoding="utf-8-sig"
    )
    cv_summary = (
        fold_metrics.groupby("model")[["MAE_kN", "RMSE_kN", "MaxAE_kN", "R2", "Bias_kN"]]
        .agg(["mean", "std"])
        .reset_index()
    )
    cv_summary.columns = ["_".join(filter(None, map(str, column))).rstrip("_") for column in cv_summary.columns]
    cv_summary.to_csv(OUT / "simple_models_cv_summary.csv", index=False, encoding="utf-8-sig")

    external_rows = []
    external_predictions = external.copy()
    for model_name, factory in model_factories().items():
        model = factory(20260826)
        model.fit(x, y)
        prediction = model.predict(x_external)
        column = model_name.replace(" ", "_") + "_prediction_kN"
        external_predictions[column] = prediction
        external_rows.append(
            {"model": model_name, "sweep_axis": "All", "n": len(external), **metrics(y_external, prediction)}
        )
        for axis in ["de", "Nc", "Nn"]:
            mask = external["sweep_axis"].eq(axis).to_numpy()
            external_rows.append(
                {"model": model_name, "sweep_axis": axis, "n": int(mask.sum()), **metrics(y_external[mask], prediction[mask])}
            )
    external_predictions.to_csv(
        OUT / "simple_models_external_predictions.csv", index=False, encoding="utf-8-sig"
    )
    external_metrics = pd.DataFrame(external_rows)
    external_metrics.to_csv(OUT / "simple_models_external_metrics.csv", index=False, encoding="utf-8-sig")

    dnn_cv = pd.read_csv(ROOT / "surrogate_model" / "results" / "cv_summary.csv")
    dnn_cv = dnn_cv.loc[dnn_cv["model"].eq("DNN")].copy()
    combined_cv = pd.concat([dnn_cv, cv_summary], ignore_index=True, sort=False)
    combined_cv["RMSE_rank"] = combined_cv["RMSE_kN_mean"].rank(method="min")
    combined_cv["MAE_rank"] = combined_cv["MAE_kN_mean"].rank(method="min")
    combined_cv.to_csv(OUT / "combined_cv_ranking.csv", index=False, encoding="utf-8-sig")

    prior_external = pd.read_csv(
        ROOT / "surrogate_model" / "results" / "external_offgrid_metrics.csv"
    )
    prior_external = prior_external.loc[
        prior_external["model"].eq("DNN ensemble") & prior_external["sweep_axis"].eq("All")
    ].copy()
    combined_external = pd.concat(
        [prior_external, external_metrics.loc[external_metrics["sweep_axis"].eq("All")]],
        ignore_index=True,
        sort=False,
    )
    combined_external["RMSE_rank"] = combined_external["RMSE_kN"].rank(method="min")
    combined_external["MAE_rank"] = combined_external["MAE_kN"].rank(method="min")
    combined_external.to_csv(OUT / "combined_external_ranking.csv", index=False, encoding="utf-8-sig")

    protocol = {
        "purpose": "Pre-specified comparison of simpler surrogate models against the existing DNN",
        "selection_rule": "No model was selected, tuned, retained, or omitted based on whether it beat the DNN",
        "cross_validation": "Same five shuffled KFold splits as DNN; random_state=20260826",
        "external_validation": "Same 168 archived off-grid 2D FEA points as DNN",
        "models": list(model_factories()),
        "target": TARGET,
        "features": FEATURES,
    }
    (OUT / "protocol.json").write_text(json.dumps(protocol, indent=2), encoding="utf-8")

    print("Cross-validation ranking (lower RMSE is better):")
    print(combined_cv[["model", "MAE_kN_mean", "RMSE_kN_mean", "R2_mean", "RMSE_rank"]].sort_values("RMSE_rank").to_string(index=False))
    print("\nIndependent 168-point FEA ranking (lower RMSE is better):")
    print(combined_external[["model", "MAE_kN", "RMSE_kN", "R2", "RMSE_rank"]].sort_values("RMSE_rank").to_string(index=False))


if __name__ == "__main__":
    main()
