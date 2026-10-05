# Final reproducibility audit

Audit date: 2026-10-04. Sources compared: the latest `00revision2/LaTeX_springer/template1.tex`, `00revision2/Response.docx`, and this release tree. The row-level comparison is in `CONSISTENCY_MATRIX.csv`.

## Outcome

The package is structurally auditable and its principal DNN data, validation protocol, benchmark scope, force convention, environment, and Maxwell current agree with the manuscript/Response. Code defects found during the audit were corrected in the repository: the air-gap input path, SPD final partial-budget handling, post-GA FE-normalized coefficient, DN nearest-neighbor tournament, runtime FE assertions, and median-run plotting selection.

The latest manuscript source also contained one displaced mesh-table cell. Case A at mesh scale 1.0 was corrected to 21,023 triangles and 2 adaptive passes, matching the archived workbook and the intended six-column layout.

The package is **not a complete independent reproduction bundle** for every numerical claim. The following scientific evidence gaps remain and no values were invented or rewritten to conceal them:

1. `statistics/raw_run_metrics.csv` reproduces rHV Friedman chi-square 15.6364 and p=0.0004024, rather than manuscript/Response 28.78 and 5.64e-7; post-hoc values also differ.
2. Historical ablation rows for three-variable problems used 15,000 evaluations rather than the stated fixed 10,000, and the historical constant-JR setting predates the corrected JR=0.1 configuration. A full 31-run corrected ablation is required before its numerical table can be claimed as reproduced.
3. The PMBRA objective-evaluation runner and trained model checkpoint linking DNN training to the released Pareto products are absent.
4. The 16-row direct-FEA CSV is a transcription of rounded manuscript Tables 13 and 14. The unrounded raw export needed to independently recover the exact aggregate statistics is absent.
5. Maxwell solved caches/convergence logs, the raw 100-repeat timing record, and several exact figure-generation scripts are absent. Response statements that those materials are archived are therefore not substantiated by this tree.
6. Historical benchmark RNG states were not preserved. The supplied seed schedule defines deterministic new runs, not bitwise recreation of the historical archive.

## Verification commands

```bash
python tools/audit_repository.py
python statistics/reproduce_statistics.py
python surrogate_baselines/run_surrogate_baselines.py
```

```matlab
addpath('ablation'); run_ablation('smoke')
run('benchmark/CEC2019/run_cec2019_comparison.m')  % full 22 x 31 study
```

Run `python tools/audit_repository.py --strict` in release review: exit code 2 means the documented scientific limitations still exist; exit code 1 means a structural check failed.

## Verification completed in this audit

- Dependency-free structural audit: all checks passed; three documented limitation classes remain.
- Full DNN workflow in the recorded core environment: hold-out MAE/RMSE 0.2838503/0.3586185 kN; five-fold MAE/RMSE 0.2671028/0.3509824 kN; 168-point MAE/RMSE 0.1050586/0.1527661 kN.
- Air-gap workflow: 15/15 FEA values loaded, including seven new simulations; all-point MAPE 0.5432%.
- Five pre-specified surrogate baselines: regenerated rankings agree with the archived manuscript comparison.
- Statistical workflow: regenerated all output tables and independently exposed the documented rHV mismatch.
- MATLAB ablation smoke test: all ten runs stopped at MaxFE=1000. A forced three-variable partial-generation test also stopped exactly at FE=1000 with 350 SPD evaluations.
- MATLAB static analysis completed for all edited algorithm/driver files; remaining messages are pre-existing style/performance warnings, not parse errors.
- The latest manuscript compiled successfully to a 20-page PDF after the mesh-table repair (only existing float/layout and missing-journal-name warnings remained).

## Data-integrity policy

Archived scientific tables and workbooks are retained as evidence, including inconsistent historical results. Repository fixes change code, paths, provenance labels, and documentation; they do not manufacture FEA, benchmark, validation, statistical, timing, or optimization observations.
