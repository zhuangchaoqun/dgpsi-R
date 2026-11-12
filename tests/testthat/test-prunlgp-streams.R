test_that("unrelated DGP paths retain their actual predictive moments", {
  skip_if(Sys.getenv("DGPSI_RUN_PRUNLGP_TESTS") != "true")
  init_py(dgpsi_ver=Sys.getenv("DGPSI_TEST_BACKEND", "dev"), verb=FALSE)
  set_thread_num(1L)
  x <- matrix(seq(-1, 1, length.out=18), ncol=1)
  u <- sin(2*x)
  fit <- function(X, Y, id) {
    set_seed(71)
    dgp(X, Y, id=id, name="sexp", depth=2, node=2, N=3, B=3, verb=FALSE)
  }
  models <- list(fit(x,u,"u"), fit(cbind(x,u),cos(x),"a"),
                 fit(cbind(x,u),u^2,"b"))
  s <- data.frame(From_Emulator=c("Global","Global","u","Global","u"),
    To_Emulator=c("u","a","a","b","b"), From_Output=1L,
    To_Input=c(1L,1L,2L,1L,2L))
  before <- dgpsi:::.prunlgp_activate(lgp(s, models, activate=FALSE, verb=FALSE),3L,72L)
  models[[2]] <- fit(x,cos(x),"a")
  s <- s[!(s$From_Emulator=="u" & s$To_Emulator=="a"),]
  after <- dgpsi:::.prunlgp_activate(lgp(s, models, activate=FALSE, verb=FALSE),3L,72L)
  xx <- matrix(seq(-.93,.93,length.out=11),ncol=1)
  p <- predict(before,xx,full_layer=TRUE)$results
  q <- predict(after,xx,full_layer=TRUE)$results
  flatten <- function(p, key) do.call(c, unname(p[[key]]))
  for (id in c("u","b")) for (key in c("mean","var"))
    expect_equal(flatten(p,key)[[id]],flatten(q,key)[[id]],tolerance=1e-12)
  expect_gt(max(abs(flatten(p,"mean")$a-flatten(q,"mean")$a)),1e-7)
  # The moments are computed by the returned model, including after light and
  # full serialisation; they are not copied from a separate reference result.
  for (light in c(TRUE,FALSE)) {
    restored <- deserialize(serialize(after,light=light))
    r <- predict(restored,xx,full_layer=TRUE)$results
    expect_equal(r,q,tolerance=1e-12)
  }
})
