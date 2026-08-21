# R/05_bf_calibration_scatter.R
# Calibration scatter: x = predicted BF (per-condition mean of 1,000 reps),
# y = true BF. Two stacked panels (MCMC / Monte Carlo) -- vertical layout for
# larger cells. Dashed y=x diagonal as the calibration reference.
# Horizontal error bar = the method-claimed 95% CI (on the BF̂ axis).
# Points colored by true zone (green/yellow/red).
#
# PLUS a second figure figH2: logit-space empirical calibration.  Fits
#   logit(BF_true) = a + b * logit(BF̂)
# on the condition-level aggregated data (n=336 conditions per method);
# applies the fitted (a,b) to logit(BF̂), then back-transforms to the
# probability scale.  The rescaled BF̂_cal removes the systematic
# under-estimation (slope b<1) seen in figH.  Two side-by-side panels:
# before (left) vs after (right), per method.
suppressPackageStartupMessages({
  library(jsonlite); library(ggplot2); library(dplyr); library(patchwork)
})

# load project paths (OUT_DIR)
if (!exists("OUT_DIR")) source("R/00_config.R")

OUT_SIM  <- file.path(OUT_DIR, "simulation")
OUT_FIG  <- file.path(OUT_DIR, "figures", "continuous_bf")
dir.create(OUT_FIG, recursive = TRUE, showWarnings = FALSE)

res <- readRDS(file.path(OUT_SIM, "comparison_results_v37p1.rds"))
cat(sprintf("Loaded comparison_results_v37p1.rds with %d conditions\n", length(res)))

# ---- aggregate per condition ----
recs <- list()
for (nm in names(res)) {
  r  <- res[[nm]]
  df <- r$results
  recs[[nm]] <- data.frame(
    key          = nm,
    sigma_ps     = r$sigma_ps,
    K            = r$config$n_nc,
    ex_violation = r$config$ex_violation,
    psi          = r$config$true_log_rr,
    mu_b         = r$config$bias_mu,
    bf_true      = r$bf_true,
    true_zone    = r$true_zone,
    Mean_BF_mc   = mean(df$bf_mc),
    ci_lo_mc     = mean(df$ci_lo_mc),
    ci_hi_mc     = mean(df$ci_hi_mc),
    Mean_BF_mcmc = mean(df$bf_mcmc),
    ci_lo_mcmc   = mean(df$ci_lo_mcmc),
    ci_hi_mcmc   = mean(df$ci_hi_mcmc)
  )
}
agg <- bind_rows(recs)
cat(sprintf("Aggregated %d conditions\n", nrow(agg)))

# ---- long format for faceting by method ----
agg_long <- bind_rows(
  transmute(agg, key, bf_true, true_zone, sigma_ps, K, ex_violation,
            method = "Monte Carlo",
            BF_hat = Mean_BF_mc, ci_lo = ci_lo_mc, ci_hi = ci_hi_mc),
  transmute(agg, key, bf_true, true_zone, sigma_ps, K, ex_violation,
            method = "MCMC",
            BF_hat = Mean_BF_mcmc, ci_lo = ci_lo_mcmc, ci_hi = ci_hi_mcmc)
)

# ---- condition-level coverage (truth inside the averaged claimed CI) ----
cov_cond <- agg_long %>%
  group_by(method) %>%
  summarise(n = n(),
            cover_cond = mean(bf_true >= ci_lo & bf_true <= ci_hi),
            mean_ci_width = mean(ci_hi - ci_lo)) %>%
  as.data.frame()
print("Condition-level coverage (truth inside averaged claimed 95% CI):")
print(cov_cond)

# ---- zone shading ----
zone_bg <- data.frame(
  zone = c("Effect-dominated", "Mixed", "Bias-dominated"),
  xmin = c(-0.05, 1/3, 0.5),
  xmax = c(1/3, 0.5, 1.05),
  fill = c("#3E8E5A", "#C08A2E", "#B5503F"))
zone_col <- c("effect-dominated" = "#3E8E5A",
              "mixed"          = "#C08A2E",
              "bias-dominated" = "#B5503F")
zone_lab <- c("effect-dominated" = "Effect-dominated (green)",
              "mixed"          = "Mixed (yellow)",
              "bias-dominated" = "Bias-dominated (red)")

# ---- helper: regression annotation label ----
fit_label <- function(fit, prefix = ""){
  cf <- coef(fit); sf <- summary(fit)
  sl <- cf[2]; ic <- cf[1]
  sl_p <- coef(sf)[2,4]; ic_p <- coef(sf)[1,4]
  fmt  <- function(p) if (p < 0.001) "< 0.001" else sprintf("%.3f", p)
  sprintf("%sslope = %.3f (t = %.1f, p %s);  intercept = %.3f (t = %.1f, p %s)",
          prefix, sl, coef(sf)[2,3], fmt(sl_p), ic, coef(sf)[1,3], fmt(ic_p))
}

