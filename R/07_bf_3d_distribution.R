# R/07_bf_3d_distribution.R
# Interactive 3D distribution of BF estimation error.
#   X = |true systematic bias|  |mu_B|            (BF numerator)
#   Y = |mu_B + psi|  (absolute observed log-RR)  (BF denominator = "systematic error + true effect")
#   Z = error metric, selectable via dropdown:
#         (1) |BF_hat - BF_true|   (absolute error, per replicate cloud)
#         (2) (BF_hat - BF_true)^2 (MSE, per replicate cloud)
#         (3) RMSE (per condition, markers)
# Methods: Monte Carlo (MC) and MCMC.
# Axes meet at the absolute-value origin corner (camera oriented so (0,0) is front).
# Output: self-contained HTML (Plotly inlined) -> output/figures/continuous_bf/figJ_3d_bf_error.html
suppressPackageStartupMessages({
  library(plotly); library(htmlwidgets); library(dplyr)
})

OUT_SIM <- "output/simulation"
OUT_FIG <- "output/figures/continuous_bf"
if (!dir.exists(OUT_FIG)) dir.create(OUT_FIG, recursive = TRUE)

cat("Loading", file.path(OUT_SIM, "comparison_results_v37p1.rds"), "\n")
res <- readRDS(file.path(OUT_SIM, "comparison_results_v37p1.rds"))
cat("conditions:", length(res), "\n")

# ---- build per-replicate long table ----
rows <- lapply(res, function(r) {
  df <- r$results
  data.frame(
    psi   = r$config$true_log_rr,
    mu_b  = r$config$bias_mu,
    K     = r$config$n_nc,
    exV   = r$config$ex_violation,
    sps   = r$config$se_psi_obs,
    bf_true = r$bf_true,
    true_zone = r$true_zone,
    bf_mc   = df$bf_mc,
    bf_mcmc = df$bf_mcmc
  )
})
d <- bind_rows(rows)
cat("total replicates:", nrow(d), "\n")

# user-requested axes (absolute magnitudes)
d$absX <- abs(d$mu_b)                 # BF numerator  = |systematic bias|
d$absY <- abs(d$mu_b + d$psi)        # BF denominator = |systematic error + true effect| (observed log-RR)
d$err_abs_mc   <- abs(d$bf_mc   - d$bf_true)
d$err_abs_mcmc <- abs(d$bf_mcmc - d$bf_true)
d$err_sq_mc    <- (d$bf_mc   - d$bf_true)^2
d$err_sq_mcmc  <- (d$bf_mcmc - d$bf_true)^2

# per-condition RMSE
cond <- d %>% group_by(psi, mu_b, K, exV, sps, true_zone, bf_true, absX, absY) %>%
  summarise(rmse_mc   = sqrt(mean(err_sq_mc)),
            rmse_mcmc = sqrt(mean(err_sq_mcmc)), .groups = "drop")
cat("per-condition rows:", nrow(cond), "\n")

# downsample clouds (memory / file size control); statistics use full data elsewhere
set.seed(7)
n_samp <- min(4500, nrow(d))
samp_mc    <- d[sample(nrow(d), n_samp), ]
samp_mcmc  <- d[sample(nrow(d), n_samp), ]

zone_colors <- c("effect-dominated" = "#1B7A3A",
                 "mixed"            = "#D4A017",
                 "bias-dominated"   = "#B83227")

# ---- traces ----
# 0: MC cloud (absolute error default)
# 1: MCMC cloud
# 2: MC per-condition RMSE markers (hidden by default)
# 3: MCMC per-condition RMSE markers (hidden by default)
p <- plot_ly() %>%
  add_trace(data = samp_mc, x = ~absX, y = ~absY, z = ~err_abs_mc,
            type = "scatter3d", mode = "markers",
            name = "Monte Carlo  |error|",
            visible = TRUE,
            marker = list(size = 4.2, opacity = 0.5, color = "#1F5AA8"),
            hovertemplate = "X=|mu_B|=%{x:.3f}<br>Y=|mu_B+psi|=%{y:.3f}<br>|err|MC=%{z:.3f}<extra>MC</extra>") %>%
  add_trace(data = samp_mcmc, x = ~absX, y = ~absY, z = ~err_abs_mcmc,
            type = "scatter3d", mode = "markers",
            name = "MCMC  |error|",
            visible = TRUE,
            marker = list(size = 4.2, opacity = 0.5, color = "#E85D04"),
            hovertemplate = "X=|mu_B|=%{x:.3f}<br>Y=|mu_B+psi|=%{y:.3f}<br>|err|MCMC=%{z:.3f}<extra>MCMC</extra>") %>%
  add_trace(data = cond, x = ~absX, y = ~absY, z = ~rmse_mc,
            type = "scatter3d", mode = "markers",
            name = "Monte Carlo  RMSE (per condition)",
            visible = FALSE,
            marker = list(size = 13, symbol = "diamond", opacity = 1,
                          color = ~true_zone, colors = zone_colors,
                          line = list(color = "#111111", width = 1.5)),
            hovertemplate = "X=|mu_B|=%{x:.3f}<br>Y=|mu_B+psi|=%{y:.3f}<br>RMSE MC=%{z:.3f}<br>zone=%{marker.color}<extra>MC RMSE</extra>") %>%
  add_trace(data = cond, x = ~absX, y = ~absY, z = ~rmse_mcmc,
            type = "scatter3d", mode = "markers",
            name = "MCMC  RMSE (per condition)",
            visible = FALSE,
            marker = list(size = 11, symbol = "circle", opacity = 1,
                          color = ~true_zone, colors = zone_colors,
                          line = list(color = "#111111", width = 1.5)),
            hovertemplate = "X=|mu_B|=%{x:.3f}<br>Y=|mu_B+psi|=%{y:.3f}<br>RMSE MCMC=%{z:.3f}<br>zone=%{marker.color}<extra>MCMC RMSE</extra>")

