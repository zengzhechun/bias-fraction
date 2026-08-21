# R/10_ba_full_viz.R
# v36 - 2026-08-21: PRIMARY-analysis visualization. Produces the two Bland-Altman
#   plots cited as the primary analysis in the manuscript: figL = interior sample
#   (excl near-boundary psi=-0.01, the primary agreement panel) and figM = full sample (incl psi=-0.01,
#   transparency analysis). Each carries the regression slope/intercept significance
#   tests (t-stat, p-value) and a legend ordered to match the left-to-right plot
#   (green = effect-dominated, yellow = mixed, red = bias-dominated).
# 重做 BA 可视化：纵向大图、参数齐全；interior 版 + 全量（含 BF=1）版各一张。
# 统计量除 BA 标准外加 diff ~ true 的回归斜率/截距，统一拼成横向参数条。
suppressMessages({
  library(dplyr); library(ggplot2); library(patchwork)
  library(grid); library(gridExtra)
})
RDS <- "output/simulation/comparison_results_v37p1.rds"
r <- readRDS(RDS); keys <- names(r)
parse <- function(k){
  sp <- strsplit(k, "_")[[1]]
  psi <- as.numeric(sub("psi", "", sp[grepl("^psi", sp)]))
  mu  <- as.numeric(sub("mu",  "", sp[grepl("^mu",  sp)]))
  c(psi, mu)
}
rows <- lapply(keys, function(k){
  cond <- r[[k]]; cdf <- cond$results; p <- parse(k)
  data.frame(psi = p[1], bf_true = cond$bf_true, zone = cond$true_zone,
             est_mc = cdf$bf_mc, est_mcmc = cdf$bf_mcmc)
})
df <- do.call(rbind, rows)
df$diff <- df$est_mcmc - df$bf_true
# Force zone factor levels in visual order (low BF -> high BF) so the legend
# reads left-to-right the same way the plot does: effect-dominated (green),
# mixed (yellow), bias-dominated (red). Without this, ggplot2 uses
# alphabetical order (bias-dominated, effect-dominated, mixed), which is
# confusing because the legend then has red first but the plot starts green.
df$zone <- factor(df$zone, levels = c("effect-dominated", "mixed", "bias-dominated"))

zc <- c("effect-dominated" = "#1B7A3A", "mixed" = "#D4A017", "bias-dominated" = "#B83227")

# ---- helper: build BA stats for a given subset ----
# Regression of diff on true BF: coefficients, 95% CI (t-based), SE, t, p.
# p-values = significance test of H0: slope/intercept = 0 (proportional bias / mean bias).
mk_stats <- function(d, label){
  n <- nrow(d)
  b <- mean(d$diff); s <- sd(d$diff)
  lo_l <- b - 1.96*s; lo_u <- b + 1.96*s
  inside  <- sum(d$diff >= lo_l & d$diff <= lo_u)
  outside <- n - inside
  in_pct  <- 100 * inside / n
  mxe <- mean(d$bf_true); mye <- mean(d$est_mcmc)
  ccc <- 2*cov(d$bf_true, d$est_mcmc) /
         (var(d$bf_true) + var(d$est_mcmc) + (mxe-mye)^2)
  r_prop <- cor(d$bf_true, d$diff)
  fit  <- lm(diff ~ bf_true, data = d)
  ci   <- confint(fit)          # 95% CI (t-based)
  sfit <- summary(fit)          # coefficients / SE / t / p
  slope     <- coef(fit)[2]; intercept <- coef(fit)[1]
  slope_se  <- coef(sfit)[2,2]; slope_t <- coef(sfit)[2,3]; slope_p <- coef(sfit)[2,4]
  int_se    <- coef(sfit)[1,2]; int_t   <- coef(sfit)[1,3]; int_p   <- coef(sfit)[1,4]
  data.frame(
    label = label, n = n,
    bias = b, sd_diff = s, loa_lo = lo_l, loa_hi = lo_u,
    in_pct = in_pct, outside_n = outside,
    ccc = ccc, r_prop = r_prop,
    reg_slope = slope, reg_slope_lo = ci[2,1], reg_slope_hi = ci[2,2],
    reg_slope_se = slope_se, reg_slope_t = slope_t, reg_slope_p = slope_p,
    reg_intercept = intercept, reg_int_se = int_se, reg_int_t = int_t, reg_int_p = int_p
  )
}

