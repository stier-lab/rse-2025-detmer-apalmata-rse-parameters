#!/usr/bin/env Rscript
################################################################################
# 20_MAIN_FIGURES_REORGANIZED.R
# A. palmata Demographic Analysis - Reorganized Publication Figures
# VERSION 1.0 - With Caribbean Map, Location & Time Dependencies
################################################################################
#
# PURPOSE: Generate reorganized main figures for publication focusing on:
#   1. Data overview with Caribbean map
#   2. Size-dependent survival and growth
#   3. Location-dependent patterns
#   4. Temporal trends
#   5. Natural vs restoration comparison
#   6. Population dynamics (transition matrix)
#   7. Meta-analysis synthesis
#
# RECOMMENDED MAIN FIGURES (6-7 for publication):
#   Figure 1: Study Overview with Caribbean Map
#   Figure 2: Size-Dependent Survival (threshold detection)
#   Figure 3: Size-Dependent Growth (CORRECTED data)
#   Figure 4: Geographic Variation (map + forest plot)
#   Figure 5: Temporal Trends
#   Figure 6: Natural vs Restoration Comparison
#   Figure 7: Population Matrix Model (λ, elasticity)
#
# Author: Detmer & Stier Lab
# Date: 2024-12-29
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)

set.seed(42)

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  20: REORGANIZED MAIN FIGURES FOR PUBLICATION                ║\n")
cat("║  With Caribbean Map & Location/Time Dependencies             ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Set paths
if (file.exists("standardized_data")) {
  project_root <- "."
} else if (file.exists("../../standardized_data")) {
  project_root <- "../.."
} else {
  stop("Cannot find project root. Run from project directory or analysis/scripts/")
}

output_dir <- file.path(project_root, "analysis/output")
fig_dir <- file.path(project_root, "analysis/figures")
pub_fig_dir <- file.path(fig_dir, "publication")
dir.create(pub_fig_dir, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# COLOR PALETTE
# ==============================================================================

colors <- list(
  # Ocean blues
  ocean_deep = "#0a3d62",
  ocean_mid = "#1a5276",
  ocean_light = "#2e86ab",

  # Coral accents
  coral_warm = "#e07a5f",
  coral_pale = "#f4a261",

  # Reef green
  reef_green = "#2a9d8f",

  # Neutrals
  sand_light = "#faf8f5",
  text_primary = "#1a1a2e",
  text_secondary = "#5d6d7e",

  # Population type colors
  natural_colony = "#264653",
  restoration_fragment = "#e07a5f"
)

# Size class colors
size_colors <- c(
  "SC1" = "#e07a5f",
  "SC2" = "#f4a261",
  "SC3" = "#e9c46a",
  "SC4" = "#2a9d8f",
  "SC5" = "#264653"
)

size_class_short <- c(
  "SC1" = "Recruit",
  "SC2" = "Sm. Juv",
  "SC3" = "Lg. Juv",
  "SC4" = "Sm. Adult",
  "SC5" = "Lg. Adult"
)

# ==============================================================================
# THEME
# ==============================================================================

theme_publication <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size + 2, color = colors$ocean_deep),
      plot.subtitle = element_text(size = base_size, color = colors$text_secondary),
      axis.title = element_text(face = "bold", size = base_size),
      axis.text = element_text(size = base_size - 1),
      legend.title = element_text(face = "bold", size = base_size),
      legend.text = element_text(size = base_size - 1),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      strip.text = element_text(face = "bold", size = base_size),
      plot.caption = element_text(size = base_size - 2, color = colors$text_secondary)
    )
}

# ==============================================================================
# LOAD DATA
# ==============================================================================

cat("Loading data...\n")

surv_data <- readRDS(file.path(output_dir, "prepared_survival_data.rds"))
growth_data <- readRDS(file.path(output_dir, "prepared_growth_data.rds"))

# Load raw data for coordinates
surv_raw <- read_csv(file.path(project_root, "standardized_data/apal_surv_ind.csv"),
                     show_col_types = FALSE)

cat(sprintf("  Survival records: %d\n", nrow(surv_data)))
cat(sprintf("  Growth records: %d\n", nrow(growth_data)))

# Check for impossible_growth flag
if ("impossible_growth" %in% names(growth_data)) {
  n_impossible <- sum(growth_data$impossible_growth, na.rm = TRUE)
  cat(sprintf("  Records flagged as impossible growth: %d\n", n_impossible))
  growth_filtered <- growth_data %>% filter(!impossible_growth)
} else {
  cat("  ⚠ impossible_growth flag not found - creating it\n")
  growth_filtered <- growth_data %>%
    filter(!((growth_cm2_yr < 0) & (abs(growth_cm2_yr) > size_cm2 * 1.1)))
}
cat(sprintf("  Growth records after filtering: %d\n", nrow(growth_filtered)))

# ==============================================================================
# FIGURE 1: STUDY OVERVIEW WITH CARIBBEAN MAP
# ==============================================================================

cat("\nCreating Figure 1: Study Overview with Caribbean Map...\n")

# Get Caribbean coastline
world <- ne_countries(scale = "medium", returnclass = "sf")
caribbean_bbox <- c(xmin = -90, xmax = -58, ymin = 8, ymax = 28)

