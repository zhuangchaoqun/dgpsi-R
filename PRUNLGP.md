# prunlgp: installation and user guide

`prunlgp()` selects internal inputs in a linked Gaussian process emulator using
validation performance. It refits the receiving component after removing an
input and recomputes predictions through the network. Each component has one
output; different receivers can retain different inputs from the same source.

This guide takes you from installation to a working example, HTML tutorials
and automated tests. The fork's **`prunlgp-master`** branch contains the complete
implementation, based on upstream **dgpsi-R master**. The R package is named
`dgpsi`; `prunlgp` is a function within it.

- [Function reference](https://zhuangchaoqun.github.io/dgpsi-R/reference/prunlgp.html)
- [Synthetic tutorial](https://zhuangchaoqun.github.io/dgpsi-R/articles/prunlgp.html)
- [Operational-data tutorial](https://zhuangchaoqun.github.io/dgpsi-R/articles/prunlgp-operational.html)
- [Recorded versions and results](VALIDATION.md)

Follow sections 1–4 in order for your first example. Sections 5–6 cover tutorial
rendering and tests from a local clone. Commands labelled **R** belong in the R
console or an R script; commands labelled **Terminal** belong in a shell.

## 1. Requirements

| Item | Requirement and purpose |
|---|---|
| R | The package declares R >= 4.0; this contribution was tested with R 4.4.2. |
| Python | Use Python 3.10 for the tested setup. The upstream initializer also supports 3.11 and 3.12. You can let `init_py()` install Python in its Conda environment. |
| Conda | Miniconda, Miniforge or Anaconda; `init_py()` offers to install Miniconda when no Conda executable is found. |
| Git | Needed to clone the repository and install the Python development backend. Make `git` available on your system PATH. |
| R build tools | If dependencies need compilation, use Rtools matching your R version on Windows, Xcode Command Line Tools on macOS, or the required compiler/system libraries on Linux. |
| Pandoc | Required for tutorial HTML. It is bundled with RStudio; otherwise install it separately and make it available to R Markdown. |
| Internet | Required for the initial R and Python dependency installation. |

The fork installs its R imports, including `reticulate`, `ggplot2` and
`visNetwork`. The commands below also install the tutorial and test tools.
`init_py()` manages the Python dependencies, including NumPy, SciPy, Numba,
scikit-learn, FAISS and the Python `dgpsi` package. A separate system Python
installation is not needed for this route.

## 2. Install the complete fork

**R — start in a fresh session:**

```r
install.packages(c("remotes", "rmarkdown", "knitr", "htmlwidgets", "testthat"))
remotes::install_github(
  "zhuangchaoqun/dgpsi-R", ref="prunlgp-master",
  dependencies=NA, upgrade="never", build_vignettes=FALSE
)
```

Restart R after installation, especially if another `dgpsi` version was loaded.
Then check the installed package:

```r
library(dgpsi)
stopifnot("prunlgp" %in% getNamespaceExports("dgpsi"))
find.package("dgpsi")
packageDescription("dgpsi")[c("Version", "RemoteUsername", "RemoteRef", "RemoteSha")]
```

The export check must complete without an error. For a GitHub installation,
the remote should identify `zhuangchaoqun` and `prunlgp-master`. A version label
alone does not distinguish this fork from other development installations.

Install the full branch rather than sourcing `R/prunlgp.R` alone. The function
uses registered methods and helpers, including support for networks with no
internal links and restoration of saved linked models. `build_vignettes=FALSE`
keeps installation separate from model training; section 5 executes the tutorials.

## 3. Set up Python once

**R — run interactively before starting any terminal scripts:**

```r
library(dgpsi)
init_py(py_ver="3.10", dgpsi_ver="dev")
set_thread_num(1)
reticulate::py_config()
reticulate::py_run_string("import dgpsi; print(dgpsi.__file__)")
```

Accept the installation prompts if the required environment is missing. If the
initializer requests an R restart, restart and run these commands again.
`py_config()` should show the intended Python interpreter, and importing `dgpsi`
should print its module location without an exception. The current initializer
uses the Conda environment `dgp_si_R_2_6_0_dev` for this explicit `dev` setting.

**The R branch and Python backend are separate choices.** This fork is based on
R master; the verified tutorials use the Python `dgpsi` development backend.
Keep `dgpsi_ver="dev"` consistent in the example, tutorial runner and tests.
Calling `init_py()` with different settings may select a different environment.
See the [upstream initializer documentation](https://mingdeyu.github.io/dgpsi-R/reference/init_py.html).

The published results used Python 3.10.20 and backend commit
`480bb30260d3a1c22af1ddffe1a11df3e4de0820`. Installing a later `dev` revision may
change numerical results. Record your environment when comparing runs; see
section 8 for the recorded-backend option.

## 4. Complete example with the supplied data

Run the following R blocks **in order in the same session**. This example needs
only the installed fork, not a local source clone. It uses the operational
sample; the main tutorial instead generates synthetic data.

### 4.1 Load the package and data

```r
library(dgpsi)
init_py(py_ver="3.10", dgpsi_ver="dev")
set_thread_num(1)

data_file <- system.file("extdata", "prunlgp_example.csv", package="dgpsi")
stopifnot(nzchar(data_file))
dat <- read.csv(data_file)
train <- subset(dat, split == "train")
validation <- subset(dat, split == "validation")
test <- subset(dat, split == "test")
global <- paste0("x", 1:16)
outputs <- c("a", "b", "c")
stopifnot(nrow(train) == 96L, nrow(validation) == 48L, nrow(test) == 96L)
table(dat$split)
```

The supplied measurements are de-identified and already centred and scaled
using training rows only. `x1`–`x16` are available global inputs; `u` and `v`
are intermediate outputs; `a`, `b` and `c` are the outputs scored during pruning.
Observed `u` and `v` train the component models. At validation and test time,
the network receives only `global` inputs and predicts its internal variables.

### 4.2 Train one DGP per output

```r
features <- list(
  u=c("x1", "x2", "x5", "x6", "x7", "x8", "x9", "x10"),
  v=c("x5", "x6", "x7", "x8", "x11", "x12"),
  a=c("x5", "x6", "x7", "x8", "x13", "x14", "x15", "x16", "u", "v"),
  b=c("x5", "x6", "x7", "x8", "x13", "x14", "x15", "x16", "u", "v"),
  c=c("x5", "x6", "x7", "x8", "x13", "x14", "x15", "x16", "u", "v")
)

# Match the original fitting seeds to the group seeds used by prunlgp.
component_seed <- function(id) as.integer((57 + 104729 *
  match(id, sort(names(features)))) %% 2147483646 + 1)

components <- lapply(names(features), function(id) {
  set_seed(component_seed(id))
  dgp(as.matrix(train[, features[[id]]]), as.matrix(train[, id, drop=FALSE]),
      id=id, name="sexp", depth=2, node=2, N=40, B=20, ess_burn=10,
      share=FALSE, bounds=c(0.1, 10), prior="ga", nugget_est=TRUE, verb=FALSE)
})
```

The five scalar models use the same architecture and fitting budget. In the
initial network, each of `a`, `b` and `c` receives both `u` and `v`.

### 4.3 Build the initial linked network

```r
connections <- do.call(rbind, lapply(names(features), function(id) {
  f <- features[[id]]
  internal <- f %in% c("u", "v")
  data.frame(
    From_Emulator=ifelse(internal, f, "Global"),
    To_Emulator=id,
    From_Output=ifelse(internal, 1L, match(f, global)),
    To_Input=seq_along(f)
  )
}))
stopifnot(sum(connections$From_Emulator != "Global") == 6L)
network <- lgp(connections, components, B=20, verb=FALSE)
```

`From_Output` selects a global matrix column or a source model's output.
`To_Input` is the column position in the receiving model's training matrix.
The six internal connections are `u` and `v` to each of `a`, `b` and `c`.

### 4.4 Prune using validation predictions

```r
refit <- function(model, keep, seed) {
  dgpsi::set_seed(seed)
  dgpsi::dgp(model$data$X[, keep, drop=FALSE], model$data$Y,
      id=model$id, name="sexp", depth=2, node=2, N=40, B=20, ess_burn=10,
      share=FALSE, bounds=c(0.1, 10), prior="ga", nugget_est=TRUE, verb=FALSE)
}

selected <- prunlgp(
  network, components,
  x=as.matrix(validation[, global]),
  y=lapply(validation[, outputs], as.numeric),
  refit=refit, seed=57, B=20, protect=0,
  search="subsets", max_rounds=2, max_evals=32, verb=TRUE
)
print(selected)
selected$history[, c("evaluation", "stage", "loss", "internal_links",
                     "admissible", "selected")]
```

The objective is the mean validation RMSE normalised by each scored output's
training standard deviation. `protect=0` additionally rejects any candidate
that increases a scored output's validation RMSE beyond numerical tolerance.
`keep` refers to columns of the original training matrix, and `refit` uses
training data only. Test responses do not enter selection.

`search="subsets"` visits each receiving model and evaluates its internal-input
subsets. For a larger network, `search="backward"` evaluates individual
deletions. The initial network remains eligible. The function returns the best
admissible evaluated graph; a run can correctly retain all links when no
evaluated deletion improves the selection criterion.

### 4.5 Predict and inspect held-out errors

```r
set_seed(57)
before <- predict(selected$initial_model, as.matrix(test[, global]),
                  full_layer=TRUE)$results
set_seed(57)
after <- predict(selected, as.matrix(test[, global]), full_layer=TRUE)$results

# Flatten the layer lists while retaining emulator IDs.
means <- function(result) do.call(c, unname(result$mean))
errors <- do.call(rbind, lapply(outputs, function(id) {
  data.frame(
    output=id,
    validation_unpruned=unname(selected$initial_rmse[id]),
    validation_pruned=unname(selected$rmse[id]),
    test_unpruned=sqrt(mean((as.numeric(means(before)[[id]])-test[[id]])^2)),
    test_pruned=sqrt(mean((as.numeric(means(after)[[id]])-test[[id]])^2))
  )
}))
print(errors, row.names=FALSE)

stopifnot(all(is.finite(as.matrix(errors[, -1]))),
  selected$score <= selected$initial_score + selected$settings$tolerance,
  all(selected$rmse <= selected$initial_rmse + selected$settings$tolerance))
```

Use `selected$initial_model` for the comparison: it has the same imputation
settings as the selection procedure. The per-output protection applies to
validation errors. The test table reports performance on the held-out sample,
where an improvement is not guaranteed.

### 4.6 View and save the actual networks

```r
print(summary(selected$initial_model))
print(summary(selected))
subset(selected$structure, From_Emulator != "Global")

output_dir <- file.path("tutorial-output", "quick-start")
dir.create(output_dir, recursive=TRUE, showWarnings=FALSE)
htmlwidgets::saveWidget(summary(selected$initial_model),
  file.path(output_dir, "initial-network.html"), selfcontained=FALSE)
htmlwidgets::saveWidget(summary(selected),
  file.path(output_dir, "pruned-network.html"), selfcontained=FALSE)
write.csv(errors, file.path(output_dir, "errors.csv"), row.names=FALSE)
cat("Quick-start example completed.\n")
```

The interactive networks appear in the RStudio Viewer. Outside RStudio, open
the saved HTML files in a browser. Keep their accompanying asset directories
when copying them. The output folder is relative to `getwd()`.

A successful example prints the completion message, creates both HTML files
and a finite error table, and passes the validation checks above. Removing an
input from one receiving model does not remove it from other receivers.

## 5. Run the tutorials and regenerate HTML

The installed package supplies the data and functions. To run the supplied
rendering scripts or tests, also obtain the source repository.

**Terminal — clone once:**

```sh
git clone --branch prunlgp-master https://github.com/zhuangchaoqun/dgpsi-R.git
cd dgpsi-R
```

If you downloaded a GitHub ZIP instead, select `prunlgp-master`, extract it and
open that directory. Subsequent relative paths assume the repository root,
which contains `DESCRIPTION`, `tools`, `vignettes` and `tests`.

**Terminal — execute and render both tutorials:**

```sh
Rscript tools/run-prunlgp-tutorial.R
Rscript tools/run-prunlgp-tutorial.R prunlgp-operational
```

The first command generates the synthetic example. The second uses the supplied
operational CSV. Each command fits new models, performs pruning and renders
the HTML; it does not reuse saved model results. Python must already be set up
interactively as in section 3.

From RStudio, the main tutorial can also be run with
`source("tools/run-prunlgp-tutorial.R")` from the repository root.
To render either article directly in R:

```r
Sys.setenv(DGPSI_RUN_PRUNLGP_VIGNETTE="true", DGPSI_TUTORIAL_BACKEND="dev")
rmarkdown::render(
  "vignettes/prunlgp.Rmd", output_dir="tutorial-output",
  knit_root_dir=getwd(), envir=new.env(parent=globalenv())
)
# For the companion, use vignettes/prunlgp-operational.Rmd and
# output_dir="tutorial-output/operational".
```

The runner is recommended because it also checks results and saves numeric
tables. A direct `render()` call creates the article but does not export those
additional CSV/RDS files. The explicit `DGPSI_RUN_PRUNLGP_VIGNETTE=true` flag
enables computations; without it, the vignette code is displayed but not run.

| Runner output | Synthetic tutorial | Operational tutorial |
|---|---|---|
| Output directory | `tutorial-output/` | `tutorial-output/operational/` |
| HTML file | `prunlgp.html` | `prunlgp-operational.html` |
| Numeric records | `errors.csv`, `system-errors.csv`, `intervals.csv` | Same file names in its directory |
| Search and structure | `search.csv`, `structure.csv`, `connections.csv` | Same file names in its directory |
| Run information | `session-info.txt`, `results.rds` | Same file names in its directory |

Success ends with **`Tutorial completed in ... seconds.`**, an HTML path and
no R error. The runner checks three scored outputs, six initial internal links,
finite errors and the objective/per-output validation protection. Inspect
`search.csv` for failed or rejected candidates; a failed candidate is recorded
even when the overall run succeeds. Re-running writes to the same output folder,
so copy it elsewhere first if you want to retain an earlier run.

To rebuild the complete local pkgdown website, including navigation and both
executed articles, run from the repository root:

```r
install.packages("pkgdown")
```

```sh
Rscript tools/build-prunlgp-site.R
```

Open `docs/index.html` afterwards. This is a local build; it does not publish
anything to GitHub. It takes longer because it rebuilds package documentation
and runs both tutorials. The prunlgp reference and tutorials retain their
page-specific author credits; other pages use the upstream package credits.
The fork's published site is deployed from `gh-pages` after this executed build
has been checked. The inherited upstream website workflow does not run on
`prunlgp-master`; use the executed build above when publishing this extension.
The commands below run the package and native tests locally.

## 6. Run automated tests

Start a fresh R session in the source repository root, using the installed fork.
The complete native test suite needs the Python environment from section 3.

```r
library(dgpsi)
stopifnot("prunlgp" %in% getNamespaceExports("dgpsi"))
Sys.setenv(DGPSI_RUN_PRUNLGP_TESTS="true", DGPSI_TEST_BACKEND="dev")
test_results <- testthat::test_dir(
  "tests/testthat", filter="prunlgp", reporter="progress",
  stop_on_failure=TRUE, stop_on_warning=TRUE
)
test_table <- as.data.frame(test_results)
stopifnot(!any(test_table$skipped), !any(test_table$error),
          all(test_table$failed == 0L))
cat("Native prunlgp tests completed without failures, warnings or skips.\n")
```

The verified revision reports **FAIL 0, WARN 0, SKIP 0, PASS 48** across 12 test
cases. Counts may change as tests are added; zero failures, warnings and skips
are the success criteria for the complete native run. Without
`DGPSI_RUN_PRUNLGP_TESTS=true`, only the lightweight tests execute and the Python
tests are skipped: that is not a complete integration check.

Coverage includes output-specific input deletion, grouped model copies,
information propagation, zero internal links, saved-model restoration,
reproducibility, parallel candidates and invalid refits. This command tests the
installed package; reinstall the fork after changing its source.

For a source-package check, first install the suggested check dependencies:

```r
remotes::install_deps(dependencies=TRUE, upgrade="never")
```

**Terminal:**

```sh
R CMD build --no-manual .
R CMD check --no-manual --no-build-vignettes dgpsi_2.6.0-9000.tar.gz
```

Use the archive name printed by `R CMD build` if the package version changes.
Check the final status and `dgpsi.Rcheck/00check.log`; the recorded check finished
with **Status: OK**. A default package check does not execute Python tests or
train the tutorials. Run the explicit native-test and tutorial commands above
as separate checks.

## 7. Runtime and troubleshooting

On the recorded Windows 11 / R 4.4.2 / Python 3.10.20 setup, with Python already
installed and numerical routines warmed up, the synthetic tutorial took about
60 seconds, the operational tutorial 81 seconds, and the native tests 148 seconds.
Allow several minutes for each on a different machine. The first R/Python setup
can take 10–30 minutes or longer, depending on downloads and dependency solving;
this is a planning estimate, not a measured installation benchmark. First model
runs can also take longer because Numba compiles numerical routines.

| Symptom | What to check |
|---|---|
| `could not find function "prunlgp"` | Restart R, load `dgpsi`, inspect `find.package("dgpsi")` and the remote fields in section 2. Install the complete `prunlgp-master` branch rather than the CRAN package. |
| `Rscript` or `R` is not found in the terminal | Add your R installation's executable directory to PATH, or use the RStudio alternatives shown in this guide. Restart the terminal after changing PATH. |
| Dependency compilation fails | Install the build tools matching your OS/R version and the system library named in the first build error. Then repeat the fork installation. |
| GitHub download fails or reaches an API limit | Check network access to GitHub and retry. For authenticated downloads, configure a personal GitHub token through your local credential setup. |
| Downloads work in a browser but time out in R | R may not inherit the system proxy. Configure R's `https_proxy` and `http_proxy` environment variables for your network, and increase `options(timeout=300)` if needed. |
| Conda or Git cannot be found | Run `Sys.which("git")` and `reticulate::conda_binary()` in R. Install the missing tool, restart R and perform section 3 interactively. |
| Python is already initialized from another environment | Restart R before `init_py()`. Inspect `Sys.getenv(c("RETICULATE_PYTHON", "RETICULATE_PYTHON_ENV", "VIRTUAL_ENV"))` for an unrelated override. Remove that override from this project's configuration if you intend to use the managed environment. |
| A module is missing or the backend is inconsistent | After initialization, inspect `reticulate::py_config()` and `dgpsi.__file__` as above. Use the same explicit backend in examples, tests and workers. |
| Linux `libstdc++.so.6`, `libcblas.so.3` or BLAS import error | Follow the diagnostics from the master initializer and the upstream installation notes. Record the error and environment before rebuilding dependencies. |
| `pandoc` is unavailable | Run `rmarkdown::pandoc_available()`. Use RStudio's bundled Pandoc or install Pandoc. For a terminal session, ensure R can find it, for example through `RSTUDIO_PANDOC` pointing to the directory containing Pandoc. |
| HTML contains code but no fitted results | Enable `DGPSI_RUN_PRUNLGP_VIGNETTE=true`, or use the tutorial runner, which sets it for you. |
| Interactive networks disappear after copying HTML | Keep the accompanying asset directories with non-self-contained HTML, or rerender in the destination directory. |
| Tests finish with `SKIP` | Enable `DGPSI_RUN_PRUNLGP_TESTS=true` and initialize Python. Skips do not establish that native prediction and pruning passed. |
| Results differ from the published table | Compare R source commit, Python commit, seed, fitting settings and dependency versions. A moving `dev` backend is not a fixed software revision. |

`RETICULATE_PYTHON` overrides other interpreter requests; see the
[reticulate environment documentation](https://rstudio.github.io/reticulate/reference/use_python.html).
Avoid loading a second Python environment in an already initialized R session.

For a reproducible problem report, include the first error, the command that
caused it, and the output of:

```r
sessionInfo()
packageDescription("dgpsi")[c("Version", "RemoteRef", "RemoteSha")]
reticulate::py_config()  # after initializing the intended environment
```

## 8. Versions and optional backend pinning

The recorded R baseline is upstream master commit
`ecd384343c53903517aa903ed7c8a150f4c5dc93`. The current fork branch remains
`prunlgp-master`; `gh-pages` holds the website. Numerical comparison records
are in [VALIDATION.md](VALIDATION.md).

To use the recorded Python source rather than whichever revision `dev` later
points to, first complete section 3 and close R. In a **fresh R session, before
loading dgpsi or initializing Python**, install that source into the existing
managed environment:

```r
reticulate::conda_install(
  envname="dgp_si_R_2_6_0_dev",
  packages=paste0("git+https://github.com/mingdeyu/DGP.git@",
                  "480bb30260d3a1c22af1ddffe1a11df3e4de0820"),
  pip=TRUE, pip_options=c("--no-deps", "--force-reinstall")
)
```

This replaces the Python `dgpsi` source in that environment and keeps its
installed dependencies. Restart R and use the same `init_py(dgpsi_ver="dev")`
command without `reinstall=TRUE`. Pinning this source does not pin NumPy, SciPy
or every other dependency; retain environment records when comparing results.

When updating the fork, reinstall it in a fresh R session, then rerun the tests
and tutorials. The R and Python branches are versioned independently.

## 9. Sync with upstream

This is a formal fork of `mingdeyu/dgpsi-R`. The `master` branch is the recorded
upstream baseline; `prunlgp-master` contains the extension and `gh-pages` the
published website. Existing work is retained in a separate private backup.

From a clean clone of the extension branch, add the upstream remote once:

```sh
git remote add upstream https://github.com/mingdeyu/dgpsi-R.git
git fetch upstream
git switch prunlgp-master
git switch -c sync-upstream-master
git merge upstream/master
```

Resolve any conflicts, reinstall the package, and rerun section 6 and both
tutorials before merging the update into `prunlgp-master`. Record the new
upstream commit and any numerical changes in `VALIDATION.md`. Rebuild the
website with `tools/build-prunlgp-site.R`; publish the checked `docs/` contents
to `gh-pages`. Updating the Python development backend is a separate change
and should be validated separately.
