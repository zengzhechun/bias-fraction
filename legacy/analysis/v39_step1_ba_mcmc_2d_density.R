## ===========================================================================
##  v39 Step 1 (v37-style) - True-BAF perspective Bland-Altman panel (BAF-hat = Gibbs posterior median)
##
##  Source : comparison_results_v37p1.rds  (960 conditions x 1000 reps = 960k)
##  Output :
##    output/figures/v39/figI_bland_altman_gibbs_2d.png        (full tri-panel 9x15)
##    output/figures/v39/figI_bland_altman_gibbs_2d_panel.png   (mid+stats only, 9x8)
##    output/tables/v39_part1_ba_gibbs_full_stats.csv
##    output/simulation/v39_ba_gibbs_reps.rds
##    output/simulation/v39_ba_gibbs_stats.rds
##
##  Visual style aligned with v37 figM_full_ba_viz.png (true-BAF perspective)
##    Top    : jittered scatter (60k sample) coloured by true_zone
##    Middle : 2D kde2d density with pretty(z, 5) colormap matching v37
##    Stats  : 13-row Bland-Altman agreement statistics table
## ===========================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(grid)
  library(gridExtra)
  library(scales)
  library(MASS)
  library(gtable)
  library(patchwork)   # wrap_elements() lives here
})

BASE    <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/第39版"
OUT_FIG <- file.path(BASE, "output/figures/v39")
OUT_TBL <- file.path(BASE, "output/tables")
OUT_RDS <- file.path(BASE, "output/simulation")
dir.create(OUT_FIG, showWarnings = FALSE, recursive = TRUE)

## ---- 1. stack per-rep values (incl. zone) ---------------------------------
sim <- readRDS(file.path(OUT_RDS, "comparison_results_v37p1.rds"))
cat("[1] Stacking", length(sim), "conditions x 1000 reps ...\n")
big <- do.call(rbind, lapply(names(sim), function(nm) {
  s <- sim[[nm]]
  if (is.null(s$results) || nrow(s$results) == 0) return(NULL)
  data.frame(
    cond_id      = nm,
    rep          = s$results$rep,
    true_bf      = s$bf_true,
    est_bf_mcmc  = s$results$bf_mcmc,
    diff_mcmc    = s$results$bf_mcmc - s$bf_true,
    zone         = s$true_zone,
    psi          = s$config$true_log_rr,
    stringsAsFactors = FALSE
  )
}))
big <- big[is.finite(big$true_bf) & is.finite(big$est_bf_mcmc) & is.finite(big$diff_mcmc), ]
cat("    Finite rows kept:", nrow(big), "\n")
cat("    Zone counts: "); print(table(big$zone))

big$zone <- factor(big$zone, levels = c("effect-dominated", "mixed", "bias-dominated"))
zc <- c("effect-dominated" = "#1B7A3A",
        "mixed"            = "#D4A017",
        "bias-dominated"   = "#B83227")
saveRDS(big, file.path(OUT_RDS, "v39_ba_gibbs_reps.rds"))

## ---- 2. compute Bland-Altman stats ----------------------------------------------
# Derived from the data, not hard-coded: the v39b grid added a third
# negative-control panel size (K = 50), taking the design from 640 conditions
# (640,000 reps) to 960 conditions (960,000 reps).
n_total   <- nrow(big)
n_used    <- nrow(big)
bias      <- mean(big$diff_mcmc)
sd_diff   <- sd(big$diff_mcmc)
loa_lo    <- bias - 1.96 * sd_diff
loa_hi    <- bias + 1.96 * sd_diff
in_n      <- sum(big$diff_mcmc >= loa_lo & big$diff_mcmc <= loa_hi)
pct_in    <- 100 * in_n / n_used
out_n     <- n_used - in_n

