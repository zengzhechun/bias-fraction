suppressMessages({
  BASE_DIR <- "/Users/zengzhechun/SynologyDrive/工作/数据分析项目/心电图大模型/心电图公开数据集/02 mimic-iv-ecg/Topic1_LTMLE_Betablocker"
  SIM_DIR <- file.path(BASE_DIR, "manuscript_v35", "output", "simulation")
  ci_sim <- readRDS(file.path(SIM_DIR, "ci_simulation_merged.rds"))
})
rp <- ci_sim$reps
# r_pt = estimated BER (bias-effect ratio, unbounded); true_class = ground-truth zone.
# Classify on BER scale given BF thresholds (cut1 effect, cut2 bias):
#   BF<cut1 <=> BER < cut1/(1-cut1);  BF>cut2 <=> BER > cut2/(1-cut2)
classify <- function(ber, eff_ber, bias_ber) {
  ifelse(is.na(ber), "unclassifiable",
  ifelse(ber > bias_ber, "bias-dominated",
  ifelse(ber < eff_ber, "effect-dominated", "competitive")))
}
sweep_grid <- expand.grid(
  cut1 = c(0.20, 0.25, 0.30, 1/3, 0.35, 0.40, 0.45),
  cut2 = c(0.50, 0.55, 0.60, 0.65)
)
results <- data.frame()
for (i in seq_len(nrow(sweep_grid))) {
  c1 <- sweep_grid$cut1[i]; c2 <- sweep_grid$cut2[i]
  eff_ber <- c1/(1-c1); bias_ber <- c2/(1-c2)
  pred <- classify(rp$r_pt, eff_ber, bias_ber)
  overall <- mean(pred == rp$true_class)
  acc_bias <- mean(pred[rp$true_class == "bias-dominated"]   == "bias-dominated")
  acc_comp <- mean(pred[rp$true_class == "competitive"]      == "competitive")
  acc_eff  <- mean(pred[rp$true_class == "effect-dominated"] == "effect-dominated")
  decisive <- mean(pred != "competitive")
  cov_bias <- mean(pred == "bias-dominated")
  cov_comp <- mean(pred == "competitive")
  cov_eff  <- mean(pred == "effect-dominated")
  results <- rbind(results, data.frame(
    cut1 = round(c1,3), cut2 = round(c2,3),
    eff_ber = round(eff_ber,3), bias_ber = round(bias_ber,3),
    overall_acc = round(100*overall,1),
    bias_acc    = round(100*acc_bias,1),
    comp_acc    = round(100*acc_comp,1),
    eff_acc     = round(100*acc_eff,1),
    decisive_rate = round(100*decisive,1),
    cov_bias = round(100*cov_bias,1),
    cov_comp = round(100*cov_comp,1),
    cov_eff  = round(100*cov_eff,1)))
}
cat("=== SWEEP RESULTS (point-estimate rule, BER thresholds derived from BF cuts) ===\n")
print(results, row.names = FALSE)

# --- Validation: default thresholds should reproduce published 69.8 / 80.0 / 41.8 / 95.1 ---
def <- classify(rp$r_pt, (1/3)/(1-1/3), 0.5/(1-0.5))
cat("\n=== DEFAULT (cut1=1/3, cut2=0.5) validation ===\n")
cat(sprintf("overall=%.1f  bias=%.1f  competitive=%.1f  effect=%.1f  decisive_rate=%.1f\n",
  100*mean(def==rp$true_class),
  100*mean(def[rp$true_class=="bias-dominated"]=="bias-dominated"),
  100*mean(def[rp$true_class=="competitive"]=="competitive"),
  100*mean(def[rp$true_class=="effect-dominated"]=="effect-dominated"),
  100*mean(def!="competitive")))

write.csv(results, "/tmp/threshold_sweep_results.csv", row.names = FALSE)

# --- Figure 1: heatmap of overall accuracy across (cut1 x cut2) ---
png("/tmp/fig_sweep_heatmap.png", width = 720, height = 560, res = 110)
cut1v <- sort(unique(results$cut1)); cut2v <- sort(unique(results$cut2))
mat <- matrix(results$overall_acc, nrow = length(cut1v), ncol = length(cut2v),
              byrow = TRUE, dimnames = list(cut1v, cut2v))
pal <- colorRampPalette(c("#F2C9C9","#FBF0D6","#CFE3CF"))(100)
image(cut1v, cut2v, mat, col = pal, xlab = "Effect threshold (BF < cut1 = effect-dominated)",
      ylab = "Bias threshold (BF > cut2 = bias-dominated)",
      main = "Overall point-estimate classification accuracy (%) across zone boundaries",
      axes = FALSE, zlim = c(min(mat)-2, max(mat)+2))
axis(1, at = cut1v, labels = sprintf("%.2f", cut1v)); axis(2, at = cut2v, labels = sprintf("%.2f", cut2v))
box()
for (i in seq_along(cut1v)) for (j in seq_along(cut2v))
  text(cut1v[i], cut2v[j], sprintf("%.1f", mat[i,j]), cex = 0.85, col = "#333333")
dev.off()

# --- Figure 2: coverage vs accuracy tradeoff (two panels) ---
png("/tmp/fig_sweep_tradeoff.png", width = 820, height = 420, res = 110)
par(mfrow = c(1,2), mar = c(4.2,4.2,3.2,1.2))
sub_eff <- results[results$cut2 == 0.50, ]
plot(sub_eff$cut1, sub_eff$eff_acc, type="b", col="#5A7A5A", lwd=2, ylim=c(0,100),
     xlab="Effect BF threshold (cut1)", ylab="%", main="Effect-dominated zone: accuracy vs coverage")
lines(sub_eff$cut1, sub_eff$cov_eff, type="b", col="#B8A060", lwd=2, lty=2)
legend("bottomleft", c("accuracy","coverage"), col=c("#5A7A5A","#B8A060"), lty=c(1,2), lwd=2, cex=0.8)
sub_bias <- results[results$cut1 == 1/3, ]
plot(sub_bias$cut2, sub_bias$bias_acc, type="b", col="#8B4A4A", lwd=2, ylim=c(0,100),
     xlab="Bias BF threshold (cut2)", ylab="%", main="Bias-dominated zone: accuracy vs coverage")
lines(sub_bias$cut2, sub_bias$cov_bias, type="b", col="#B8A060", lwd=2, lty=2)
legend("bottomright", c("accuracy","coverage"), col=c("#8B4A4A","#B8A060"), lty=c(1,2), lwd=2, cex=0.8)
dev.off()
cat("\nFigures written: /tmp/fig_sweep_heatmap.png, /tmp/fig_sweep_tradeoff.png\n")