# Extract unique site coordinates
site_coords <- surv_raw %>%
  filter(!is.na(latitude), !is.na(longitude)) %>%
  group_by(region, location) %>%
  summarise(
    lat = mean(latitude, na.rm = TRUE),
    lon = mean(longitude, na.rm = TRUE),
    n = n(),
    survival = mean(survived, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(!is.na(lat), !is.na(lon))

# Region-level summary for larger points
region_coords <- surv_raw %>%
  filter(!is.na(latitude), !is.na(longitude)) %>%
  group_by(region) %>%
  summarise(
    lat = mean(latitude, na.rm = TRUE),
    lon = mean(longitude, na.rm = TRUE),
    n = n(),
    survival = mean(survived, na.rm = TRUE),
    .groups = "drop"
  )

cat(sprintf("  Found %d unique sites across %d regions\n",
            nrow(site_coords), nrow(region_coords)))

# Panel A: Caribbean Map
p1a <- ggplot() +
  geom_sf(data = world, fill = "gray95", color = "gray70", linewidth = 0.2) +
  geom_point(data = region_coords,
             aes(x = lon, y = lat, size = n, fill = survival * 100),
             shape = 21, color = "white", stroke = 0.8, alpha = 0.9) +
  geom_text(data = region_coords,
            aes(x = lon, y = lat, label = region),
            size = 2.5, nudge_y = 0.8, color = colors$text_primary, fontface = "bold") +
  coord_sf(xlim = c(-90, -58), ylim = c(10, 28), expand = FALSE) +
  scale_size_continuous(name = "n obs", range = c(3, 15),
                        breaks = c(100, 500, 1000, 3000)) +
  scale_fill_gradient2(name = "Survival (%)",
                       low = colors$coral_warm, mid = colors$coral_pale, high = colors$reef_green,
                       midpoint = 80, limits = c(50, 100)) +
  labs(subtitle = "A. Study sites across the Caribbean") +
  theme_publication() +
  theme(
    axis.title = element_blank(),
    panel.grid = element_blank(),
    legend.position = "right"
  )

# Panel B: Geographic distribution (bar chart)
region_summary <- surv_data %>%
  group_by(region) %>%
  summarise(n = n(), .groups = "drop") %>%
  arrange(desc(n))

p1b <- ggplot(region_summary, aes(x = reorder(region, n), y = n)) +
  geom_col(fill = colors$ocean_mid, alpha = 0.8) +
  geom_text(aes(label = scales::comma(n)), hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(subtitle = "B. Observations by region", x = NULL, y = "Number of observations") +
  theme_publication() +
  theme(panel.grid.major.y = element_blank())

# Panel C: Temporal coverage
temporal_summary <- surv_data %>%
  group_by(survey_yr) %>%
  summarise(n = n(), .groups = "drop")

p1c <- ggplot(temporal_summary, aes(x = survey_yr, y = n)) +
  geom_col(fill = colors$reef_green, alpha = 0.8) +
  scale_x_continuous(breaks = seq(2005, 2024, 5)) +
  labs(subtitle = "C. Temporal coverage", x = "Year", y = "Number of observations") +
  theme_publication()

# Panel D: Population type breakdown
pop_summary <- surv_data %>%
  group_by(population_type) %>%
  summarise(
    n = n(),
    survival = mean(survived) * 100,
    .groups = "drop"
  ) %>%
  mutate(
    label = sprintf("n=%s\n(%.0f%%)\n%.0f%% survival",
                    scales::comma(n), n/sum(n)*100, survival)
  )

p1d <- ggplot(pop_summary, aes(x = population_type, y = n, fill = population_type)) +
  geom_col(alpha = 0.9, width = 0.7) +
  geom_text(aes(label = label), vjust = -0.3, size = 3, lineheight = 0.9) +
  scale_fill_manual(values = c("Natural colony" = colors$natural_colony,
                               "Restoration fragment" = colors$restoration_fragment),
                    guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(subtitle = "D. Population type (KEY STRATIFICATION)",
       x = NULL, y = "Number of observations") +
  theme_publication()

# Combine
fig1 <- (p1a | p1b) / (p1c | p1d) +
  plot_annotation(
    title = "Figure 1. A. palmata Demographic Database Overview",
    caption = sprintf("Total: %s survival observations, %s growth observations, %d regions, %d-%d",
                      scales::comma(nrow(surv_data)), scales::comma(nrow(growth_data)),
                      n_distinct(surv_data$region),
                      min(surv_data$survey_yr, na.rm = TRUE),
                      max(surv_data$survey_yr, na.rm = TRUE)),
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.caption = element_text(size = 9, color = colors$text_secondary)
    )
  )

ggsave(file.path(pub_fig_dir, "Fig1_study_overview.png"), fig1, width = 14, height = 10, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig1_study_overview.pdf"), fig1, width = 14, height = 10)
cat("  ✓ Saved: Fig1_study_overview.png/pdf\n")

# ==============================================================================
# FIGURE 2: SIZE-DEPENDENT SURVIVAL (Natural Colonies)
# ==============================================================================

cat("\nCreating Figure 2: Size-Dependent Survival...\n")

# Use natural colonies only for threshold detection
surv_natural <- surv_data %>%
  filter(population_type == "Natural colony")

# Fit GAM
library(mgcv)
# NOTE: Using k=3 to constrain smoothness (allows at most 1 bend/inflection point)
# Higher k values (e.g., k=5) allow multiple wiggles that may overfit noise
surv_gam <- gam(survived ~ s(log_size, k = 3),
                data = surv_natural,
                family = binomial,
                method = "REML")

# Predictions
pred_grid <- data.frame(log_size = seq(min(surv_natural$log_size, na.rm = TRUE),
                                        max(surv_natural$log_size, na.rm = TRUE),
                                        length.out = 200))
pred_grid$fit <- predict(surv_gam, newdata = pred_grid, type = "response")
pred_se <- predict(surv_gam, newdata = pred_grid, type = "link", se.fit = TRUE)
pred_grid$ci_lower <- plogis(pred_se$fit - 1.96 * pred_se$se.fit)
pred_grid$ci_upper <- plogis(pred_se$fit + 1.96 * pred_se$se.fit)

# Find inflection point (second derivative = 0)
pred_grid$d1 <- c(NA, diff(pred_grid$fit))
pred_grid$d2 <- c(NA, diff(pred_grid$d1))
inflection_idx <- which.min(abs(pred_grid$d2[-c(1:10, (nrow(pred_grid)-10):nrow(pred_grid))]))
inflection_size <- exp(pred_grid$log_size[inflection_idx + 10])

# Binned data for overlay
surv_binned <- surv_natural %>%
  mutate(size_bin = cut(log_size, breaks = 25)) %>%
  group_by(size_bin) %>%
  summarise(
    log_size = mean(log_size),
    survival = mean(survived),
    n = n(),
    se = sqrt(survival * (1 - survival) / n),
    .groups = "drop"
  ) %>%
  filter(!is.na(log_size))

fig2 <- ggplot() +
  # Confidence ribbon
  geom_ribbon(data = pred_grid,
              aes(x = log_size, ymin = ci_lower * 100, ymax = ci_upper * 100),
              fill = colors$reef_green, alpha = 0.25) +
  # Binned points
  geom_point(data = surv_binned,
             aes(x = log_size, y = survival * 100, size = n),
             color = colors$ocean_deep, alpha = 0.7) +
  # GAM fit
  geom_line(data = pred_grid,
            aes(x = log_size, y = fit * 100),
            color = colors$reef_green, linewidth = 1.5) +
  # Threshold line
  geom_vline(xintercept = log(inflection_size), linetype = "dashed",
             color = colors$coral_warm, linewidth = 0.8) +
  annotate("text", x = log(inflection_size), y = 15,
           label = sprintf("Threshold:\n%.0f cm²", inflection_size),
           hjust = -0.1, color = colors$coral_warm, fontface = "bold", size = 3.5) +
  # Scales
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                        breaks = c(10, 50, 100, 500, 1000, 5000, 10000))
  ) +
  scale_y_continuous(name = "Annual survival probability (%)", limits = c(0, 100)) +
  scale_size_continuous(name = "Sample size", range = c(2, 8), guide = "none") +
  labs(
    title = "Figure 2. Size-Dependent Survival in A. palmata (Natural Colonies)",
    subtitle = "GAM fit with 95% CI; vertical dashed line = inflection point threshold",
    caption = sprintf("Natural colonies: n = %s observations (%.1f%% survival) from %d studies\nRestoration fragments excluded (n = %s, %.1f%% survival) - see Fig 6 for comparison",
                      scales::comma(nrow(surv_natural)),
                      mean(surv_natural$survived) * 100,
                      n_distinct(surv_natural$study),
                      scales::comma(nrow(surv_data) - nrow(surv_natural)),
                      mean(surv_data$survived[surv_data$population_type == "Restoration fragment"]) * 100)
  ) +
  theme_publication()

ggsave(file.path(pub_fig_dir, "Fig2_survival_threshold.png"), fig2, width = 12, height = 8, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig2_survival_threshold.pdf"), fig2, width = 12, height = 8)
cat("  ✓ Saved: Fig2_survival_threshold.png/pdf\n")

# ==============================================================================
# FIGURE 2B: SMALL COLONY SURVIVAL THRESHOLD (0-100 cm²)
# ==============================================================================
# Key finding: Natural colonies show ~10 cm² threshold with +19 pp survival jump
# Restoration fragments show OPPOSITE pattern (larger = worse survival)

cat("\nCreating Figure 2b: Small Colony Survival Threshold (0-100 cm²)...\n")

# Filter to small colonies only (0-100 cm²)
small_data <- surv_data %>%
  filter(size_cm2 <= 100) %>%
  mutate(
    size_bin = cut(size_cm2,
                   breaks = c(0, 5, 10, 15, 25, 50, 75, 100),
                   include.lowest = TRUE)
  )

# Separate natural and fragments
small_natural <- small_data %>% filter(population_type == "Natural colony")
small_frag <- small_data %>% filter(population_type == "Restoration fragment")

# Fit GAMs for each population type
model_small_natural <- gam(survived ~ s(log_size, k = 4, bs = "tp"),
                           data = small_natural, family = binomial, method = "REML")

model_small_frag <- gam(survived ~ s(log_size, k = 4, bs = "tp"),
                        data = small_frag, family = binomial, method = "REML")

# Create prediction grid for small colonies
pred_small <- data.frame(
  log_size = seq(log(1), log(100), length.out = 200)
)
pred_small$size_cm2 <- exp(pred_small$log_size)

# Natural predictions with CI
pred_nat_small <- predict(model_small_natural, newdata = pred_small, type = "link", se.fit = TRUE)
pred_small$survival_natural <- plogis(pred_nat_small$fit) * 100
pred_small$nat_lower <- plogis(pred_nat_small$fit - 1.96 * pred_nat_small$se.fit) * 100
pred_small$nat_upper <- plogis(pred_nat_small$fit + 1.96 * pred_nat_small$se.fit) * 100

# Fragment predictions with CI
pred_frag_small <- predict(model_small_frag, newdata = pred_small, type = "link", se.fit = TRUE)
pred_small$survival_frag <- plogis(pred_frag_small$fit) * 100
pred_small$frag_lower <- plogis(pred_frag_small$fit - 1.96 * pred_frag_small$se.fit) * 100
pred_small$frag_upper <- plogis(pred_frag_small$fit + 1.96 * pred_frag_small$se.fit) * 100

# Calculate binned means for plotting
binned_small_natural <- small_natural %>%
  mutate(size_bin_num = cut(size_cm2, breaks = c(0, 5, 10, 15, 25, 40, 60, 80, 100), include.lowest = TRUE)) %>%
  group_by(size_bin_num) %>%
  summarise(
    size_cm2 = median(size_cm2),
    n = n(),
    survival = mean(survived) * 100,
    se = sqrt(survival/100 * (1 - survival/100) / n) * 100,
    .groups = "drop"
  ) %>%
  filter(n >= 10)

binned_small_frag <- small_frag %>%
  mutate(size_bin_num = cut(size_cm2, breaks = c(0, 10, 20, 30, 40, 50, 60, 75, 100), include.lowest = TRUE)) %>%
  group_by(size_bin_num) %>%
  summarise(
    size_cm2 = median(size_cm2),
    n = n(),
    survival = mean(survived) * 100,
    se = sqrt(survival/100 * (1 - survival/100) / n) * 100,
    .groups = "drop"
  ) %>%
  filter(n >= 10)

# Calculate key statistics
nat_below_10 <- small_natural %>% filter(size_cm2 < 10)
nat_above_10 <- small_natural %>% filter(size_cm2 >= 10)
nat_diff <- mean(nat_above_10$survived) * 100 - mean(nat_below_10$survived) * 100

# Create the plot
fig2b <- ggplot() +
  # Natural colonies - ribbon
  geom_ribbon(data = pred_small,
              aes(x = size_cm2, ymin = nat_lower, ymax = nat_upper),
              fill = colors$reef_green, alpha = 0.2) +
  # Fragments - ribbon
  geom_ribbon(data = pred_small,
              aes(x = size_cm2, ymin = frag_lower, ymax = frag_upper),
              fill = colors$coral_warm, alpha = 0.2) +
  # Natural colonies - line
  geom_line(data = pred_small,
            aes(x = size_cm2, y = survival_natural, color = "Natural colonies"),
            linewidth = 1.5) +
  # Fragments - line
  geom_line(data = pred_small,
            aes(x = size_cm2, y = survival_frag, color = "Restoration fragments"),
            linewidth = 1.5) +
  # Binned points - natural
  geom_pointrange(data = binned_small_natural,
                  aes(x = size_cm2, y = survival,
                      ymin = survival - 1.96*se, ymax = survival + 1.96*se,
                      color = "Natural colonies"),
                  size = 0.8, linewidth = 0.8) +
  # Binned points - fragments
  geom_pointrange(data = binned_small_frag,
                  aes(x = size_cm2, y = survival,
                      ymin = survival - 1.96*se, ymax = survival + 1.96*se,
                      color = "Restoration fragments"),
                  size = 0.8, linewidth = 0.8) +
  # 10 cm² threshold line
  geom_vline(xintercept = 10, linetype = "dashed", color = colors$ocean_deep, linewidth = 1) +
  annotate("text", x = 12, y = 95, label = "~10 cm² threshold",
           hjust = 0, fontface = "bold", color = colors$ocean_deep, size = 4) +
  # Vulnerable zone
  annotate("rect", xmin = 0, xmax = 10, ymin = 0, ymax = 100,
           alpha = 0.05, fill = colors$coral_warm) +
  annotate("text", x = 5, y = 15, label = "Vulnerable\nrecruits",
           hjust = 0.5, color = colors$ocean_deep, size = 3.5, fontface = "italic") +
  # Scales
  scale_x_continuous(
    name = expression(paste("Colony size (cm"^2, ")")),
    breaks = c(1, 5, 10, 25, 50, 75, 100),
    limits = c(1, 100)
  ) +
  scale_y_continuous(
    name = "Annual survival probability (%)",
    limits = c(0, 100),
    breaks = seq(0, 100, 20)
  ) +
  scale_color_manual(
    name = "Population type",
    values = c("Natural colonies" = colors$reef_green, "Restoration fragments" = colors$coral_warm)
  ) +
  labs(
    title = "Figure 2b. Small Colony Survival Threshold (0-100 cm²)",
    subtitle = sprintf("Natural colonies show +%.0f pp survival jump above ~10 cm²; Fragments show OPPOSITE pattern", nat_diff),
    caption = sprintf("Natural colonies: n=%d (<10 cm²: %.1f%% survival, ≥10 cm²: %.1f%% survival)\nRestoration fragments: n=%d (larger fragments survive WORSE - possibly due to transplant stress)",
                      nrow(small_natural),
                      mean(nat_below_10$survived) * 100,
                      mean(nat_above_10$survived) * 100,
                      nrow(small_frag))
  ) +
  theme_publication() +
  theme(
    legend.position = c(0.75, 0.25),
    legend.background = element_rect(fill = "white", color = "gray80"),
    legend.title = element_text(face = "bold")
  )

ggsave(file.path(pub_fig_dir, "Fig2b_small_colony_threshold.png"), fig2b, width = 10, height = 7, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig2b_small_colony_threshold.pdf"), fig2b, width = 10, height = 7)
cat("  ✓ Saved: Fig2b_small_colony_threshold.png/pdf\n")
cat(sprintf("    Key finding: Natural colonies <10 cm²: %.1f%% survival, ≥10 cm²: %.1f%% (+%.1f pp)\n",
            mean(nat_below_10$survived) * 100,
            mean(nat_above_10$survived) * 100,
            nat_diff))

# ==============================================================================
# FIGURE 3: SIZE-DEPENDENT GROWTH (CORRECTED DATA)
# ==============================================================================

cat("\nCreating Figure 3: Size-Dependent Growth (CORRECTED)...\n")

# Winsorize for visualization
lower_bound <- quantile(growth_filtered$growth_cm2_yr, 0.05, na.rm = TRUE)
upper_bound <- quantile(growth_filtered$growth_cm2_yr, 0.95, na.rm = TRUE)

growth_viz <- growth_filtered %>%
  mutate(growth_winsorized = pmax(pmin(growth_cm2_yr, upper_bound), lower_bound))

# Filter for GAM
growth_for_gam <- growth_filtered %>%
  mutate(pct_change = growth_cm2_yr / size_cm2 * 100) %>%
  filter(pct_change > -50 & pct_change < 200)

# Fit GAM
# NOTE: Using k=3 to constrain smoothness (allows at most 1 bend/inflection point)
growth_gam <- gam(growth_cm2_yr ~ s(log_size, k = 3),
                  data = growth_for_gam, method = "REML")

pred_grid_g <- data.frame(log_size = seq(min(growth_filtered$log_size, na.rm = TRUE),
                                          max(growth_filtered$log_size, na.rm = TRUE),
                                          length.out = 200))
pred_grid_g$fit <- predict(growth_gam, newdata = pred_grid_g)
pred_se_g <- predict(growth_gam, newdata = pred_grid_g, se.fit = TRUE)
pred_grid_g$ci_lower <- pred_se_g$fit - 1.96 * pred_se_g$se.fit
pred_grid_g$ci_upper <- pred_se_g$fit + 1.96 * pred_se_g$se.fit

# Binned growth
growth_binned <- growth_filtered %>%
  mutate(size_bin = cut(log_size, breaks = 20)) %>%
  group_by(size_bin) %>%
  summarise(
    log_size = mean(log_size),
    mean_growth = mean(growth_cm2_yr, na.rm = TRUE),
    median_growth = median(growth_cm2_yr, na.rm = TRUE),
    n = n(),
    pct_positive = mean(growth_cm2_yr > 0, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  filter(!is.na(log_size))

# Panel A: Absolute growth
p3a <- ggplot() +
  geom_point(data = growth_viz,
             aes(x = log_size, y = growth_winsorized),
             alpha = 0.1, size = 0.8, color = colors$ocean_light) +
  geom_hline(yintercept = 0, linetype = "dashed", color = colors$text_secondary) +
  geom_ribbon(data = pred_grid_g,
              aes(x = log_size, ymin = ci_lower, ymax = ci_upper),
              fill = colors$coral_warm, alpha = 0.3) +
  geom_line(data = pred_grid_g, aes(x = log_size, y = fit),
            color = colors$coral_warm, linewidth = 1.5) +
  geom_point(data = growth_binned, aes(x = log_size, y = mean_growth, size = n),
             color = colors$ocean_deep, alpha = 0.8) +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                        breaks = c(10, 100, 1000, 10000))
  ) +
  scale_y_continuous(name = expression(paste("Growth rate (cm"^2, "/yr)")),
                     limits = c(lower_bound, upper_bound)) +
  scale_size_continuous(range = c(2, 6), guide = "none") +
  labs(subtitle = "A. Absolute growth rate vs. colony size\n(positive values = tissue gain)") +
  theme_publication()

# Panel B: Percent positive growth by size
pos_growth_binned <- growth_filtered %>%
  mutate(size_bin = cut(log_size, breaks = 15)) %>%
  group_by(size_bin) %>%
  summarise(
    log_size = mean(log_size),
    pct_positive = mean(growth_cm2_yr > 0, na.rm = TRUE) * 100,
    n = n(),
    .groups = "drop"
  ) %>%
  filter(!is.na(log_size))

# Fit binomial GAM
# NOTE: Using k=3 to constrain smoothness (allows at most 1 bend/inflection point)
growth_data_pos <- growth_filtered %>% mutate(positive = as.integer(growth_cm2_yr > 0))
pos_gam <- gam(positive ~ s(log_size, k = 3), data = growth_data_pos,
               family = binomial, method = "REML")

pred_pos <- data.frame(log_size = seq(min(growth_filtered$log_size, na.rm = TRUE),
                                       max(growth_filtered$log_size, na.rm = TRUE),
                                       length.out = 200))
pred_pos$fit <- predict(pos_gam, newdata = pred_pos, type = "response") * 100
pred_pos_se <- predict(pos_gam, newdata = pred_pos, type = "link", se.fit = TRUE)
pred_pos$ci_lower <- plogis(pred_pos_se$fit - 1.96 * pred_pos_se$se.fit) * 100
pred_pos$ci_upper <- plogis(pred_pos_se$fit + 1.96 * pred_pos_se$se.fit) * 100

p3b <- ggplot() +
  geom_ribbon(data = pred_pos,
              aes(x = log_size, ymin = ci_lower, ymax = ci_upper),
              fill = colors$reef_green, alpha = 0.2) +
  geom_point(data = pos_growth_binned, aes(x = log_size, y = pct_positive, size = n),
             color = colors$ocean_deep, alpha = 0.7) +
  geom_line(data = pred_pos, aes(x = log_size, y = fit),
            color = colors$reef_green, linewidth = 1.5) +
  geom_hline(yintercept = 75, linetype = "dotted", color = colors$text_secondary) +
  annotate("text", x = min(pred_pos$log_size) + 0.5, y = 77,
           label = "75% positive", color = colors$text_secondary, size = 3, hjust = 0) +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                        breaks = c(10, 100, 1000, 10000))
  ) +
  scale_y_continuous(name = "Probability of positive growth (%)", limits = c(50, 100)) +
  scale_size_continuous(range = c(2, 6), guide = "none") +
  labs(subtitle = "B. Probability of positive growth (vs. shrinkage)") +
  theme_publication()

# Panel C: Relative Growth Rate (RGR) - mirrors survival threshold analysis
# RGR = growth / initial_size, handles heteroscedasticity and explains 31.7% variance
growth_rgr <- growth_filtered %>%
  mutate(rgr = growth_cm2_yr / size_cm2) %>%
  filter(abs(rgr) < quantile(abs(rgr), 0.99, na.rm = TRUE))  # Remove 1% outliers

# Fit GAM for RGR
# NOTE: Using k=3 to constrain smoothness (allows at most 1 bend/inflection point)
rgr_gam <- gam(rgr ~ s(log_size, k = 3), data = growth_rgr, method = "REML")
rgr_r2 <- summary(rgr_gam)$r.sq

pred_rgr <- data.frame(log_size = seq(min(growth_rgr$log_size, na.rm = TRUE),
                                       max(growth_rgr$log_size, na.rm = TRUE),
                                       length.out = 200))
pred_rgr$fit <- predict(rgr_gam, newdata = pred_rgr)
pred_rgr_se <- predict(rgr_gam, newdata = pred_rgr, se.fit = TRUE)
pred_rgr$ci_lower <- pred_rgr_se$fit - 1.96 * pred_rgr_se$se.fit
pred_rgr$ci_upper <- pred_rgr_se$fit + 1.96 * pred_rgr_se$se.fit

# Find inflection point for RGR threshold
pred_rgr$d1 <- c(NA, diff(pred_rgr$fit))
pred_rgr$d2 <- c(NA, diff(pred_rgr$d1))
# Avoid edge effects
valid_range <- 10:(nrow(pred_rgr) - 10)
rgr_inflection_idx <- valid_range[which.max(abs(pred_rgr$d2[valid_range]))]
rgr_threshold_size <- exp(pred_rgr$log_size[rgr_inflection_idx])

# Binned RGR
rgr_binned <- growth_rgr %>%
  mutate(size_bin = cut(log_size, breaks = 20)) %>%
  group_by(size_bin) %>%
  summarise(
    log_size = mean(log_size),
    mean_rgr = mean(rgr, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  filter(!is.na(log_size))

p3c <- ggplot() +
  geom_point(data = growth_rgr,
             aes(x = log_size, y = rgr),
             alpha = 0.1, size = 0.8, color = colors$ocean_light) +
  geom_hline(yintercept = 0, linetype = "dashed", color = colors$text_secondary) +
  geom_ribbon(data = pred_rgr,
              aes(x = log_size, ymin = ci_lower, ymax = ci_upper),
              fill = colors$coral_pale, alpha = 0.3) +
  geom_line(data = pred_rgr, aes(x = log_size, y = fit),
            color = colors$coral_pale, linewidth = 1.5) +
  geom_point(data = rgr_binned, aes(x = log_size, y = mean_rgr, size = n),
             color = colors$ocean_deep, alpha = 0.8) +
  # Threshold line
  geom_vline(xintercept = log(rgr_threshold_size), linetype = "dashed",
             color = colors$coral_warm, linewidth = 0.8) +
  annotate("text", x = log(rgr_threshold_size), y = max(pred_rgr$ci_upper) * 0.9,
           label = sprintf("Threshold:\n%.0f cm²", rgr_threshold_size),
           hjust = -0.1, color = colors$coral_warm, fontface = "bold", size = 3.5) +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                        breaks = c(10, 100, 1000, 10000))
  ) +
  scale_y_continuous(name = expression(paste("Relative growth rate (yr"^-1, ")"))) +
  scale_size_continuous(range = c(2, 6), guide = "none") +
  labs(subtitle = sprintf("C. Relative growth rate (RGR) vs. size — R² = %.1f%%\n(RGR = growth / initial size; smaller corals grow faster relative to their size)",
                          rgr_r2 * 100)) +
  theme_publication()

fig3 <- (p3a | p3b) / p3c +
  plot_annotation(
    title = "Figure 3. Size-Dependent Growth in A. palmata (CORRECTED DATA)",
    caption = sprintf("n = %s observations after excluding %d impossible values (6.9%%); %.1f%% show positive growth overall.\nRGR threshold at ~%.0f cm² (inflection point). RGR explains %.1f%% of variance vs 1%% for absolute growth.",
                      scales::comma(nrow(growth_filtered)),
                      nrow(growth_data) - nrow(growth_filtered),
                      mean(growth_filtered$growth_cm2_yr > 0, na.rm = TRUE) * 100,
                      rgr_threshold_size,
                      rgr_r2 * 100),
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.caption = element_text(size = 9, color = colors$text_secondary)
    )
  )

ggsave(file.path(pub_fig_dir, "Fig3_growth_corrected.png"), fig3, width = 14, height = 12, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig3_growth_corrected.pdf"), fig3, width = 14, height = 12)
cat("  ✓ Saved: Fig3_growth_corrected.png/pdf\n")

# ==============================================================================
# FIGURE 4: GEOGRAPHIC VARIATION
# ==============================================================================

cat("\nCreating Figure 4: Geographic Variation...\n")

# Regional survival by population type
region_pop_stats <- surv_data %>%
  group_by(region, population_type) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    ci_lower = pmax(0, survival - 1.96 * se),
    ci_upper = pmin(1, survival + 1.96 * se),
    .groups = "drop"
  ) %>%
  filter(n >= 20)

# Overall means by population type
overall_means <- surv_data %>%
  group_by(population_type) %>%
  summarise(overall_survival = mean(survived), .groups = "drop")

# Order regions by natural colony survival
region_order <- region_pop_stats %>%
  filter(population_type == "Natural colony") %>%
  arrange(survival) %>%
  pull(region)

# Add regions only in fragments
fragment_only <- region_pop_stats %>%
  filter(population_type == "Restoration fragment",
         !region %in% region_order) %>%
  arrange(survival) %>%
  pull(region)

region_order <- c(region_order, fragment_only)

region_pop_stats <- region_pop_stats %>%
  mutate(region = factor(region, levels = region_order))

# Panel A: Forest plot
p4a <- ggplot(region_pop_stats, aes(x = survival * 100, y = region,
                                     color = population_type, shape = population_type)) +
  geom_vline(data = overall_means,
             aes(xintercept = overall_survival * 100, color = population_type),
             linetype = "dashed", linewidth = 0.8) +
  geom_errorbarh(aes(xmin = ci_lower * 100, xmax = ci_upper * 100),
                 height = 0.3, linewidth = 0.8, position = position_dodge(0.5)) +
  geom_point(aes(size = n), position = position_dodge(0.5)) +
  scale_color_manual(name = "Population Type",
                     values = c("Natural colony" = colors$natural_colony,
                               "Restoration fragment" = colors$restoration_fragment)) +
  scale_shape_manual(name = "Population Type", values = c(16, 17)) +
  scale_size_continuous(name = "n", range = c(3, 10)) +
  scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    subtitle = "A. Regional survival rates by population type",
    x = "Annual survival (%)",
    y = NULL
  ) +
  theme_publication() +
  theme(legend.position = "bottom")