interior <- df %>% filter(psi != -0.01)
full_set <- df
cat("Interior (excl psi=-0.01): ", nrow(interior), "  Full: ", nrow(full_set), "\n")
cat(sprintf("Near-boundary reps (psi=-0.01, true BF > 0.95): %d\n",
            sum(full_set$psi == -0.01)))

# ---- helper: build the BA scatter + density stacked panel ----
mk_panels <- function(d, subtitle_extra){
  set.seed(7)
  # scatter subsample 60k for clarity
  ss <- d[sample(nrow(d), 60000), ]
  # point-cloud density subsample 80k
  ds <- d[sample(nrow(d), 80000), ]
  bias <- mean(d$diff); sd_ <- sd(d$diff)
  lo_l <- bias - 1.96*sd_; lo_u <- bias + 1.96*sd_

  # --- top: jittered scatter
  p_top <- ggplot(ss, aes(x = bf_true, y = diff, color = zone)) +
    geom_jitter(width = 0.045, height = 0.005,
                size = 0.55, alpha = 0.06, na.rm = TRUE) +
    geom_hline(yintercept = bias, color = "#1F1F1F", linewidth = 0.7) +
    geom_hline(yintercept = lo_l, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.85) +
    geom_hline(yintercept = lo_u, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.85) +
    annotate("label", x = Inf, y = lo_u, label = sprintf("+1.96 SD LoA = %.3f", lo_u),
             color = "#B83227", size = 3.6, fontface = "italic",
             hjust = 1.04, vjust = -0.6, fill = "white", linewidth = 0) +
    annotate("label", x = Inf, y = lo_l, label = sprintf("-1.96 SD LoA = %.3f", lo_l),
             color = "#B83227", size = 3.6, fontface = "italic",
             hjust = 1.04, vjust = 1.6, fill = "white", linewidth = 0) +
    annotate("label", x = Inf, y = bias,
             label = sprintf("overall mean bias = %.3f", bias),
             color = "#1F1F1F", size = 3.6, fontface = "italic",
             hjust = 1.04, vjust = -0.7, fill = "white", linewidth = 0) +
    scale_color_manual(values = zc) +
    labs(title = "Top. Jittered scatter (horizontally broadened)",
         subtitle = subtitle_extra,
         x = "True BF",
         y = "Estimated BF - True BF (MCMC)") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom", legend.title = element_blank(),
          plot.title = element_text(face = "bold"),
          panel.grid.minor = element_blank(),
          panel.background = element_rect(fill = "white", color = NA),
          plot.background  = element_rect(fill = "white", color = NA))

  # --- middle: 2D density on white
  dens_obj <- MASS::kde2d(d$bf_true, d$diff, h = c(0.04, 0.025), n = c(140, 140))
  df_dens  <- expand.grid(bf_true = dens_obj$x, diff = dens_obj$y)
  df_dens$z <- as.vector(dens_obj$z)
  pal <- colorRampPalette(c("white", scales::alpha("#FBE7B6", 0.85),
                            "#F7B267", "#E85D04", "#B83227", "#5B0F4A"))
  p_mid <- ggplot(df_dens, aes(x = bf_true, y = diff, fill = z)) +
    geom_raster() +
    scale_fill_gradientn(colours = pal(64), name = "density",
                         breaks = pretty(range(df_dens$z), 5),
                         labels = function(x) sprintf("%.2f", x)) +
    geom_contour(aes(z = z, fill = NULL), color = "white",
                 linewidth = 0.25, alpha = 0.45,
                 breaks = pretty(range(df_dens$z), 8)[-1]) +
    geom_hline(yintercept = bias, color = "#1F1F1F", linewidth = 0.7) +
    geom_hline(yintercept = lo_l, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.9) +
    geom_hline(yintercept = lo_u, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.9) +
    annotate("label", x = Inf, y = lo_u, label = sprintf("+1.96 SD LoA = %.3f", lo_u),
             color = "#B83227", size = 3.4, fontface = "italic",
             hjust = 1.05, vjust = -0.6, fill = "white", linewidth = 0) +
    annotate("label", x = Inf, y = lo_l, label = sprintf("-1.96 SD LoA = %.3f", lo_l),
             color = "#B83227", size = 3.4, fontface = "italic",
             hjust = 1.05, vjust = 1.6, fill = "white", linewidth = 0) +
    annotate("label", x = Inf, y = bias,
             label = sprintf("overall mean bias = %.3f", bias),
             color = "#1F1F1F", size = 3.4, fontface = "italic",
             hjust = 1.05, vjust = -0.7, fill = "white", linewidth = 0) +
    labs(title = "Middle. 2D density (warm ramp on white)",
         subtitle = sprintf("mass of %s reps; warm color = higher point concentration",
                            format(nrow(d), big.mark = ",")),
         x = "True BF",
         y = "Estimated BF - True BF (MCMC)") +
    coord_cartesian(xlim = range(d$bf_true) * c(0.96, 1.04),
                    ylim = range(d$diff) * c(1.08, 1.08),
                    expand = FALSE) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "right",
          plot.title = element_text(face = "bold"),
          panel.grid = element_blank(),
          panel.background = element_rect(fill = "white", color = NA),
          plot.background  = element_rect(fill = "white", color = NA),
          legend.background = element_rect(fill = "white", color = NA),
          legend.key        = element_rect(fill = "white", color = NA))

  list(top = p_top, mid = p_mid)
}

