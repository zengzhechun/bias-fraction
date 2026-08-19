# ============================================================================
# 单条件 200 次重复抽样 · 逐行可复现演示
# 完全忠实于 bias-fraction/analysis/run_sim_worker_v35.R 的机制
# 本脚本只演示「一个条件」: psi=-0.30, muB=-0.20, sigmaB=0.05, K=12, exV=0.30
# ============================================================================

## 第 0 段: 加载依赖与工具函数 ----------------------------------------------
library(EmpiricalCalibration)          # 提供 fitNull() 拟合经验零分布、calibrateP()

# ber_to_bf: 论文记号, BER = |mu_B|/|logRR_cal|, BF = BER/(1+BER)
# 与 biasratio/R/ber-estimate.R:110 的 bf <- ber/(1+ber) 完全一致
ber_to_bf <- function(ber) ber / (1 + ber)

# classify_pt: 点估计三区分类 (与源码第 91-94 行一致)
#   BER > 1      -> 偏倚主导 (红区)
#   BER < 0.5    -> 效应主导 (绿区)
#   0.5 ~ 1      -> 竞争/混合 (黄区)
classify_pt <- function(b) {
  if (is.na(b)) return(NA_character_)
  if (b > 1) "bias-dominated" else if (b < 0.5) "effect-dominated" else "competitive"
}

## 第 1 段: 固定这个条件的 5 个因子 (整轮模拟中不变) -------------------------
true_log_rr <- -0.30   # psi:  主研究真实 log 风险比 (效应量)
bias_mu     <- -0.20   # muB:  真实系统性偏倚 (同时是负对照分布均值)
bias_sigma  <- 0.05    # sigmaB: 负对照离散度 (抽样噪声标准差)
n_nc        <- 12      # K:    负对照个数
ex_violation<- 0.30    # 交互性违反比例 (30% 的负对照其实是「有真效应」的)

## 第 2 段: 由固定因子算出该条件的唯一真值 ---------------------------------
# BER_true = |muB| / |psi| = 0.20/0.30 = 0.6667  -> 落在黄区
bsr_true <- abs(bias_mu) / abs(true_log_rr)
bf_true  <- ber_to_bf(bsr_true)              # 0.40
true_class <- classify_pt(bsr_true)          # "competitive"
cat(sprintf("该条件真值: BER_true=%.4f  BF_true=%.4f  true_class=%s\n",
            bsr_true, bf_true, true_class))

