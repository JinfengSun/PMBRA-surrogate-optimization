# Minimal workflows

Install Python dependencies and run DNN training from the repository root:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python surrogate_model/train_validate_dnn.py
```

Generated results are written to ignored output directories and are not part of
the public repository. External validation requires the three request-only CSV
files documented in `data/README.md`.
