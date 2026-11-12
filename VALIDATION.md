# Validation

This contribution is based on upstream R master commit
`ecd384343c53903517aa903ed7c8a150f4c5dc93`. The earlier R dev-based results below
were obtained at commit `a62a319af8eeeafce541acade0887601b117e6f8` and are retained
as historical comparisons. In the new formal fork, `master` preserves the
upstream baseline and `prunlgp-master` contains the extension. The previous
repository is retained separately as a private backup.

Both versions were evaluated on Windows 11 with R 4.4.2, Python 3.10.20 and
Python dgpsi dev commit `480bb30260d3a1c22af1ddffe1a11df3e4de0820`. The Python
backend was held fixed to isolate the change in the R upstream base.

## Experimental settings

Both examples use five scalar DGPs, 40 training iterations, `ess_burn=10`, twenty
imputations, seed 57 and `protect=0`. Original and reduced-input fits use matching
group-specific seeds. The search minimises mean validation NRMSE and rejects
any candidate that worsens a scored validation output. Candidate evaluation
uses stable per-component imputation streams and native uncertainty propagation.
Two subset passes and at most 32 evaluations are allowed.

The data, transformations, seeds, fitting budget and selection settings are
unchanged from the R dev-based comparison. No test-directed parameter or sample
changes were made for the master-based runs.

## Synthetic example

The main tutorial generates 80 training, 120 validation and 240 independent
test rows using seed 1729 and the equations shown in the article.

| Quantity | Unpruned | Pruned |
|---|---:|---:|
| Internal connections | 6 | 2 |
| Validation mean NRMSE | 0.919986 | 0.430324 |
| Test mean NRMSE | 0.867040 | 0.407817 |

The selected graph retains u for a and v for c; b retains no internal input.
All three validation and test errors decrease. These are synthetic results,
not measurements from an operating system.

## Operational-data companion

The operational CSV is unchanged: 96 training, 48 validation and 96 test rows.
Its SHA-256 is
`cc22f368c4d863a75efdf91c2b7ff29df24fcfb8b63205ffc971633f75b9bd07`.

| Quantity | Unpruned | Pruned |
|---|---:|---:|
| Internal connections | 6 | 1 |
| Validation mean NRMSE | 0.885412 | 0.481936 |
| Test mean NRMSE | 0.947889 | 0.582670 |

Only v to a is retained. Models b and c still predict their outputs from global
inputs. Test RMSE decreases by 34.88% for a, 28.59% for b and 48.57% for c.
Mean test NRMSE decreases by 38.53% relative to the master-based unpruned model.
The sample was used in earlier tutorial development and is not a new
prospective evaluation.

## Comparison with the R dev base

The same Python backend, data and tutorial settings were used for both R bases.

| Example | R base | Unpruned test mean NRMSE | Pruned test mean NRMSE | Retained links |
|---|---|---:|---:|---:|
| Synthetic | dev | 0.178999 | 0.169024 | 3 |
| Synthetic | master | 0.867040 | 0.407817 | 2 |
| Operational | dev | 0.444737 | 0.475874 | 2 |
| Operational | master | 0.947889 | 0.582670 | 1 |

Pruning improves both examples relative to their master-based baselines.
However, the master-based pruned models have higher absolute test errors than
the corresponding dev-based pruned models. A larger relative pruning benefit
does not establish that master is the more accurate implementation.

The upstream R branches differ in component construction and linked-input
handling. In particular, dev changed the reordering of deep-layer global inputs
and their length-scale parameters. This contribution preserves master's
`lgp()` and `dgp()` implementations; it does not import the dev constructor.
These comparisons change the R base as a whole and do not attribute all of the
error difference to a single upstream change.

## Checks and reproduction

### New-fork verification, 12 November 2026

The new public repository is a formal fork of `mingdeyu/dgpsi-R`. Its `master`
branch remains at the upstream commit above. The complete contribution was
migrated from source revision `04608eb41c729c2e7fcdecdea3d373daa104a0ac` without
changing any R implementation, executable tutorial, test or example-data file.
The former repository and its branches are retained as a private backup.

The README's `remotes::install_github()` command installed source revision
`9a61661751c86fb9512cf2e1dcc2ab7c4a39ebdf` into a separate R library. The export,
installation directory and GitHub source metadata were checked. Subsequent
edits only clarify documentation and record this verification.

Fresh R sessions then ran:

- All 12 native test cases: 48 passed expectations; no failures, warnings or skips.
- All six R blocks in section 4 of `PRUNLGP.md`, unchanged and in order.
- Both tutorial runners, fitting the models from scratch: about 77 seconds for
  the synthetic example and 104 seconds for the operational example on this
  machine while other checks were running.
- `R CMD build --no-manual` followed by
  `R CMD check --no-manual --no-build-vignettes`: **Status: OK**.

The two new tutorial runs reproduce the tables above and retain respectively
two and one internal connections. The README example reproduces the operational
tutorial's per-output validation and test errors. Package and tutorial code,
data and scientific settings were not changed to obtain these results.

The R sessions and extension library were fresh; installed R dependencies and
the recorded Python runtime were reused. This is a Windows/R 4.4.2 verification,
not a clean operating-system installation or a cross-platform numerical test.
Building the source archive without its vignette outputs produces two missing-
vignette warnings; the documented check builds those outputs first. The native
tests and executed tutorials are separate from the default package check.

### Test coverage

All 12 native tests and 48 expectations passed, with no failures, warnings or skips.
The source build and `R CMD check --no-manual --no-build-vignettes` completed
with Status OK. Executable tutorial chunks and the pruning implementation were
also checked against the dev-based comparison; they are unchanged.

The native tests cover scalar-output deletion, grouped copies, actual upstream
information propagation, serial/parallel consistency, all-links-removed
prediction and full/light serialization. A regression test verifies unchanged
means and variances for unrelated paths after a deletion.

Both tutorial scripts execute from scratch. The site articles and tables come
from their actual model fits. Follow [PRUNLGP.md](PRUNLGP.md) for installation,
execution and the native integration tests. Package checks skip Python training
unless explicitly enabled; the executed tutorials are checked separately.
