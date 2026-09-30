# R/97_direction_regimes_summary.R
# ---------------------------------------------------------------------------
# 把主网格（同号，偏倚放大）与镜像网格（正 mu_B：缩小 / 抵消 / 反转）合并，
# 按「偏倚相对真实效应的方向」分成四支，比较 BAF 估计质量与两层规则的行为。
#
# 输入：
#   output/simulation/comparison_results_v37p1.rds   主网格 960 条件（放大）
#   output/simulation/comparison_results_mirror.rds  镜像网格 960 条件
# 输出：
#   output/tables/v40_direction_regimes.csv          条件级长表（1920 行）
#   output/tables/v40_direction_summary.json         四支总览 + 讲解器序列数据
#
# 四支的定义（psi 为真实 log RR，mu_b 为系统偏倚中心；psi_obs 的期望 = psi + mu_b）：
#   inflation    偏倚与真效应同号且绝对值更大 -> 表观效应被放大
#   shrinkage    偏倚与真效应反号但更小     -> 表观效应朝零缩小
#   cancellation 两者恰好抵消               -> 表观效应为零
#   reversal     偏倚与真效应反号且更大     -> 效应方向被反转
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({ library(jsonlite) })
source("R/00_config.R")
source("R/01_bsr_core.R")

set.seed(20260917)

## ---- 1. 载入两份网格 -------------------------------------------------------
cat("[1] loading both grids ...\n")
res_main   <- readRDS(file.path(SIM_DIR, "comparison_results_v37p1.rds"))
# 允许用环境变量指向别的镜像网格文件（用于脚本自检，正式运行不设该变量）
mirror_rds <- Sys.getenv("MIRROR_RESULTS",
                         file.path(SIM_DIR, "comparison_results_mirror.rds"))
res_mirror <- readRDS(mirror_rds)
stopifnot(length(res_main) == 960, length(res_mirror) == 960)

parse_key <- function(key) {
  psi  <- as.numeric(sub(".*_psi(-?[0-9.]+)_mu.*", "\\1", key))
  mu_b <- as.numeric(sub(".*_mu(-?[0-9.]+)_sps.*", "\\1", key))
  c(psi = psi, mu_b = mu_b)
}

regime_of <- function(psi, mu_b) {
  obs <- psi + mu_b
  if (abs(obs) < 1e-9)        return("cancellation")
  if (sign(obs) != sign(psi)) return("reversal")
  if (abs(obs) > abs(psi))    return("inflation")
  "shrinkage"
}

flatten <- function(res, grid_tag) {
  parts <- vector("list", length(res))
  for (i in seq_along(res)) {
    e   <- res[[i]]
    key <- names(res)[i]
    pm  <- parse_key(key)
    d   <- e$results
    parts[[i]] <- data.frame(
      grid      = grid_tag,
      cond      = key,
      psi       = pm[["psi"]],
      mu_b      = pm[["mu_b"]],
      sigma_ps  = e$sigma_ps,
      K         = if (grepl("K50", e$config_id)) 50L
                  else if (grepl("K25", e$config_id)) 25L else 12L,
      exV       = if (grepl("exV0\\.3", e$config_id)) 0.3 else 0.0,
      bf_true   = e$bf_true,
      true_zone = e$true_zone,
      bf        = d$bf_mcmc,
      lo        = d$ci_lo_mcmc,
      hi        = d$ci_hi_mcmc,
      cal_p     = d$cal_p,
      naive_p   = d$naive_p,
      stringsAsFactors = FALSE)
  }
  do.call(rbind, parts)
}

S <- rbind(flatten(res_main, "main"), flatten(res_mirror, "mirror"))
rm(res_main, res_mirror); invisible(gc())
cat(sprintf("    %s repetitions\n", format(nrow(S), big.mark = ",")))

S$obs_expect <- S$psi + S$mu_b
S$regime <- ifelse(abs(S$obs_expect) < 1e-9, "cancellation",
             ifelse(sign(S$obs_expect) != sign(S$psi), "reversal",
              ifelse(abs(S$obs_expect) > abs(S$psi), "inflation", "shrinkage")))
