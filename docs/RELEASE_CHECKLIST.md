# Author confirmation checklist

- [ ] Select a code license (MIT, BSD-3-Clause, GPL-3.0, or another approved
  license) and confirm compatibility with any later-added CEC2019 assets.
- [ ] Confirm the final repository title, author list, article DOI, and
  preferred citation metadata; manuscript source is intentionally excluded.
- [x] Exclude DNN outputs and optimization/statistical result files.
- [x] Include `Force Table 1_7.csv` as public training data.
- [ ] Confirm that `de1.csv`, `Nc1.csv`, and `Nn1.csv` remain request-only.
- [x] Add and scan the ANSYS Maxwell 2D `.aedt` project; no personal path,
  username, email, remote path, or license-server reference was found.
- [ ] Confirm that ANSYS Electronics Desktop 2025 R1 is the intended public
  simulation version and that all embedded material definitions may be shared.
- [x] Include the newly supplied CEC2019 functions, reference PS/PF data,
  indicator implementations, and NSGA-II/DN-NSGA-II baselines.
- [ ] Confirm authorship and redistribution licenses for the supplied baseline,
  benchmark, reference-data, and indicator files.
- [ ] Resolve the benchmark budget: manuscript/archive `5000*n_var` versus the
  later driver `10000*n_var` objective evaluations.
- [ ] Record MATLAB release/toolboxes and the Python/TensorFlow versions used for
  the final reported runs.
- [ ] Confirm whether the post-paper `MMODE_ES.m` experiment is out of scope.
- [ ] Run a clean-machine MATLAB benchmark reproduction and a DNN reproduction
  after the request-only external-validation inputs are supplied.
