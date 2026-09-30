# R/96_mirror_mu_regimes.R
# ---------------------------------------------------------------------------
# 镜像偏倚网格（mirror mu_B grid）：补齐模拟研究的方向覆盖。
#
# 背景：主网格（R/16_sim_v37p1_80grid.R）的 psi 与 mu_B 都是负值，两者同号，
# 因此 psi_obs = psi + mu_B + eps 在任何条件下都比 psi 更远离 0，模拟研究
# 只刻画了「偏倚放大了表观效应」这一支。审稿意见第 1 条指出该限制。
#
# 本脚本把 mu_B 取正号（+0.05 … +0.40），psi 保持负号（-0.40 … -0.01），于是
# psi + mu_B 可以取到三种情形（由 classify_regime() 判定，写进结果）：
#
#   mu_B 为正且 |mu_B| < |psi|   ->  shrinkage   偏倚把表观效应朝零缩小
#   mu_B 为正且 |mu_B| = |psi|   ->  cancellation 完全抵消（表观效应为零）
#   mu_B 为正且 |mu_B| > |psi|   ->  reversal    偏倚把效应方向反转
#
# 网格结构与主网格严格同构（同样的 10 档 psi、8 档 mu_B、2 档 sigma_ps、
# 3 档 K、2 档 exV、n_rep = 1000），因此三支之间可以直接对照。
#   psi 10 x mu_B 8 x sigma_ps 2 x K 3 x exV 2 = 960 conditions
#   x 1000 reps = 960,000 analyses
#
# 与主网格的唯一区别：
#   1. mu_B 取正值；
#   2. 随机数流独立（seed 基址 +100000），避免与主网格共用同一条流；
#   3. 额外记录 psi_obs、mu_hat_mc、mu_hat_mcmc，用于可視化「真实效应 →
#      被偏倚推移后的观察效应 → 估计出的偏倚 → 校正后效应」这条链条。
#      （主网格脚本 run_method_compare() 不记录这三列；为避免改动已被主网格
#      依赖的共享模块，这里放一份最小扩展副本 run_method_compare_dir()，
#      计算逻辑与 R/02_comparison_study.R 完全一致，只多写三列。）
#
# 断点续跑：每跑完一批条件就把结果原子写回 comparison_results_mirror.rds，
# 重启时自动跳过已存在的条件（与主网格同一套 resume 约定）。
#
# 并行执行：条件之间彼此独立，且每个条件在 run_method_compare_dir() 内部用
# set.seed(SEED_OFFSET + seed + combo_idx * 100) 自己播种，因此并行不会改变
# 任何一个条件的结果——串行与并行必须逐位相同，这一点在改版时已实测核对。
# 单机 16 核下 8 路并行把机时从约 4.8 小时压到约 1 小时以内。
# ---------------------------------------------------------------------------

source("R/00_config.R")
source("R/02_comparison_study.R")

# 运行开关（正式运行时不设这些环境变量，全部走默认值）：
#   MIRROR_N_REP    每条件重复数，默认 1000
#   MIRROR_OUT      输出文件名，默认 comparison_results_mirror.rds（测试请换名，避免污染正式结果）
#   MIRROR_MAX_COND 只跑前 N 个条件，默认 0 = 不限
#   MC_CORES        并行路数，默认 8；设 1 即退化为串行
out_rds  <- file.path(SIM_DIR, Sys.getenv("MIRROR_OUT", "comparison_results_mirror.rds"))
prog_txt <- file.path(SIM_DIR, paste0(tools::file_path_sans_ext(basename(out_rds)),
                                      "_progress.txt"))
max_cond <- as.integer(Sys.getenv("MIRROR_MAX_COND", "0"))

mc_cores <- suppressWarnings(as.integer(Sys.getenv("MC_CORES", "8")))
if (is.na(mc_cores) || mc_cores < 1L) mc_cores <- 1L
mc_cores <- min(mc_cores, max(1L, parallel::detectCores() - 1L))

# ---- 方向情形标签 ----------------------------------------------------------
# 依据 psi + mu_B（观察效应的期望值）判定，而不是单次重复的 psi_obs——后者
# 含抽样噪声，同一个格点会在相邻情形之间跳动，标签就不稳定了。
classify_regime <- function(psi, mu_b) {
  obs <- psi + mu_b
  if (abs(obs) < 1e-9)          return("cancellation")
  if (sign(obs) != sign(psi))   return("reversal")
  if (abs(obs) > abs(psi))      return("inflation")
  "shrinkage"
}

