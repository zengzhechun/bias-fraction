# R/23_dual_view_metrics.R
# Dual-view operating characteristics for the nested reporting rules R0-R4
# (plus the stand-alone comparators C1, C2), and dual-view ROC curves.
#
# Why this script exists
# ----------------------
# A reporting rule does two things at once: it declares a repetition usable as
# effect evidence, and by doing so it withholds every repetition it does not
# declare usable. Those two readings are the same rule seen from opposite ends,
# and they answer different questions:
#
#   effect-dominated view  positive call = declared usable, positive truth = truly ED
#   bias-dominated view    positive call = withheld,        positive truth = truly BD
#
# R/18 reports only the bias-dominated view, which is why the rule definitions
# (written as "declare usable when ...") and the reported sensitivity /
# specificity (written as "detect bias dominance") read in opposite directions.
# Reporting both views side by side removes the conflict: the rule definitions
# stay as they are, and each view gets its own four numbers.
#
# Truth is three-level (effect-dominated / mixed / bias-dominated), so each view
# collapses it to two levels. "Not truly effect-dominated" is mixed or
# bias-dominated; "not truly bias-dominated" is mixed or effect-dominated. The
# mixed zone therefore falls in the negative group of BOTH views, which is why
# the two views are not mirror images of each other and why both are worth
# reporting: the mixed zone is the group neither view can get right.
#
# Input : output/simulation/comparison_results_v37p1.rds
#         (960 conditions x 1000 reps = 960,000 repetitions)
# Output: output/tables/v39_dual_view_strategy.csv
#         output/tables/v39_dual_view_roc.csv
#         output/tables/v39_dual_view_auc.csv
#         output/tables/v39_dual_view.json

suppressPackageStartupMessages({
  library(jsonlite)
})
source("R/00_config.R")

cat("[1] loading simulation ...\n")
res <- readRDS(file.path(SIM_DIR, "comparison_results_v37p1.rds"))
stopifnot(length(res) == 960L)

## -- flatten ----------------------------------------------------------------
parts <- vector("list", length(res))
for (i in seq_along(res)) {
  e <- res[[i]]
  d <- e$results
  parts[[i]] <- data.frame(
    bf_true = e$bf_true,
    bf      = d$bf_mcmc,
    lo      = d$ci_lo_mcmc,
    hi      = d$ci_hi_mcmc,
    zone    = d$zone_mcmc,
    cal_p   = d$cal_p,
    naive_p = d$naive_p,
    stringsAsFactors = FALSE
  )
}
S <- do.call(rbind, parts)
rm(parts); invisible(gc())

S$half   <- (S$hi - S$lo) / 2
S$bd_tru <- S$bf_true > BF_THRESH_BIAS      # truth: bias-dominated
S$ed_tru <- S$bf_true < BF_THRESH_EFFECT    # truth: effect-dominated
cat(sprintf("    %s repetitions | truth: ED %s, mixed %s, BD %s\n",
            format(nrow(S), big.mark = ","),
            format(sum(S$ed_tru), big.mark = ","),
            format(sum(!S$ed_tru & !S$bd_tru), big.mark = ","),
            format(sum(S$bd_tru), big.mark = ",")))

