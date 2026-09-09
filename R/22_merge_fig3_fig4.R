# 合并 Figure 3（经验零分布）与 Figure 4（BF 三区）为双面板图（A/B 纵向堆叠）
# 目的：腾出一个图表位给基线特征表（JAMA ≤5 tables/figures）
suppressMessages(library(magick))

fig_dir <- file.path("output", "figures")
out_dir <- file.path(fig_dir, "v38")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

a <- image_trim(image_read(file.path(fig_dir, "fig01_calibration_plot.png")))
b <- image_trim(image_read(file.path(fig_dir, "fig02_BF_main.png")))

W <- 2200
a <- image_resize(a, paste0(W, "x"))
b <- image_resize(b, paste0(W, "x"))

# 面板字母
lab <- function(im, txt) {
  image_annotate(im, txt, location = "+18+46", size = 66,
                 weight = 700, color = "black", font = "Helvetica")
}
a <- lab(a, "A"); b <- lab(b, "B")

gap   <- image_blank(width = W, height = 46, color = "white")
panel <- image_append(c(a, gap, b), stack = TRUE)
panel <- image_border(panel, "white", "20x20")

out <- file.path(out_dir, "fig3_null_bf_panels.png")
image_write(panel, out, density = 300)

info <- image_info(panel)
cat("WROTE:", out, "\n")
cat("dims :", info$width, "x", info$height, "\n")
cat("size :", round(file.size(out) / 1024, 1), "KB\n")
