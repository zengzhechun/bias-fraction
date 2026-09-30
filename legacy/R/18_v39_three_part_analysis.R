# R/18_v39_three_part_analysis.R
# ---------------------------------------------------------------------------
# Master analysis script for manuscript v39 ("第39版").
#
# The v39 paper is organised in three sequential parts. This script produces
# every number the manuscript quotes for Parts I-III, from the existing
# v39b (2026-09-01): the negative-control panel size K gained a third level
# (50), so the design is now 10 x 8 x 2 x 3 x 2 = 960 conditions x 1000
# repetitions = 960,000 analyses. K = 12 and K = 25 are bit-for-bit unchanged.
# 960-condition x 1000-repetition simulation (comparison_results_v37p1.rds)
# and the existing case-study objects. Nothing is re-simulated.
#
#   Part I   The metric. BAF = |mu_B_hat| / (|mu_B_hat| + psi_tilde).
#   Part II  Simulation study, two steps.
#            Step 1  Bland-Altman agreement: is BF_hat an accurate estimator
#                    of BF_true?  (accuracy of the measurement)
#            Step 2  Two-layer decision rule: calibrated p (layer 1, signal
#                    existence) + continuous BF_hat with its 95% CI (layer 2,
#                    credibility grading). Does the two-layer rule outperform
#                    the calibrated p-value alone?  (accuracy of the decision)
#   Part III Beta-blocker target trial emulation, two clinical questions,
#            read through the calibrated p + BAF + CI-width interface.
#
# Outputs
#   output/tables/v39_part1_bland_altman.csv
#   output/tables/v39_part2_reliability_lookup.csv
#   output/tables/v39_part2_strategy_comparison.csv
#   output/tables/v39_part2_confusion3x3.csv
#   output/tables/v39_part2_subgroups.csv
#   output/tables/v39_part2_discrimination.csv
#   output/tables/v39_part3_case_verdicts.csv
#   output/tables/v39_all_numbers.json          <- single source of truth
#   output/figures/v39/figP1_*.png  figP2_*.png
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(jsonlite)
  library(ggplot2)
})

source("R/00_config.R")
source("R/01_bsr_core.R")

V38_FIG <- file.path(FIG_DIR, "v39")
dir.create(V38_FIG, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)

set.seed(20260827)
NUM <- list()   # collector for the JSON single-source-of-truth

`%||%` <- function(a, b) if (is.null(a)) b else a

# ===========================================================================
# 0. Load and flatten the simulation
# ===========================================================================
cat("[0] loading simulation ...\n")
res <- readRDS(file.path(SIM_DIR, "comparison_results_v37p1.rds"))
# 10 psi x 8 mu_B x 2 sigma_ps x 3 K x 2 ex_violation = 960 conditions
stopifnot(length(res) == 960)

parse_key <- function(key) {
  psi  <- as.numeric(sub(".*_psi(-?[0-9.]+)_mu.*", "\\1", key))
  mu_b <- as.numeric(sub(".*_mu(-?[0-9.]+)_sps.*", "\\1", key))
  c(psi = psi, mu_b = mu_b)
}

parts <- vector("list", length(res))
for (i in seq_along(res)) {
  e   <- res[[i]]
  key <- names(res)[i]
  pm  <- parse_key(key)
  d   <- e$results
  n   <- nrow(d)
  parts[[i]] <- data.frame(
    cond      = key,
    psi       = pm[["psi"]],
    mu_b      = pm[["mu_b"]],
    sigma_ps  = e$sigma_ps,
    # Parse K from config_id ("sps0.06_K12_exV0", "sps0.1_K50_exV0.3") rather
    # than testing for "K25" and defaulting everything else to 12, which would
    # silently mislabel every K = 50 condition as K = 12 now that a third panel
    # size exists. Validated immediately below so a bad parse cannot slip through.
    K         = as.integer(sub(".*_K([0-9]+)_.*", "\\1", e$config_id)),
    exV       = if (grepl("exV0\\.3", e$config_id)) 0.3 else 0.0,
    bf_true   = e$bf_true,
    true_zone = e$true_zone,
    bf        = d$bf_mcmc,
    lo        = d$ci_lo_mcmc,
    hi        = d$ci_hi_mcmc,
    zone      = d$zone_mcmc,
    cal_p     = d$cal_p,
    naive_p   = d$naive_p,
    stringsAsFactors = FALSE
  )
}
S <- do.call(rbind, parts)
rm(parts); invisible(gc())
cat(sprintf("    flattened %s repetitions across %d conditions\n",
            format(nrow(S), big.mark = ","), length(res)))