## -- reliability lookup, reproduced exactly as in R/18 section 2.3 ----------
# Needed only so that R4 is the same rule R/18 evaluated. Kept byte-identical
# on purpose; if R/18 changes, change it here too.
NBIN <- 12
brk  <- unique(quantile(S$bf, probs = seq(0, 1, length.out = NBIN + 1)))
brk[1] <- -Inf; brk[length(brk)] <- Inf
S$bin <- cut(S$bf, breaks = brk, labels = FALSE, include.lowest = TRUE)
S$ciclass <- ifelse(S$half <= median(S$half), "narrow", "wide")
agg_bin <- function(idx) tapply(S$bd_tru[idx], S$bin[idx], mean)
p_narrow <- as.numeric(agg_bin(S$ciclass == "narrow"))
p_wide   <- as.numeric(agg_bin(S$ciclass == "wide"))
p_cons   <- pmax(p_narrow, p_wide)
VERDICT_BREAKS <- c(0.15, 0.45, 0.65)
verdict_of <- function(p) {
  ifelse(is.na(p), "insufficient evidence",
  ifelse(p <  VERDICT_BREAKS[1], "usable as effect evidence",
  ifelse(p <  VERDICT_BREAKS[2], "mixed, hypothesis-generating",
  ifelse(p <  VERDICT_BREAKS[3], "competitive, no verdict",
                                 "not usable as effect evidence"))))
}
S$p_bd_look <- p_cons[S$bin]
S$verdict   <- verdict_of(S$p_bd_look)

## -- the rules --------------------------------------------------------------
L1 <- S$cal_p < 0.05
strat <- list(
  R0 = S$naive_p < 0.05,
  R1 = L1,
  R2 = L1 & S$bf < BF_THRESH_BIAS,
  R3 = L1 & S$zone == "effect-dominated",
  R4 = L1 & S$verdict == "usable as effect evidence",
  C1 = S$bf < BF_THRESH_BIAS,
  C2 = S$zone == "effect-dominated"
)

## -- dual-view operating characteristics ------------------------------------
# decl = declared usable as effect evidence; withheld = !decl
# Naming is explicit about both the call and the truth group so that no column
# can be read as its complement by mistake.
oc_dual <- function(decl) {
  withh <- !decl
  pc <- function(x) if (length(x) == 0) NA_real_ else 100 * mean(x)
  data.frame(
    declare_usable_pct = pc(decl),
    # effect-dominated view: a positive call is "declared usable"
    sens_ed = pc( decl[S$ed_tru]),     # P(declare usable | truly ED)
    spec_ed = pc(withh[!S$ed_tru]),    # P(withhold       | not truly ED)
    ppv_ed  = pc(S$ed_tru[decl]),      # P(truly ED | declared usable)
    npv_ed  = pc(!S$ed_tru[withh]),    # P(not ED   | withheld)
    # bias-dominated view: a positive call is "withheld"
    sens_bd = pc(withh[S$bd_tru]),     # P(withhold       | truly BD)
    spec_bd = pc( decl[!S$bd_tru]),    # P(declare usable | not truly BD)
    ppv_bd  = pc(S$bd_tru[withh]),     # P(truly BD | withheld)
    npv_bd  = pc(!S$bd_tru[decl]),     # P(not BD   | declared usable)
    stringsAsFactors = FALSE
  )
}
STRAT <- cbind(rule = names(strat),
               do.call(rbind, lapply(strat, oc_dual)),
               stringsAsFactors = FALSE)
row.names(STRAT) <- NULL
write.csv(STRAT, file.path(TAB_DIR, "v39_dual_view_strategy.csv"), row.names = FALSE)
print(STRAT, digits = 4)

## -- sanity checks ----------------------------------------------------------
# Each view must be an internally consistent 2x2 table over the same 960,000
# rows. Bayes ties the four numbers together: with p = prevalence of the
# positive truth, P(positive call) = p*sens + (1-p)*(1-spec), and
# PPV = p*sens / P(positive call). If a column is ever read as its own
# complement, or a truth group silently drops the mixed zone, these fail.
p_ed <- mean(S$ed_tru); p_bd <- mean(S$bd_tru)
pr_ed <- STRAT$declare_usable_pct          # positive call share, ED view
pr_bd <- 100 - STRAT$declare_usable_pct    # positive call share, BD view
chk <- function(lhs, rhs, what)
  stopifnot(max(abs(lhs - rhs), na.rm = TRUE) < 1e-6 || stop(
    sprintf("dual-view 2x2 inconsistent (%s); max gap %.4g", what,
            max(abs(lhs - rhs), na.rm = TRUE))))
