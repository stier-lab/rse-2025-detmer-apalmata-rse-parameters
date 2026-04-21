################################################################################
# 61_fig_biological_realism.R - FigS29 biological realism scenario comparison
################################################################################
#
# PURPOSE:
#   Produce FigS29 — the 3-panel figure for the biological-realism scenario
#   framework. Inputs: biological_realism_scenarios.csv (from script 60).
#
# PANELS:
#   (a) Tornado: Δλ vs baseline per scenario (horizontal bars)
#   (b) Sexual vs asexual replacement share across scenarios (stacked bar)
#   (c) 50-yr trajectory: representative scenarios (S0, S1, S4, S7, S8)
#
# OUTPUTS:
#   - 06_analysis/figures/supplementary/FigS29_biological_realism.png + .pdf
#
# Author: Detmer & Stier Lab
# Date: 2026-04-18
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

print_header("Script 61: FigS29 biological realism figure")

# --- Load inputs ---
summary_tab <- read.csv("06_analysis/output/biological_realism_scenarios.csv",
                         stringsAsFactors = FALSE)
scenario_rds <- readRDS("06_analysis/output/biological_realism_scenarios.rds")

# Preserve scenario order
summary_tab$scenario <- factor(summary_tab$scenario,
                               levels = paste0("S", 0:8))
summary_tab$label_display <- sprintf("%s: %s",
                                      as.character(summary_tab$scenario),
                                      summary_tab$label)

# --- Panel (a): tornado plot of Δλ ---
tornado_data <- summary_tab %>%
  filter(scenario != "S0") %>%
  mutate(direction = ifelse(delta_lambda >= 0, "increase", "decrease"))

p_a <- ggplot(tornado_data,
              aes(x = reorder(label_display, delta_lambda),
                  y = delta_lambda,
                  fill = direction)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey30") +
  geom_text(aes(label = sprintf("%+.3f", delta_lambda),
                hjust = ifelse(delta_lambda >= 0, -0.1, 1.1)),
            size = 2.8) +
  coord_flip(ylim = c(-0.22, 0.22)) +
  scale_y_continuous(breaks = seq(-0.2, 0.2, 0.1),
                     labels = sprintf("%+.2f", seq(-0.2, 0.2, 0.1))) +
  scale_fill_manual(values = c(increase = "#2C7FB8", decrease = "#E66101")) +
  labs(x = NULL,
       y = expression(paste(Delta, lambda, " vs baseline (S0)")),
       title = "a. Scenario sensitivity") +
  theme_manuscript() +
  theme(legend.position = "none",
        axis.text.y = element_text(size = 8),
        plot.title = element_text(size = 10, face = "bold"))

# --- Panel (b): sexual vs asexual replacement share ---
share_data <- summary_tab %>%
  transmute(scenario,
            label_display,
            sexual = sexual_contribution_pct,
            fragmentation = 100 - sexual_contribution_pct) %>%
  tidyr::pivot_longer(c(sexual, fragmentation),
                       names_to = "pathway", values_to = "pct")

p_b <- ggplot(share_data,
              aes(x = scenario, y = pct, fill = pathway)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = c(sexual = "#238B45",
                                fragmentation = "#969696"),
                    labels = c(sexual = "Sexual", fragmentation = "Fragmentation"),
                    name = NULL) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 101)) +
  labs(x = NULL,
       y = "Share of SC1 inflow (%)",
       title = "b. Reproductive pathway share") +
  theme_manuscript() +
  theme(legend.position = "bottom",
        plot.title = element_text(size = 10, face = "bold"))

# --- Panel (c): 50-yr projection for representative scenarios ---
focal <- c("S0", "S1", "S4", "S7", "S8")
project_50yr <- function(sc) {
  A <- sc$result$matrix
  n0 <- c(1000, 0, 0, 0, 0)  # Start with a pulse at SC1
  traj <- matrix(NA, nrow = 51, ncol = length(n0))
  traj[1, ] <- n0
  for (t in 1:50) traj[t + 1, ] <- as.numeric(A %*% traj[t, ])
  data.frame(year = 0:50,
             scenario = sc$scenario,
             label = sc$label,
             total = rowSums(traj))
}
trajectories <- do.call(rbind,
                         lapply(scenario_rds[
                                   sapply(scenario_rds, function(x) x$scenario %in% focal)],
                                project_50yr))
trajectories$label_display <- sprintf("%s: %s", trajectories$scenario, trajectories$label)

p_c <- ggplot(trajectories,
              aes(x = year, y = total, color = label_display)) +
  geom_line(linewidth = 0.8) +
  scale_y_log10(breaks = scales::trans_breaks("log10", function(x) 10^x),
                 labels = scales::trans_format("log10", scales::math_format(10^.x))) +
  scale_color_manual(values = c("grey30", "#2C7FB8", "#E66101", "#238B45", "#762A83"),
                     name = NULL) +
  labs(x = "Year",
       y = "Total colonies (log scale)",
       title = "c. 50-year projection") +
  theme_manuscript() +
  theme(legend.position = "bottom",
        legend.text = element_text(size = 7),
        plot.title = element_text(size = 10, face = "bold"))

# --- Combine and save ---
fig <- (p_a / p_b / p_c) + plot_layout(heights = c(1.2, 1, 1.2))

save_manuscript_fig(fig,
                     "FigS29_biological_realism",
                     width_mm = 170, height_mm = 220,
                     fig_dir = "06_analysis/figures/supplementary")

print_success("FigS29 rendered")

cat("\nDone.\n")
