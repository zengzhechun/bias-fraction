# 第38版 / 任务2 (Plan A): Q2 (GDMT) baseline SMD table
# Mirrors R/25_adjusted_smd_iptw.R (Q1, BB) but for the GDMT question.
# Authoritative treatment definition: scripts/run_ltmle_gdmt.R
#   - cohort: Y_W0 == 0 (14,677 grace-period survivors, SAME as Q1 Table 3)
#   - A_gdmt_W0 is BINARY in the data; the analysis sets abar opt=1 / subopt=0,
#     and imputes A_gdmt_W0[NA] -> 0, so the contrast is
#     Optimized GDMT = A_gdmt_W0 == 1 (n = 1744) vs Not optimized = A_gdmt_W0 != 1
#     (n = 12,933; 9,439 observed 0 + 3,494 missing imputed to 0).
#   - NOTE: the manuscript/code label ">=2/3 classes" overstates the threshold;
#     the actual data implement a binary received-vs-not contrast. The table below
#     uses the binary contrast that produced the published GDM case-study numbers.
# Two SMD口径:
#   optA = IPTW 倾向模型含全部 16 个 Table 3 变量 (balance-check 口径, 与论文叙事一致)
#   optB = IPTW 倾向模型仅含估计 g 模型使用的 10 个协变量 (estimation-honest 口径)
# The published eTable uses optA (avoids the #69 consistency trap).
suppressMessages({ library(data.table) })

BASE_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker"
DATA_DIR <- file.path(BASE_DIR, "DATA")
OUT_DIR  <- file.path(BASE_DIR, "第38版", "output")
TAB_DIR  <- file.path(OUT_DIR, "tables")

# ---- 1. 加载并按 run_baseline_smd.R 清洗 (与 Q1 同口径) ----
ltmle_K2 <- readRDS(file.path(DATA_DIR, "ltmle_wide_K2_gdmt.rds"))
d <- as.data.frame(ltmle_K2)
d <- d[d$Y_W0 == 0, ]                                  # grace-period survivors, 14677

# GDMT treatment (binary, per run_ltmle_gdmt.R): NA -> Not optimized
d$A_gdmt_W0[is.na(d$A_gdmt_W0)] <- 0
d$treat <- factor(ifelse(d$A_gdmt_W0 == 1, "Optimized GDMT", "Not optimized GDMT"),
                  levels = c("Optimized GDMT", "Not optimized GDMT"))

clean_num <- function(x, lower = NULL, upper = NULL) {
  x[is.infinite(x)] <- NA_real_; x[is.nan(x)] <- NA_real_
  if (!is.null(lower)) x[x < lower] <- NA_real_
  if (!is.null(upper)) x[x > upper] <- NA_real_
  x
}
d$age      <- clean_num(d$age, 18, 100)
d$L_qtc_W0 <- clean_num(d$L_qtc_W0, 200, 800)
d$L_hr_W0  <- clean_num(d$L_hr_W0, 20, 300)
d$L_qrs_W0 <- clean_num(d$L_qrs_W0, 40, 250)
d$L_egfr_W0 <- clean_num(d$L_egfr_W0, 1, 300)
d$L_cr_W0  <- clean_num(d$L_cr_W0, 0.1, 25)
d$L_k_W0   <- clean_num(d$L_k_W0, 1.5, 10)
d$L_na_W0  <- clean_num(d$L_na_W0, 110, 180)
d$L_hb_W0  <- clean_num(d$L_hb_W0, 4, 22)
d$gender   <- factor(d$gender, levels = c("M","F"))
d$L_af_W0  <- factor(ifelse(d$L_af_W0 == 1, "Yes","No"), levels = c("No","Yes"))
d$L_lbbb_W0<- factor(ifelse(d$L_lbbb_W0 == 1, "Yes","No"), levels = c("No","Yes"))
d$egfr_lt60    <- factor(ifelse(d$L_egfr_W0 < 60, "Yes","No"), levels = c("No","Yes"))
d$qtc_prolonged<- factor(ifelse((d$gender=="M" & d$L_qtc_W0>460) | (d$gender=="F" & d$L_qtc_W0>480), "Yes","No"), levels=c("No","Yes"))
d$qrs_ge120    <- factor(ifelse(d$L_qrs_W0 >= 120, "Yes","No"), levels = c("No","Yes"))
d$age_ge75     <- factor(ifelse(d$age >= 75, "Yes","No"), levels = c("No","Yes"))

