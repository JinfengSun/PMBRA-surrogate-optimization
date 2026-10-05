# PMBRA surrogate-assisted optimization

Reproducibility package for the manuscript **“Surrogate-Assisted Multi-objective Structural Optimization of a Permanent-Magnet Bridged Reluctance Actuator.”**

## Repository contents

- `data/`: the 4,096-case full-factorial FEA table, the 168-point intermediate grid, the seven newly simulated air-gap points within the 15-point sweep, and the available Pareto-region FEA validation workbooks.
- `dnn/`: DNN definition, training, cross-validation, intermediate-grid validation, air-gap validation, configurations, archived results, and preserved split information.
- `surrogate_baselines/`: linear, ridge, quadratic, decision-tree, and k-nearest-neighbor surrogate comparison material.
- `benchmark/`: NSGA-II, DN-NSGA-II, SPD-DN-NSGA-II, CEC2019 functions/reference data, and the deterministic rerun schedule.
- `ablation/`: SPD-off, constant-JR, and q = 64, 512, and 1024 ablation settings with the archived run-level and summary results.
- `statistics/`: run-level metrics and Mann–Whitney, Holm, Vargha–Delaney, Friedman, and Wilcoxon outputs.
- `PMBRA_optimization/`: optimization inputs, raw Pareto results, constraint results, and direct FEA validation files.
- `figures/`: source data grouped for Figs. 6–12.
- `maxwell/`: the ANSYS Maxwell project and run notes.
- `environment/`: recorded Python, MATLAB, and ANSYS versions.

See `MANIFEST.md` for the file-level mapping and `checksums.txt` for SHA-256 integrity values.

## Python environment

```bash
python -m pip install -r requirements.txt
```

The recorded core environment is Python 3.12.13, TensorFlow 2.21.0, NumPy 2.5.2, and pandas 3.0.5. The DNN validation protocol uses an 80/20 hold-out split with seed 42, shuffled five-fold cross-validation with split seed 20260826, and network seeds 7, 21, 42, 84, and 126.

The archived DNN implementation combines hold-out, five-fold, and 168-point intermediate-grid validation in one pipeline. Therefore, `dnn/cross_validation.py` and `dnn/intermediate_validation.py` preserve the same complete validation script under task-oriented filenames.

## Benchmark protocol

The CEC2019 comparison uses 22 problems, 31 runs, population size `100*n_var`, and a total evaluation budget of `10000*n_var`, including initial-population evaluations. The supplied rerun seed schedule starts at 20260826. The original RNG states of the archived historical runs were not preserved; the schedule applies to new reruns.

Run the principal reproducibility workflows from the repository root:

```bash
python dnn/train_dnn.py
python surrogate_baselines/run_surrogate_baselines.py
python statistics/reproduce_statistics.py
python tools/audit_repository.py
```

```matlab
run('benchmark/CEC2019/run_cec2019_comparison.m')
run_ablation('smoke')   % after addpath('ablation')
run_ablation('paper')   % full 31-run study
```

The DNN scripts train on the signed Maxwell `Force_y` output; reported `q_F` is its positive magnitude. Since the model depth is 1 m, the numerical magnitude in kN equals `q_F` in kN/m. Actuator thrust is then `F [N] = q_F [kN/m] * (0.2*N_s) [mm]`.

For release review, `python tools/audit_repository.py --strict` intentionally returns exit code 2 while the scientific limitations below remain. Regenerate SHA-256 values after any release edit with `python tools/generate_checksums.py`.

## Known archive limitations

- `maxwell/Project.aedt` stores default `I = 5 A`.
- No `Project.aedtresults` cache or solver-profile/convergence export is included, so the archived mesh/pass/runtime claims cannot be independently checked from this package.
- The unrounded raw 16-row direct-FEA export is unavailable. `published_validation_points_16.csv` contains only the displayed values from manuscript Tables 13 and 14.
- The manuscript ablation uses a fixed `MaxFE = 10000` for every problem. The archived rows contain 10,000 evaluations for two-variable cases but 15,000 for three-variable cases, so the archived ablation is not equal-budget. The corrected script passes an exact MaxFE override and stops every paper-mode run at 10,000. The pre-audit script also configured the constant-JR variant as `3/8`, whereas the manuscript states `JR = 0.1`.
- Recalculation from `statistics/raw_run_metrics.csv` gives the reported rPSP, IGDX, and IGDF suite tests, but gives rHV Friedman `chi^2 = 15.6364`, `p = 0.0004024`, not the manuscript's `chi^2 = 28.78`, `p = 5.64e-7`.
- Source scripts for the PMBRA-specific optimization, Figs. 8--12, and the 100-repeat timing experiment are not included; only their available data/products and protocol metadata are archived.

## Data boundary

The repository excludes solved `*.aedtresults` caches, temporary files, manuscript sources, and local virtual environments. Third-party CEC2019 materials retain their original provenance and terms. See `AUDIT_REPORT.md` for the release audit and unresolved blockers.
