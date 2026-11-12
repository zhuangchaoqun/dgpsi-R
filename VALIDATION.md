# Validation

## Current implementation

The fork is based on upstream R master
`ecd384343c53903517aa903ed7c8a150f4c5dc93`, with the mixed-input ordering
correction in `lgp()` ported from upstream dev
`a62a319af8eeeafce541acade0887601b117e6f8`. The clean master branch remains
unchanged. The DGP training constructor and prunlgp search and objective are
unchanged.

The recorded environment is Windows 11, R 4.4.2, Python 3.10.20 and Python dgpsi
source `480bb30260d3a1c22af1ddffe1a11df3e4de0820`. R sessions and package libraries
are separate; existing dependencies and the Python runtime are reused.

## Why input ordering matters

When a receiving DGP uses both global and internal inputs, the linked backend
consumes internal inputs first. The earlier master constructor remapped the
connection indices without consistently reordering the deep-layer training
inputs and their lengthscales. The correction aligns these quantities and
orders connection-table rows by their receiving input positions.

An independent regression check uses an upstream GP whose maximum prediction
error is 0.00000293. Passing its prediction through a link should closely agree
with passing the corresponding observed value. The maximum downstream mean
difference was 1.784694 with the previous mapping and 0.00000773 after correction.
The regression also checks predictive variances and invariance to connection-row
order. It tests actual information transmission, rather than inferring correct
linking from different RMSE values.

The earlier apparent pruning benefits were affected by this input-order error.
[The historical record](VALIDATION-legacy.md) preserves the published numbers
through f62b778. The results below supersede those numbers.

## Unchanged data and selection settings

Both tutorials keep their data, seed and fitting budget. Each scalar DGP uses
two layers, two latent nodes, the squared exponential kernel, 40 iterations,
10 ESS burn-in steps per iteration and 20 imputations. Seed 57 controls matched
original/refitted component seeds and stable component imputation streams.

Pruning minimises mean validation NRMSE. The normalising scales come from
training responses. With `protect=0`, an admissible candidate cannot worsen any
scored validation output beyond numerical tolerance. The search uses two subset
passes and at most 32 evaluations. Neither the retained sources nor the number
of retained connections is prescribed. The test set does not select the graph.

## Operational example

The same `prunlgp_example.csv` supplies 96 training, 48 validation and 96 test
rows, two intermediate responses and three scored responses. Causal filtering,
training-only scaling and the prediction information set are unchanged. The
CSV is byte-identical to the earlier release, SHA-256:

`cc22f368c4d863a75efdf91c2b7ff29df24fcfb8b63205ffc971633f75b9bd07`.

The corrected run retains **u to a** and **v to c**, removing the other four
internal connections independently. Both intermediate models therefore supply
a retained downstream prediction. Model b continues to predict from its global
inputs; no output model is deleted.

| Quantity | Unpruned | Pruned |
|---|---:|---:|
| Internal connections | 6 | 2 |
| Validation mean NRMSE | 0.470206 | 0.459021 |
| Test mean NRMSE | 0.444737 | 0.475874 |

| Output | Validation unpruned | Validation pruned | Test unpruned | Test pruned |
|---|---:|---:|---:|---:|
| a | 0.762719 | 0.761562 | 0.789238 | 0.854998 |
| b | 0.435682 | 0.405167 | 0.302891 | 0.324359 |
| c | 0.212217 | 0.210332 | 0.242083 | 0.248266 |

The search record also shows why u was retained. Starting from the selected
input subsets, the evaluated candidate that removes u from a and refits that
receiver increases a's validation RMSE from 0.761562 to 0.871652. The other two
outputs' errors remain unchanged. That candidate is rejected by validation
protection. This is an observed predictive contribution of u, not a rule
requiring the algorithm to retain at least one outgoing link from each source.

All three validation errors decrease, but all three test errors increase.
This operational example demonstrates output-specific selection and the limits
of validation protection; it does not establish a held-out accuracy advantage.
The CSV was not replaced or screened to force a preferred retained graph.
It is a retrospective tutorial sample used in earlier development, not a new
prospective field evaluation.

## Synthetic example

The unchanged generator provides 80 training, 120 validation and 240 independent
test rows. The corrected network retains u to a, u to b, and v to c.

| Quantity | Unpruned | Pruned |
|---|---:|---:|
| Internal connections | 6 | 3 |
| Validation mean NRMSE | 0.191363 | 0.180517 |
| Test mean NRMSE | 0.178999 | 0.169024 |

All three validation and test errors decrease. The generating equation for b
uses only global inputs, yet retaining u improves finite-sample prediction.
Predictive input selection does not identify causal relationships. These numbers
reproduce the earlier dev-based comparison with the corresponding input-order
correction ported to master.

## Reproduction

Both tutorial runners refit their models and save the actual candidate records,
structures and per-output errors. The published articles come from executed
R Markdown. The package checks and native tests are separate from tutorial fits.
The input-order regression extends the native suite to 13 cases and 52
expectations, all passed with no failures, warnings or skips on 12 November 2026.
`R CMD build --no-manual` and `R CMD check --no-manual --no-build-vignettes`
completed with **Status: OK**. The earlier tests also cover grouped copies, independent receivers,
unchanged paths, zero links, serialization and parallel candidate evaluation.

Follow [PRUNLGP.md](PRUNLGP.md) for installation, Python setup, test commands,
tutorial execution and upstream synchronization. Cross-platform numerical
identity is not established by the Windows verification.