# ---- helper: render the parameter ribbon (compact table, NO header to avoid overlap) ----
fmt_p <- function(p) if (is.na(p)) "NA" else if (p < 0.001) "< 0.001" else sprintf("%.3f", p)
mk_param_ribbon <- function(st){
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
      "Prop. bias r (Pearson, diff vs true)",
      "Regression slope: diff ~ true BF",
      "  slope [95% CI]",
      "  slope t-stat, p-value",
      "  intercept",
      "  intercept t-stat, p-value"
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
      sprintf("%.3f", st$r_prop),
      sprintf("%.3f", st$reg_slope),
      sprintf("[%.3f, %.3f]", st$reg_slope_lo, st$reg_slope_hi),
      sprintf("t = %.1f, p %s", st$reg_slope_t, fmt_p(st$reg_slope_p)),
      sprintf("%.3f", st$reg_intercept),
      sprintf("t = %.1f, p %s", st$reg_int_t, fmt_p(st$reg_int_p))
    ),
    stringsAsFactors = FALSE
  )
  ttl <- textGrob("Bland-Altman agreement statistics",
                  gp = gpar(fontface = "bold.italic", fontsize = 13,
                            col = "#1F1F1F"))
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
  # attach the title row above the table
  tbl <- gtable::gtable_add_rows(tbl, heights = unit(0.55, "line"), pos = 0)
  tbl <- gtable::gtable_add_grob(tbl, ttl, t = 1, l = 1, r = ncol(tbl))
  wrap_elements(tbl) +
    theme(plot.background  = element_rect(fill = "white", color = NA),
          panel.background = element_rect(fill = "white", color = NA))
}

# ---- compute stats for both subsets (CI + regression significance included in mk_stats) ----
st_int  <- mk_stats(interior,  "interior (MCMC)")
st_full <- mk_stats(full_set,  "full (MCMC)")
cat("\n--- stats (with regression significance) ---\n")
print(st_int[, c("n","bias","sd_diff","in_pct","ccc","r_prop",
                 "reg_slope","reg_slope_t","reg_slope_p",
                 "reg_intercept","reg_int_t","reg_int_p")])
print(st_full[, c("n","bias","sd_diff","in_pct","ccc","r_prop",
                  "reg_slope","reg_slope_t","reg_slope_p",
                  "reg_intercept","reg_int_t","reg_int_p")])

# ---- build figure: figL (interior) ----
panels_int <- mk_panels(interior, "interior (excludes near-boundary psi=-0.01); one cloud per true-BF level")
ribbon_int <- mk_param_ribbon(st_int)
figL_new <- panels_int$top / panels_int$mid / ribbon_int +
  plot_layout(heights = c(3, 2.6, 2.2))
ggsave("output/figures/continuous_bf/figL_interior_ba_viz.png", figL_new,
       width = 9, height = 15, dpi = 150, bg = "white")

# ---- build figure: figM (full 640 conditions, includes BF=1) ----
panels_full <- mk_panels(full_set, "full design (640 conditions x 1000 reps, includes near-boundary psi=-0.01)")
ribbon_full <- mk_param_ribbon(st_full)
figM_new <- panels_full$top / panels_full$mid / ribbon_full +
  plot_layout(heights = c(3, 2.6, 2.2))
ggsave("output/figures/continuous_bf/figM_full_ba_viz.png", figM_new,
       width = 9, height = 15, dpi = 150, bg = "white")

cat("\nSaved:\n  output/figures/continuous_bf/figL_interior_ba_viz.png\n")
cat("  output/figures/continuous_bf/figM_full_ba_viz.png\n")