S$half     <- (S$hi - S$lo) / 2
S$diff     <- S$bf - S$bf_true
S$bd_tru   <- S$bf_true > BF_THRESH_BIAS
S$covered  <- S$lo <= S$bf_true & S$bf_true <= S$hi
S$l1_pass  <- S$cal_p < 0.05
# 规则判定（与正文表 2 的四条规则一致，用 MCMC 口径的 BAF 与区间）
S$zone <- ifelse(is.na(S$bf) | is.na(S$hi), "unclassifiable",
           ifelse(S$hi <= BF_THRESH_BIAS, "effect-dominated",
            ifelse(S$lo > BF_THRESH_BIAS, "bias-dominated", "mixed")))
S$R2 <- S$l1_pass & S$bf  < BF_THRESH_BIAS      # 层 1 + 点估计 < 0.5
S$R3 <- S$l1_pass & S$hi <= BF_THRESH_BIAS      # 层 1 + 区间上界 <= 0.5
S$C2 <- S$hi <= BF_THRESH_BIAS                  # 仅区间上界 <= 0.5

## ---- 2. 条件级长表 ---------------------------------------------------------
cat("[2] condition-level table ...\n")
sp <- split(seq_len(nrow(S)), S$cond)
cond_tab <- do.call(rbind, lapply(sp, function(ix) {
  z <- S[ix, ]
  data.frame(
    grid = z$grid[1], cond = z$cond[1], regime = z$regime[1],
    psi = z$psi[1], mu_b = z$mu_b[1],
    psi_obs_expect = round(z$psi[1] + z$mu_b[1], 4),
    bf_true = round(z$bf_true[1], 4), true_zone = z$true_zone[1],
    sigma_ps = z$sigma_ps[1], K = z$K[1], exV = z$exV[1],
    n_rep = nrow(z),
    mean_bf = round(mean(z$bf), 4),
    bias = round(mean(z$diff), 4),
    rmse = round(sqrt(mean(z$diff^2)), 4),
    sd_diff = round(sd(z$diff), 4),
    zone_match = round(mean(z$zone == z$true_zone), 4),
    coverage = round(mean(z$covered), 4),
    med_half = round(median(z$half), 4),
    layer1_pass = round(mean(z$l1_pass), 4),
    R2_yield = round(mean(z$R2), 4),
    R3_yield = round(mean(z$R3), 4),
    R3_misuse = round(mean(z$bd_tru[z$R3]), 4),
    stringsAsFactors = FALSE)
}))
rownames(cond_tab) <- NULL
write.csv(cond_tab, file.path(TAB_DIR, "v40_direction_regimes.csv"),
          row.names = FALSE)
cat(sprintf("    wrote v40_direction_regimes.csv (%d rows)\n", nrow(cond_tab)))

## ---- 3. 四支总览 -----------------------------------------------------------
cat("[3] regime summary ...\n")
REG_ORDER <- c("inflation", "shrinkage", "cancellation", "reversal")
reg_sum <- do.call(rbind, lapply(REG_ORDER, function(rg) {
  ix <- S$regime == rg
  if (!any(ix)) return(NULL)
  z <- S[ix, ]
  data.frame(
    regime = rg,
    n_cond = length(unique(z$cond)),
    n_rep = nrow(z),
    # BAF 估计质量
    bias_mean = round(mean(z$diff), 4),
    bias_sd = round(sd(z$diff), 4),
    rmse = round(sqrt(mean(z$diff^2)), 4),
    ccc = round({
      m1 <- mean(z$bf); m2 <- mean(z$bf_true)
      s1 <- sd(z$bf);   s2 <- sd(z$bf_true)
      if (s1 == 0 || s2 == 0) NA_real_ else
        2 * cov(z$bf, z$bf_true) / (s1^2 + s2^2 + (m1 - m2)^2)
    }, 4),
    coverage = round(mean(z$covered), 4),
    med_half = round(median(z$half), 4),
    # 分区与规则
    zone_match = round(mean(z$zone == z$true_zone), 4),
    layer1_pass = round(mean(z$l1_pass), 4),
    R2_yield = round(mean(z$R2), 4),
    R3_yield = round(mean(z$R3), 4),
    R3_misuse = round(if (any(z$R3)) mean(z$bd_tru[z$R3]) else NA_real_, 4),
    C2_yield = round(mean(z$C2), 4),
    # 真值构成
    pct_bd_true = round(mean(z$bd_tru), 4),
    stringsAsFactors = FALSE)
}))
rownames(reg_sum) <- NULL
write.csv(reg_sum, file.path(TAB_DIR, "v40_direction_summary.csv"),
          row.names = FALSE)