ccc_one <- function(x, y) {
  nn <- length(x)
  mx <- mean(x); my <- mean(y)
  vx <- var(x);   vy <- var(y)
  sxy <- sum((x - mx) * (y - my)) / nn
  2 * sxy / (vx + vy + (mx - my)^2)
}
L        <- ccc_one(big$true_bf, big$est_bf_mcmc)
r_prop   <- cor(big$diff_mcmc, big$true_bf)
fit      <- lm(diff_mcmc ~ true_bf, data = big)
slope    <- coef(fit)[["true_bf"]]
slope_ci <- confint(fit)["true_bf", ]
slope_t  <- summary(fit)$coefficients["true_bf", "t value"]
slope_p  <- summary(fit)$coefficients["true_bf", "Pr(>|t|)"]
intercept <- coef(fit)[["(Intercept)"]]
int_t    <- summary(fit)$coefficients["(Intercept)", "t value"]
int_p    <- summary(fit)$coefficients["(Intercept)", "Pr(>|t|)"]

cat("[2] Bland-Altman stats (n_used =", n_used, "):\n")
cat(sprintf("    bias=%.4f, sd=%.4f, LoA=[%.4f, %.4f]\n", bias, sd_diff, loa_lo, loa_hi))
cat(sprintf("    in_LoA=%d (%.3f%%), CCC=%.4f, r_prop=%.4f, slope=%.4f, t=%.1f\n",
            in_n, pct_in, L, r_prop, slope, slope_t))

## ---- 3. save stats table CSV -----------------------------------------------
fmt_p <- function(p) ifelse(p < 0.001, "< 0.001", sprintf("= %.3f", p))
df_stats <- data.frame(
  Quantity = c(
    "n (reps)",
    "Overall mean bias",
    "SD(diff)",
    "LoA (lower, upper)",
    "Within LoA",
    "(inside count / total)",
    "Outside LoA (reps)",
    "Lin's CCC",
    "Prop. bias r (Pearson, diff vs true)",
    "Regression slope: diff ~ true BAF",
    "slope [95% CI]",
    "slope t-stat, p-value",
    "intercept"
  ),
  Value = c(
    format(n_used, big.mark = ","),
    sprintf("%.3f", bias),
    sprintf("%.3f", sd_diff),
    sprintf("[%.3f, %.3f]", loa_lo, loa_hi),
    sprintf("%.1f%%", pct_in),
    sprintf("%s / %s", format(in_n, big.mark = ","), format(n_used, big.mark = ",")),
    format(out_n, big.mark = ","),
    sprintf("%.3f", L),
    sprintf("%.3f", r_prop),
    sprintf("%.3f", slope),
    sprintf("[%.3f, %.3f]", slope_ci[1], slope_ci[2]),
    sprintf("t = %.1f, p %s", slope_t, fmt_p(slope_p)),
    sprintf("%.3f", intercept)
  ),
  stringsAsFactors = FALSE
)
write.csv(df_stats, file.path(OUT_TBL, "v39_part1_ba_gibbs_full_stats.csv"), row.names = FALSE)
cat("    saved:", file.path(OUT_TBL, "v39_part1_ba_gibbs_full_stats.csv"), "\n")

## ---- 4. warm palette matched to v37 ----------------------------------------
warm_pal_v37 <- colorRampPalette(c(
  "white",
  scales::alpha("#FBE7B6", 0.85),
  "#F7B267", "#E85D04", "#B83227", "#5B0F4A"
))