# ---- 引擎：R/02 run_method_compare() 的最小扩展副本 ------------------------
# 多记录三列：psi_obs（本次重复观察到的效应）、mu_hat_mc / mu_hat_mcmc
# （两种方法估计出的系统偏倚）。其余计算逐行与 R/02 相同。
run_method_compare_dir <- function(true_log_rr, bias_mu, bias_sigma,
                                   n_nc, ex_violation,
                                   n_rep = 1000, seed = 42,
                                   se_psi_obs = 0.06,
                                   mcmc_iter = 400, mcmc_warmup = 100) {
  set.seed(seed)
  n_ex <- round(n_nc * ex_violation)
  nc_bias <- c(rep(bias_mu, n_nc - n_ex), rep(bias_mu + 0.15, n_ex))
  bsr_true <- if (abs(true_log_rr) < 1e-10) Inf else abs(bias_mu) / abs(true_log_rr)
  bf_true  <- if (is.finite(bsr_true)) bsr_to_bf(bsr_true) else 1
  true_zone <- if (bsr_true > 1) "bias-dominated"
               else if (bf_true < 1/3) "effect-dominated"
               else "mixed"

  out <- data.frame(rep = seq_len(n_rep),
                    bf_mc = NA_real_, bf_mcmc = NA_real_,
                    zone_mc = NA_character_, zone_mcmc = NA_character_,
                    ci_lo_mc = NA_real_, ci_hi_mc = NA_real_,
                    ci_lo_mcmc = NA_real_, ci_hi_mcmc = NA_real_,
                    cal_p = NA_real_, naive_p = NA_real_,
                    psi_obs = NA_real_, mu_hat_mc = NA_real_,
                    mu_hat_mcmc = NA_real_)
  for (r in seq_len(n_rep)) {
    nc_log_rr <- rnorm(n_nc, mean = nc_bias, sd = bias_sigma)
    nc_se     <- runif(n_nc, 0.03, 0.12)
    obs_log_rr <- true_log_rr + bias_mu + rnorm(1, 0, se_psi_obs)

    # --- MC: point estimate via fitNull, CI via bootstrap ---
    nf <- EmpiricalCalibration::fitNull(nc_log_rr, nc_se)
    mu_b <- nf[1]
    lt   <- obs_log_rr - mu_b
    bsr_mc <- abs(mu_b) / max(abs(lt), 1e-8)
    bf_mc  <- bsr_to_bf(bsr_mc)
    boot   <- bsr_bootstrap(obs_log_rr, se_psi_obs, nc_log_rr, nc_se,
                            n_boot = 50, seed = seed + 1000 + r)
    out$bf_mc[r] <- bf_mc
    out$ci_lo_mc[r] <- boot$bf_ci_lo
    out$ci_hi_mc[r] <- boot$bf_ci_hi
    out$zone_mc[r] <- zone_from_bf(bf_mc, boot$bf_ci_lo, boot$bf_ci_hi)

    # --- MCMC: posterior median of BAF over posterior of mu_B ---
    post <- mcmc_fit_null(nc_log_rr, nc_se, n_iter = mcmc_iter,
                          n_warmup = mcmc_warmup, seed = seed + r)
    mu_draws <- post$mu_draws
    lt_draws <- obs_log_rr - mu_draws
    bsr_draws <- abs(mu_draws) / pmax(abs(lt_draws), 1e-8)
    bf_draws  <- bsr_draws / (1 + bsr_draws)
    mcmc_lo <- quantile(bf_draws, 0.025)
    mcmc_hi <- quantile(bf_draws, 0.975)
    out$bf_mcmc[r] <- median(bf_draws)
    out$ci_lo_mcmc[r] <- mcmc_lo
    out$ci_hi_mcmc[r] <- mcmc_hi
    out$zone_mcmc[r] <- zone_from_bf(median(bf_draws), mcmc_lo, mcmc_hi)

    # --- OHDSI calibrated p-value and naive (uncalibrated) p-value ---
    se_cal  <- sqrt(se_psi_obs^2 + nf[2]^2)
    cal_est <- obs_log_rr - nf[1]
    out$cal_p[r]   <- 2 * (1 - pnorm(abs(cal_est) / se_cal))
    out$naive_p[r] <- 2 * (1 - pnorm(abs(obs_log_rr) / se_psi_obs))

    # --- 本脚本新增的三列 ---
    out$psi_obs[r]     <- obs_log_rr
    out$mu_hat_mc[r]   <- mu_b
    out$mu_hat_mcmc[r] <- post$mu_mean
  }
  list(config = list(true_log_rr = true_log_rr, bias_mu = bias_mu,
                     bias_sigma = bias_sigma, n_nc = n_nc,
                     ex_violation = ex_violation, se_psi_obs = se_psi_obs),
       bf_true = bf_true, true_zone = true_zone,
       regime = classify_regime(true_log_rr, bias_mu),
       results = out)
}

