# 第38版 / 任务2 (A+): Table 3 "调整后 SMD" 列
# 严格复用 run_baseline_smd.R 的清洗口径 (clean_num 范围 + 派生二值 + 性别特异性QTc阈值)
# 计算 stabilized IPTW 加权 SMD，与未调整 SMD 同分母约定 (未加权合并SD)，保证可比。
# 两种口径:
#   optA = IPTW 倾向模型含全部 16 个 Table 3 变量 (balance-check 口径, 与论文叙事一致)
#   optB = IPTW 倾向模型仅含 A+ 估计 g 模型使用的 10 个协变量 (estimation-honest 口径)
suppressMessages({ library(data.table) })

DATA_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/DATA"

# ---- 1. 加载并按 run_baseline_smd.R 清洗 ----
ltmle_K2 <- readRDS(file.path(DATA_DIR, "ltmle_wide_K2_guideline.rds"))
d <- as.data.frame(ltmle_K2)
d <- d[d$Y_W0 == 0, ]                                  # grace-period survivors, 14677
d$treat <- factor(ifelse(d$A_W0 >= 2, ">=50% Guideline BB", "<50% Guideline BB"),
                  levels = c(">=50% Guideline BB", "<50% Guideline BB"))

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

# ---- 2. Table 3 的 16 个变量 ----
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
trt01 <- as.numeric(d$treat == ">=50% Guideline BB")   # 1=treated

# ---- 3. 未调整 SMD (同分母约定, 用于校验 & 并列) ----
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
  # PS 模型: 连续 NA 用列中位数填补 (完整 case PS), 二值 NA 用 0 填补
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

# 与原始 baseline_smd_results 校验
orig <- readRDS(file.path(DATA_DIR, "baseline_smd_results.rds"))$smd_values
orig_sel <- orig[match(c("age (mean (SD))","gender (%)","L_hr_W0 (mean (SD))","L_qrs_W0 (mean (SD))",
  "L_qtc_W0 (mean (SD))","L_cr_W0 (mean (SD))","L_egfr_W0 (mean (SD))","L_hb_W0 (mean (SD))",
  "L_na_W0 (mean (SD))","L_k_W0 (mean (SD))","L_af_W0 (%)","L_lbbb_W0 (%)",
  "qtc_prolonged (%)","qrs_ge120 (%)","egfr_lt60 (%)","age_ge75 (%)"), names(orig))]
names(orig_sel) <- all16

cat("=== 校验: 本脚本未调整 SMD vs 原始 baseline_smd_results ===\n")
cmp <- cbind(round(smd_unadj,3), round(as.numeric(orig_sel),3))
colnames(cmp) <- c("recomputed","original"); print(cmp)
cat("\n=== 调整后 SMD  optA (IPTW, 全16变量) ===\n")
print(round(resA$smd,3)); cat(sprintf("  weight range %.3f-%.3f mean %.3f\n", min(resA$sw),max(resA$sw),mean(resA$sw)))
cat("\n=== 调整后 SMD  optB (IPTW, g模型10变量) ===\n")
print(round(resB$smd,3)); cat(sprintf("  weight range %.3f-%.3f mean %.3f\n", min(resB$sw),max(resB$sw),mean(resB$sw)))

saveRDS(list(unadj=smd_unadj, orig=as.numeric(orig_sel), adjA=resA$smd, adjB=resB$smd,
             swA=resA$sw, swB=resB$sw, cov_all16=all16, cov_gmodel10=gmodel10,
             cleaning="replicated run_baseline_smd.R"),
        file="output/tables/adjusted_smd_iptw.rds")
cat("\nWROTE output/tables/adjusted_smd_iptw.rds\n")