# 层 1 的过线率还受 sigma_ps 影响，单列一版便于解释
l1_by_sigma <- do.call(rbind, lapply(REG_ORDER, function(rg) {
  z <- S[S$regime == rg, ]
  if (!nrow(z)) return(NULL)
  do.call(rbind, lapply(sort(unique(z$sigma_ps)), function(s) {
    zz <- z[z$sigma_ps == s, ]
    data.frame(regime = rg, sigma_ps = s,
               layer1_pass = round(mean(zz$l1_pass), 4),
               med_half = round(median(zz$half), 4))
  }))
}))

## ---- 4. 讲解器序列数据 -----------------------------------------------------
cat("[4] explainer series ...\n")

# (a) 四支的 BAF_hat - BAF_true 分布（直方图，等比抽样以免主网格支碾压）
brk <- seq(-0.85, 0.85, by = 0.025)
diff_hist <- lapply(REG_ORDER, function(rg) {
  x <- pmin(pmax(S$diff[S$regime == rg], -0.849), 0.849)
  if (!length(x)) return(NULL)
  h <- hist(x, breaks = brk, plot = FALSE)
  list(regime = rg, mid = round(h$mids, 4), count = as.integer(h$counts))
})
names(diff_hist) <- REG_ORDER

# (b) 条件级的 psi/BAF_true 平面：分区准确率与层 1 过线率（每格平均）
grid_cells <- do.call(rbind, lapply(REG_ORDER, function(rg) {
  z <- cond_tab[cond_tab$regime == rg, ]
  if (!nrow(z)) return(NULL)
  agg <- do.call(rbind, lapply(split(z, paste(z$psi, z$mu_b)), function(g) {
    data.frame(regime = rg, psi = g$psi[1], mu_b = g$mu_b[1],
               bf_true = round(mean(g$bf_true), 4),
               zone_match = round(mean(g$zone_match), 4),
               layer1_pass = round(mean(g$layer1_pass), 4),
               bias = round(mean(g$bias), 4))
  }))
  agg
}))

# (c) BAF_true 分箱后的估计质量（三支可比的校准曲线）
S$bf_bin <- cut(S$bf_true, breaks = seq(0, 1, by = 0.1), include.lowest = TRUE)
cal_curve <- do.call(rbind, lapply(REG_ORDER, function(rg) {
  z <- S[S$regime == rg, ]
  if (!nrow(z)) return(NULL)
  do.call(rbind, lapply(split(z, z$bf_bin), function(g) {
    if (nrow(g) < 200) return(NULL)
    q <- quantile(g$bf, c(0.05, 0.25, 0.5, 0.75, 0.95))
    data.frame(regime = rg,
               bf_true = round(mean(g$bf_true), 4), n = nrow(g),
               p05 = round(q[1], 4), p25 = round(q[2], 4),
               p50 = round(q[3], 4), p75 = round(q[4], 4),
               p95 = round(q[5], 4))
  }))
}))

# (d) 向量示意用的锚点：每个 (psi, mu_b) 格点的观察效应期望与偏倚占比
vectors <- unique(cond_tab[, c("regime", "psi", "mu_b", "psi_obs_expect",
                               "bf_true", "true_zone")])
vectors <- vectors[order(vectors$regime, vectors$psi, vectors$mu_b), ]

OUT <- list(
  regimes = reg_sum,
  l1_by_sigma = l1_by_sigma,
  diff_hist = diff_hist,
  grid_cells = grid_cells,
  cal_curve = cal_curve,
  vectors = vectors,
  n_rep_total = nrow(S),
  thresholds = list(bias_dom = BF_THRESH_BIAS, effect_dom = BF_THRESH_EFFECT)
)
write_json(OUT, file.path(TAB_DIR, "v40_direction_summary.json"),
           auto_unbox = TRUE, digits = 6, na = "null", pretty = TRUE)

cat("\n=== 四支总览 ===\n")
print(reg_sum[, c("regime", "n_cond", "bias_mean", "rmse", "coverage",
                  "zone_match", "layer1_pass", "R3_yield", "R3_misuse")])
cat(sprintf("\n[done] wrote v40_direction_summary.json and v40_direction_regimes.csv\n"))
