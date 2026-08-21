# R/09_interior_ba_viz.R
# Redesigned interior Bland-Altman (exclude near-boundary psi=-0.01) for clinicians.
# Goal: kill the "vertical bar + big dot = 95% CI" illusion.
#   Left  : horizontal-jittered scatter (breaks vertical bars into clouds), colored by zone.
#           No per-condition mean dot; only overall bias line + thin LoA reference lines.
#   Right : 2D density rainbow (viridis) showing the mass distribution of (true BF, diff).
suppressMessages({ library(dplyr); library(ggplot2); library(patchwork) })
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
# interior: exclude the near-boundary psi=-0.01 level (highest true BF; the ceiling-effect driver)
sub <- df[df$psi != -0.01, ]
cat(sprintf("Interior reps (excl psi=0): %d per method\n", nrow(sub)))
cat("Distinct interior bf_true:", paste(sort(unique(round(sub$bf_true,3))), collapse=", "), "\n")

zc <- c("effect-dominated" = "#1B7A3A", "mixed" = "#D4A017", "bias-dominated" = "#B83227")
bias_mm <- mean(sub$est_mcmc - sub$bf_true); sd_mm <- sd(sub$est_mcmc - sub$bf_true)
lo_l <- bias_mm - 1.96*sd_mm; lo_u <- bias_mm + 1.96*sd_mm
cat(sprintf("MCMC interior: bias=%.3f sd=%.3f LoA=[%.3f,%.3f] r_prop=%.3f CCC=%.3f\n",
            bias_mm, sd_mm, lo_l, lo_u,
            cor(sub$bf_true, sub$est_mcmc - sub$bf_true),
            {mx=mean(sub$bf_true);my=mean(sub$est_mcmc);2*cov(sub$bf_true,sub$est_mcmc)/(var(sub$bf_true)+var(sub$est_mcmc)+(mx-my)^2)}))
# regression of diff on true BF -> significance of proportional bias & mean bias
fit_09 <- lm((est_mcmc - bf_true) ~ bf_true, data = sub)
s_09   <- summary(fit_09)
sl_p <- coef(s_09)[2,4]; ic_p <- coef(s_09)[1,4]
fmt_p <- function(p) if (p < 0.001) "< 0.001" else sprintf("%.3f", p)
cat(sprintf("Slope = %.3f (SE %.4f), t = %.1f, p %s\n",
            coef(fit_09)[2], coef(s_09)[2,2], coef(s_09)[2,3], fmt_p(sl_p)))
cat(sprintf("Intercept = %.3f (SE %.4f), t = %.1f, p %s\n",
            coef(fit_09)[1], coef(s_09)[1,2], coef(s_09)[1,3], fmt_p(ic_p)))

set.seed(7)
ss <- sub[sample(nrow(sub), 60000), ]   # subsample for scatter clarity
ss$y <- ss$est_mcmc - ss$bf_true

# ---- Left: jittered scatter (horizontal spread widened) ----
p_scatter <- ggplot(ss, aes(x = bf_true, y = y, color = zone)) +
  # wider width -> true-BF "columns" become continuous clouds, no more visible vertical bars
  geom_jitter(width = 0.055, height = 0.005, size = 0.55, alpha = 0.06, na.rm = TRUE) +
  geom_hline(yintercept = bias_mm, color = "#1F1F1F", linewidth = 0.7) +
  geom_hline(yintercept = lo_l, color = "#B83227", linetype = "dashed", linewidth = 0.55, alpha = 0.85) +
  geom_hline(yintercept = lo_u, color = "#B83227", linetype = "dashed", linewidth = 0.55, alpha = 0.85) +
  scale_color_manual(values = zc) +
  labs(title = "A. Jittered scatter (horizontal spread)",
       subtitle = "X jittered within each true-BF level; no per-condition mean dot",
       x = "True BF (interior, excludes near-boundary psi=-0.01)",
       y = "Estimated BF - True BF (MCMC)") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", legend.title = element_blank(),
        panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold")) +
  # Pretty reference labels: rounded white-filled boxes anchored to RIGHT side of plot,
  # offset just above/below each line so they don't sit on the cloud of points.
  annotate("label", x = 0.875, y = lo_u, label = "+1.96 SD LoA",
           color = "#B83227", size = 3.6, fontface = "italic", hjust = 1, vjust = -0.6,
           fill = "white", linewidth = 0) +
  annotate("label", x = 0.875, y = lo_l, label = "-1.96 SD LoA",
           color = "#B83227", size = 3.6, fontface = "italic", hjust = 1, vjust = 1.6,
           fill = "white", linewidth = 0) +
  annotate("label", x = 0.875, y = bias_mm, label = "overall mean bias",
           color = "#1F1F1F", size = 3.6, fontface = "italic", hjust = 1, vjust = -0.7,
           fill = "white", linewidth = 0)

