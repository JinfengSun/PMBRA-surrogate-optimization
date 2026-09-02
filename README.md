# Surrogate-Assisted Multi-objective Structural Optimization of a PMBRA

Public code, training data, and reproducibility material for the paper
"Surrogate-Assisted Multi-objective Structural Optimization of a
Permanent-Magnet Bridged Reluctance Actuator."

This release contains source code and the 4096-case FEA training table. Saved
DNN predictions/metrics, optimization runs, benchmark results, and statistical
result tables are intentionally excluded.

## Contents

- `data/public/Force Table 1_7.csv`: public full-factorial FEA training data.
- `surrogate_model/dnn_model.py`: standalone 4-64-32-16-1 DNN definition.
- `surrogate_model/train_validate_dnn.py`: DNN training and validation workflow.
- `surrogate_model/compare_surrogates.py`: simpler-model comparison workflow.
- `optimization/algorithms/`: NSGA-II, DN-NSGA-II, and SPD-DN-NSGA-II sources.
- `benchmarks/cec2019/`: complete supplied benchmark driver, problem functions,
  reference PS/PF datasets, and indicator functions.
- `statistics/`: statistical-analysis source code, without result files.
- `simulation/`: sanitized ANSYS Maxwell 2D project, instructions, and screenshots.
- `figures/`: plotting source code, without generated DNN-result figures.
- `paper/`: matching manuscript source and bibliography.

## Environment

Python 3.10-3.12 is recommended:

```bash
python -m venv .venv
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

MATLAB is required for SPD-DN-NSGA-II and CEC2019. The exact MATLAB release and
toolboxes still need to be supplied by the authors.

## DNN reproduction

The training table is already located at:

```text
data/public/Force Table 1_7.csv
```

Run:

```bash
python surrogate_model/train_validate_dnn.py
```

The exact network architecture is exposed separately in
`surrogate_model/dnn_model.py` for reuse and inspection.

The script writes newly generated outputs to the ignored directory
`surrogate_model/results/`; no pretrained model or previously generated DNN
results are distributed. External off-grid validation additionally requires
`de1.csv`, `Nc1.csv`, and `Nn1.csv` under `data/private/`. These three files are
not included and may be requested from the corresponding author.

To compare fixed simpler surrogate models after producing the DNN outputs:

```bash
python surrogate_model/compare_surrogates.py
```

## SPD-DN-NSGA-II

The proposed implementation is called from MATLAB as:

```matlab
[ps, pf] = SPD_DN_NSGAII_Optimized(fname, xl, xu, n_obj, pop_size, max_gen);
```

Only source code is included. Saved populations, Pareto fronts, metric tables,
and algorithm run results are excluded.

The updated package also includes the supplied standalone `NSGAII.m` and
`DN_NSGAII.m` baselines under `optimization/algorithms/`.

## CEC2019 benchmark

`benchmarks/cec2019/run_cec2019_comparison.m` contains the 22-problem, 31-run
configuration and now has the supplied problem functions, reference PS/PF data,
indicators, and all three algorithm sources. The manuscript uses `5000*n_var`
evaluations while the supplied driver sets `10000*n_var`; resolve this before
claiming exact paper reproduction. Generated results are Git-ignored.

## Statistical analysis

`statistics/reproduce_statistics.py` contains the analysis logic. Algorithm
run-level inputs and all generated statistical tables are excluded. After an
authorized `statistics/results/raw_run_metrics.csv` is supplied, run:

```bash
python statistics/reproduce_statistics.py
```

## Simulation project

`simulation/PMBRA_Maxwell2D.aedt` is the released magnetostatic Maxwell 2D
project. Its header identifies ANSYS Electronics Desktop 2025 R1. The project
contains `Maxwell2DDesign1`, `Setup1`, parameter sweeps, and the force-table
report definition. No solved `.aedtresults` cache is included; open and solve
the project locally to regenerate outputs. See `simulation/README.md`.

## Data and result availability

The 4096-case training dataset is public in this repository. External validation
sweeps may be made available upon reasonable request. DNN and optimization
results are deliberately not included; users should regenerate them using the
released code and authorized dependencies.

See `docs/FILE_MANIFEST.md`, `docs/EXCLUDED_FILES.md`, and
`docs/RELEASE_CHECKLIST.md` before publication.

## License

No license has been selected. A `LICENSE` file must be added before release.

## Citation

Add the final article DOI and Zenodo DOI after acceptance and deposition.
