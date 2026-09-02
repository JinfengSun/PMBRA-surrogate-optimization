# Optimization algorithms

`algorithms/` contains the three MATLAB implementations supplied for the paper:

- `NSGAII.m`: standard NSGA-II baseline.
- `DN_NSGAII.m`: decision-niched NSGA-II baseline.
- `SPD_DN_NSGAII_Optimized.m`: proposed SPD-DN-NSGA-II implementation.

The helper routines used by each implementation are embedded as local functions
in the corresponding `.m` file. No saved populations, Pareto fronts, metric
tables, figures, or `.mat` run results are distributed.

Run the complete comparison with
`../benchmarks/cec2019/run_cec2019_comparison.m`. The benchmark driver adds the
algorithm directory to MATLAB using repository-relative paths.

The source archive does not include explicit per-file license headers. Confirm
authorship and redistribution rights for the baseline and CEC-derived material
before making the GitHub repository public.
