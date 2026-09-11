## ===========================================================================
##  v39 new analysis 1 — Held-out validation of the BAF reliability lookup
##
##  Motivation (review finding): the 12-bucket lookup table in the manuscript
##  was built from the SAME 960,000 repetitions that were then used to score
##  the decision rules R0-R4. The manuscript argued that the induced optimism
##  must be small because every cell holds >= 1,000 repetitions, but it offered
##  no empirical check. This script supplies one.
##
##  Two cross-validation schemes, both seeded and repeated five times:
##    (a) repetition-level : within each condition, 20% of repetitions are held
##                           out, so both halves span the whole grid.
##    (b) condition-level  : 20% of the 960 conditions are held out entirely,
##                           which also tests generalisation to grid cells that
##                           never contributed to the lookup.
##
##  Everything the lookup needs (bin edges, median half-width, per-bin
##  P(bias-dominated), verdicts) is estimated on TRAIN only and applied to TEST
##  unchanged. Nothing is recomputed on TEST except the evaluation.
##
##  Result: repetition-level hold-out reproduces the in-sample numbers almost
##  exactly, but condition-level hold-out raises the misuse rate of every rule,
##  because a lookup built on 80% of the grid assigns bin edges and per-bin
##  probabilities that do not transfer perfectly to cells it has never seen.
##
##  Input : output/simulation/comparison_results_v37p1.rds   (960 x 1000)
##  Output: output/tables/v39_lookup_holdout.csv
##          output/tables/v39_lookup_holdout_detail.csv
##          output/tables/v39_lookup_holdout_folds.csv
##          output/simulation/v39_lookup_holdout.rds
## ===========================================================================

suppressPackageStartupMessages({ library(data.table) })

BASE   <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第39版"
IN_RDS <- file.path(BASE, "output/simulation/comparison_results_v37p1.rds")
OUT_T  <- file.path(BASE, "output/tables")
OUT_S  <- file.path(BASE, "output/simulation")

BF_BD <- 0.5          # BF_THRESH_BIAS
BF_ED <- 1/3          # BF_THRESH_EFFECT
NBIN  <- 12
VERDICT_BREAKS <- c(0.15, 0.45, 0.65)
SEED  <- 39L
NFOLD <- 5L

rule_labels <- c(
  "R0 uncalibrated p < .05 (no bias correction)",
  "R1 calibrated p < .05 (layer 1 only)",
  "R2 R1 + BAF point estimate < 0.5",
  "R3 R1 + whole BAF CI clear of the bias-dominated zone (< 0.5)",
  "R4 R1 + calibrated-probability verdict (full two-layer)",
  "C1 BAF point estimate alone",
  "C2  whole BAF CI clear of the bias-dominated zone (< 0.5), alone"
)

## ---- 1. build the repetition-level frame ----------------------------------
cat("[1] flattening comparison_results_v37p1.rds ...\n")
res <- readRDS(IN_RDS)

parts <- vector("list", length(res))
for (i in seq_along(res)) {
  e <- res[[i]]; d <- e$results
  parts[[i]] <- data.table(
    cond    = names(res)[i],
    rep     = as.integer(d$rep),
    bf      = d$bf_mcmc,
    lo      = d$ci_lo_mcmc,
    hi      = d$ci_hi_mcmc,
    cal_p   = d$cal_p,
    naive_p = d$naive_p
  )
}
S <- rbindlist(parts)
S[, half := (hi - lo) / 2]
S[, L1   := cal_p < 0.05]
S[, r0   := naive_p < 0.05]

# truth labels come from the condition, not from the estimate.
# NB: do NOT pre-create bd_tru / ed_tru on S, or the merge below would emit
# bd_tru.x / bd_tru.y and every downstream reference would fail.
TRUTH <- rbindlist(lapply(seq_along(res), function(i)
  data.table(cond = names(res)[i], bf_true = res[[i]]$bf_true)))
TRUTH[, `:=`(bd_tru = bf_true > BF_BD, ed_tru = bf_true < BF_ED)]
S <- merge(S, TRUTH, by = "cond", all.x = TRUE)
stopifnot(!anyNA(S$bd_tru), !anyNA(S$ed_tru))
setorder(S, cond, rep)
cat(sprintf("    %s repetitions across %d conditions; truth share BD = %.1f%%\n",
            format(nrow(S), big.mark = ","), uniqueN(S$cond),
            100 * mean(unique(S[, .(cond, bd_tru)])$bd_tru)))

verdict_of <- function(p) {
  ifelse(is.na(p), "insufficient evidence",
  ifelse(p <  VERDICT_BREAKS[1], "usable as effect evidence",
  ifelse(p <  VERDICT_BREAKS[2], "mixed, hypothesis-generating",
  ifelse(p <  VERDICT_BREAKS[3], "competitive, no verdict",
                                 "not usable as effect evidence"))))
}

build_lookup <- function(tr) {
  med_half <- median(tr$half)
  tr <- copy(tr); tr[, ciclass := ifelse(half <= med_half, "narrow", "wide")]
  brk <- unique(quantile(tr$bf, probs = seq(0, 1, length.out = NBIN + 1)))
  brk[1] <- -Inf; brk[length(brk)] <- Inf
  tr[, bin := cut(bf, breaks = brk, labels = FALSE, include.lowest = TRUE)]
  agg <- function(idx) as.numeric(tapply(tr$bd_tru[idx], tr$bin[idx], mean))
  LOOK <- data.table(
    bin = seq_len(NBIN),
    bf_centre = as.numeric(tapply(tr$bf, tr$bin, median)),
    p_bd_all = agg(rep(TRUE, nrow(tr))),
    p_bd_narrow = agg(tr$ciclass == "narrow"),
    p_bd_wide   = agg(tr$ciclass == "wide")
  )
  LOOK[, p_bd_conservative := pmax(p_bd_narrow, p_bd_wide, na.rm = TRUE)]
  LOOK[, verdict := verdict_of(p_bd_conservative)]
  list(med_half = med_half, brk = brk, LOOK = LOOK)
}

