# Proposed public file manifest

## Data and simulation

- `data/public/Force Table 1_7.csv`: 4096-case FEA training dataset.
- `simulation/PMBRA_Maxwell2D.aedt`: sanitized Maxwell 2D project.
- `simulation/3D_Maxwell_Run_Instructions.md` and screenshots.

## DNN and analysis code

- `surrogate_model/dnn_model.py`: standalone 4-64-32-16-1 DNN definition.
- `surrogate_model/train_validate_dnn.py`: training and validation workflow.
- `surrogate_model/compare_surrogates.py`: simpler-surrogate comparison.
- `statistics/reproduce_statistics.py`: statistical-analysis source only.
- `figures/plot_jr_fe_trend.py`: paper-related plotting source.

## Optimization and CEC2019

- `optimization/algorithms/NSGAII.m`.
- `optimization/algorithms/DN_NSGAII.m`.
- `optimization/algorithms/SPD_DN_NSGAII_Optimized.m`.
- `benchmarks/cec2019/run_cec2019_comparison.m`.
- `benchmarks/cec2019/problems/*.m`: 22 problem definitions.
- `benchmarks/cec2019/reference_data/*.mat`: 22 reference PS/PF datasets.
- `benchmarks/cec2019/indicators/*.m`: CR, hypervolume, and IGD.
- Supplied benchmark provenance notes.

## Documentation

- `README.md`, dependency and ignore files, paper source, bibliography, and the
  files under `docs/`.

Saved DNN outputs, trained weights, optimization populations/fronts, algorithm
metric tables, generated statistics, figures, caches, and logs are excluded.