# ---- dropdown to switch error metric on Z ----
# restyle z for traces 0,1 (clouds) between absolute / squared error;
# toggle visibility of clouds (0,1) vs per-condition markers (2,3).
btn_abs <- list(
  method = "restyle",
  args = list(list(
    z = list(samp_mc$err_abs_mc, samp_mcmc$err_abs_mcmc),
    visible = list(TRUE, TRUE, FALSE, FALSE),
    "scene.zaxis.title" = list(text = "Z = |BF_hat - BF_true|  (absolute error)")
  ), c(0, 1, 2, 3)),
  label = "|error| (absolute)")

btn_mse <- list(
  method = "restyle",
  args = list(list(
    z = list(samp_mc$err_sq_mc, samp_mcmc$err_sq_mcmc),
    visible = list(TRUE, TRUE, FALSE, FALSE),
    "scene.zaxis.title" = list(text = "Z = (BF_hat - BF_true)^2  (MSE)")
  ), c(0, 1, 2, 3)),
  label = "MSE (squared)")

btn_rmse <- list(
  method = "restyle",
  args = list(list(
    visible = list(FALSE, FALSE, TRUE, TRUE),
    "scene.zaxis.title" = list(text = "Z = RMSE  (per condition)")
  ), c(0, 1, 2, 3)),
  label = "RMSE (per condition)")

p <- p %>% layout(
  title = list(
    text = "3D distribution of BF estimation error: X = |systematic bias| (BF numerator), Y = |mu_B + psi| (BF denominator), Z = error metric (select below)",
    font = list(size = 14, family = "Arial Black")),
  scene = list(
    xaxis = list(title = "X = |true systematic bias|  |mu_B|  (BF numerator)",
                 zeroline = TRUE, zerolinecolor = "#222222", zerolinewidth = 2,
                 showgrid = TRUE, gridcolor = "#888888",
                 color = "#222222", titlefont = list(size = 13), tickfont = list(size = 11)),
    yaxis = list(title = "Y = |mu_B + psi|  observed log-RR (BF denominator)",
                 zeroline = TRUE, zerolinecolor = "#222222", zerolinewidth = 2,
                 showgrid = TRUE, gridcolor = "#888888",
                 color = "#222222", titlefont = list(size = 13), tickfont = list(size = 11)),
    zaxis = list(title = "Z = |BF_hat - BF_true|  (absolute error)",
                 showgrid = TRUE, gridcolor = "#888888",
                 color = "#222222", titlefont = list(size = 13), tickfont = list(size = 11)),
    # camera oriented so the (0,0) absolute-value corner is toward the viewer
    camera = list(eye = list(x = -1.7, y = -1.7, z = 1.05)),
    bgcolor = "#f7f7f7"
  ),
  legend = list(orientation = "h", y = -0.04, font = list(size = 12)),
  margin = list(l = 0, r = 0, t = 60, b = 0),
  updatemenus = list(list(
    buttons = list(btn_abs, btn_mse, btn_rmse),
    direction = "down",
    x = 0.02, y = 1.0, xanchor = "left", yanchor = "top",
    bgcolor = "#eeeeee", bordercolor = "#888888", font = list(size = 12)
  ))
)

out_html <- file.path(OUT_FIG, "figJ_3d_bf_error.html")
htmlwidgets::saveWidget(p, out_html, selfcontained = TRUE,
                        title = "BF error 3D distribution")
cat("Saved", out_html, "\n")
cat(sprintf("X range |mu_B|: [%.3f, %.3f]\n", min(d$absX), max(d$absX)))
cat(sprintf("Y range |mu_B+psi|: [%.3f, %.3f]\n", min(d$absY), max(d$absY)))
cat(sprintf("overall mean |error| MC=%.3f MCMC=%.3f\n",
            mean(d$err_abs_mc), mean(d$err_abs_mcmc)))
cat(sprintf("overall RMSE MC=%.3f MCMC=%.3f\n",
            sqrt(mean(d$err_sq_mc)), sqrt(mean(d$err_sq_mcmc))))