# Guard the parsed factor levels: a silent misparse here would corrupt every
# subgroup and every K-stratified number downstream.
stopifnot(setequal(unique(S$K),   c(12L, 25L, 50L)),
          setequal(unique(S$exV), c(0, 0.3)))
cat(sprintf("    K levels: %s | reps per K: %s\n",
            paste(sort(unique(S$K)), collapse = ", "),
            paste(format(table(S$K), big.mark = ","), collapse = " / ")))

S$half   <- (S$hi - S$lo) / 2
S$diff   <- S$bf - S$bf_true
S$bd_tru <- S$bf_true > BF_THRESH_BIAS            # truth: bias-dominated
S$ed_tru <- S$bf_true < BF_THRESH_EFFECT          # truth: effect-dominated
S$interior <- S$psi != -0.01                      # exclude near-boundary level

NUM$design <- list(
  n_conditions      = length(res),
  n_reps_per_cond   = 1000L,
  n_total           = nrow(S),
  psi_levels        = sort(unique(S$psi)),
  mu_b_levels       = sort(unique(S$mu_b)),
  sigma_ps_levels   = sort(unique(S$sigma_ps)),
  K_levels          = sort(unique(S$K)),
  exV_levels        = sort(unique(S$exV)),
  bf_true_values    = sort(unique(round(S$bf_true, 3))),
  n_interior        = sum(S$interior),
  n_boundary        = sum(!S$interior),
  truth_share = list(
    bias_dominated   = mean(S$bd_tru),
    mixed            = mean(!S$bd_tru & !S$ed_tru),
    effect_dominated = mean(S$ed_tru)
  )
)

# ===========================================================================
# PART II - Step 1.  Bland-Altman agreement of the continuous BAF estimator
# ===========================================================================
cat("[1] Part II Step 1: Bland-Altman agreement ...\n")

ccc <- function(x, y) {
  mx <- mean(x); my <- mean(y)
  vx <- mean((x - mx)^2); vy <- mean((y - my)^2)
  cxy <- mean((x - mx) * (y - my))
  2 * cxy / (vx + vy + (mx - my)^2)
}

ba_stats <- function(est, tru, label) {
  d  <- est - tru
  b  <- mean(d); s <- sd(d)
  lo <- b - 1.96 * s; hi <- b + 1.96 * s
  fit <- lm(d ~ tru)
  cf  <- summary(fit)$coefficients
  ci  <- confint(fit)
  data.frame(
    analysis   = label,
    n          = length(d),
    bias       = b,
    sd_diff    = s,
    loa_lo     = lo,
    loa_hi     = hi,
    pct_in_loa = 100 * mean(d >= lo & d <= hi),
    ccc        = ccc(est, tru),
    r_prop     = cor(d, tru),
    slope      = cf[2, 1], slope_lo = ci[2, 1], slope_hi = ci[2, 2],
    slope_t    = cf[2, 3], slope_p  = cf[2, 4],
    intercept  = cf[1, 1], int_lo   = ci[1, 1], int_hi   = ci[1, 2],
    int_t      = cf[1, 3], int_p    = cf[1, 4],
    mae        = mean(abs(d)),
    rmse       = sqrt(mean(d^2)),
    stringsAsFactors = FALSE
  )
}

ba_int  <- ba_stats(S$bf[S$interior], S$bf_true[S$interior], "interior (primary)")
ba_full <- ba_stats(S$bf,             S$bf_true,             "full (transparency)")
BA <- rbind(ba_int, ba_full)
write.csv(BA, file.path(TAB_DIR, "v39_part1_bland_altman.csv"), row.names = FALSE)
print(BA[, c("analysis", "n", "bias", "sd_diff", "loa_lo", "loa_hi",
             "pct_in_loa", "ccc", "slope", "slope_t")], digits = 3)

# per-condition mean bias, for the agreement figure
cond_ba <- aggregate(cbind(diff, bf) ~ cond + bf_true + psi + interior, data = S, FUN = mean)
NUM$part1 <- list(
  interior = as.list(ba_int[, -1]),
  full     = as.list(ba_full[, -1]),
  interior_worst_cond_bias = max(abs(cond_ba$diff[cond_ba$interior])),
  n_conditions_interior    = sum(!duplicated(cond_ba$cond[cond_ba$interior]))
)