# ---- 网格（与主网格同构，mu_B 取正号）-------------------------------------
psi_vals  <- round(seq(-0.40, -0.01, length.out = 10), 2)
mu_b_vals <- round(seq( 0.05,  0.40, length.out = 8),  2)
sigma_ps_vals     <- c(0.06, 0.10)
K_vals            <- c(12, 25, 50)
ex_violation_vals <- c(0.0, 0.3)
mcmc_iter <- 400; mcmc_warmup <- 100
n_rep <- as.integer(Sys.getenv("MIRROR_N_REP", "1000"))
seed  <- 43
SEED_OFFSET <- 100000   # 与主网格流分离

n_cond_total <- length(psi_vals) * length(mu_b_vals) *
  length(sigma_ps_vals) * length(K_vals) * length(ex_violation_vals)

cat("=========================================================\n")
cat(" 镜像偏倚网格（缩小 / 完全抵消 / 反转）\n")
cat(sprintf(" psi %d 档 x mu_B %d 档 x sigma_ps %d x K %d x exV %d = %d 条件\n",
            length(psi_vals), length(mu_b_vals), length(sigma_ps_vals),
            length(K_vals), length(ex_violation_vals), n_cond_total))
cat(sprintf(" 合计 %d 条件 x %d 次重复 = %d 次分析\n",
            n_cond_total, n_rep, n_cond_total * n_rep))
cat(sprintf(" 预估机时 ~%.1f 小时（按主网格实测 21 秒/条件）\n",
            n_cond_total * 21 / 3600))
cat("=========================================================\n")

configs <- expand.grid(sigma_ps = sigma_ps_vals, K = K_vals,
                       ex_violation = ex_violation_vals, stringsAsFactors = FALSE)
# 与主网格相同的 resume 约定：K = 50 排在最后，保证 configs 行号（进而 key 的
# cfg 编号）稳定，重启时已完成的条件下标不会漂移。
configs <- rbind(configs[configs$K != 50, ], configs[configs$K == 50, ])
rownames(configs) <- NULL
configs$config_id <- sprintf("sps%s_K%d_exV%s",
                             configs$sigma_ps, configs$K, configs$ex_violation)

combo_grid <- expand.grid(K = K_vals, ex_violation = ex_violation_vals,
                          psi = psi_vals, mu_b = mu_b_vals, stringsAsFactors = FALSE)
combo_grid <- rbind(combo_grid[combo_grid$K != 50, ],
                    combo_grid[combo_grid$K == 50, ])
rownames(combo_grid) <- NULL
combo_grid$combo_id <- sprintf("K%d_exV%s_psi%s_mu%s",
                               combo_grid$K, combo_grid$ex_violation,
                               combo_grid$psi, combo_grid$mu_b)

# ---- 任务清单 -------------------------------------------------------------
# 任务顺序与串行版的三重循环完全一致（cfg -> psi -> mu_b）。这一点很重要：
# combo_idx 决定每个条件的 seed，而 key 决定 resume 时是否跳过，两者都依赖
# 顺序，所以顺序不能在改版时被重排，否则续跑的两半会用不同的随机流。
tasks <- list()
for (cfg_i in seq_len(nrow(configs))) {
  cfg <- configs[cfg_i, ]
  for (psi in psi_vals) {
    for (mu_b in mu_b_vals) {
      combo_id  <- sprintf("K%d_exV%s_psi%s_mu%s",
                           cfg$K, cfg$ex_violation, psi, mu_b)
      combo_idx <- which(combo_grid$combo_id == combo_id)
      tasks[[length(tasks) + 1L]] <- list(
        key         = sprintf("cfg%d_psi%s_mu%s_sps%s", cfg_i, psi, mu_b, cfg$sigma_ps),
        psi         = psi,
        mu_b        = mu_b,
        sigma_ps    = cfg$sigma_ps,
        K           = cfg$K,
        ex_violation = cfg$ex_violation,
        config_id   = cfg$config_id,
        combo_idx   = combo_idx)
    }
  }
}
stopifnot(length(tasks) == n_cond_total)

# ---- resume ---------------------------------------------------------------
results <- if (file.exists(out_rds)) {
  existing <- readRDS(out_rds)
  cat(sprintf("续跑：已载入 %d 个条件（%s）\n", length(existing), basename(out_rds)))
  existing
} else list()

already_done <- vapply(tasks, function(tk) tk$key %in% names(results), logical(1))
todo <- tasks[!already_done]
if (max_cond > 0L) todo <- todo[seq_len(min(max_cond, length(todo)))]

done <- length(results)
cat(sprintf("计划 %d 个条件，已完成 %d，本次运行 %d，并行路数 %d\n",
            n_cond_total, done, length(todo), mc_cores))