# Panel B: Size × Region heatmap (for regions with sufficient data)
size_region <- surv_data %>%
  filter(!is.na(size_class)) %>%
  group_by(region, size_class) %>%
  summarise(
    n = n(),
    survival = mean(survived) * 100,
    .groups = "drop"
  ) %>%
  filter(n >= 10)

p4b <- ggplot(size_region, aes(x = region, y = size_class, fill = survival)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.0f%%\n(n=%d)", survival, n)),
            size = 2.5, color = "white", fontface = "bold") +
  scale_fill_gradient2(name = "Survival\n(%)",
                       low = colors$coral_warm, mid = colors$coral_pale, high = colors$reef_green,
                       midpoint = 75, limits = c(50, 100), na.value = "gray90") +
  scale_y_discrete(labels = size_class_short) +
  labs(subtitle = "B. Size × Region survival matrix", x = NULL, y = "Size Class") +
  theme_publication() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank()
  )

fig4 <- p4a / p4b +
  plot_annotation(
    title = "Figure 4. Geographic Variation in A. palmata Survival",
    caption = "Dashed lines = overall mean survival by population type. Only region×size combinations with n ≥ 10 shown.",
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.caption = element_text(size = 9, color = colors$text_secondary)
    )
  ) +
  plot_layout(heights = c(1, 0.8))