# ===========================================================================
# PART II - Step 2.  Two-layer decision rule
# ===========================================================================
cat("[2] Part II Step 2: two-layer decision rule ...\n")

## 2.1 Layer 1 - calibrated p as a signal-existence filter -------------------
L1 <- S$cal_p < 0.05
NUM$part2$layer1 <- list(
  alpha             = 0.05,
  pass_rate_overall = mean(L1),
  pass_rate_by_truth = list(
    bias_dominated   = mean(L1[S$bd_tru]),
    mixed            = mean(L1[!S$bd_tru & !S$ed_tru]),
    effect_dominated = mean(L1[S$ed_tru])
  ),
  # the central weakness: among repetitions that clear layer 1, how many are
  # truly bias-dominated?
  bd_share_among_pass = mean(S$bd_tru[L1]),
  naive_pass_rate     = mean(S$naive_p < 0.05)
)
cat(sprintf("    layer-1 pass %.1f%%; of those %.1f%% are truly bias-dominated\n",
            100 * mean(L1), 100 * mean(S$bd_tru[L1])))

## 2.2 CI-width classes ------------------------------------------------------
med_half <- median(S$half)
S$ciclass <- ifelse(S$half <= med_half, "narrow", "wide")
NUM$part2$ci_width <- list(
  median_half_width = med_half,
  quartiles_half    = as.numeric(quantile(S$half, c(0.25, 0.5, 0.75))),
  mean_half_by_K    = tapply(S$half, S$K, mean),
  coverage_overall  = mean(S$lo <= S$bf_true & S$bf_true <= S$hi),
  coverage_narrow   = mean((S$lo <= S$bf_true & S$bf_true <= S$hi)[S$ciclass == "narrow"]),
  coverage_wide     = mean((S$lo <= S$bf_true & S$bf_true <= S$hi)[S$ciclass == "wide"])
)

## 2.3 Reliability lookup: P(truth bias-dominated | BF_hat bin, CI class) ----
NBIN <- 12
brk  <- unique(quantile(S$bf, probs = seq(0, 1, length.out = NBIN + 1)))
brk[1] <- -Inf; brk[length(brk)] <- Inf
S$bin <- cut(S$bf, breaks = brk, labels = FALSE, include.lowest = TRUE)

agg_bin <- function(idx) {
  tapply(S$bd_tru[idx], S$bin[idx], mean)
}
p_all    <- agg_bin(rep(TRUE, nrow(S)))
p_narrow <- agg_bin(S$ciclass == "narrow")
p_wide   <- agg_bin(S$ciclass == "wide")
n_narrow <- as.numeric(table(S$bin[S$ciclass == "narrow"]))
n_wide   <- as.numeric(table(S$bin[S$ciclass == "wide"]))
ctr      <- tapply(S$bf, S$bin, median)

VERDICT_BREAKS <- c(0.15, 0.45, 0.65)
verdict_of <- function(p) {
  ifelse(is.na(p), "insufficient evidence",
  ifelse(p <  VERDICT_BREAKS[1], "usable as effect evidence",
  ifelse(p <  VERDICT_BREAKS[2], "mixed, hypothesis-generating",
  ifelse(p <  VERDICT_BREAKS[3], "competitive, no verdict",
                                 "not usable as effect evidence"))))
}

LOOK <- data.frame(
  bin        = seq_len(NBIN),
  bf_lo      = head(brk, -1),
  bf_hi      = tail(brk, -1),
  bf_centre  = as.numeric(ctr),
  n_narrow   = n_narrow,
  n_wide     = n_wide,
  p_bd_narrow = as.numeric(p_narrow),
  p_bd_wide   = as.numeric(p_wide),
  p_bd_all    = as.numeric(p_all)
)
LOOK$p_bd_conservative <- pmax(LOOK$p_bd_narrow, LOOK$p_bd_wide)
LOOK$verdict           <- verdict_of(LOOK$p_bd_conservative)
LOOK$ci_width_gain     <- LOOK$p_bd_wide - LOOK$p_bd_narrow
write.csv(LOOK, file.path(TAB_DIR, "v39_part2_reliability_lookup.csv"), row.names = FALSE)
print(LOOK[, c("bin", "bf_centre", "p_bd_narrow", "p_bd_wide",
               "p_bd_conservative", "verdict")], digits = 3)

