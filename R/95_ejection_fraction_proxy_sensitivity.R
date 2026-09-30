# ============================================================================
# 95_ejection_fraction_proxy_sensitivity.R
#
# 目的（审稿意见第 5 条）：MIMIC-IV 与 MIMIC-IV-ECG 都不带 LVEF，因此"心力衰竭
#   伴射血分数降低（HFrEF）"这一人群口径必须说清是怎么落地的。本脚本把
#   scripts/run_lvef_proxy.R 的射血分数代理定义搬到本稿正式口径上重算：
#     - 队列：ltmle_wide_K2_guideline.rds（与主分析同一队列、同一暴露定义）
#     - 估计：与 scripts/run_grace_period_guideline.R 主分析逐项一致
#             （10 个基线协变量、Y_W0 == 0、单点处理节点、
#              g 模型 SL.glm + SL.glmnet、Q 模型主效应 logistic）
#     - 校准：guideline 面板经验原假设（R/92 提升）
#
#   代理定义（与 run_lvef_proxy.R 相同，只在 guideline 队列上重算）：
#     probable HFrEF = 出院诊断含 I50.2x（收缩性心衰）
#                      或 QRS >= 120 ms 且 LBBB（CRT 指征，典型 HFrEF）
#     probable HFpEF = 含 I50.3x（舒张性心衰）且不含 I50.2x 且非上述 CRT 指征
#     两者互斥，均不覆盖的病历为不确定型
#
# 输出：output/tables/v40_ejection_fraction_proxy.csv
# ============================================================================
suppressPackageStartupMessages({
  library(data.table)
  library(ltmle)
  library(EmpiricalCalibration)
})

BASE_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg"
WORK_DIR <- file.path(BASE_DIR, "Topic1_LTMLE_Betablocker")
DATA_DIR <- file.path(WORK_DIR, "DATA")
V40_DIR  <- file.path(WORK_DIR, "第40版")
TAB_DIR  <- file.path(V40_DIR, "output", "tables")
MIMIC_HOSP <- file.path(BASE_DIR, "mimic-iv-2.2/hosp")
set.seed(43)

source(file.path(V40_DIR, "R", "00_config.R"))
source(file.path(V40_DIR, "R", "01_bsr_core.R"))

## ---- 1. 队列与暴露（与主分析同口径） ---------------------------------------
ltmle_K2 <- readRDS(file.path(DATA_DIR, "ltmle_wide_K2_guideline.rds"))
clean_numeric <- function(x, lower = NULL, upper = NULL) {
  x[is.infinite(x)] <- NA_real_; x[is.nan(x)] <- NA_real_
  if (!is.null(lower)) x[x < lower] <- NA_real_
  if (!is.null(upper)) x[x > upper] <- NA_real_
  x
}
ltmle_K2[, L_qtc_W0  := clean_numeric(L_qtc_W0, 200, 800)]
ltmle_K2[, L_hr_W0   := clean_numeric(L_hr_W0, 20, 300)]
ltmle_K2[, L_qrs_W0  := clean_numeric(L_qrs_W0, 40, 250)]
ltmle_K2[, L_egfr_W0 := clean_numeric(L_egfr_W0, 1, 300)]
ltmle_K2[, L_cr_W0   := clean_numeric(L_cr_W0, 0.1, 25)]
for (col in names(ltmle_K2)) {
  if (is.logical(ltmle_K2[[col]])) set(ltmle_K2, j = col, value = as.integer(ltmle_K2[[col]]))
}

## ---- 2. 射血分数代理分类（照抄 run_lvef_proxy.R 的定义） -------------------
hf_cohort <- readRDS(file.path(DATA_DIR, "hf_cohort_processed.rds"))
hf_index  <- unique(hf_cohort[is_baseline_ecg == TRUE, .(subject_id, hosp_hadm_id)])

diag <- fread(file.path(MIMIC_HOSP, "diagnoses_icd.csv"),
              select = c("subject_id", "hadm_id", "icd_code", "icd_version"))