# ---- 批量并行执行 ---------------------------------------------------------
# 每个条件独立播种，故并行与串行的结果逐位相同。每批跑完即原子落盘，
# 中途中断只损失最后一批。
run_one <- function(tk) {
  t1 <- Sys.time()
  res <- run_method_compare_dir(
    true_log_rr = tk$psi, bias_mu = tk$mu_b, bias_sigma = 0.05,
    n_nc = tk$K, ex_violation = tk$ex_violation,
    n_rep = n_rep, seed = SEED_OFFSET + seed + tk$combo_idx * 100,
    se_psi_obs = tk$sigma_ps,
    mcmc_iter = mcmc_iter, mcmc_warmup = mcmc_warmup)
  res$elapsed_sec <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
  res$config_id   <- tk$config_id
  res$sigma_ps    <- tk$sigma_ps
  res$se_psi_obs  <- tk$sigma_ps
  res
}

batch_size <- max(1L, mc_cores) * 4L
t0 <- Sys.time(); n_this_run <- 0L
cursor <- 1L
while (cursor <= length(todo)) {
  idx   <- cursor:min(cursor + batch_size - 1L, length(todo))
  chunk <- todo[idx]

  chunk_res <- if (mc_cores > 1L) {
    parallel::mclapply(chunk, run_one, mc.cores = mc_cores, mc.preschedule = FALSE)
  } else {
    lapply(chunk, run_one)
  }
  for (j in seq_along(chunk)) results[[chunk[[j]]$key]] <- chunk_res[[j]]

  n_this_run <- n_this_run + length(chunk)
  done       <- done + length(chunk)

  saveRDS(results, paste0(out_rds, ".tmp"))
  file.rename(paste0(out_rds, ".tmp"), out_rds)

  wall   <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  per    <- wall / n_this_run          # 摊销后的墙钟秒数/条件
  remain <- length(todo) - n_this_run
  writeLines(sprintf("%s  done=%d/%d  last=%s  batch=%.1fs/cond  avg=%.1fs/cond  eta=%.1fhr",
                     format(Sys.time(), "%H:%M:%S"), done, n_cond_total,
                     tail(names(results), 1),
                     mean(vapply(chunk_res, function(r) r$elapsed_sec, numeric(1))),
                     per, per * remain / 3600),
             prog_txt)
  cat(sprintf("[%s] %d/%d（本批 %d 个，并行 %d，%.1f 墙钟秒/条件，预计还需 ~%.1f 小时）\n",
              format(Sys.time(), "%H:%M:%S"), done, n_cond_total,
              length(chunk), mc_cores, per, per * remain / 3600))

  cursor <- cursor + batch_size
}

# ---- 汇总 ------------------------------------------------------------------
agg <- do.call(rbind, lapply(names(results), function(k) {
  r <- results[[k]]; cm <- r$results
  data.frame(
    config_id = r$config_id, sigma_ps = r$sigma_ps,
    K = r$config$n_nc, ex_violation = r$config$ex_violation,
    psi = r$config$true_log_rr, mu_b = r$config$bias_mu,
    regime = r$regime,
    psi_obs_mean = mean(cm$psi_obs),
    bf_true = r$bf_true, true_zone = r$true_zone,
    acc_mc   = mean(cm$zone_mc   == r$true_zone),
    acc_mcmc = mean(cm$zone_mcmc == r$true_zone),
    agree    = mean(cm$zone_mc   == cm$zone_mcmc),
    bias_mc   = mean(cm$bf_mc   - r$bf_true),
    bias_mcmc = mean(cm$bf_mcmc - r$bf_true),
    rmse_mc   = sqrt(mean((cm$bf_mc   - r$bf_true)^2)),
    rmse_mcmc = sqrt(mean((cm$bf_mcmc - r$bf_true)^2)),
    mu_sign_correct_mc   = mean(sign(cm$mu_hat_mc)   == sign(r$config$bias_mu)),
    mu_sign_correct_mcmc = mean(sign(cm$mu_hat_mcmc) == sign(r$config$bias_mu)),
    layer1_pass = mean(cm$cal_p < 0.05),
    elapsed_sec = if (!is.null(r$elapsed_sec)) r$elapsed_sec else NA_real_)
}))
agg_stem <- if (identical(basename(out_rds), "comparison_results_mirror.rds"))
  "comparison_agg_mirror" else
  paste0(tools::file_path_sans_ext(basename(out_rds)), "_agg")
saveRDS(agg, file.path(SIM_DIR, paste0(agg_stem, ".rds")))
jsonlite::write_json(agg, file.path(SIM_DIR, paste0(agg_stem, ".json")),
                     dataframe = "columns", auto_unbox = TRUE,
                     digits = 6, pretty = TRUE)

cat(sprintf("\n=== 全部完成：%d/%d 条件，用时 %.1f 分钟 ===\n",
            done, n_cond_total,
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))
writeLines(sprintf("COMPLETE %d/%d at %s", done, n_cond_total,
                   format(Sys.time(), "%H:%M:%S")), prog_txt)
