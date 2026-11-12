test_that("a nearly deterministic internal input agrees with its observed value", {
  skip_if(Sys.getenv("DGPSI_RUN_PRUNLGP_TESTS") != "true")
  init_py(dgpsi_ver=Sys.getenv("DGPSI_TEST_BACKEND", "dev"), verb=FALSE)
  set_thread_num(1L)
  set_seed(123)
  X <- matrix(runif(48, -1, 1), ncol=2)
  u <- matrix(X[,1]); y <- matrix(2*u + sin(2*X[,2]))
  root <- gp(X[,1,drop=FALSE], u, id="u", nugget=1e-10,
             prior="ga", bounds=c(.1,10), verb=FALSE)
  set_seed(124)
  receiver <- dgp(cbind(X[,2], u), y, id="a", depth=2, node=2,
    N=15, B=10, ess_burn=5, name="sexp", share=FALSE,
    bounds=c(.1,10), prior="ga", nugget_est=TRUE, verb=FALSE)
  linked <- data.frame(From_Emulator=c("Global","Global","u"),
    To_Emulator=c("u","a","a"), From_Output=c(1L,2L,1L), To_Input=c(1L,1L,2L))
  observed <- linked; observed$From_Emulator[3] <- "Global"
  predict_graph <- function(s) {
    object <- dgpsi:::.prunlgp_activate(
      lgp(s, list(root,receiver), activate=FALSE, verb=FALSE), 10L, 91L)
    predict(object, X, full_layer=TRUE)$results
  }
  p <- predict_graph(linked); q <- predict_graph(observed)
  flatten <- function(z,key) do.call(c,unname(z[[key]]))
  expect_lt(max(abs(flatten(p,"mean")$u-u)), 1e-4)
  expect_lt(max(abs(flatten(p,"mean")$a-flatten(q,"mean")$a)), 1e-3)
  expect_lt(max(abs(flatten(p,"var")$a-flatten(q,"var")$a)), 1e-3)
  # Connection rows do not define the trained component's column order.
  reversed <- predict_graph(linked[3:1,])
  expect_equal(reversed,p,tolerance=1e-10)
})
