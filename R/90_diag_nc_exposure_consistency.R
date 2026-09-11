# ============================================================================
# 90_diag_nc_exposure_consistency.R  —  只读诊断脚本
#
# 目的：量化「12 个负对照所用的暴露定义」与「主分析所用暴露定义」之间的差别，
#       对经验原假设 mu_B / sigma_B 的影响。
#
# 背景：主分析 scripts/run_grace_period_guideline.R 读 ltmle_wide_K2_guideline.rds
#       （A_W0 >= 2 占 12.1%）；12 个负对照
#       scripts/run_negative_controls_expanded_Codex.R 读 ltmle_wide_K2.rds
#       （A_W0 >= 2 占 43.0%）。两文件行数相同（15,053），但 A_W0 的编码含义不同。
#
# 做法：把同一套负对照结局（由 MIMIC-IV 诊断表按 subject_id 合并生成）分别挂到
#       两个队列上，用各自文件的 A_W0 重新拟合 12 个单点 LTMLE，再各做一次
#       EmpiricalCalibration::fitNull。K2 那一路用于自校验：它应当复现
#       DATA/bias_calibration_results.rds$null_fit。
#
# 本脚本不修改任何既有数据或稿件，只写 output/tables/diag_nc_exposure_consistency.*
# ============================================================================
suppressPackageStartupMessages({
  library(data.table)
  library(ltmle)
  library(EmpiricalCalibration)
  library(jsonlite)
})

BASE_DIR   <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg"
WORK_DIR   <- file.path(BASE_DIR, "Topic1_LTMLE_Betablocker")
DATA_DIR   <- file.path(WORK_DIR, "DATA")
V39_DIR    <- file.path(WORK_DIR, "第39版")
TAB_DIR    <- file.path(V39_DIR, "output", "tables")
MIMIC_HOSP <- file.path(BASE_DIR, "mimic-iv-2.2/hosp")
NC_MIN_EVENTS <- 50L

set.seed(43)

# ---- 1. 负对照清单与诊断表（照抄 run_negative_controls_expanded_Codex.R） ----
nc_filtered <- readRDS(file.path(DATA_DIR, "negative_controls_filtered_Codex.rds"))
nc_names    <- names(nc_filtered)
cat(sprintf("负对照个数: %d\n", length(nc_names)))

diag <- fread(file.path(MIMIC_HOSP, "diagnoses_icd.csv"),
              select = c("subject_id", "hadm_id", "icd_code", "icd_version"))
diag[, icd_nodot := gsub("\\.", "", icd_code)]

hf_cohort  <- readRDS(file.path(DATA_DIR, "hf_cohort_processed.rds"))
hf_lookup  <- unique(hf_cohort[, .(subject_id, index_hadm_id = as.character(hosp_hadm_id))])
index_hadm_map <- setNames(hf_lookup$index_hadm_id, hf_lookup$subject_id)

diag_hf <- diag[subject_id %in% hf_cohort$subject_id]
diag_hf[, is_index_hosp := as.character(hadm_id) == index_hadm_map[as.character(subject_id)]]
diag_hf[is.na(is_index_hosp), is_index_hosp := FALSE]
diag_hf[, window := fifelse(is_index_hosp, "W0", "W1")]

for (nc_name in nc_names) {
  nc <- nc_filtered[[nc_name]]
  all_codes <- unique(c(gsub("\\.", "", nc$icd10), gsub("\\.", "", nc$icd9)))
  diag_hf[, paste0("nc_", nc_name) := icd_nodot %chin% all_codes]
}

# ---- 2. 把负对照结局按 subject_id 合并到指定队列 ----
attach_nc <- function(rds_file) {
  dt <- as.data.table(readRDS(rds_file))
  for (nc_name in nc_names) {
    col_name <- paste0("nc_", nc_name)
    for (win in c("W0", "W1")) {
      out_col <- paste0("nc_", nc_name, "_", win)
      nc_pts <- diag_hf[window == win & get(col_name) == TRUE, .(tmp = 1L), by = subject_id]
      if (nrow(nc_pts) > 0) {
        setnames(nc_pts, "tmp", out_col)
        dt <- merge(dt, nc_pts, by = "subject_id", all.x = TRUE)
      }
    }
  }
  for (col in grep("^nc_", names(dt), value = TRUE))
    set(dt, i = which(is.na(dt[[col]])), j = col, value = 0L)
  dt
}

# ---- 3. 单个负对照的单点 LTMLE（照抄 run_nc_ltmle） ----
W0_L_vars <- c("L_qtc_W0","L_hr_W0","L_qrs_W0","L_cr_W0","L_egfr_W0",
               "L_k_W0","L_af_W0","L_lbbb_W0","age","gender")