NUM$part2$lookup            <- LOOK
NUM$part2$verdict_breaks    <- VERDICT_BREAKS
NUM$part2$ci_width_gain_max <- max(LOOK$ci_width_gain, na.rm = TRUE)
NUM$part2$ci_width_gain_med <- median(LOOK$ci_width_gain, na.rm = TRUE)

## 2.4 Discrimination: does CI width add information beyond BF_hat? ---------
# All 960,000 simulated repetitions are used. An earlier draft subsampled
# 200,000 here for memory; the full set fits comfortably and reviewers
# will (rightly) question why a subset was used when the whole grid is
# available. Discrimination AUC, GLM and the likelihood-ratio test below
# therefore describe the complete design, not a sample.
auc_of <- function(score, pos) {
  r  <- rank(score)
  n1 <- as.numeric(sum(pos)); n0 <- as.numeric(sum(!pos))
  (sum(r[pos]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

m_bf   <- glm(bd_tru ~ bf, data = S, family = binomial())
m_bfci <- glm(bd_tru ~ bf + half, data = S, family = binomial())
m_full <- glm(bd_tru ~ bf + half + I(cal_p < 0.05), data = S, family = binomial())

DISC <- data.frame(
  predictor = c("calibrated p-value alone", "BAF_hat alone",
                "BAF_hat + CI half-width", "BAF_hat + CI half-width + calibrated p"),
  # each score is oriented so that a higher value means "more likely truly
  # bias-dominated"; for the calibrated p-value that orientation is the p-value
  # itself, because a large calibrated p is what a bias-dominated estimate produces
  auc = c(auc_of(S$cal_p, S$bd_tru),
          auc_of(S$bf, S$bd_tru),
          auc_of(predict(m_bfci, type = "link"), S$bd_tru),
          auc_of(predict(m_full, type = "link"), S$bd_tru)),
  stringsAsFactors = FALSE
)
lr <- anova(m_bf, m_bfci, test = "Chisq")
DISC$note <- c("", "", sprintf("LR chi2 = %.1f, df = %d, p %s",
                               lr$Deviance[2], lr$Df[2],
                               ifelse(lr$`Pr(>Chi)`[2] < 1e-4, "< .001",
                                      sprintf("= %.4f", lr$`Pr(>Chi)`[2]))), "")
write.csv(DISC, file.path(TAB_DIR, "v39_part2_discrimination.csv"), row.names = FALSE)
print(DISC, digits = 4)
NUM$part2$discrimination <- DISC
NUM$part2$or_half_width  <- exp(coef(m_bfci)["half"])
NUM$part2$glm_n          <- nrow(S)

# What does the CI width actually buy? Three ways of reading the same BF_hat bin:
#   (a) pooled        - one probability per bin, CI width ignored
#   (b) width-specific- the probability of the observed CI-width class
#   (c) conservative  - max(narrow, wide) within the bin
S$p_pool <- LOOK$p_bd_all[S$bin]
S$p_spec <- ifelse(S$ciclass == "narrow",
                   LOOK$p_bd_narrow[S$bin], LOOK$p_bd_wide[S$bin])
S$p_cons <- LOOK$p_bd_conservative[S$bin]
v_pool <- verdict_of(S$p_pool)
v_spec <- verdict_of(S$p_spec)
v_cons <- verdict_of(S$p_cons)

rule_oc <- function(v, label) {
  decl <- L1 & v == "usable as effect evidence"
  data.frame(
    reading               = label,
    declare_usable_pct    = 100 * mean(decl),
    bd_among_declared_pct = 100 * mean(S$bd_tru[decl]),
    sens_ed_pct           = 100 * mean(decl[S$ed_tru]),
    spec_bd_pct           = 100 * mean(!decl[S$bd_tru]),
    stringsAsFactors = FALSE
  )
}
CIRULE <- rbind(
  rule_oc(v_pool, "pooled probability (CI width ignored)"),
  rule_oc(v_spec, "width-specific probability"),
  rule_oc(v_cons, "conservative max(narrow, wide)")
)
write.csv(CIRULE, file.path(TAB_DIR, "v39_part2_ci_width_rules.csv"), row.names = FALSE)
print(CIRULE, digits = 3)

NUM$part2$ci_width_role <- list(
  rules = CIRULE,
  pct_verdict_changed_spec_vs_pool = 100 * mean(v_spec != v_pool),
  pct_verdict_changed_cons_vs_pool = 100 * mean(v_cons != v_pool),
  bins_changed_cons_vs_pool = which(verdict_of(LOOK$p_bd_conservative) !=
                                    verdict_of(LOOK$p_bd_all)),
  max_abs_prob_gap_within_bin = max(abs(LOOK$ci_width_gain), na.rm = TRUE),
  delta_auc_from_ci_width = DISC$auc[3] - DISC$auc[2]
)

## 2.5 Strategy comparison ---------------------------------------------------
# Task: declare an estimate "usable as effect evidence".
S$p_bd_look <- LOOK$p_bd_conservative[S$bin]
S$verdict   <- verdict_of(S$p_bd_look)

strat <- list(
  # a nested sequence: each row adds exactly one component
  `R0 uncalibrated p < .05 (no bias correction)` = S$naive_p < 0.05,
  `R1 calibrated p < .05 (layer 1 only)`         = L1,
  `R2 R1 + BAF point estimate < 0.5`              = L1 & S$bf < BF_THRESH_BIAS,
  `R3 R1 + whole BAF credible interval clear of the bias-dominated zone (< 0.5)`      = L1 & S$zone == "effect-dominated",
  `R4 R1 + calibrated-probability verdict (full two-layer)` =
      L1 & S$verdict == "usable as effect evidence",
  # component checks, reported for completeness
  `C1 BAF point estimate alone`                   = S$bf < BF_THRESH_BIAS,
  `C2 whole BAF credible interval clear of the bias-dominated zone (< 0.5), alone`    = S$zone == "effect-dominated"
)

oc <- function(decl) {
  data.frame(
    declare_usable_pct = 100 * mean(decl),
    bd_among_declared_pct = if (any(decl)) 100 * mean(S$bd_tru[decl]) else NA_real_,
    ppv_not_bd_pct        = if (any(decl)) 100 * mean(!S$bd_tru[decl]) else NA_real_,
    sens_ed_pct           = 100 * mean(decl[S$ed_tru]),
    spec_bd_pct           = 100 * mean(!decl[S$bd_tru]),
    stringsAsFactors = FALSE
  )
}
STRAT <- do.call(rbind, lapply(strat, oc))
STRAT <- cbind(strategy = names(strat), STRAT)
write.csv(STRAT, file.path(TAB_DIR, "v39_part2_strategy_comparison.csv"), row.names = FALSE)
print(STRAT, digits = 3)
NUM$part2$strategies <- STRAT

## 2.6 Decision cascade (flow counts for the sankey/figure) -----------------
flow <- data.frame(
  stage = c("all repetitions",
            "layer 1 pass (calibrated p < .05)",
            "layer 1 pass and usable verdict",
            "layer 1 pass and mixed verdict",
            "layer 1 pass and competitive verdict",
            "layer 1 pass and not-usable verdict"),
  n = c(nrow(S), sum(L1),
        sum(L1 & S$verdict == "usable as effect evidence"),
        sum(L1 & S$verdict == "mixed, hypothesis-generating"),
        sum(L1 & S$verdict == "competitive, no verdict"),
        sum(L1 & S$verdict == "not usable as effect evidence")),
  stringsAsFactors = FALSE
)
flow$bd_true_n <- c(
  sum(S$bd_tru), sum(S$bd_tru & L1),
  sum(S$bd_tru & L1 & S$verdict == "usable as effect evidence"),
  sum(S$bd_tru & L1 & S$verdict == "mixed, hypothesis-generating"),
  sum(S$bd_tru & L1 & S$verdict == "competitive, no verdict"),
  sum(S$bd_tru & L1 & S$verdict == "not usable as effect evidence"))
flow$bd_share_pct <- 100 * flow$bd_true_n / flow$n
write.csv(flow, file.path(TAB_DIR, "v39_part2_flow.csv"), row.names = FALSE)
print(flow, digits = 3)
NUM$part2$flow <- flow

## 2.7 3x3 confusion matrix (truth zone x BAF zone) --------------------------
S$true_zone3 <- ifelse(S$bd_tru, "bias-dominated",
                ifelse(S$ed_tru, "effect-dominated", "mixed"))
cm <- table(truth = S$true_zone3, read = S$zone)
CM <- as.data.frame.matrix(cm)
CM$row_total <- rowSums(CM)
write.csv(cbind(truth = rownames(CM), CM),
          file.path(TAB_DIR, "v39_part2_confusion3x3.csv"), row.names = FALSE)
print(round(100 * prop.table(cm, 1), 1))
NUM$part2$confusion3x3 <- cbind(truth = rownames(CM), CM)
NUM$part2$zone_accuracy <- list(
  overall          = 100 * mean(S$zone == S$true_zone3),
  bias_dominated   = 100 * mean(S$zone[S$true_zone3 == "bias-dominated"]   == "bias-dominated"),
  mixed            = 100 * mean(S$zone[S$true_zone3 == "mixed"]            == "mixed"),
  effect_dominated = 100 * mean(S$zone[S$true_zone3 == "effect-dominated"] == "effect-dominated")
)

## 2.8 Subgroup robustness ---------------------------------------------------
sub_oc <- function(idx, label) {
  decl <- L1 & S$verdict == "usable as effect evidence"
  data.frame(
    subgroup              = label,
    n                     = sum(idx),
    layer1_pass_pct       = 100 * mean(L1[idx]),
    declare_usable_pct    = 100 * mean(decl[idx]),
    bd_among_declared_pct = if (any(decl[idx])) 100 * mean(S$bd_tru[idx & decl]) else NA_real_,
    bd_among_layer1_pct   = 100 * mean(S$bd_tru[idx & L1]),
    median_half_width     = median(S$half[idx]),
    stringsAsFactors = FALSE
  )
}
SUB <- rbind(
  sub_oc(S$K == 12,        "K = 12 negative controls"),
  sub_oc(S$K == 25,        "K = 25 negative controls"),
  sub_oc(S$K == 50,        "K = 50 negative controls"),
  sub_oc(S$exV == 0,       "bias exchangeability held"),
  sub_oc(S$exV == 0.3,     "30% exchangeability violation"),
  sub_oc(S$sigma_ps == 0.06, "sigma_ps = 0.06"),
  sub_oc(S$sigma_ps == 0.10, "sigma_ps = 0.10")
)
write.csv(SUB, file.path(TAB_DIR, "v39_part2_subgroups.csv"), row.names = FALSE)
print(SUB, digits = 3)
NUM$part2$subgroups <- SUB

# ===========================================================================
# PART III - case study read through the two-layer interface
# ===========================================================================
cat("[3] Part III: case-study verdicts ...\n")
bsr <- readRDS(file.path(OUT_DIR, "data", "bsr_results_v35.rds"))
bb <- bsr$bb; gdmt <- bsr$gdmt

read_case <- function(o, label) {
  bf   <- o$boot$bf_median
  lo   <- o$boot$bf_ci_lo
  hi   <- o$boot$bf_ci_hi
  half <- (hi - lo) / 2
  b    <- max(which(brk[-length(brk)] <= bf))
  cls  <- if (half <= med_half) "narrow" else "wide"
  pbd  <- LOOK$p_bd_conservative[b]
  data.frame(
    exposure   = label,
    rr_uncal   = o$bsr$rr_uncal,
    log_rr_uncal = o$bsr$log_rr_uncal,
    mu_b       = o$bsr$mu_bias,
    sigma_b    = o$bsr$sigma_bias,
    rr_cal     = o$bsr$rr_true,
    log_rr_cal = o$bsr$log_rr_true,
    cal_p      = o$bsr$cal_p,
    layer1_pass = o$bsr$cal_p < 0.05,
    bf         = bf, bf_lo = lo, bf_hi = hi,
    half_width = half, ci_class = cls,
    lookup_bin = b,
    p_bias_dominated = pbd,
    verdict    = verdict_of(pbd),
    zone       = o$bsr$zone %||% NA_character_,
    stringsAsFactors = FALSE
  )
}
CASE <- rbind(read_case(bb, "Beta-blocker >=50% target dose"),
              read_case(gdmt, "GDMT >=2 of 3 classes"))
write.csv(CASE, file.path(TAB_DIR, "v39_part3_case_verdicts.csv"), row.names = FALSE)
print(CASE[, c("exposure", "rr_uncal", "rr_cal", "cal_p", "bf", "bf_lo", "bf_hi",
               "ci_class", "p_bias_dominated", "verdict")], digits = 3)
NUM$part3$cases <- CASE
NUM$part3$nc <- {
  ncobj <- readRDS(file.path(DATA_DIR, "negative_controls_expanded.rds"))
  est <- ncobj$estimates
  list(K = nrow(est),
       all_protective = all(est$logRr < 0),
       logrr_min = min(est$logRr), logrr_max = max(est$logRr),
       shapiro_p = bsr$diagnostics$shapiro_p)
}
NUM$part3$sensitivity <- list(
  loo_bf_min = min(bsr$loo$bf), loo_bf_max = max(bsr$loo$bf),
  loo_fall_bf = bsr$loo$bf[bsr$loo$excluded_nc == "fall"],
  sl_bf = bsr$sl$bf, sl_bf_lo = bsr$sl$bf_ci_lo, sl_bf_hi = bsr$sl$bf_ci_hi,
  gp_cal_rr = range(bsr$grace_period_sensitivity$cal_rr),
  gp_bf     = range(bsr$grace_period_sensitivity$bf)
)

# ===========================================================================
# 4. Figures
# ===========================================================================
cat("[4] figures ...\n")
th <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = COLOR_GRID),
        text = element_text(colour = COLOR_TEXT),
        plot.title = element_text(face = "bold", size = 12),
        plot.caption = element_text(size = 8, colour = COLOR_NEUTRAL, hjust = 0))

## Fig P2A: reliability curve, narrow vs wide
rl <- rbind(
  data.frame(bf = LOOK$bf_centre, p = LOOK$p_bd_narrow, cls = "Narrow CI (half-width <= median)"),
  data.frame(bf = LOOK$bf_centre, p = LOOK$p_bd_wide,   cls = "Wide CI (half-width > median)")
)
gA <- ggplot(rl, aes(bf, p, colour = cls, shape = cls)) +
  geom_hline(yintercept = VERDICT_BREAKS, linetype = "dashed",
             colour = COLOR_NEUTRAL, linewidth = 0.3) +
  geom_line(linewidth = 0.7) + geom_point(size = 2.1) +
  annotate("text", x = 0.03, y = VERDICT_BREAKS + 0.03, hjust = 0, size = 2.7,
           colour = COLOR_NEUTRAL, label = paste0("P = ", VERDICT_BREAKS)) +
  scale_colour_manual(values = c(COLOR_EFFECT_DOM, COLOR_BIAS_DOM)) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent_format(accuracy = 1)) +
  labs(x = expression(hat(BAF)~"reading (bin median)"),
       y = "P(truth is bias-dominated)",
       colour = NULL, shape = NULL,
       title = "Layer 2 calibration of the continuous BAF reading",
       caption = sprintf("%s simulated repetitions. Dashed lines are the verdict thresholds 0.15 / 0.45 / 0.65.",
                         format(nrow(S), big.mark = ","))) +
  th + theme(legend.position = c(0.02, 0.95), legend.justification = c(0, 1),
             legend.background = element_rect(fill = "white", colour = NA))