ggsave(file.path(pub_fig_dir, "Fig4_geographic_variation.png"), fig4, width = 12, height = 14, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig4_geographic_variation.pdf"), fig4, width = 12, height = 14)
cat("  ✓ Saved: Fig4_geographic_variation.png/pdf\n")

# ==============================================================================
# FIGURE 5: TEMPORAL TRENDS
# ==============================================================================

cat("\nCreating Figure 5: Temporal Trends...\n")

# Annual survival trend
annual_survival <- surv_data %>%
  group_by(survey_yr) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    ci_lower = pmax(0, survival - 1.96 * se),
    ci_upper = pmin(1, survival + 1.96 * se),
    .groups = "drop"
  ) %>%
  filter(n >= 20)

# Trend line
if (nrow(annual_survival) >= 3) {
  trend_model <- lm(survival ~ survey_yr, data = annual_survival, weights = n)
  trend_slope <- coef(trend_model)[2]
  trend_p <- summary(trend_model)$coefficients[2, 4]
}

# Panel A: Annual trend
p5a <- ggplot(annual_survival, aes(x = survey_yr, y = survival * 100)) +
  geom_smooth(method = "lm", se = TRUE, color = colors$coral_warm,
              fill = colors$coral_warm, alpha = 0.2, linewidth = 1) +
  geom_errorbar(aes(ymin = ci_lower * 100, ymax = ci_upper * 100),
                width = 0.3, color = colors$ocean_deep) +
  geom_point(aes(size = n), color = colors$ocean_deep, alpha = 0.8) +
  scale_size_continuous(name = "n", range = c(2, 8)) +
  scale_x_continuous(breaks = seq(2005, 2024, 3)) +
  scale_y_continuous(limits = c(50, 100)) +
  labs(
    subtitle = sprintf("A. Annual survival trend (slope = %.2f%%/yr, p = %.3f)",
                       trend_slope * 100, trend_p),
    x = "Year",
    y = "Annual survival (%)"
  ) +
  theme_publication() +
  theme(legend.position = "right")

