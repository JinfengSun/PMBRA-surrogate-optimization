# Proposed exclusions from the public release

## Data and generated results

- External validation data: `de1.csv`, `Nc1.csv`, and `Nn1.csv`.
- DNN and simpler-surrogate row-level prediction CSVs.
- All DNN metric tables, protocols, split indices, and generated result figures.
- All optimization/CEC run outputs, raw metric tables, and statistical results.
- ANSYS `.aedtresults` solved-data/cache directories and generated field data.

`Force Table 1_7.csv` is now explicitly included as public training data.

## Generated, temporary, or environment-specific material

- All `node_modules/`, `__pycache__/`, `.mplconfig/`, QA render directories,
  contact sheets, page PNGs, logs, LaTeX auxiliaries, and local caches.
- PDF/DOCX QA reports and response-export artifacts.
- Copy-back PowerShell scripts and workbook-inspection helpers.

## Historical or paper-revision material

- Duplicate trees `completed_revision/`, `completed_revision_v2/`,
  `completed_revision_v3/`, and `final_project_revision/` after selecting the
  latest authoritative files.
- Superseded manuscript variants, reviewer-response editing scripts, and
  deprecated SPD-DN-NSGA-II copies.
- All manuscript `.tex`, bibliography `.bib`, publication PDF/DOCX files, and
  nonessential paper/simulation screenshots.
- `MMODE_ES.m` and `test_compare_mmode_es.m` as unrelated post-paper comparison
  work. The newly supplied paper benchmark driver is used instead.

## Privacy/path hygiene

- Original EPS/PDF figure files containing embedded absolute Windows paths in
  metadata were not copied.
- No account credentials or API keys were found in the selected text sources.
  A final archive-level scan is still required after author-supplied files and
  license text are added.
