#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(ggplot2)
  library(rdrobust)
})
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value=TRUE)[1]))
docs <- dirname(dirname(script))
source(file.path(docs, "labs/data/load-data.R"))
data_dir <- file.path(docs, "labs/data")
assets <- file.path(docs, "slides/assets")
theme_set(theme_minimal(base_size=16) +
  theme(legend.position="bottom", panel.grid.minor=element_blank()))
save_plot <- function(p, filename) {
  ggsave(file.path(assets, filename), p, width=11, height=5.6, dpi=160, bg="white")
}
gt <- as.data.frame(qed_data("gov_transfers", directory=data_dir))
gt$side <- factor(ifelse(gt$Income_Centered < 0, "Eligible", "Ineligible"))
gt$bin <- cut(gt$Income_Centered, seq(-0.02,0.02,by=0.001), include.lowest=TRUE)
bins <- aggregate(cbind(Income_Centered, Participation, Support) ~ bin + side, gt, mean)
palette <- c(Eligible="#177b72", Ineligible="#245ca4")
save_plot(ggplot(bins, aes(Income_Centered, Participation, color=side)) +
  geom_point(size=3) + geom_vline(xintercept=0, linetype=2) +
  scale_color_manual(values=palette) +
  labs(x="Centered assignment score", y="Programme participation", color=NULL),
  "rdd-assignment.png")
local <- subset(gt, abs(Income_Centered) < 0.01)
local$weight <- 1-abs(local$Income_Centered)/0.01
fit <- lm(Support ~ side*Income_Centered, local, weights=weight)
grid <- data.frame(Income_Centered=c(seq(-0.01,0,length.out=100),
                                    seq(0,0.01,length.out=100)),
                   side=rep(c("Eligible", "Ineligible"), each=100))
grid$Support <- predict(fit, grid)
save_plot(ggplot(bins, aes(Income_Centered, Support, color=side)) +
  geom_point(size=2.5) + geom_line(data=grid, linewidth=1) +
  geom_vline(xintercept=0, linetype=2) + scale_color_manual(values=palette) +
  labs(x="Centered assignment score", y="Mean government-support score", color=NULL),
  "rdd-local-lines.png")
rows <- do.call(rbind, lapply(c(0.005,0.01,0.015,0.02), function(h) {
  f <- rdrobust(gt$Support, gt$Income_Centered, c=0, p=1, q=2,
    h=h, b=h, kernel="triangular", vce="hc0", masspoints="adjust",
    stdvars=TRUE, bwselect="mserd", bwrestrict=TRUE, scaleregul=1)
  data.frame(h=factor(h), conventional=-f$coef[1,1], corrected=-f$coef[3,1],
    lower=-f$ci[3,2], upper=-f$ci[3,1])
}))
save_plot(ggplot(rows, aes(h, corrected)) +
  geom_hline(yintercept=0, linetype=2, color="grey60") +
  geom_errorbar(aes(ymin=lower, ymax=upper), width=0.12, color="#177b72") +
  geom_point(aes(color="Bias-corrected"), size=3) +
  geom_point(aes(y=conventional, color="Conventional"), shape=17, size=3) +
  scale_color_manual(values=c("Bias-corrected"="#177b72", Conventional="#245ca4")) +
  labs(x="Fixed estimation and bias bandwidth", y="Programme effect (support-score units)",
       color=NULL), "rdd-bandwidths.png")
raw <- as.data.frame(qed_data("mortgages", directory=data_dir))
v <- subset(raw, !is.na(qob_minus_kw) & !is.na(vet_wwko) &
                   !is.na(home_ownership) & abs(qob_minus_kw) < 12)
means <- aggregate(cbind(vet_wwko, home_ownership) ~ qob_minus_kw, v, mean)
long <- rbind(data.frame(score=means$qob_minus_kw, value=means$vet_wwko,
                         outcome="Veteran status"),
              data.frame(score=means$qob_minus_kw, value=means$home_ownership,
                         outcome="Homeownership"))
save_plot(ggplot(long, aes(score, value)) +
  geom_point(size=2.5, color="#245ca4") +
  geom_vline(xintercept=0, linetype=2) + facet_wrap(~outcome, scales="free_y") +
  labs(x="Birth-quarter score", y="Observed proportion"), "rdd-fuzzy.png")
message("Generated four RDD figures from bundled snapshots.")