diag_hf <- merge(diag[grepl("^I50", icd_code)], hf_index,
                 by.x = c("subject_id", "hadm_id"),
                 by.y = c("subject_id", "hosp_hadm_id"))
hf_type <- diag_hf[, .(
  has_systolic  = any(grepl("I50\\.?2", icd_code)),
  has_diastolic = any(grepl("I50\\.?3", icd_code))
), by = subject_id]

hf_type <- merge(hf_type, ltmle_K2[, .(subject_id, L_qrs_W0, L_lbbb_W0, Y_W0)],
                 by = "subject_id", all.y = TRUE)
for (cc in c("has_systolic", "has_diastolic")) {
  hf_type[is.na(get(cc)), (cc) := FALSE]
}
hf_type[, prob_hfref := has_systolic | (L_qrs_W0 >= 120 & L_lbbb_W0 == 1)]
hf_type[, prob_hfpef := has_diastolic & !has_systolic &
          !(L_qrs_W0 >= 120 & L_lbbb_W0 == 1)]
hf_type[, indeterminate := !prob_hfref & !prob_hfpef]

cat(sprintf("代理分类（分析队列 %d 人）：收缩性编码 %d；舒张性编码 %d；\n",
            nrow(hf_type), sum(hf_type$has_systolic), sum(hf_type$has_diastolic)))
cat(sprintf("  probable HFrEF %d；probable HFpEF %d；不确定 %d\n",
            sum(hf_type$prob_hfref), sum(hf_type$prob_hfpef), sum(hf_type$indeterminate)))

## ---- 3. 与主分析逐项一致的估计函数 -----------------------------------------
W0_L_vars <- c("L_qtc_W0","L_hr_W0","L_qrs_W0","L_cr_W0","L_egfr_W0",
               "L_k_W0","L_af_W0","L_lbbb_W0","age","gender")

fit_one <- function(dt, label) {
  data_primary <- dt[Y_W0 == 0]
  avail <- intersect(c(W0_L_vars, "A_W0", "Y_W1"), names(data_primary))
  d <- as.data.frame(data_primary[, ..avail])
  d$A_W0   <- as.integer(d$A_W0 >= 2)
  d$gender <- as.numeric(factor(d$gender, levels = c("M", "F")))
  for (col in W0_L_vars) {
    if (col %in% names(d) && is.numeric(d[[col]])) {
      x <- d[[col]]; x[is.infinite(x)] <- NA_real_; x[is.nan(x)] <- NA_real_
      d[[col]][is.na(x)] <- median(x, na.rm = TRUE)
    }
  }
  Qform <- c(Y_W1 = paste("Q.kplus1 ~ A_W0 +", paste(W0_L_vars, collapse = " + ")))
  abar_treat   <- matrix(1, nrow(d), 1); colnames(abar_treat)   <- "A_W0"
  abar_control <- matrix(0, nrow(d), 1); colnames(abar_control) <- "A_W0"
  fit <- ltmle(data = d, Anodes = "A_W0", Lnodes = W0_L_vars, Ynodes = "Y_W1",
               survivalOutcome = FALSE, abar = list(abar_treat, abar_control),
               SL.library = c("SL.glm", "SL.glmnet"), Qform = Qform,
               estimate.time = FALSE)
  s  <- summary(fit)
  rr <- s$effect.measures$RR$estimate
  se <- s$effect.measures$RR$std.dev
  cat(sprintf("  %-28s n=%d  RR=%.4f  logRR=%.4f  se=%.4f\n",
              label, nrow(d), rr, log(rr), se))
  data.frame(subgroup = label, n = nrow(d), n_deaths = sum(d$Y_W1),
             rr_uncal = rr, log_rr_uncal = log(rr), se_log_rr = se,
             stringsAsFactors = FALSE)
}