# Panel B: Size class × Year heatmap
size_year <- surv_data %>%
  filter(!is.na(size_class), !is.na(survey_yr)) %>%
  group_by(survey_yr, size_class) %>%
  summarise(
    n = n(),
    survival = mean(survived) * 100,
    .groups = "drop"
  ) %>%
  filter(n >= 10)

p5b <- ggplot(size_year, aes(x = survey_yr, y = size_class, fill = survival)) +
  geom_tile(color = "white", linewidth = 0.3) +
  scale_fill_gradient2(name = "Survival (%)",
                       low = colors$coral_warm, mid = colors$coral_pale, high = colors$reef_green,
                       midpoint = 75, limits = c(50, 100), na.value = "gray90") +
  scale_x_continuous(breaks = seq(2005, 2024, 3)) +
  scale_y_discrete(labels = size_class_short) +
  labs(subtitle = "B. Size class × Year survival patterns", x = "Year", y = "Size Class") +
  theme_publication() +
  theme(panel.grid = element_blank())

# Panel C: Interannual variability by size class
cv_by_size <- surv_data %>%
  filter(!is.na(size_class), !is.na(survey_yr)) %>%
  group_by(size_class, survey_yr) %>%
  summarise(survival = mean(survived), n = n(), .groups = "drop") %>%
  filter(n >= 10) %>%
  group_by(size_class) %>%
  summarise(
    mean_surv = mean(survival),
    sd_surv = sd(survival),
    cv = sd_surv / mean_surv * 100,
    n_years = n(),
    .groups = "drop"
  ) %>%
  filter(n_years >= 3)