apply_lookup <- function(te, L) {
  te <- copy(te)
  te[, bin := cut(bf, breaks = L$brk, labels = FALSE, include.lowest = TRUE)]
  te[, p_cons  := L$LOOK$p_bd_conservative[bin]]
  te[, verdict := verdict_of(p_cons)]
  te[, clear_bd := hi <= BF_BD]
  ## NOTE 1: the masks must be written as te$col, not as bare names. r0 / L1 /
  ## bf are COLUMNS of te, not objects in this function's frame, so bare names
  ## raise "object 'r0' not found".
  ## NOTE 2: as.logical() is essential. R subsets with a numeric vector as
  ## positional indices, so a 0/1 mask silently returns the wrong rows.
  rules <- list(
    te$r0, te$L1, te$L1 & te$bf < BF_BD, te$L1 & te$clear_bd,
    te$L1 & te$verdict == "usable as effect evidence",
    te$bf < BF_BD, te$clear_bd
  )
  rbindlist(lapply(seq_along(rules), function(j) {
    decl <- as.logical(rules[[j]])
    data.table(
      rule = rule_labels[j], n = nrow(te),
      declare_usable_pct    = 100 * mean(decl),
      bd_among_declared_pct = 100 * mean(te$bd_tru[decl]),
      sens_ed_pct           = 100 * mean(decl[te$ed_tru]),
      spec_bd_pct           = 100 * mean(!decl[te$bd_tru])
    )
  }))
}

## ---- 2. two cross-validation schemes, five folds each ---------------------
cat(sprintf("[2] %d-fold cross-validation, two schemes ...\n", NFOLD))
set.seed(SEED)
S[, u_rep := runif(.N)]
conds <- unique(S$cond)
set.seed(SEED + 1)
cond_fold <- data.table(cond = conds, fold = sample(rep(seq_len(NFOLD), length.out = length(conds))))
S <- merge(S, cond_fold, by = "cond", all.x = TRUE)
S[, fold_rep := cut(rank(u_rep, ties.method = "first"),
                   breaks = NFOLD, labels = FALSE)]

fold_run <- function(scheme) {
  fcol <- if (scheme == "rep") "fold_rep" else "fold"
  rbindlist(lapply(seq_len(NFOLD), function(f) {
    tr <- S[get(fcol) != f]; te <- S[get(fcol) == f]
    L  <- build_lookup(tr)
    a  <- apply_lookup(tr, L); b <- apply_lookup(te, L)
    m  <- merge(a, b, by = "rule", suffixes = c("_train", "_test"))
    m[, `:=`(scheme = scheme, fold = f)]
    m
  }))
}
CV <- rbind(fold_run("rep"), fold_run("condition"))
CV[, `:=`(delta_misuse_pp  = bd_among_declared_pct_test - bd_among_declared_pct_train,
          delta_declare_pp = declare_usable_pct_test - declare_usable_pct_train)]
fwrite(CV, file.path(OUT_T, "v39_lookup_holdout_folds.csv"))

AGG <- CV[, .(
  declare_train = mean(declare_usable_pct_train),
  declare_test  = mean(declare_usable_pct_test),
  declare_test_min = min(declare_usable_pct_test),
  declare_test_max = max(declare_usable_pct_test),
  misuse_train  = mean(bd_among_declared_pct_train),
  misuse_test   = mean(bd_among_declared_pct_test),
  misuse_test_min = min(bd_among_declared_pct_test),
  misuse_test_max = max(bd_among_declared_pct_test),
  delta_misuse  = mean(delta_misuse_pp),
  delta_declare = mean(delta_declare_pp)
), by = .(scheme, rule)]
setorder(AGG, scheme, rule)
fwrite(AGG, file.path(OUT_T, "v39_lookup_holdout.csv"))
cat("\n[3] five-fold cross-validated operating characteristics\n")
print(AGG[, .(scheme, rule = substr(rule, 1, 3),
              declare_tr = round(declare_train, 1), declare_te = round(declare_test, 1),
              misuse_tr = round(misuse_train, 2), misuse_te = round(misuse_test, 2),
              range = sprintf("%.1f-%.1f", misuse_test_min, misuse_test_max),
              d = round(delta_misuse, 2))])

## ---- 3. detail: lookup built on 80% of conditions -------------------------
set.seed(SEED + 1)
hold <- sample(conds, size = round(0.20 * length(conds)))
L80  <- build_lookup(S[!(cond %in% hold)])
det  <- copy(L80$LOOK)[, split := "lookup built on 80% of conditions (20% held out)"]
fwrite(det, file.path(OUT_T, "v39_lookup_holdout_detail.csv"))

## ---- 4. persist -----------------------------------------------------------
saveRDS(list(cv = CV, aggregate = AGG, lookup_80 = L80,
             held_conditions = hold,
             session = list(seed = SEED, nfold = NFOLD,
                            date = as.character(Sys.Date()))),
        file.path(OUT_S, "v39_lookup_holdout.rds"))

cat("\n=== DONE (lookup hold-out) ===\n")