fit_one_nc <- function(data_valid, nc_col, label) {
  cols_needed <- c(W0_L_vars, "A_W0", nc_col)
  d <- as.data.frame(data_valid[, ..cols_needed])
  names(d)[names(d) == nc_col] <- "Y_W1"
  d$A_W0   <- as.integer(d$A_W0 >= 2)
  d$gender <- as.numeric(factor(d$gender, levels = c("M", "F")))
  for (col in W0_L_vars) {
    if (col %in% names(d) && is.numeric(d[[col]])) {
      x <- d[[col]]; x[is.infinite(x)] <- NA_real_; x[is.nan(x)] <- NA_real_
      d[[col]][is.na(x)] <- median(x, na.rm = TRUE)
    }
  }
  if (sum(d$Y_W1) < NC_MIN_EVENTS) {
    cat(sprintf("    %-28s 事件数 %d < %d，跳过\n", label, sum(d$Y_W1), NC_MIN_EVENTS))
    return(NULL)
  }
  abar_treat   <- matrix(1, nrow(d), 1); colnames(abar_treat)   <- "A_W0"
  abar_control <- matrix(0, nrow(d), 1); colnames(abar_control) <- "A_W0"
  fit <- tryCatch(
    ltmle(data = d, Anodes = "A_W0",
          Lnodes = intersect(W0_L_vars, names(d)), Ynodes = "Y_W1",
          survivalOutcome = FALSE, abar = list(abar_treat, abar_control),
          SL.library = "SL.glm", estimate.time = FALSE),
    error = function(e) { cat(sprintf("    %-28s 失败: %s\n", label, e$message)); NULL })
  if (is.null(fit)) return(NULL)
  s  <- summary(fit)
  rr <- s$effect.measures$RR$estimate
  cat(sprintf("    %-28s n=%d  RR=%.3f  logRR=%.4f  se=%.4f\n",
              label, nrow(d), rr, log(rr), s$effect.measures$RR$std.dev))
  data.frame(outcome = nc_col, label = label, n = nrow(d),
             n_events = sum(d$Y_W1), rr = rr,
             logRr = log(rr), seLogRr = s$effect.measures$RR$std.dev,
             stringsAsFactors = FALSE)
}

run_arm <- function(tag, rds_file) {
  cat(sprintf("\n===== 队列 %s : %s =====\n", tag, basename(rds_file)))
  dt <- attach_nc(rds_file)
  valid <- dt[Y_W0 == 0]
  cat(sprintf("  行数 %d -> Y_W0==0 后 %d ; A_W0>=2 占 %.1f%%\n",
              nrow(dt), nrow(valid),
              100 * mean(as.integer(valid$A_W0) >= 2)))
  rows <- list()
  for (nc_name in nc_names) {
    w1_col <- paste0("nc_", nc_name, "_W1")
    if (!(w1_col %in% names(valid))) next
    r <- fit_one_nc(valid, w1_col, nc_filtered[[nc_name]]$label)
    if (!is.null(r)) rows[[nc_name]] <- r
  }
  est <- do.call(rbind, rows)
  null_fit <- fitNull(logRr = est$logRr, seLogRr = est$seLogRr)
  cat(sprintf("  --> fitNull: mean = %.6f , sd = %.6f  (K=%d)\n",
              null_fit[1], null_fit[2], nrow(est)))
  list(n_total = nrow(dt), n_valid = nrow(valid),
       pct_exposed = 100 * mean(as.integer(valid$A_W0) >= 2),
       estimates = est,
       null_mean = unname(null_fit[1]), null_sd = unname(null_fit[2]))
}

arm_k2    <- run_arm("K2 (负对照现用)", file.path(DATA_DIR, "ltmle_wide_K2.rds"))
arm_guide <- run_arm("guideline (主分析现用)", file.path(DATA_DIR, "ltmle_wide_K2_guideline.rds"))

# ---- 4. 自校验：K2 一路应复现 bias_calibration_results.rds$null_fit ----
ref <- readRDS(file.path(DATA_DIR, "bias_calibration_results.rds"))$null_fit
cat("\n===== 自校验 =====\n")
cat(sprintf("  bias_calibration_results.rds $ null_fit : mean=%.6f  sd=%.6f\n", ref[1], ref[2]))
cat(sprintf("  本次 K2 重算                              : mean=%.6f  sd=%.6f\n",
            arm_k2$null_mean, arm_k2$null_sd))
cat(sprintf("  差                                        : dmean=%+.6f  dsd=%+.6f\n",
            arm_k2$null_mean - ref[1], arm_k2$null_sd - ref[2]))

# ---- 5. 用新原假设重算两个案例的校准后效应（仅点估计，供方向判断） ----
cases <- fromJSON(file.path(TAB_DIR, "v39_all_numbers.json"), simplifyVector = FALSE)$part3$cases
cat("\n===== 若改用 guideline 暴露的负对照，两个案例的校准后效应 =====\n")
cat(sprintf("%-34s %10s %10s %10s %10s\n", "case", "logRR_uncal", "mu_B(old)", "mu_B(new)", "logRR_cal_new"))
for (cs in cases) {
  lr <- cs$log_rr_uncal
  cat(sprintf("%-34s %10.5f %10.5f %10.5f %10.5f\n",
              substr(cs$exposure, 1, 32), lr, cs$mu_b, arm_guide$null_mean,
              lr - arm_guide$null_mean))
}

# ---- 6. 落盘 ----
out <- list(
  generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  question = "12 negative controls were fitted on ltmle_wide_K2.rds while the main analysis used ltmle_wide_K2_guideline.rds; the A_W0 encoding differs between the two files.",
  reference_null_fit = list(mean = unname(ref[1]), sd = unname(ref[2])),
  arm_k2    = arm_k2,
  arm_guide = arm_guide
)
write_json(out, file.path(TAB_DIR, "diag_nc_exposure_consistency.json"),
           pretty = TRUE, auto_unbox = TRUE, digits = 10)
saveRDS(out, file.path(TAB_DIR, "diag_nc_exposure_consistency.rds"))
cat("\n已写出 output/tables/diag_nc_exposure_consistency.json\n")