cat("\n===== 估计（guideline 队列 / 主分析同一配置） =====\n")
rows <- list(
  fit_one(ltmle_K2, "Full cohort (all I50.x)"),
  fit_one(merge(ltmle_K2, hf_type[prob_hfref == TRUE, .(subject_id)], by = "subject_id"),
          "Probable HFrEF"),
  fit_one(merge(ltmle_K2, hf_type[prob_hfpef == TRUE, .(subject_id)], by = "subject_id"),
          "Probable HFpEF")
)
out <- rbindlist(rows)

## ---- 4. 用 guideline 面板做 BAF 校准 ----------------------------------------
bsr   <- readRDS(file.path(OUT_DIR, "data", "bsr_results_v35_guideline.rds"))
nc    <- readRDS(file.path(OUT_DIR, "data",
                           "negative_controls_expanded_guideline.rds"))$estimates
nc_log_rr <- nc$logRr; names(nc_log_rr) <- nc$outcome
nc_se     <- nc$seLogRr; names(nc_se)    <- nc$outcome

cal <- rbindlist(lapply(seq_len(nrow(out)), function(i) {
  obs  <- out$log_rr_uncal[i]; se <- out$se_log_rr[i]
  est  <- bsr_estimate(obs, se, nc_log_rr, nc_se)
  boot <- bsr_bootstrap(obs, se, nc_log_rr, nc_se)
  data.frame(rr_cal = exp(est$log_rr_true), cal_p = est$cal_p,
             baf = boot$bf_median, baf_lo = boot$bf_ci_lo, baf_hi = boot$bf_ci_hi,
             stringsAsFactors = FALSE)
}))
out <- cbind(out, cal)
out[, layer1_pass := cal_p < 0.05]

## 与 R/18 同法：按 BAF 点估计定位 12 桶，取该桶的保守概率（宽窄两列取大）
NUMJ  <- jsonlite::fromJSON(file.path(TAB_DIR, "v40_all_numbers.json"),
                            simplifyVector = FALSE)
LOOKJ <- NUMJ$part2$lookup
brk   <- vapply(LOOKJ, function(x) as.numeric(x$bf_centre), numeric(1))
out[, p_bias_dominated := vapply(seq_len(.N), function(i) {
  b <- max(which(brk <= baf[i]))
  as.numeric(LOOKJ[[b]]$p_bd_conservative)
}, numeric(1))]

print(out, row.names = FALSE, digits = 4)
write.csv(out, file.path(TAB_DIR, "v40_ejection_fraction_proxy.csv"), row.names = FALSE)

## ---- 5. 代理分类计数（供 eMethods 引用，分母为整个队列与分析队列） ----------
cls <- data.frame(
  stratum = c("probable HFrEF", "probable HFpEF", "neither (indeterminate)", "total"),
  n_cohort = c(sum(hf_type$prob_hfref), sum(hf_type$prob_hfpef),
               sum(hf_type$indeterminate), nrow(hf_type)),
  stringsAsFactors = FALSE)
cls$pct_cohort <- 100 * cls$n_cohort / nrow(hf_type)
an <- hf_type[Y_W0 == 0]
cls$n_analytic <- c(sum(an$prob_hfref), sum(an$prob_hfpef),
                    sum(an$indeterminate), nrow(an))
cls$pct_analytic <- 100 * cls$n_analytic / nrow(an)
cls$has_systolic_code  <- c(sum(an$has_systolic),  NA, NA,
                            sum(an$has_systolic))
cls$has_diastolic_code <- c(NA, sum(an$has_diastolic), NA,
                            sum(an$has_diastolic))
print(cls, row.names = FALSE, digits = 4)
write.csv(cls, file.path(TAB_DIR, "v40_ejection_fraction_classification.csv"),
          row.names = FALSE)

cat("\n已写出: output/tables/v40_ejection_fraction_proxy.csv\n",
    "        output/tables/v40_ejection_fraction_classification.csv\n", sep = "")