chk(pr_ed, p_ed * STRAT$sens_ed + (1 - p_ed) * (100 - STRAT$spec_ed),
    "ED view: declared-usable share")
chk(pr_bd, p_bd * STRAT$sens_bd + (1 - p_bd) * (100 - STRAT$spec_bd),
    "BD view: withheld share")
chk(STRAT$ppv_ed, 100 * p_ed * STRAT$sens_ed / pr_ed, "ED view: PPV")
chk(STRAT$ppv_bd, 100 * p_bd * STRAT$sens_bd / pr_bd, "BD view: PPV")
chk(STRAT$npv_ed, 100 * (1 - p_ed) * STRAT$spec_ed / (100 - pr_ed), "ED view: NPV")
chk(STRAT$npv_bd, 100 * (1 - p_bd) * STRAT$spec_bd / (100 - pr_bd), "BD view: NPV")
cat("    dual-view 2x2 tables internally consistent\n")
cat(sprintf("    mixed-zone share (negative group of both views): %.1f%%\n",
            100 * mean(!S$ed_tru & !S$bd_tru)))

## -- dual-view ROC curves ---------------------------------------------------
# Every score is oriented so that a HIGHER value means "more likely truly
# bias-dominated". In the bias-dominated view a positive call is a high score;
# in the effect-dominated view a positive call is a low score. Both rates are
# taken over that view's own truth groups, so the two panels are not reflections
# of one another: the mixed zone is a negative in both.
auc_mw <- function(score, pos) {
  r  <- rank(score)
  n1 <- as.numeric(sum(pos)); n0 <- as.numeric(sum(!pos))
  (sum(r[pos]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

set.seed(20260827)
m_bfci <- glm(bd_tru ~ bf + half, data = S, family = binomial())
SCR <- list(
  `Calibrated P alone`     = S$cal_p,
  `BAF-hat alone`           = S$bf,
  `BAF-hat + CI half-width` = as.numeric(predict(m_bfci, type = "link"))
)
AUC <- data.frame(
  score = names(SCR),
  auc_ed = sapply(SCR, function(s) auc_mw(-s, S$ed_tru)),
  auc_bd = sapply(SCR, function(s) auc_mw( s, S$bd_tru)),
  stringsAsFactors = FALSE
)
write.csv(AUC, file.path(TAB_DIR, "v39_dual_view_auc.csv"), row.names = FALSE)
print(AUC, digits = 4)

roc_pair <- function(score, n = 300) {
  qs <- unique(quantile(score, seq(0, 1, length.out = n)))
  data.frame(
    x_bd = sapply(qs, function(t) mean(score[!S$bd_tru] >= t)),
    y_bd = sapply(qs, function(t) mean(score[ S$bd_tru] >= t)),
    x_ed = sapply(qs, function(t) mean(score[!S$ed_tru] <= t)),
    y_ed = sapply(qs, function(t) mean(score[ S$ed_tru] <= t)))
}
ROC <- do.call(rbind, lapply(names(SCR), function(nm)
  cbind(score = nm, roc_pair(SCR[[nm]]))))
row.names(ROC) <- NULL
write.csv(ROC, file.path(TAB_DIR, "v39_dual_view_roc.csv"), row.names = FALSE)

## -- export -----------------------------------------------------------------
out <- list(
  n_total    = nrow(S),
  truth_share = list(effect_dominated = mean(S$ed_tru),
                     mixed            = mean(!S$ed_tru & !S$bd_tru),
                     bias_dominated   = mean(S$bd_tru)),
  strategies = STRAT,
  auc        = AUC
)
write(toJSON(out, digits = 6, auto_unbox = TRUE, pretty = TRUE),
      file.path(TAB_DIR, "v39_dual_view.json"))
cat("saved v39_dual_view.{strategy,auc,roc}.csv and v39_dual_view.json\n")