ggsave(file.path(V38_FIG, "figP2A_reliability_curve.png"), gA,
       width = 7, height = 4.6, dpi = 300)

## Fig P2B: decision cascade
fl <- flow[-1, ]
fl$stage <- factor(fl$stage, levels = rev(fl$stage))
fl2 <- rbind(
  data.frame(stage = fl$stage, n = fl$bd_true_n,        truth = "truly bias-dominated"),
  data.frame(stage = fl$stage, n = fl$n - fl$bd_true_n, truth = "truly not bias-dominated"))
gB <- ggplot(fl2, aes(stage, n, fill = truth)) +
  geom_col(width = 0.68) + coord_flip() +
  scale_fill_manual(values = c(COLOR_BIAS_DOM, COLOR_EFFECT_DOM)) +
  scale_y_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE)) +
  labs(x = NULL, y = "Simulated repetitions", fill = NULL,
       title = "Two-layer decision cascade",
       caption = "Layer 1 keeps repetitions with calibrated p < .05; layer 2 grades them by the BAF reading and its CI width.") +
  th + theme(legend.position = "top")
ggsave(file.path(V38_FIG, "figP2B_decision_cascade.png"), gB,
       width = 7.6, height = 4.2, dpi = 300)

## Fig P2C: ROC-style comparison
roc_pts <- function(score, pos, n = 300) {
  qs <- unique(quantile(score, seq(0, 1, length.out = n)))
  data.frame(
    fpr = sapply(qs, function(t) mean(score[!pos] >= t)),
    tpr = sapply(qs, function(t) mean(score[pos]  >= t)))
}
rc <- rbind(
  cbind(roc_pts(S$cal_p, S$bd_tru), model = "Calibrated p alone"),
  cbind(roc_pts(S$bf, S$bd_tru), model = "BAF_hat alone"),
  cbind(roc_pts(predict(m_bfci, type = "link"), S$bd_tru), model = "BAF_hat + CI half-width"))
