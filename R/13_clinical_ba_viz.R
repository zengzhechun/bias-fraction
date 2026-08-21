## Clinical-style Bland-Altman plot v4: X = CONDITION-MEAN predicted BF (one X per psi x mu_B),
## Y = per-rep (BF̂ − BF_true) -> vertical stripes at each condition (classic BA look, predicted-BF grouping)
## Same layout as figL/figM (jittered scatter + 2D density + agreement ribbon) but
## x-axis swapped to BF̂ itself rather than BF_true. This is the clinician's view:
## "given the BF your model hands back, what's the error range you'd expect?"

suppressMessages({
  library(dplyr); library(ggplot2); library(patchwork)
  library(grid); library(gridExtra)
})

BASE <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker/manuscript_v37"
RDS  <- file.path(BASE, "output/simulation/comparison_results_v37p1.rds")
OUT_DIR <- file.path(BASE, "output/figures/continuous_bf")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ---- long-format per-rep data ----
r <- readRDS(RDS); keys <- names(r)
rows <- lapply(keys, function(k){
  cond <- r[[k]]
  data.frame(
    cond_key  = k,
    psi       = cond$config$true_log_rr,
    mu_b      = cond$config$bias_mu,
    bf_true   = cond$bf_true,
    zone      = cond$true_zone,
    bf_mcmc   = cond$results$bf_mcmc,
    bf_mc     = cond$results$bf_mc
  )
})
df <- do.call(rbind, rows)
df$diff_mcmc <- df$bf_mcmc - df$bf_true
df$cond_mean_bf <- ave(df$bf_mcmc, df$cond_key)  # 每个 psi x mu_B 条件的条件均值 BF̂（一个 X 值，Y 为该条件 1000 个重复）
df$zone <- factor(df$zone, levels = c("effect-dominated", "mixed", "bias-dominated"))
zc <- c("effect-dominated" = "#1B7A3A", "mixed" = "#D4A017", "bias-dominated" = "#B83227")

interior <- df %>% filter(psi != -0.01)
full_set <- df
cat(sprintf("Clinical BA: interior reps = %d, full reps = %d\n",
            nrow(interior), nrow(full_set)))

# ---- helper: BA stats (LM diff ~ x_var; same as R/10) ----
mk_stats <- function(d, x_var, label){
  x <- d[[x_var]]
  y <- d$diff_mcmc
  n <- length(y)
  b <- mean(y); s <- sd(y)
  lo_l <- b - 1.96*s; lo_u <- b + 1.96*s
  inside  <- sum(y >= lo_l & y <= lo_u)
  in_pct  <- 100 * inside / n
  fit  <- lm(y ~ x)
  ci   <- confint(fit)
  sfit <- summary(fit)
  data.frame(
    label = label, n = n,
    bias = b, sd_diff = s, loa_lo = lo_l, loa_hi = lo_u,
    in_pct = in_pct,
    ccc = { mx <- mean(x); my <- mean(d$bf_mcmc); 2*cov(x, d$bf_mcmc) /
            (var(x) + var(d$bf_mcmc) + (mx - my)^2) },
    r_prop = cor(x, y),
    reg_slope = coef(fit)[2], reg_slope_lo = ci[2,1], reg_slope_hi = ci[2,2],
    reg_slope_se = coef(sfit)[2,2], reg_slope_t = coef(sfit)[2,3], reg_slope_p = coef(sfit)[2,4],
    reg_intercept = coef(fit)[1], reg_int_se = coef(sfit)[1,2],
    reg_int_t = coef(sfit)[1,3], reg_int_p = coef(sfit)[1,4]
  )
}

