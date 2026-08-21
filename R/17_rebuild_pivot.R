# R/17_rebuild_pivot.R
# Regenerate the bilingual explainer's 3D pivot data island (__PIVOT_DATA__) from the
# 640-condition v37.1 comparison_results RDS so the interactive cube matches the manuscript.
# Uses the MCMC BF estimator (primary, per manuscript): bf_mcmc / ci_*_mcmc / zone_mcmc.
# v37.1 - 2026-08-21

suppressPackageStartupMessages({ library(jsonlite) })
SIM_DIR   <- "output/simulation"
HTML_PATH <- "互动讲解器_BF_simulator_v37.html"
RES_RDS   <- file.path(SIM_DIR, "comparison_results_v37p1.rds")

r <- readRDS(RES_RDS)
cat(sprintf("loaded %d conditions\n", length(r)))

parse_pmu <- function(key) {
  psi  <- as.numeric(sub(".*_psi(-?[0-9.]+)_mu.*", "\\1", key))
  mu_b <- as.numeric(sub(".*_mu(-?[0-9.]+)_sps.*", "\\1", key))
  list(psi = psi, mu_b = mu_b)
}

records <- list()
for (key in names(r)) {
  e   <- r[[key]]
  res <- e$results
  bt  <- e$bf_true
  bf  <- res$bf_mcmc
  lo  <- res$ci_lo_mcmc
  hi  <- res$ci_hi_mcmc
  z   <- res$zone_mcmc
  pm  <- parse_pmu(key)
  cid <- e$config_id
  K  <- if (grepl("K25", cid)) 25L else 12L
  ex <- if (grepl("exV0\\.3", cid)) 0.3 else 0
  records[[length(records) + 1]] <- list(
    cond_key   = key,
    psi        = pm$psi,
    mu_b       = pm$mu_b,
    sigma_ps   = e$sigma_ps,
    K          = K,
    ex_violation = ex,
    bf_true    = bt,
    mae        = mean(abs(bf - bt)),
    rmse       = sqrt(mean((bf - bt)^2)),
    mean_bias  = mean(bf - bt),
    coverage   = mean(lo <= bt & bt <= hi),
    ci_width   = mean(hi - lo),
    accuracy   = mean(z == e$true_zone) * 100
  )
}
cat(sprintf("built %d pivot records\n", length(records)))

factor_levels <- list(
  psi          = sort(unique(sapply(records, function(x) x$psi))),
  mu_b         = sort(unique(sapply(records, function(x) x$mu_b))),
  sigma_ps     = c(0.06, 0.10),
  K            = c(12, 25),
  ex_violation = c(0, 0.3)
)
stat_cols   <- c("mae", "rmse", "mean_bias", "coverage", "ci_width", "accuracy")
stat_labels <- c("MAE (mean |BF̂−BF_true|)", "RMSE", "Mean bias",
                 "95% CI coverage (%)", "Mean CI width", "Classification accuracy (%)")

obj <- list(factor_levels = factor_levels, stat_cols = stat_cols,
            stat_labels = stat_labels, records = records)
json_str <- jsonlite::toJSON(obj, auto_unbox = TRUE, digits = 6, pretty = TRUE)

html <- paste(readLines(HTML_PATH, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
pat <- '(?s)window\\.__PIVOT_DATA__ = \\{.*?\\};'
if (!grepl(pat, html, perl = TRUE)) stop("__PIVOT_DATA__ block not found")
new_block <- paste0('window.__PIVOT_DATA__ = ', json_str, ';')
html_new <- sub(pat, new_block, html, perl = TRUE)
if (html_new == html) stop("pivot block not replaced")
writeLines(html_new, HTML_PATH, useBytes = TRUE)
cat(sprintf("injected 640-condition pivot (%d records, psi=%d levels, mu_b=%d levels) into explainer\n",
            length(records), length(factor_levels$psi), length(factor_levels$mu_b)))