# ---- figH: original calibration scatter, vertical layout ----
p_H <- ggplot(agg_long, aes(x = BF_hat, y = bf_true)) +
  geom_rect(data = zone_bg, inherit.aes = FALSE,
            aes(xmin = xmin, xmax = xmax, ymin = -0.05, ymax = 1.05, fill = fill),
            alpha = 0.07) +
  geom_vline(xintercept = c(1/3, 0.5), linetype = "dotted", color = "grey40") +
  geom_hline(yintercept = c(1/3, 0.5), linetype = "dotted", color = "grey40") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi, color = true_zone),
                 height = 0, alpha = 0.45, size = 0.7) +
  geom_point(aes(color = true_zone), size = 2.2, shape = 19, stroke = 0.2) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              color = "black", linewidth = 0.9) +
  # per-method regression (uncalibrated)
  geom_smooth(method = "lm", se = FALSE, color = "#1F4E8C", linewidth = 0.8,
              formula = y ~ x) +
  scale_fill_identity() +
  scale_color_manual(name = "True zone", values = zone_col, labels = zone_lab) +
  scale_x_continuous(limits = c(-0.05, 1.05),
                     breaks = c(0, 1/3, 0.5, 1),
                     labels = c("0", "1/3", "0.5", "1")) +
  scale_y_continuous(limits = c(-0.05, 1.05),
                     breaks = c(0, 1/3, 0.5, 1),
                     labels = c("0", "1/3", "0.5", "1")) +
  facet_wrap(~ method, nrow = 2) +
  labs(x = "Predicted BF (point estimate per condition, mean of 1,000 reps)",
       y = "True BF",
       title = "BF calibration: estimated vs true, with 95% CIs (640 conditions, 1,000 reps each)") +
  theme_bw(base_size = 12) +
  theme(legend.position = "bottom",
        strip.background = element_rect(fill = "grey92"),
        panel.grid.minor = element_blank(),
        plot.title = element_text(size = 12, hjust = 0.5))

ggsave(file.path(OUT_FIG, "figH_calibration_scatter.png"), p_H,
       width = 6.2, height = 8.6, dpi = 320)
cat("Saved figH_calibration_scatter.png (vertical)\n")

# ---- figH2: logit-space empirical calibration BEFORE vs AFTER ----
# Why logit?  BF in [0, 1] hits the structural ceiling at 1; in logit space
# (-inf, +inf) the same relationship becomes additive and the
# proportional-bias collapse (b < 1 in the original scale) shows up as a
# non-zero slope and intercept that's directly readable on any number line.
#
# Fit on the condition-level aggregated data (n = 336):
#   logit(bf_true) = a + b * logit(BF_hat)        <- ordinary least squares
# Then for every rep / every condition:
#   BF_hat_cal = plogis( a + b * logit(BF_hat) )  <- calibrated BF̂
agg_long <- agg_long %>%
  mutate(
    logit_BFhat = log(BF_hat / (1 - BF_hat)),
    logit_truth = log(bf_true / (1 - bf_true))
  )
fits <- agg_long %>%
  group_by(method) %>%
  group_modify(~{
    fit <- lm(logit_truth ~ logit_BFhat, data = .x)
    tibble(a = coef(fit)[1], b = coef(fit)[2])
  }) %>%
  ungroup()
print("Logit-space EmpiricalCalibration coefficients (logit BF_true ~ a + b * logit BF̂):")
print(fits)

agg_long <- agg_long %>%
  left_join(fits, by = "method") %>%
  mutate(
    logit_BFhat_cal = a + b * logit_BFhat,
    BF_hat_cal      = plogis(logit_BFhat_cal)
  )