## ---- 5. PANELS : Top scatter + Middle 2D density ---------------------------
mk_panels <- function(d, subtitle_extra, bias_int = NULL, ccc_int = NULL){
  set.seed(7)
  ss <- d[sample(nrow(d), 60000), ]                      # 60k for scatter
  bias_ <- mean(d$diff); sd_ <- sd(d$diff)
  lo_l  <- bias_ - 1.96*sd_; lo_u <- bias_ + 1.96*sd_

  ## --- TOP : jittered scatter coloured by zone ---------------------------
  p_top <- ggplot(ss, aes(x = true_bf, y = diff_mcmc, color = zone)) +
    geom_jitter(width = 0.045, height = 0.005,
                size = 0.55, alpha = 0.06, na.rm = TRUE) +
    geom_hline(yintercept = bias_, color = "#1F1F1F", linewidth = 0.7) +
    geom_hline(yintercept = lo_l, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.85) +
    geom_hline(yintercept = lo_u, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.85) +
    annotate("label", x = Inf, y = lo_u,
             label = sprintf("+1.96 SD LoA = %.3f", lo_u),
             color = "#B83227", size = 3.4, fontface = "italic",
             hjust = 1.04, vjust = -0.6, fill = "white", linewidth = 0) +
    annotate("label", x = Inf, y = lo_l,
             label = sprintf("-1.96 SD LoA = %.3f", lo_l),
             color = "#B83227", size = 3.4, fontface = "italic",
             hjust = 1.04, vjust = 1.6, fill = "white", linewidth = 0) +
    annotate("label", x = Inf, y = bias_,
             label = sprintf("overall mean bias = %.3f", bias_),
             color = "#1F1F1F", size = 3.4, fontface = "italic",
             hjust = 1.04, vjust = -0.7, fill = "white", linewidth = 0) +
    scale_color_manual(values = zc, drop = FALSE) +
    labs(title = "Top. Jittered scatter (horizontally broadened)",
         subtitle = subtitle_extra,
         x = NULL, y = "BAF-hat (Gibbs posterior median) - true BAF", color = NULL) +
    scale_x_continuous(limits = c(0, 1.02),
                       breaks = c(0.25, 0.50, 0.75, 1.00),
                       expand = expansion(mult = c(0.005, 0.02))) +
    scale_y_continuous(limits = c(-0.86, 0.66),
                       breaks = c(-0.8, -0.4, 0.0, 0.4),
                       expand = expansion(mult = c(0.02, 0.02))) +
    coord_cartesian(ylim = c(-0.86, 0.66)) +
    theme_minimal(base_size = 12) +
    theme(
      legend.position  = "bottom",
      legend.text      = element_text(size = 10),
      plot.title       = element_text(face = "bold", size = 13),
      plot.subtitle    = element_text(size = 10, color = "grey25"),
      panel.grid       = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background  = element_rect(fill = "white", color = NA),
      axis.text        = element_text(color = "black", size = 10),
      axis.title       = element_text(face = "bold", size = 11)
    )

  ## --- MIDDLE : 2D density (v37 palette, pretty(z,5)) --------------------
  dens_obj <- MASS::kde2d(d$true_bf, d$diff_mcmc, h = c(0.04, 0.025), n = c(140, 140))
  df_dens  <- expand.grid(bf_true = dens_obj$x, diff = dens_obj$y)
  df_dens$z <- as.vector(dens_obj$z)
  p_mid <- ggplot(df_dens, aes(x = bf_true, y = diff, fill = z)) +
    geom_raster() +
    scale_fill_gradientn(
      colours = warm_pal_v37(64), name = "density",
      breaks = pretty(range(df_dens$z), 5),
      labels = function(x) sprintf("%.2f", x)
    ) +
    geom_contour(aes(z = z, fill = NULL), color = "white",
                 linewidth = 0.25, alpha = 0.45,
                 breaks = pretty(range(df_dens$z), 8)[-1]) +
    geom_hline(yintercept = bias_, color = "#1F1F1F", linewidth = 0.7) +
    geom_hline(yintercept = lo_l, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.9) +
    geom_hline(yintercept = lo_u, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.9) +
    annotate("label", x = Inf, y = lo_u,
             label = sprintf("+1.96 SD LoA = %.3f", lo_u),
             color = "#B83227", size = 3.4, fontface = "italic",
             hjust = 1.05, vjust = -0.6, fill = "white", linewidth = 0) +
    annotate("label", x = Inf, y = lo_l,
             label = sprintf("-1.96 SD LoA = %.3f", lo_l),
             color = "#B83227", size = 3.4, fontface = "italic",
             hjust = 1.05, vjust = 1.6, fill = "white", linewidth = 0) +
    annotate("label", x = Inf, y = bias_,
             label = sprintf("overall mean bias = %.3f", bias_),
             color = "#1F1F1F", size = 3.4, fontface = "italic",
             hjust = 1.05, vjust = -0.7, fill = "white", linewidth = 0) +
    # vline at bf_true=0.8 removed: interior is now defined by the near-boundary psi=-0.01 exclusion
    {if (!is.null(bias_int)) annotate("text", x = 0.02, y = 0.25,
             label = sprintf("interior (excl psi = -0.01): mean bias = %.3f, CCC = %.3f",
                             bias_int, ccc_int),
             size = 2.5, color = "grey30", hjust = 0, vjust = 1)} +
    labs(title = "Bland-Altman 2D density (BAF-hat by Gibbs vs true BAF)",
         subtitle = sprintf("mass of %s reps; warm color = higher point concentration",
                            format(nrow(d), big.mark = ",")),
         x = "True BAF",
         y = "BAF-hat (Gibbs posterior median) - true BAF") +
    scale_x_continuous(limits = c(0, 1.02),
                       breaks = c(0.25, 0.50, 0.75, 1.00),
                       expand = expansion(mult = c(0.005, 0.02))) +
    scale_y_continuous(limits = c(-0.45, 0.28),
                       breaks = c(-0.4, -0.2, 0.0, 0.2),
                       expand = expansion(mult = c(0.02, 0.02))) +
    theme_minimal(base_size = 12) +
    theme(
      legend.position  = "right",
      plot.title       = element_text(face = "bold", size = 13),
      plot.subtitle    = element_text(size = 10, color = "grey25"),
      panel.grid       = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background  = element_rect(fill = "white", color = NA),
      legend.background = element_rect(fill = "white", color = NA),
      legend.key        = element_rect(fill = "white", color = NA),
      axis.text        = element_text(color = "black", size = 10),
      axis.title       = element_text(face = "bold", size = 11)
    )

  list(top = p_top, mid = p_mid)
}

