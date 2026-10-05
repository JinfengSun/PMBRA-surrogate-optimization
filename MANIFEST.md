# Release manifest

This manifest maps the manuscript/Response claims to the public artifacts. It does not imply that a product file is independently reproducible when the source or raw evidence is listed as missing in `AUDIT_REPORT.md`.

| Claim or workflow | Primary source | Archived output/evidence |
|---|---|---|
| 4,096-case factorial FEA dataset | `data/fea_4096/Force_Table_1_7.csv` | same file; four inputs and signed Maxwell `Force_y` |
| DNN architecture and training | `dnn/dnn_model.py`, `dnn/train_dnn.py`, `dnn/config/validation_protocol.json` | `dnn/results/` and `dnn/seeds/` |
| Five-fold/intermediate validation | `dnn/train_dnn.py` (task-oriented copies are retained) | `dnn/results/cv_*`, `dnn/results/external_offgrid_*` |
| Seven-point air-gap check | `dnn/airgap_validation.py` | `data/offgrid_airgap_7/g_sweep_de11_Nn14_Nc14_predictions.csv` |
| Five pre-specified surrogate baselines | `surrogate_baselines/run_surrogate_baselines.py` | `surrogate_baselines/results/` |
| CEC2019 comparison | `benchmark/CEC2019/run_cec2019_comparison.m` and three algorithm folders | reference data under `benchmark/CEC2019/`; run-level archive under `statistics/` |
| Native-dimensional hypervolume | `benchmark/CEC2019/indicators/Hypervolume_calculation.m` | benchmark driver outputs when rerun |
| Suite-level statistical tests | `statistics/reproduce_statistics.py` | `statistics/reproduced_results/` |
| SPD ablation | `ablation/run_ablation.m` | `ablation/paper_*` (historical, unequal-budget rows disclosed) and `ablation/reproduced_results/` |
| PMBRA Pareto products | source runner/checkpoint not archived | `PMBRA_optimization/raw_pareto_results/` and `constraint_results/` |
| Direct 16-point FEA validation | unrounded final export not archived | displayed-value transcription and two candidate workbooks under `PMBRA_optimization/direct_FEA_validation/` |
| Maxwell model | `maxwell/Project.aedt` | `maxwell/mesh_validation.xlsx`; solved caches/logs not archived |
| Figure material | exact scripts incomplete | `figures/Fig6_data/` through `figures/Fig12_data/` |
| Software versions | `requirements.txt`, `environment/` | recorded version text/JSON |
| Cross-source audit | `CONSISTENCY_MATRIX.csv`, `tools/audit_repository.py` | `AUDIT_REPORT.md`, `checksums.txt` |

`checksums.txt` covers every release file except itself and transient/cache directories. Regenerate it only after all release edits with `python tools/generate_checksums.py`.
