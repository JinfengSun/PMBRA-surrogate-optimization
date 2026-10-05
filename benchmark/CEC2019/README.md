# CEC2019 multimodal multi-objective benchmark

This directory contains the 22-problem, 31-run comparison driver, problem definitions, reference PS/PF data, and CR/HV/IGD indicator implementations.

The driver resolves paths relative to itself and calls the three sources under `benchmark/NSGA-II/`, `benchmark/DN-NSGA-II/`, and `benchmark/SPD-DN-NSGA-II/`. Its paper-reproduction settings are:

- population size: `100*n_var`;
- total objective-function evaluations: `10000*n_var`, including the initial population;
- runs per problem: 31;
- deterministic run seed: `20260826 + (problem_index-1)*31 + (run_index-1)`;
- the same run seed is reset before each competing algorithm.

Run:

```matlab
run('benchmark/CEC2019/run_cec2019_comparison.m')
```

Generated files are written to `benchmark/CEC2019/results/`. The archived historical runs did not preserve their MATLAB RNG states; `benchmark/benchmark_config/seed_schedule.csv` defines deterministic seeds for new paired reruns.

`indicators/Hypervolume_calculation.m` evaluates hypervolume in the native objective-space dimension and therefore includes the four three-objective problems.

Before public release, verify redistribution rights and retain citations/license notices required by the original benchmark authors. `CEC2019_ORIGINAL_README.txt` and `SOURCE_NOTE.txt` preserve the available provenance notes.