## ---- 6. STATS table (aligned with v37 ribbon block) -----------------------
mk_param_ribbon <- function(st) {
  rows <- data.frame(
    Quantity = c(
      "n (reps)",
      "Overall mean bias",
      "SD(diff)",
      "LoA (lower, upper)",
      "Within LoA",
      "  (inside count / total)",
      "Outside LoA (reps)",
      "Lin's CCC",
      "Regression slope: diff ~ true BAF",
      "  slope [95% CI]",
      "  slope t-stat, p-value"
    ),
    Value = c(
      format(st$n, big.mark = ","),
      sprintf("%.3f", st$bias),
      sprintf("%.3f", st$sd_diff),
      sprintf("[%.3f, %.3f]", st$loa_lo, st$loa_hi),
      sprintf("%.1f%%", st$in_pct),
      sprintf("%s / %s",
              format(st$n - st$outside_n, big.mark = ","),
              format(st$n,         big.mark = ",")),
      format(st$outside_n, big.mark = ","),
      sprintf("%.3f", st$ccc),
      sprintf("%.3f", st$reg_slope),
      sprintf("[%.3f, %.3f]", st$reg_slope_lo, st$reg_slope_hi),
      sprintf("t = %.1f, p %s", st$reg_slope_t, fmt_p(st$reg_slope_p))
    ),
    stringsAsFactors = FALSE
  )
  ttl <- textGrob("Bland-Altman agreement statistics",
                  gp = gpar(fontface = "bold.italic", fontsize = 13, col = "#1F1F1F"))
  tbl <- tableGrob(rows, rows = NULL,
                   cols = c("Quantity", "Value"),
                   theme = ttheme_minimal(
                     base_size = 11.5,
                     core = list(
                       fg_params = list(hjust = c(0, 0), x = c(0.02, 0.02),
                                        fontface = c("plain", "plain")),
                       bg_params = list(fill = c("#FAFAFA", "#FFFFFF"))
                     ),
                     colhead = list(fg_params = list(fontface = "bold", col = "white"),
                                    bg_params = list(fill = "#1F1F1F"))))
  tbl <- gtable::gtable_add_rows(tbl, heights = unit(0.9, "line"), pos = 0)
  tbl <- gtable::gtable_add_grob(tbl, ttl, t = 1, l = 1, r = ncol(tbl))
  # measure the table's natural height inside a real graphics viewport so the
  # layout slot can be sized exactly (prevents overlap + bottom clipping)
  dev <- pdf(file = tempfile(fileext = ".pdf"), width = 9, height = 12)
  tbl_h_in <- convertHeight(sum(tbl$heights), "in", valueOnly = TRUE)
  dev.off()
  wrapped <- wrap_elements(tbl) +
    theme(plot.margin = margin(t = 12, b = 6, unit = "pt"),
          plot.background  = element_rect(fill = "white", color = NA),
          panel.background = element_rect(fill = "white", color = NA))
  list(wrapped = wrapped, h_in = tbl_h_in)
}