# ---- 2. 16 个 Table 3 变量 ----
cont16 <- c("age","L_hr_W0","L_qrs_W0","L_qtc_W0","L_cr_W0","L_egfr_W0","L_hb_W0","L_na_W0","L_k_W0")
bin16  <- c("gender","L_af_W0","L_lbbb_W0","qtc_prolonged","qrs_ge120","egfr_lt60","age_ge75")
all16  <- c(cont16, bin16)
gmodel10 <- c("L_qtc_W0","L_hr_W0","L_qrs_W0","L_cr_W0","L_egfr_W0","L_k_W0","L_af_W0","L_lbbb_W0","age","gender")

# 处理为数值 (二值 0/1; 连续 原值; NA 保留)
to_num <- function(v){
  x <- d[[v]]
  if(is.factor(x)) as.numeric(x) - 1 else as.numeric(x)
}
X <- sapply(all16, to_num)          # 16 列, NA 保留
Xg <- sapply(gmodel10, to_num)      # 10 列
trt01 <- as.numeric(d$treat == "Optimized GDMT")   # 1=optimized

# ---- 3. 未调整 SMD (同分母约定) ----
smd_unadj <- numeric(length(all16)); names(smd_unadj) <- all16
for(v in all16){
  x <- X[,v]; ok <- !is.na(x)
  xt <- x[ok & trt01==1]; xc <- x[ok & trt01==0]
  if(v %in% cont16){
    denom <- sqrt((var(xt)+var(xc))/2)
    smd_unadj[v] <- (mean(xt)-mean(xc))/denom
  } else {
    p <- (mean(xt)+mean(xc))/2
    denom <- sqrt(p*(1-p))
    smd_unadj[v] <- (mean(xt)-mean(xc))/denom
  }
}

# ---- 4. stabilized IPTW + 加权 SMD ----
compute_adj <- function(Xmat, cov_names){
  Xc <- Xmat
  for(j in 1:ncol(Xc)){
    na.idx <- is.na(Xc[,j])
    if(any(na.idx)){
      if(is.numeric(Xc[,j])) Xc[na.idx,j] <- median(Xc[,j], na.rm=TRUE)
      else Xc[na.idx,j] <- 0
    }
  }
  colnames(Xc) <- cov_names
  ps <- predict(glm(trt01 ~ ., data=as.data.frame(Xc), family=binomial), type="response")
  p1 <- mean(trt01)
  sw <- ifelse(trt01==1, p1/ps, (1-p1)/(1-ps))
  sw <- pmin(pmax(sw, 1e-3), 20)     # 截断极端权重
  out <- numeric(length(all16)); names(out) <- all16
  for(v in all16){
    x <- X[,v]; ok <- !is.na(x)
    xt <- x[ok & trt01==1]; xc <- x[ok & trt01==0]
    wt <- sw[ok & trt01==1]; wc <- sw[ok & trt01==0]
    if(v %in% cont16){
      denom <- sqrt((var(xt)+var(xc))/2)
      m1 <- sum(wt*xt)/sum(wt); m0 <- sum(wc*xc)/sum(wc)
      out[v] <- (m1-m0)/denom
    } else {
      p <- (mean(xt)+mean(xc))/2; denom <- sqrt(p*(1-p))
      m1 <- sum(wt*xt)/sum(wt); m0 <- sum(wc*xc)/sum(wc)
      out[v] <- (m1-m0)/denom
    }
  }
  list(sw=sw, smd=out)
}
resA <- compute_adj(X,  all16)
resB <- compute_adj(Xg, gmodel10)