p5c <- ggplot(cv_by_size, aes(x = size_class, y = cv, fill = size_class)) +
  geom_col(alpha = 0.8, width = 0.7) +
  geom_text(aes(label = sprintf("%.0f%%", cv)), vjust = -0.3, size = 3.5, fontface = "bold") +
  scale_fill_manual(values = size_colors, guide = "none") +
  scale_x_discrete(labels = size_class_short) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(subtitle = "C. Interannual variability (CV) by size class",
       x = "Size Class", y = "Coefficient of Variation (%)") +
  theme_publication()

fig5 <- (p5a | p5c) / p5b +
  plot_annotation(
    title = "Figure 5. Temporal Patterns in A. palmata Survival",
    caption = sprintf("Data from %d-%d. Only year×size combinations with n ≥ 10 shown in heatmap.",
                      min(surv_data$survey_yr, na.rm = TRUE),
                      max(surv_data$survey_yr, na.rm = TRUE)),
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.caption = element_text(size = 9, color = colors$text_secondary)
    )
  ) +
  plot_layout(heights = c(1, 0.8))

ggsave(file.path(pub_fig_dir, "Fig5_temporal_trends.png"), fig5, width = 14, height = 12, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig5_temporal_trends.pdf"), fig5, width = 14, height = 12)
cat("  ✓ Saved: Fig5_temporal_trends.png/pdf\n")

# ==============================================================================
# FIGURE 6: NATURAL VS RESTORATION COMPARISON
# ==============================================================================

cat("\nCreating Figure 6: Natural vs Restoration Comparison...\n")

# Size-matched comparison
size_matched <- surv_data %>%
  filter(!is.na(size_class), !is.na(population_type)) %>%
  group_by(size_class, population_type) %>%
  summarise(
    n = n(),
    survival = mean(survived),
    se = sqrt(survival * (1 - survival) / n),
    ci_lower = pmax(0, survival - 1.96 * se),
    ci_upper = pmin(1, survival + 1.96 * se),
    .groups = "drop"
  ) %>%
  filter(n >= 10)

# Panel A: Survival by size and population type
p6a <- ggplot(size_matched, aes(x = size_class, y = survival * 100, fill = population_type)) +
  geom_col(position = position_dodge(0.8), width = 0.7, alpha = 0.9) +
  geom_errorbar(aes(ymin = ci_lower * 100, ymax = ci_upper * 100),
                position = position_dodge(0.8), width = 0.25) +
  scale_fill_manual(name = "Population Type",
                    values = c("Natural colony" = colors$natural_colony,
                              "Restoration fragment" = colors$restoration_fragment)) +
  scale_x_discrete(labels = size_class_short) +
  scale_y_continuous(limits = c(0, 100)) +
  labs(subtitle = "A. Survival by size class and population type",
       x = "Size Class", y = "Annual survival (%)") +
  theme_publication() +
  theme(legend.position = "top")

# Panel B: Size distributions
p6b <- ggplot(surv_data %>% filter(!is.na(population_type)),
              aes(x = log_size, fill = population_type, color = population_type)) +
  geom_density(alpha = 0.4, linewidth = 1) +
  geom_vline(data = surv_data %>%
               group_by(population_type) %>%
               summarise(med = median(log_size, na.rm = TRUE), .groups = "drop"),
             aes(xintercept = med, color = population_type),
             linetype = "dashed", linewidth = 1) +
  scale_fill_manual(name = "Population Type",
                    values = c("Natural colony" = colors$natural_colony,
                              "Restoration fragment" = colors$restoration_fragment)) +
  scale_color_manual(name = "Population Type",
                     values = c("Natural colony" = colors$natural_colony,
                               "Restoration fragment" = colors$restoration_fragment)) +
  scale_x_continuous(
    name = expression(paste("Log colony size (log cm"^2, ")")),
    sec.axis = sec_axis(~exp(.), name = expression(paste("Colony size (cm"^2, ")")),
                        breaks = c(10, 50, 100, 500, 1000, 5000))
  ) +
  labs(subtitle = "B. Size distribution overlap (dashed = median)") +
  theme_publication() +
  theme(legend.position = "none")

# Panel C: Size-matched survival difference
# Calculate difference (natural - fragment) for each size class
survival_diff <- size_matched %>%
  select(size_class, population_type, survival, se) %>%
  pivot_wider(names_from = population_type, values_from = c(survival, se)) %>%
  mutate(
    diff = `survival_Natural colony` - `survival_Restoration fragment`,
    diff_se = sqrt(`se_Natural colony`^2 + `se_Restoration fragment`^2),
    diff_lower = diff - 1.96 * diff_se,
    diff_upper = diff + 1.96 * diff_se
  ) %>%
  filter(!is.na(diff))

p6c <- ggplot(survival_diff, aes(x = size_class, y = diff * 100)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = colors$text_secondary) +
  geom_errorbar(aes(ymin = diff_lower * 100, ymax = diff_upper * 100),
                width = 0.25, linewidth = 0.8, color = colors$ocean_deep) +
  geom_point(size = 4, color = colors$ocean_deep) +
  geom_text(aes(label = sprintf("%+.0f pp", diff * 100)), vjust = -1, size = 3.5, fontface = "bold") +
  scale_x_discrete(labels = size_class_short) +
  scale_y_continuous(limits = c(-30, 40)) +
  labs(subtitle = "C. Survival advantage: Natural − Fragment (at same size)",
       x = "Size Class", y = "Survival difference (percentage points)") +
  theme_publication()

fig6 <- (p6a | p6b) / p6c +
  plot_annotation(
    title = "Figure 6. Natural Colonies vs Restoration Fragments: Size-Matched Comparison",
    subtitle = "KEY FINDING: At matching sizes, natural colonies have 13-17 pp higher survival",
    caption = sprintf("Natural colonies: n=%s (%.1f%% survival); Fragments: n=%s (%.1f%% survival)\nOverall difference: %.1f pp; Size-matched mean difference: %.1f pp",
                      scales::comma(sum(surv_data$population_type == "Natural colony")),
                      mean(surv_data$survived[surv_data$population_type == "Natural colony"]) * 100,
                      scales::comma(sum(surv_data$population_type == "Restoration fragment")),
                      mean(surv_data$survived[surv_data$population_type == "Restoration fragment"]) * 100,
                      (mean(surv_data$survived[surv_data$population_type == "Natural colony"]) -
                       mean(surv_data$survived[surv_data$population_type == "Restoration fragment"])) * 100,
                      mean(survival_diff$diff, na.rm = TRUE) * 100),
    theme = theme(
      plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
      plot.subtitle = element_text(size = 12, face = "bold", color = colors$coral_warm),
      plot.caption = element_text(size = 9, color = colors$text_secondary)
    )
  )

ggsave(file.path(pub_fig_dir, "Fig6_fragment_comparison.png"), fig6, width = 14, height = 12, dpi = 300)
ggsave(file.path(pub_fig_dir, "Fig6_fragment_comparison.pdf"), fig6, width = 14, height = 12)
cat("  ✓ Saved: Fig6_fragment_comparison.png/pdf\n")

# ==============================================================================
# FIGURE 7: POPULATION MATRIX MODEL
# ==============================================================================

cat("\nCreating Figure 7: Population Matrix Model...\n")

# Load transition matrix results if available
matrix_file <- file.path(output_dir, "transition_matrix.rds")
if (file.exists(matrix_file)) {
  matrix_results <- readRDS(matrix_file)

  A <- matrix_results$projection_matrix
  lambda <- matrix_results$lambda
  lambda_ci <- matrix_results$lambda_ci
  elasticity <- matrix_results$elasticity
  w <- matrix_results$stable_distribution
  lambda_boot <- matrix_results$lambda_bootstrap

  size_labels <- c("SC1\n(recruit)", "SC2\n(sm. juv)", "SC3\n(lg. juv)",
                   "SC4\n(sm. adult)", "SC5\n(lg. adult)")

  # Panel A: Transition matrix
  A_df <- as.data.frame(as.table(A)) %>%
    rename(to = Var1, from = Var2, probability = Freq) %>%
    mutate(
      to = factor(to, levels = rev(rownames(A))),
      from = factor(from, levels = colnames(A)),
      label = ifelse(probability > 0.005, sprintf("%.2f", probability), "")
    )

  p7a <- ggplot(A_df, aes(x = from, y = to, fill = probability)) +
    geom_tile(color = "white", linewidth = 0.5) +
    geom_text(aes(label = label), color = "white", size = 3.5, fontface = "bold") +
    scale_fill_gradient2(name = "Transition\nProbability",
                         low = "white", mid = colors$ocean_light, high = colors$ocean_deep,
                         midpoint = 0.3, limits = c(0, 1)) +
    scale_x_discrete(labels = size_labels) +
    scale_y_discrete(labels = rev(size_labels)) +
    labs(subtitle = sprintf("A. Projection matrix (λ = %.3f)", lambda),
         x = "From Size Class", y = "To Size Class") +
    theme_publication() +
    theme(panel.grid = element_blank()) +
    coord_fixed()

  # Panel B: Elasticity matrix
  E_df <- as.data.frame(as.table(elasticity)) %>%
    rename(to = Var1, from = Var2, elast = Freq) %>%
    mutate(
      to = factor(to, levels = rev(rownames(elasticity))),
      from = factor(from, levels = colnames(elasticity)),
      label = ifelse(elast > 0.01, sprintf("%.2f", elast), "")
    )

  e_stasis <- sum(diag(elasticity))
  e_growth <- sum(elasticity[lower.tri(elasticity)])

  # Panel C: Stable distribution
  size_class_names <- c("SC1", "SC2", "SC3",
                        "SC4", "SC5")
  stable_df <- data.frame(
    size_class = factor(size_class_names, levels = size_class_names),
    proportion = w
  )

  p7b <- ggplot(E_df, aes(x = from, y = to, fill = elast)) +
    geom_tile(color = "white", linewidth = 0.5) +
    geom_text(aes(label = label), color = "white", size = 3.5, fontface = "bold") +
    scale_fill_gradient2(name = "Elasticity",
                         low = "white", mid = colors$coral_pale, high = colors$coral_warm,
                         midpoint = 0.1, limits = c(0, max(elasticity))) +
    scale_x_discrete(labels = size_labels) +
    scale_y_discrete(labels = rev(size_labels)) +
    labs(subtitle = sprintf("B. Elasticity matrix (Stasis: %.0f%%, Growth: %.0f%%)",
                            e_stasis * 100, e_growth * 100),
         x = "From Size Class", y = "To Size Class") +
    theme_publication() +
    theme(panel.grid = element_blank()) +
    coord_fixed()

  p7c <- ggplot(stable_df, aes(x = size_class, y = proportion * 100, fill = size_class)) +
    geom_col(width = 0.7, alpha = 0.9) +
    geom_text(aes(label = sprintf("%.1f%%", proportion * 100)), vjust = -0.3, size = 3.5, fontface = "bold") +
    scale_fill_manual(values = size_colors, guide = "none") +
    scale_x_discrete(labels = size_labels) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(subtitle = "C. Stable size distribution", x = NULL, y = "Proportion (%)") +
    theme_publication()

  # Panel D: Bootstrap lambda distribution
  lambda_df <- data.frame(lambda = lambda_boot)
  p_decline <- mean(lambda_boot < 1)

  p7d <- ggplot(lambda_df, aes(x = lambda)) +
    geom_histogram(fill = colors$ocean_light, color = "white", bins = 30, alpha = 0.8) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "red", linewidth = 1) +
    geom_vline(xintercept = lambda, color = colors$ocean_deep, linewidth = 1.5) +
    annotate("text", x = 1, y = Inf, label = "λ = 1\n(stable)",
             vjust = 2, hjust = -0.1, color = "red", size = 3) +
    annotate("text", x = lambda, y = Inf, label = sprintf("λ = %.3f", lambda),
             vjust = 2, hjust = 1.1, color = colors$ocean_deep, size = 3, fontface = "bold") +
    labs(subtitle = sprintf("D. Bootstrap distribution of λ (P(decline) = %.0f%%)", p_decline * 100),
         x = "Population Growth Rate (λ)", y = "Count") +
    theme_publication()

  fig7 <- (p7a | p7b) / (p7c | p7d) +
    plot_annotation(
      title = "Figure 7. A. palmata Population Matrix Model",
      subtitle = sprintf("λ = %.3f (95%% CI: %.3f-%.3f) — Population %s",
                         lambda, lambda_ci[1], lambda_ci[2],
                         ifelse(lambda < 1, "DECLINING", "GROWING")),
      caption = "Elasticity analysis shows adult survival (stasis) is the most critical parameter for population growth.",
      theme = theme(
        plot.title = element_text(size = 14, face = "bold", color = colors$ocean_deep),
        plot.subtitle = element_text(size = 12, face = "bold",
                                     color = ifelse(lambda < 1, colors$coral_warm, colors$reef_green)),
        plot.caption = element_text(size = 9, color = colors$text_secondary)
      )
    )

  ggsave(file.path(pub_fig_dir, "Fig7_population_matrix.png"), fig7, width = 14, height = 12, dpi = 300)
  ggsave(file.path(pub_fig_dir, "Fig7_population_matrix.pdf"), fig7, width = 14, height = 12)
  cat("  ✓ Saved: Fig7_population_matrix.png/pdf\n")
} else {
  cat("  ⚠ Transition matrix results not found. Run 07_transition_matrix_analysis.R first.\n")
}

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  FIGURE GENERATION COMPLETE                                  ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("Main publication figures saved to:", pub_fig_dir, "\n\n")
cat("FIGURES GENERATED:\n")
cat("  ✓ Fig1_study_overview.png/pdf - Study overview with Caribbean map\n")
cat("  ✓ Fig2_survival_threshold.png/pdf - Size-dependent survival (full range)\n")
cat("  ✓ Fig2b_small_colony_threshold.png/pdf - Small colony threshold (0-100 cm²)\n")
cat("  ✓ Fig3_growth_corrected.png/pdf - Size-dependent growth (CORRECTED)\n")
cat("  ✓ Fig4_geographic_variation.png/pdf - Regional variation\n")
cat("  ✓ Fig5_temporal_trends.png/pdf - Temporal patterns\n")
cat("  ✓ Fig6_fragment_comparison.png/pdf - Natural vs restoration\n")
cat("  ✓ Fig7_population_matrix.png/pdf - Population dynamics\n")

cat("\nKEY FINDINGS VISUALIZED:\n")
cat("  • Small colony threshold: ~10 cm² (+19 pp survival for natural colonies)\n")
cat("  • Restoration fragments show OPPOSITE pattern (larger = worse at small sizes)\n")
cat("  • λ = 0.979 (population declining ~2.1%/year)\n")
cat("  • Natural colonies: ~14 pp higher survival than fragments\n")
cat("  • Adult survival most critical (54.6% elasticity)\n")
cat("  • 75% of corals show positive growth (after data correction)\n")
cat("  • Considerable heterogeneity (I² = 98.4%) across studies\n")