## ---- 7. assemble -------------------------------------------------------
st <- list(n = n_used, bias = bias, sd_diff = sd_diff,
           loa_lo = loa_lo, loa_hi = loa_hi,
           in_pct = pct_in, outside_n = out_n,
           ccc = L, r_prop = r_prop,
           reg_slope = slope, reg_slope_lo = slope_ci[1], reg_slope_hi = slope_ci[2],
           reg_slope_t = slope_t, reg_slope_p = slope_p,
           reg_intercept = intercept)
## interior-grid stats (exclude the near-boundary psi=-0.01 set, matching the manuscript text)
big_int  <- big[abs(big$psi - (-0.01)) >= 1e-9, ]
bias_int <- mean(big_int$diff_mcmc)
ccc_int  <- ccc_one(big_int$true_bf, big_int$est_bf_mcmc)
cat(sprintf("    interior (excl psi=-0.01): n=%d bias=%.4f ccc=%.4f\n", nrow(big_int), bias_int, ccc_int))
panels <- mk_panels(big, "full design (960 conditions x 1000 reps, includes near-boundary psi=-0.01)", bias_int, ccc_int)
ribbon <- mk_param_ribbon(st)
# Ribbon slot = measured table height + breathing room, so the stats block
# never overlaps the density panel's x-axis and never clips at the page bottom.
rib_h <- ribbon$h_in + 0.45
cat("    measured stats-table height:", sprintf("%.2f", ribbon$h_in), "in; slot =", sprintf("%.2f", rib_h), "in\n")

## Full tri-panel  (Top + Middle + Stats)  -- embedded in the interactive explainer
top_h <- 4.7; mid_h <- 4.7
H_full <- top_h + mid_h + rib_h + 0.15
fig_full <- panels$top / panels$mid / ribbon$wrapped +
  plot_layout(heights = c(top_h, mid_h, rib_h))
png_full <- file.path(OUT_FIG, "figI_bland_altman_gibbs_2d.png")
ggsave(filename = png_full, plot = fig_full,
       width = 9, height = H_full, dpi = 300, bg = "white", limitsize = FALSE)
cat("[3] full tri-panel saved:", png_full, sprintf(" (9 x %.2f in)", H_full), "\n")

## Compact panel  (Middle + Stats only)  -- JAMA Figure 1
mid_h2  <- 5.3
H_panel <- mid_h2 + rib_h + 0.15
fig_panel <- panels$mid / ribbon$wrapped + plot_layout(heights = c(mid_h2, rib_h))
png_panel <- file.path(OUT_FIG, "figI_bland_altman_gibbs_2d_panel.png")
ggsave(filename = png_panel, plot = fig_panel,
       width = 9, height = H_panel, dpi = 300, bg = "white", limitsize = FALSE)
cat("    compact mid+stats saved:", png_panel, sprintf(" (9 x %.2f in)", H_panel), "\n")

## ---- 8. persist canonical stats -------------------------------------------
saveRDS(
  list(stats = list(
    n_total=n_total, n_used=n_used,
    bias=bias, sd_diff=sd_diff, loa_lo=loa_lo, loa_hi=loa_hi,
    pct_in=pct_in, in_n=in_n, out_n=out_n,
    ccc=L, r_prop=r_prop, slope=slope,
    slope_lo=slope_ci[1], slope_hi=slope_ci[2],
    slope_t=slope_t, slope_p=slope_p,
    intercept=intercept, intercept_t=int_t, intercept_p=int_p),
       df_stats = df_stats),
  file.path(OUT_RDS, "v39_ba_gibbs_stats.rds")
)

cat("\n=== DONE ===\n")
