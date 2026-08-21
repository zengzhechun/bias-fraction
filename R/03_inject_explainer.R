# R/03_inject_explainer.R
# Re-inject the full 8-config x 1000-rep (v37) comparison results into the interactive
# explainer HTML (id="cmp-data" JSON block), and recompute per-region diagnostics
# correctly (per-condition true_zone, unlike the legacy single-true_zone aggregate).
# v37 - 2026-08-21

suppressPackageStartupMessages({
  library(jsonlite)
})

THIS_DIR <- "R"
source(file.path(THIS_DIR, "00_config.R"))

HTML_PATH  <- "互动讲解器_BF_simulator_v37.html"
RES_RDS    <- file.path(SIM_DIR, "comparison_results_v37p1.rds")
AGG_JSON   <- file.path(SIM_DIR, "comparison_agg_v37p1.json")

zones <- c("effect-dominated", "mixed", "bias-dominated")

if (!file.exists(RES_RDS)) stop("comparison_results_v37p1.rds not found; run R/02_comparison_study.R first")
results <- readRDS(RES_RDS)
cat(sprintf("loaded %d conditions from comparison_results_v37p1.rds\n", length(results)))

# ---- Aggregate confusion matrices + error flow (per-condition correct) ----
cm_mc   <- matrix(0, 3, 3)
cm_mcmc <- matrix(0, 3, 3)
ef_mc   <- matrix(0, 3, 3)  # off-diagonal misclassification counts
ef_mcmc <- matrix(0, 3, 3)

for (k in names(results)) {
  r  <- results[[k]]
  ti <- which(zones == r$true_zone)
  em <- match(r$results$zone_mc,    zones)
  eo <- match(r$results$zone_mcmc,  zones)
  for (j in seq_along(em)) {
    cm_mc[ti, em[j]] <- cm_mc[ti, em[j]] + 1
    cm_mcmc[ti, eo[j]] <- cm_mcmc[ti, eo[j]] + 1
    if (em[j] != ti) ef_mc[ti, em[j]] <- ef_mc[ti, em[j]] + 1
    if (eo[j] != ti) ef_mcmc[ti, eo[j]] <- ef_mcmc[ti, eo[j]] + 1
  }
}

# error-flow proportions (row-normalized over off-diagonal)
ef_mc_p   <- ef_mc;   ef_mcmc_p <- ef_mcmc
for (i in 1:3) {
  rs <- sum(ef_mc[i, -i]);   if (rs > 0) ef_mc_p[i, -i]   <- ef_mc[i, -i]   / rs
  rs <- sum(ef_mcmc[i, -i]); if (rs > 0) ef_mcmc_p[i, -i] <- ef_mcmc[i, -i] / rs
}

# per-zone sens/spec/ppv/npv
per_zone <- function(cm) {
  N <- sum(cm)
  out <- list()
  for (z in zones) {
    zi <- which(zones == z)
    TP <- cm[zi, zi]; FN <- sum(cm[zi, ]) - TP
    FP <- sum(cm[, zi]) - TP; TN <- N - TP - FN - FP
    out[[z]] <- list(
      sens = if ((TP + FN) > 0) round(TP / (TP + FN), 4) else NULL,
      spec = if ((TN + FP) > 0) round(TN / (TN + FP), 4) else NULL,
      ppv  = if ((TP + FP) > 0) round(TP / (TP + FP), 4) else NULL,
      npv  = if ((TN + FN) > 0) round(TN / (TN + FN), 4) else NULL,
      n_true = as.integer(TP + FN), n_pred = as.integer(TP + FP)
    )
  }
  out
}
pz_mc   <- per_zone(cm_mc)
pz_mcmc <- per_zone(cm_mcmc)

# ---- agg (full per-condition table) from JSON the simulation already wrote ----
agg <- jsonlite::fromJSON(AGG_JSON)

# ---- design summary ----
n_rep <- 1000L  # full design: 1000 repetitions per condition (set in 02_comparison_study.R)
ds <- list(
  configs = "2 (sigma_ps) x 2 (K) x 2 (ex_violation) = 8 configs",
  psi_grid = "10 levels (-0.01, -0.05, -0.10, -0.14, -0.18, -0.23, -0.27, -0.31, -0.36, -0.40); v37.1 extended grid refines the high-BF (small |psi|) region for sharper bias characterization; ψ=−0.01 (RR=0.99) replaces the true-null ψ=0 to remove the BF=1 singularity",
  mu_b_grid = "8 levels (-0.05, -0.10, -0.15, -0.20, -0.25, -0.30, -0.35, -0.40)",
  n_rep = n_rep,
  mcmc_iter = 400L,
  mcmc_warmup = 100L,
  total_conditions = length(results),
  total_runs = length(results) * n_rep,
  note = "extended 8-config x 10x8 (psi,mu_B) grid x 1000-rep run (640 conditions) loaded; R script: R/16_sim_v37p1_80grid.R"
)

obj <- list(
  mc_conf   = cm_mc,
  mcmc_conf = cm_mcmc,
  zones     = zones,
  mc_ef     = ef_mc_p,
  mcmc_ef   = ef_mcmc_p,
  mc_pz     = pz_mc,
  mcmc_pz   = pz_mcmc,
  agg       = agg,
  design_summary = ds
)

json_str <- jsonlite::toJSON(obj, auto_unbox = TRUE, digits = 6, pretty = TRUE)

# ---- replace the cmp-data script block in the HTML ----
html <- readLines(HTML_PATH, warn = FALSE, encoding = "UTF-8")
html <- paste(html, collapse = "\n")
pat <- '(?s)(<script type="application/json" id="cmp-data">).*?(</script>)'
new_block <- paste0('\\1', json_str, '\\2')
html_new <- sub(pat, new_block, html, perl = TRUE)
if (html_new == html) stop("cmp-data block not found / not replaced")
writeLines(html_new, HTML_PATH, useBytes = TRUE)
cat(sprintf("injected full %d-condition agg + recomputed diagnostics into explainer\n", length(results)))