gC <- ggplot(rc, aes(fpr, tpr, colour = model)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dotted", colour = COLOR_NEUTRAL) +
  geom_line(linewidth = 0.75) +
  scale_colour_manual(values = c(COLOR_OHDSI, COLOR_COMPETITIVE, COLOR_BIAS_DOM)) +
  labs(x = "False-positive rate", y = "True-positive rate", colour = NULL,
       title = "Detecting a truly bias-dominated estimate",
       caption = sprintf("All %s repetitions (the full %d-condition x %d-repetition design). AUC: calibrated p %.3f; BAF_hat %.3f; BAF_hat + CI width %.3f.",
                         format(nrow(S), big.mark = ","),
                         length(res),
                         nrow(S) %/% length(res),
                         DISC$auc[1], DISC$auc[2], DISC$auc[3])) +
  th + theme(legend.position = c(0.98, 0.05), legend.justification = c(1, 0),
             legend.background = element_rect(fill = "white", colour = NA))
ggsave(file.path(V38_FIG, "figP2C_roc.png"), gC, width = 5.8, height = 5.0, dpi = 300)

## Fig P2D: CI half-width distribution
gD <- ggplot(S, aes(half, fill = factor(K))) +
  geom_histogram(bins = 70, position = "identity", alpha = 0.62, colour = NA) +
  geom_vline(xintercept = med_half, linetype = "dashed", colour = COLOR_TEXT) +
  annotate("text", x = med_half, y = Inf, vjust = 1.6, hjust = -0.06, size = 3,
           colour = COLOR_TEXT, label = sprintf("median = %.3f", med_half)) +
  scale_fill_manual(values = COLOR_K,
                    name = "Negative controls (K)") +
  labs(x = "95% CI half-width of BAF_hat", y = "Repetitions",
       title = "The CI-width split used by layer 2",
       caption = "Narrow and wide classes are defined by the median half-width of the whole simulation.") +
  th + theme(legend.position = c(0.98, 0.95), legend.justification = c(1, 1))
ggsave(file.path(V38_FIG, "figP2D_ci_width.png"), gD, width = 6.4, height = 4.2, dpi = 300)

## Fig P1: interior Bland-Altman (compact, per-condition means)
ci_ba <- cond_ba[cond_ba$interior, ]
gP1 <- ggplot(ci_ba, aes(bf_true, diff)) +
  geom_hline(yintercept = 0, linetype = "dotted", colour = COLOR_NEUTRAL) +
  geom_hline(yintercept = ba_int$bias, colour = COLOR_BIAS_DOM, linewidth = 0.6) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = ba_int$loa_lo, ymax = ba_int$loa_hi,
           fill = COLOR_OHDSI, alpha = 0.10) +
  geom_point(alpha = 0.55, size = 1.5, colour = COLOR_TEXT) +
  labs(x = "True BAF", y = expression(hat(BAF) - BAF[true]),
       title = "Step 1: agreement of the BAF estimator (interior analysis)",
       caption = sprintf("Points are the %d interior conditions (means of 1000 repetitions). Solid line: mean bias %.3f. Band: 95%% limits of agreement [%.3f, %.3f].",
                         nrow(ci_ba), ba_int$bias, ba_int$loa_lo, ba_int$loa_hi)) +
  th
ggsave(file.path(V38_FIG, "figP1_interior_ba_conditions.png"), gP1,
       width = 6.6, height = 4.2, dpi = 300)

# ===========================================================================
# 5. Single source of truth
# ===========================================================================
write_json(NUM, file.path(TAB_DIR, "v39_all_numbers.json"),
           auto_unbox = TRUE, digits = 8, pretty = TRUE, na = "null")
cat("[done] wrote v39_all_numbers.json and 8 CSV tables; figures in output/figures/v39/\n")
