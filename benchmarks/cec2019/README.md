# CEC2019 multimodal multi-objective benchmark

This directory now contains the complete benchmark material found in the
updated workspace:

- `run_cec2019_comparison.m`: 22-problem, 31-run comparison driver.
- `problems/`: 22 MATLAB problem definitions.
- `reference_data/`: reference Pareto-set/front `.mat` files containing `PS`
  and `PF`; these are benchmark references, not algorithm run results.
- `indicators/`: CR, hypervolume, and IGD implementations.
- `CEC2019_ORIGINAL_README.txt` and `SOURCE_NOTE.txt`: supplied provenance notes.

From MATLAB, run:

```matlab
run('benchmarks/cec2019/run_cec2019_comparison.m')
```

The driver resolves all paths from its own location and calls the three sources
under `optimization/algorithms/`. Newly generated output is written to
`benchmarks/cec2019/results/`, which is excluded by `.gitignore`.

The supplied driver uses `10000*n_var` objective evaluations, whereas the
manuscript text reports `5000*n_var`. This release preserves the newly supplied
driver setting; the authors must confirm the exact paper-reproduction budget.

Before public release, verify redistribution rights and add citations/license
notices required by the original CEC2019 problem and reference-data authors.