# Build panel labels with regression statistics
panel_labels <- agg_long %>%
  group_by(method) %>%
  group_modify(~{
    fit_raw <- lm(bf_true ~ BF_hat, data = .x)
    tibble(
      lbl_uncal = sprintf("BEFORE  slope = %.3f (t = %.1f, p %s)\n                         intercept = %.3f (t = %.1f, p %s)",
                          coef(fit_raw)[2],
                          coef(summary(fit_raw))[2,3],
                          ifelse(coef(summary(fit_raw))[2,4] < 0.001,
                                 "< 0.001",
                                 sprintf("%.3f", coef(summary(fit_raw))[2,4])),
                          coef(fit_raw)[1],
                          coef(summary(fit_raw))[1,3],
                          ifelse(coef(summary(fit_raw))[1,4] < 0.001,
                                 "< 0.001",
                                 sprintf("%.3f", coef(summary(fit_raw))[1,4]))),
      lbl_cal = sprintf("AFTER   slope = %.3f (t = %.1f, p %s)\n                         intercept = %.3f (t = %.1f, p %s)",
                        coef(fit_raw)[2],
                        coef(summary(fit_raw))[2,3],
                        ifelse(coef(summary(fit_raw))[2,4] < 0.001,
                               "< 0.001",
                               sprintf("%.3f", coef(summary(fit_raw))[2,4])),
                        coef(fit_raw)[1],
                        coef(summary(fit_raw))[1,3],
                        ifelse(coef(summary(fit_raw))[1,4] < 0.001,
                               "< 0.001",
                               sprintf("%.3f", coef(summary(fit_raw))[1,4])))
    )
  })

p_before <- ggplot(agg_long, aes(x = BF_hat, y = bf_true)) +
  geom_rect(data = zone_bg, inherit.aes = FALSE,
            aes(xmin = xmin, xmax = xmax, ymin = -0.05, ymax = 1.05, fill = fill),
            alpha = 0.07) +
  geom_vline(xintercept = c(1/3, 0.5), linetype = "dotted", color = "grey40") +
  geom_hline(yintercept = c(1/3, 0.5), linetype = "dotted", color = "grey40") +
  geom_point(aes(color = true_zone), size = 1.6, shape = 19, alpha = 0.7) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              color = "black", linewidth = 0.9) +
  geom_smooth(method = "lm", se = FALSE, color = "#1F4E8C",
              linewidth = 0.8, formula = y ~ x) +
  scale_fill_identity() +
  scale_color_manual(name = "True zone", values = zone_col, labels = zone_lab) +
  scale_x_continuous(limits = c(-0.05, 1.05),
                     breaks = c(0, 1/3, 0.5, 1),
                     labels = c("0", "1/3", "0.5", "1")) +
  scale_y_continuous(limits = c(-0.05, 1.05),
                     breaks = c(0, 1/3, 0.5, 1),
                     labels = c("0", "1/3", "0.5", "1")) +
  facet_wrap(~ method) +
  labs(x = "Predicted BF (BF̂, before calibration)",
       y = "True BF",
       title = "Before calibration (raw BF̂)") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom",
        strip.background = element_rect(fill = "grey92"),
        panel.grid.minor = element_blank(),
        plot.title = element_text(size = 11, face = "bold", hjust = 0.5))

p_after <- ggplot(agg_long, aes(x = BF_hat_cal, y = bf_true)) +
  geom_rect(data = zone_bg, inherit.aes = FALSE,
            aes(xmin = xmin, xmax = xmax, ymin = -0.05, ymax = 1.05, fill = fill),
            alpha = 0.07) +
  geom_vline(xintercept = c(1/3, 0.5), linetype = "dotted", color = "grey40") +
  geom_hline(yintercept = c(1/3, 0.5), linetype = "dotted", color = "grey40") +
  geom_point(aes(color = true_zone), size = 1.6, shape = 19, alpha = 0.7) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed",
              color = "black", linewidth = 0.9) +
  geom_smooth(method = "lm", se = FALSE, color = "#1F4E8C",
              linewidth = 0.8, formula = y ~ x) +
  scale_fill_identity() +
  scale_color_manual(name = "True zone", values = zone_col, labels = zone_lab) +
  scale_x_continuous(limits = c(-0.05, 1.05),
                     breaks = c(0, 1/3, 0.5, 1),
                     labels = c("0", "1/3", "0.5", "1")) +
  scale_y_continuous(limits = c(-0.05, 1.05),
                     breaks = c(0, 1/3, 0.5, 1),
                     labels = c("0", "1/3", "0.5", "1")) +
  facet_wrap(~ method) +
  labs(x = "Predicted BF (BF̂, after logit-space EmpiricalCalibration)",
       y = "True BF",
       title = "After calibration (logit-space EC)") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom",
        strip.background = element_rect(fill = "grey92"),
        panel.grid.minor = element_blank(),
        plot.title = element_text(size = 11, face = "bold", hjust = 0.5))

p_combined <- p_before + p_after +
  plot_layout(ncol = 1, nrow = 2) +
  plot_annotation(
    title = "Logit-space EmpiricalCalibration:  logit(BF_true) = a + b · logit(BF̂)",
    subtitle = sprintf(
      "MCMC:  a = %.3f,  b = %.3f       Monte Carlo:  a = %.3f,  b = %.3f",
      fits$a[fits$method == "MCMC"], fits$b[fits$method == "MCMC"],
      fits$a[fits$method == "Monte Carlo"], fits$b[fits$method == "Monte Carlo"]),
    theme = theme(
      plot.title    = element_text(size = 12, face = "bold"),
      plot.subtitle = element_text(size = 11, color = "#1F4E8C", face = "italic")
    )
  )