## 第 3 段: 复现源码的确定性种子 (保证 200 次可复现) -----------------------
# 源码第 30-35 行用 expand.grid 构造 84 个基础条件; 我们重建同一张网格,
# 找到本条件所在的行号 i, 再用源码第 127-130 行的公式算 cond_seed。
sim_grid <- expand.grid(
  true_log_rr = c(0, -0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
  bias_mu     = c(-0.05, -0.10, -0.15, -0.20, -0.30, -0.40),
  bias_sigma  = c(0.05, 0.10),
  stringsAsFactors = FALSE
)
i <- which(sim_grid$true_log_rr == true_log_rr &
           sim_grid$bias_mu     == bias_mu     &
           sim_grid$bias_sigma  == bias_sigma)
base_seed <- 42L
cond_seed <- base_seed + i * 7L +
  as.integer(abs(true_log_rr) * 1000) +
  as.integer(abs(bias_mu)     * 100)  +
  as.integer(bias_sigma       * 10)
cat(sprintf("条件网格行号 i=%d  条件种子 cond_seed=%d\n", i, cond_seed))

## 第 4 段: 跑 200 次重复, 每次记录「抽样出来的样本」 -----------------------
n_rep <- 200
# 交互性违反: 取后 round(K*exV) 个负对照作为「被违反」的对照
#   round(12*0.30) = 4  -> 12 个负对照里, 前 8 个均值=-0.20, 后 4 个均值=-0.05
n_ex <- round(n_nc * ex_violation)
nc_bias_template <- c(rep(bias_mu, n_nc - n_ex),        # 8 个干净负对照, 均值 muB
                      rep(bias_mu + 0.15, n_ex))         # 4 个被违反负对照, 均值 muB+0.15

set.seed(cond_seed)   # 与源码一致: 条件内只设一次种子, 200 轮顺序消费随机流

# 预分配「每轮负对照抽样」数据框 (200 轮 x 12 个 = 2400 行) 与「每轮汇总」数据框 (200 行)
nc_rows   <- vector("list", n_rep)   # 每个元素是一轮的 12 个负对照
rep_summ  <- data.frame(rep_id = 1:n_rep, mu_b = NA_real_, sigma_b = NA_real_,
                        obs_log_rr = NA_real_, bsr_est = NA_real_,
                        bf_est = NA_real_, pt_class = NA_character_,
                        stringsAsFactors = FALSE)

for (r in seq_len(n_rep)) {
  # --- 本轮抽样第 1 步: 抽 12 个负对照的观测效应 (主要变异源) ---
  # nc_log_rr[k] ~ N(nc_bias[k], sigmaB); 前 8 个围绕 -0.20, 后 4 个围绕 -0.05
  nc_log_rr <- rnorm(n_nc, mean = nc_bias_template, sd = bias_sigma)

  # --- 本轮抽样第 2 步: 抽 12 个负对照的标准误 (决定 fitNull 的权重) ---
  nc_se <- runif(n_nc, 0.03, 0.12)     # 每个负对照 SE 独立从 U(0.03,0.12) 抽

  # --- 本轮抽样第 3 步: 抽主研究观测效应 (常数 SE, 只抽一次噪声) ---
  se_log_rr  <- 0.06                    # 主研究 SE: 固定常数, 不抽
  obs_log_rr <- true_log_rr + bias_mu + rnorm(1, 0, se_log_rr)
  #   = -0.30 + (-0.20) + N(0,0.06) = -0.50 + 噪声
  #   其中 obs - muB(真实) = -0.30 = psi, 即「去偏后」的真实效应

  # --- 拟合经验零分布: 用 12 个负对照估出 (mu_b, sigma_b) ---
  nf <- fitNull(nc_log_rr, nc_se)      # EmpiricalCalibration::fitNull
  mu_b    <- nf[1]                     # 经验零均值估计 (对 muB 的抽样估计, 带误差)
  sigma_b <- nf[2]                     # 经验零离散度估计

  # --- 计算 BF / BER 点估计 ---
  lt <- obs_log_rr - mu_b              # 去偏后的 logRR = 观测 - 经验零均值
  if (abs(lt) < 1e-8) lt <- if (lt >= 0) 1e-8 else -1e-8   # 防除零
  bsr_est_r <- abs(mu_b) / abs(lt)     # 估计 BER = |mu_b| / |obs - mu_b|
  bf_est_r  <- ber_to_bf(bsr_est_r)

  # --- 记录本轮 ---
  rep_summ[r, ] <- list(rep_id = r, mu_b = mu_b, sigma_b = sigma_b,
                        obs_log_rr = obs_log_rr, bsr_est = bsr_est_r,
                        bf_est = bf_est_r, pt_class = classify_pt(bsr_est_r))
  nc_rows[[r]] <- data.frame(rep_id = r,
                             nc_id = 1:n_nc,
                             is_shifted = c(rep(FALSE, n_nc - n_ex), rep(TRUE, n_ex)),
                             nc_bias_true = nc_bias_template,
                             nc_log_rr = nc_log_rr,
                             nc_se = nc_se,
                             stringsAsFactors = FALSE)
}

## 第 5 段: 展示「抽样出来的样本」数据框长什么样 ----------------------------
nc_all  <- do.call(rbind, nc_rows)          # 2400 行: 每轮 12 个负对照
nc_rep1 <- nc_all[nc_all$rep_id == 1, ]     # 取第 1 轮的 12 个负对照 (最具体的「样本」)
cat("\n===== 第 1 轮抽出的 12 个负对照 (这就是「样本数据框」的一行批) =====\n")
print(nc_rep1, row.names = FALSE)

cat("\n===== 200 轮逐轮汇总数据框 (前 8 行) =====\n")
print(head(rep_summ, 8), row.names = FALSE)

cat(sprintf("\n200 轮: mu_b 均值=%.4f (真值应≈%.2f, 因 4 个被违反对照被拉向 -0.05 而偏高)\n",
            mean(rep_summ$mu_b), bias_mu))
cat(sprintf("200 轮: bsr_est 均值=%.4f (真值 %.4f)  落入各区占比:\n", mean(rep_summ$bsr_est), bsr_true))
cat("  红区(bias>1):", round(100*mean(rep_summ$pt_class=="bias-dominated"),1), "%\n")
cat("  黄区(comp  ):", round(100*mean(rep_summ$pt_class=="competitive"),1),     "%\n")
cat("  绿区(eff<0.5):", round(100*mean(rep_summ$pt_class=="effect-dominated"),1),"%\n")

## 第 6 段: 落盘, 便于用户直接打开核对 ----------------------------------------
write.csv(rep_summ, "/tmp/condition_walkthrough_rep200.csv", row.names = FALSE)
write.csv(nc_rep1, "/tmp/condition_walkthrough_nc_rep1.csv", row.names = FALSE)
cat("\n已写出:\n  /tmp/condition_walkthrough_rep200.csv  (200 行逐轮汇总)\n  /tmp/condition_walkthrough_nc_rep1.csv (第1轮 12 个负对照)\n")