# ---- Right: 2D density on WHITE background ----
# Use MASS::kde2d directly so the LOW-density canvas stays white (= density 0).
# Continuous viridis-style warm ramp: white -> amber -> magenta. No deep-blue outer bins.
dens_obj <- MASS::kde2d(sub$bf_true, sub$est_mcmc - sub$bf_true,
                        h = c(0.04, 0.025), n = c(140, 140))
df_dens  <- expand.grid(bf_true = dens_obj$x, diff = dens_obj$y)
df_dens$z <- as.vector(dens_obj$z)
# the white-to-magenta ramp approximates plasma without the deep-blue bottom
pal <- colorRampPalette(c("white", scales::alpha("#FBE7B6", 0.85),
                          "#F7B267", "#E85D04", "#B83227", "#5B0F4A"))

p_dens <- ggplot(df_dens, aes(x = bf_true, y = diff, fill = z)) +
  geom_raster() +
  scale_fill_gradientn(colours = pal(64), name = "density",
                       breaks = pretty(range(df_dens$z), 5),
                       labels = function(x) sprintf("%.2f", x)) +
  geom_contour(aes(z = z, fill = NULL), color = "white", linewidth = 0.25, alpha = 0.45,
               breaks = pretty(range(df_dens$z), 8)[-1]) +
  geom_hline(yintercept = bias_mm, color = "#1F1F1F", linewidth = 0.7) +
  geom_hline(yintercept = lo_l, color = "#B83227", linetype = "dashed", linewidth = 0.55, alpha = 0.9) +
  geom_hline(yintercept = lo_u, color = "#B83227", linetype = "dashed", linewidth = 0.55, alpha = 0.9) +
  labs(title = "B. 2D density (warm ramp on white)",
       subtitle = "mass of 288,000 reps; warm color = higher point concentration",
       x = "True BF (interior, excludes near-boundary psi=-0.01)",
       y = "Estimated BF - True BF (MCMC)") +
  coord_cartesian(xlim = range(sub$bf_true) * c(0.97, 1.03),
                  ylim = range(sub$est_mcmc - sub$bf_true) * c(1.05, 1.05),
                  expand = FALSE) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "right", panel.grid = element_blank(),
        plot.title = element_text(face = "bold"),
        panel.background = element_rect(fill = "white", color = NA),
        plot.background  = element_rect(fill = "white", color = NA),
        legend.background = element_rect(fill = "white", color = NA),
        legend.key        = element_rect(fill = "white", color = NA)) +
  annotate("label", x = Inf, y = lo_u, label = "+1.96 SD LoA",
           color = "#B83227", size = 3.6, fontface = "italic", hjust = 1.05, vjust = -0.6,
           fill = "white", linewidth = 0) +
  annotate("label", x = Inf, y = lo_l, label = "-1.96 SD LoA",
           color = "#B83227", size = 3.6, fontface = "italic", hjust = 1.05, vjust = 1.6,
           fill = "white", linewidth = 0) +
  annotate("label", x = Inf, y = bias_mm, label = "overall mean bias",
           color = "#1F1F1F", size = 3.6, fontface = "italic", hjust = 1.05, vjust = -0.7,
           fill = "white", linewidth = 0)

cap_09 <- sprintf(
  "Regression (diff ~ true BF, interior): slope = %.3f (t = %.1f, p %s); intercept = %.3f (t = %.1f, p %s). Slope p < 0.05 => significant proportional bias.",
  coef(fit_09)[2], coef(s_09)[2,3], fmt_p(sl_p),
  coef(fit_09)[1], coef(s_09)[1,3], fmt_p(ic_p))
fig <- p_scatter + p_dens + plot_layout(widths = c(1, 1.05)) +
  plot_annotation(caption = cap_09, theme = theme(plot.caption = element_text(size = 9, hjust = 0)))
# NOTE: canonical interior figure with the full agreement table is output/figures/continuous_bf/figL_interior_ba_viz.png (from R/10).
# This legacy horizontal layout is saved under a distinct name to avoid clobbering it.
ggsave("output/figures/continuous_bf/figL_interior_ba_viz_S9.png", fig,
       width = 12, height = 5.6, dpi = 140, bg = "white")
cat("Saved figL_interior_ba_viz_S9.png (legacy horizontal interior; significance in caption)\n")