# ---- 5. 两组分布 (供 eTable 7) ----
# 标签与 Table 3 完全一致；顺序与 all16 对齐
lab_map <- c(age="Age, mean (SD), y", gender="Female, n (%)",
  L_hr_W0="Heart rate, mean (SD), bpm", L_qrs_W0="QRS duration, mean (SD), ms",
  L_qtc_W0="QTc interval, mean (SD), ms", L_cr_W0="Creatinine, mean (SD), mg/dL",
  L_egfr_W0="eGFR, mean (SD), mL/min/1.73m^2", L_hb_W0="Hemoglobin, mean (SD), g/dL",
  L_na_W0="Sodium, mean (SD), mEq/L", L_k_W0="Potassium, mean (SD), mEq/L",
  L_af_W0="Atrial fibrillation, n (%)", L_lbbb_W0="Left bundle branch block, n (%)",
  qtc_prolonged="Prolonged QTc, n (%)", qrs_ge120="Wide QRS (>=120 ms), n (%)",
  egfr_lt60="eGFR <60 mL/min/1.73m^2, n (%)", age_ge75="Age >=75 y, n (%)")
sec_fn <- function(v){
  if (v %in% c("age","gender","age_ge75")) return("Demographics")
  if (v %in% c("L_cr_W0","L_egfr_W0","L_hb_W0","L_na_W0","L_k_W0","egfr_lt60")) return("Laboratory")
  "Electrocardiographic"
}
grp_summary <- function(){
  rows <- list()
  for(v in all16){
    x <- X[,v]; ok <- !is.na(x)
    xt <- x[ok & trt01==1]; xc <- x[ok & trt01==0]
    if(v %in% cont16){
      o <- c(mean(xt), sd(xt), mean(xc), sd(xc))
    } else {
      n1 <- sum(ok & trt01==1); n0 <- sum(ok & trt01==0)
      o <- c(100*mean(xt), n1, 100*mean(xc), n0)   # pct, n
    }
    rows[[v]] <- c(label=lab_map[v], section=sec_fn(v),
                   opt=o[1], opt_n=o[2], not=o[3], not_n=o[4],
                   unadj=as.numeric(smd_unadj[v]), adjA=as.numeric(resA$smd[v]))
  }
  as.data.frame(do.call(rbind, rows), stringsAsFactors=FALSE)
}
groups <- grp_summary()

# ---- 6. 汇总 ----
n_total <- nrow(d)
n_opt   <- sum(trt01==1)
n_not   <- sum(trt01==0)
n_missing_gdmt <- sum(is.na(ltmle_K2$A_gdmt_W0[ltmle_K2$Y_W0 == 0]))
summ <- list(
  n_total = n_total, n_opt = n_opt, n_not = n_not, n_missing_gdmt = n_missing_gdmt,
  n_imb_unadj = sum(abs(smd_unadj) > 0.10),
  mean_abs_unadj = mean(abs(smd_unadj)),
  max_unadj = max(abs(smd_unadj)),
  n_imb_adjA = sum(abs(resA$smd) > 0.10),
  max_adjA = max(abs(resA$smd)),
  n_imb_adjB = sum(abs(resB$smd) > 0.10),
  max_adjB = max(abs(resB$smd))
)

cat("=== Q2 GDMT baseline SMD ===\n")
cat(sprintf("N = %d (Optimized %d, Not optimized %d)\n", n_total, n_opt, n_not))
cat("Unadjusted: ", sprintf("%d/%d exceed 0.10; mean|smd|=%.3f max=%.3f\n",
    summ$n_imb_unadj, length(all16), summ$mean_abs_unadj, summ$max_unadj))
cat("IPTW adjA (16-var): ", sprintf("%d/%d exceed 0.10; max=%.3f\n",
    summ$n_imb_adjA, length(all16), summ$max_adjA))
cat("IPTW adjB (10-var): ", sprintf("%d/%d exceed 0.10; max=%.3f\n",
    summ$n_imb_adjB, length(all16), summ$max_adjB))
print(round(data.frame(unadj=as.numeric(smd_unadj), adjA=as.numeric(resA$smd),
                        adjB=as.numeric(resB$smd)),3))

saveRDS(list(unadj=smd_unadj, adjA=resA$smd, adjB=resB$smd,
             swA=resA$sw, swB=resB$sw, groups=groups, summary=summ,
             cov_all16=all16, cov_gmodel10=gmodel10,
             cleaning="replicated run_baseline_smd.R; GDMT binary contrast per run_ltmle_gdmt.R"),
        file=file.path(TAB_DIR, "adjusted_smd_iptw_gdmt.rds"))
cat("\nWROTE ", file.path(TAB_DIR, "adjusted_smd_iptw_gdmt.rds"), "\n")
