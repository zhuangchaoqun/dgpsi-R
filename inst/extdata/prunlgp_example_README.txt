prunlgp_example.csv

A de-identified, standardised extract of operational measurements for the
operational-data companion to the prunlgp tutorial. This is measured data,
not synthetic data. The main tutorial generates synthetic data in its R code.

Rows: 240 (96 training, 48 validation, 96 test).
Columns: split, x1--x16, u, v, a, b, c.

The three partitions come from successive, non-overlapping periods. Sampling
positions were fixed uniformly within each period before model fitting.
Measurements were smoothed using a one-sided Gaussian kernel, then transformed
using means and sample standard deviations from the 96 training rows only.
Values are rounded to six decimal places. Component fitting uses training rows;
connection selection uses validation rows. This benchmark has been used during
tutorial development and is not a new prospective evaluation.

u and v are intermediate responses; a, b and c are downstream responses. x1--x4
are origin boundary inputs, x5 is an origin external condition, x6--x8 are known
calendar features, x9--x12 are origin states, and x13--x16 are prescribed boundary
inputs at the target time. Future observations of u, v, a, b or c are never supplied
to linked validation or test prediction.

Dates, physical variable names, units, equipment identifiers, raw measurements
and inverse transformation parameters are not distributed. Standardisation and
identifier removal reduce disclosure; they do not provide a formal anonymity
guarantee against an adversary holding matching time-series data.

The tutorial is a small demonstration of the package interface, not a
reproduction of the full twelve-output case study. Its error measures refer to
the filtered and standardised responses.
