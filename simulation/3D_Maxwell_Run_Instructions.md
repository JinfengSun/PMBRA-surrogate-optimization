# 3D axial-scaling validation protocol

The two supplied AEDT projects are Maxwell 2D XY magnetostatic models with `ModelDepth='1meter'`; no Maxwell 3D design is present. Therefore, the three 3D force values must not be inferred from the 2D results.

Use one fixed cross-section (`de=27 mm`, `g=0.3 mm`, `Nn=14`, `Nc=14`) and create three otherwise identical Maxwell 3D models with axial depths of 20, 40, and 60 mm (`Ns=100, 200, 300` at `dl=0.2 mm`). Preserve the DW310-35 nonlinear B-H curve, N50M magnet properties and magnetization directions, copper regions, exterior boundary, and two 100-turn coils carrying 5 A (500 A-turns per coil). Apply an end-region-aware adaptive mesh and require the thrust change between the final two passes to be below 0.5%.

For each case, export the mover force along the same physical direction as `Force1.Force_y`. Enter the converged 3D force in `3d_scaling_validation_protocol.csv` and calculate

`relative_error_percent = 100 * (3D_force_N - 2D_scaled_force_N) / 3D_force_N`.

Report signed and absolute errors. The comparison tests the axial linear-scaling assumption and should not be described as complete 3D optimization validation.