# ---- helper: top jittered scatter + middle 2D density ----
mk_panels_pred <- function(d, x_var, subtitle_extra){
  set.seed(7)
  ss <- d[sample(nrow(d), 60000), ]
  ds <- d[sample(nrow(d), 80000), ]
  x <- d[[x_var]]
  y <- d$diff_mcmc
  bias <- mean(y); sd_ <- sd(y)
  lo_l <- bias - 1.96*sd_; lo_u <- bias + 1.96*sd_

  p_top <- ggplot(ss, aes(x = .data[[x_var]], y = diff_mcmc, color = zone)) +
    geom_jitter(width = if (x_var == "cond_mean_bf") 0.004 else if (x_var == "bf_true") 0.045 else 0.025,
                height = 0.005, size = 0.55, alpha = 0.06, na.rm = TRUE) +
    geom_hline(yintercept = bias,  color = "#1F1F1F", linewidth = 0.7) +
    geom_hline(yintercept = lo_l, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.85) +
    geom_hline(yintercept = lo_u, color = "#B83227",
               linetype = "dashed", linewidth = 0.55, alpha = 0.85) +
    scale_color_manual(values = zc) +
    labs(title = "Top. Jittered scatter (horizontally broadened)",
         subtitle = subtitle_extra,
         x = paste0("Condition-mean Predicted BF (BF̂)"),
         y = "Estimated BF (BF̂) − True BF (BF_true)") +
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
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom", legend.title = element_blank(),
          plot.title = element_text(face = "bold"),
          panel.grid.minor = element_blank(),
          panel.background = element_rect(fill = "white", color = NA),
          plot.background  = element_rect(fill = "white", color = NA))

  dens_obj <- MASS::kde2d(x, y, h = c(0.04, 0.025), n = c(140, 140))
  df_dens  <- expand.grid(bf_pred = dens_obj$x, diff = dens_obj$y)
  df_dens$z <- as.vector(dens_obj$z)
  pal <- colorRampPalette(c("white", scales::alpha("#FBE7B6", 0.85),
                            "#F7B267", "#E85D04", "#B83227", "#5B0F4A"))
  p_mid <- ggplot(df_dens, aes(x = bf_pred, y = diff, fill = z)) +
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
         x = "Condition-mean Predicted BF (BF̂)",
         y = "Estimated BF (BF̂) − True BF (BF_true)") +
    coord_cartesian(xlim = range(x) * c(0.97, 1.03),
                    ylim = range(y) * c(1.08, 1.08),
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

# ---- agreement parameter ribbon (same as R/10 but for predicted BF x-axis) ----
fmt_p <- function(p) if (is.na(p)) "NA" else if (p < 0.001) "< 0.001" else sprintf("%.3f", p)
mk_param_ribbon <- function(st){
  rows <- data.frame(
    Quantity = c(
      "x-axis",
      "n (reps)",
      "Overall mean bias",
      "SD(diff)",
      "LoA (lower, upper)",
      "Within LoA",
      "  (inside count / total)",
      "Outside LoA (reps)",
      "Lin's CCC (true vs BF̂)",
      "Prop. r (diff vs BF̂)",
      "Regression slope: diff ~ cond-mean BF̂",
      "  slope [95% CI]",
      "  slope t-stat, p-value",
      "  intercept",
      "  intercept t-stat, p-value"
    ),
    Value = c(
      "Condition-mean Predicted BF (BF̂)",
      format(st$n, big.mark = ","),
      sprintf("%.3f", st$bias),
      sprintf("%.3f", st$sd_diff),
      sprintf("[%.3f, %.3f]", st$loa_lo, st$loa_hi),
      sprintf("%.1f%%", st$in_pct),
      sprintf("%s / %s",
              format(st$n - round(st$n * (1 - st$in_pct/100)), big.mark = ","),
              format(st$n, big.mark = ",")),
      format(round(st$n * (1 - st$in_pct/100)), big.mark = ","),
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
  ttl <- textGrob("Clinical-view BA agreement statistics  ·  x = cond-mean BF̂",
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
  tbl <- gtable::gtable_add_rows(tbl, heights = unit(0.55, "line"), pos = 0)
  tbl <- gtable::gtable_add_grob(tbl, ttl, t = 1, l = 1, r = ncol(tbl))
  wrap_elements(tbl) +
    theme(plot.background  = element_rect(fill = "white", color = NA),
          panel.background = element_rect(fill = "white", color = NA))
}

# ---- compute stats & build two figures ----
st_int  <- mk_stats(interior,  "cond_mean_bf", "interior, condition-mean-BF view")
st_full <- mk_stats(full_set,  "cond_mean_bf", "full, condition-mean-BF view")
cat("\n--- stats (interior, predicted BF) ---\n")
print(st_int[, c("n","bias","sd_diff","in_pct","ccc","r_prop",
                 "reg_slope","reg_slope_t","reg_slope_p",
                 "reg_intercept","reg_int_t","reg_int_p")])
cat("\n--- stats (full, predicted BF) ---\n")
print(st_full[, c("n","bias","sd_diff","in_pct","ccc","r_prop",
                  "reg_slope","reg_slope_t","reg_slope_p",
                  "reg_intercept","reg_int_t","reg_int_p")])

panels_int  <- mk_panels_pred(interior, "cond_mean_bf",
                              "interior (excl near-boundary psi=-0.01); x = condition-mean Predicted BF")
panels_full <- mk_panels_pred(full_set, "cond_mean_bf",
                              "full design (640 conditions x 1000 reps); x = condition-mean Predicted BF")
ribbon_int  <- mk_param_ribbon(st_int)
ribbon_full <- mk_param_ribbon(st_full)

figN_pred_int  <- panels_int$top  / panels_int$mid  / ribbon_int  +
  plot_layout(heights = c(3, 2.6, 2.4))
figN_pred_full <- panels_full$top / panels_full$mid / ribbon_full +
  plot_layout(heights = c(3, 2.6, 2.4))

ggsave(file.path(OUT_DIR, "figN_clinical_ba.png"),
       figN_pred_int, width = 9, height = 14, dpi = 150, bg = "white")
ggsave(file.path(OUT_DIR, "figN_clinical_ba_predicted_full.png"),
       figN_pred_full, width = 9, height = 14, dpi = 150, bg = "white")
cat("\nSaved:\n")
cat("  output/figures/continuous_bf/figN_clinical_ba.png",
    sprintf("(%d KB)\n",
            file.info(file.path(OUT_DIR, "figN_clinical_ba.png"))$size %/% 1024))
cat("  output/figures/continuous_bf/figN_clinical_ba_predicted_full.png\n")
