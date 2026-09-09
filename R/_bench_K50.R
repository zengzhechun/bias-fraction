# K=50 单条件耗时实测（不改任何产物文件）
source("R/00_config.R")
source("R/02_comparison_study.R")

cat(R.version.string, "\n")
for (K in c(25, 50)) {
  t1 <- Sys.time()
  r <- run_method_compare(
    true_log_rr = -0.20, bias_mu = -0.20, bias_sigma = 0.05,
    n_nc = K, ex_violation = 0.0,
    n_rep = 1000, seed = 43,
    se_psi_obs = 0.06,
    mcmc_iter = 400, mcmc_warmup = 100)
  el <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
  cat(sprintf("K=%3d  1000 reps  耗时 %6.1f s   (MC/MCMC 均含)\n", K, el))
}
cat("\n按此推算 320 个新条件的总时长：\n")
cat(sprintf("  K=25 基准: %.1f s/条件 -> %.1f 小时\n", 14.1, 14.1*320/3600))
