# Data availability

`public/Force Table 1_7.csv`, containing the 4096 full-factorial FEA training
cases, is included in this release with the author's approval.

The three external validation sweeps remain non-public and, when authorized,
are expected under `data/private/` with these exact names:

- `de1.csv`, `Nc1.csv`, and `Nn1.csv`

Required columns are `de [mm]`, `g [mm]`, `Nn []`, `Nc []`, and
`Force1.Force_y [kNewton]`. The repository includes aggregate metrics and
package intentionally omits all saved DNN and optimization result files.
Contact the corresponding author and state the intended scientific use to
request the external-validation sweeps; release remains subject to the authors'
and institution's approval.