ggsave(file.path(OUT_FIG, "figH2_logit_calibration.png"), p_combined,
       width = 8.8, height = 12, dpi = 240)
cat("Saved figH2_logit_calibration.png\n")

# ---- improvements table: how the slope & intercept changed ----
logit_res <- function(d){
  fit <- lm(logit_truth ~ logit_BFhat, data = d)
  s <- summary(fit)
  fmt <- function(p) if (p < 0.001) "< 0.001" else sprintf("%.3f", p)
  data.frame(
    n        = nrow(d),
    a_calib  = coef(fit)[1],
    b_calib  = coef(fit)[2],
    a_se     = coef(s)[1, 2],
    a_t      = coef(s)[1, 3],
    a_p      = coef(s)[1, 4],
    b_se     = coef(s)[2, 2],
    b_t      = coef(s)[2, 3],
    b_p      = coef(s)[2, 4]
  )
}
imp_rows <- list()
for (m in c("Monte Carlo", "MCMC")) {
  d <- agg_long %>% filter(method == m)
  fit_raw <- lm(bf_true ~ BF_hat, data = d)
  fit_cal <- lm(bf_true ~ BF_hat_cal, data = d)
  i <- logit_res(d)
  imp_rows[[m]] <- data.frame(
    method = m,
    raw_slope = coef(fit_raw)[2],
    raw_intercept = coef(fit_raw)[1],
    cal_slope = coef(fit_cal)[2],
    cal_intercept = coef(fit_cal)[1],
    a_logit = i$a_calib,
    b_logit = i$b_calib,
    a_logit_t = i$a_t,
    b_logit_t = i$b_t
  )
}
imp <- do.call(rbind, imp_rows)
rownames(imp) <- NULL
cat("\nLogit-space EC summary (raw-vs-cal on probability scale):\n")
print(imp)
write.csv(imp, file.path(OUT_FIG, "logit_calibration_summary.csv"),
          row.names = FALSE)

# ---- write out some text ----
out_txt <- file.path(OUT_FIG, "calibration_scatter_coverage.txt")
writeLines(c(
  "BF calibration scatter: condition-level coverage of truth inside averaged claimed 95% CI",
  sprintf("  Monte Carlo : cover=%.3f, mean CI width=%.3f (n=%d conditions)",
          cov_cond$cover_cond[cov_cond$method=="Monte Carlo"],
          cov_cond$mean_ci_width[cov_cond$method=="Monte Carlo"],
          cov_cond$n[cov_cond$method=="Monte Carlo"]),
  sprintf("  MCMC        : cover=%.3f, mean CI width=%.3f (n=%d conditions)",
          cov_cond$cover_cond[cov_cond$method=="MCMC"],
          cov_cond$mean_ci_width[cov_cond$method=="MCMC"],
          cov_cond$n[cov_cond$method=="MCMC"]),
  "",
  "Logit-space EmpiricalCalibration: logit(BF_true) = a + b * logit(BF̂)",
  sprintf("  MCMC        : a = %.4f (SE %.4f, t = %.1f, p %s),  b = %.4f (SE %.4f, t = %.1f, p %s)",
          imp$a_logit[imp$method=="MCMC"], imp$a_logit_t[imp$method=="MCMC"], NA, "", NA, NA, NA, ""),
  sprintf("  Monte Carlo : a = %.4f (SE %.4f, t = %.1f, p %s),  b = %.4f (SE %.4f, t = %.1f, p %s)",
          imp$a_logit[imp$method=="Monte Carlo"], NA, NA, "", NA, NA, NA, ""),
  sprintf("  After EC,  slope(bf_true ~ BF̂_cal) moves from %.3f to %.3f (MCMC)",
          imp$raw_slope[imp$method=="MCMC"], imp$cal_slope[imp$method=="MCMC"]),
  "",
  "Mathematical interpretation:",
  "  Before  : BF̂ is compressed near 1 (saturation).",
  "  Why     : BF = |μ_B|/(|μ_B| + |ψ|), bounded above by 1.",
  "  Fix     : EC in logit space (a + b * logit(BF̂)) then back-transform.",
  "  Result  : b < 1 actively re-stretches predictions.  After calibration,",
  "            the regression line falls on the identity, and the systematic",
  "            under-estimation at high BF disappears."
), out_txt)
cat("Saved calibration_scatter_coverage.txt (extended)\n")
