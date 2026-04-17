#!/usr/bin/env Rscript
################################################################################
# 34_DISTURBANCE_SUMMARIES.R
# Publication-quality summaries for the A. palmata disturbance timeline
################################################################################
#
# PURPOSE: Generate publication-quality summary tables and figures from the
#          curated disturbance/stressor timeline for A. palmata across the
#          Caribbean (by type, region, decade, and severity).
#
# INPUTS:
#   - 05_data/standardized/apal_disturbance_stressor_timeline.csv (curated timeline)
#
# OUTPUTS:
#   - 07_reporting/manuscript/tables/disturbance_catalog.csv (full annotated catalog)
#   - 07_reporting/manuscript/tables/disturbance_summary_by_type.csv
#   - 07_reporting/manuscript/tables/disturbance_summary_by_region.csv
#   - 07_reporting/manuscript/tables/disturbance_summary_by_tier.csv
#   - 07_reporting/manuscript/tables/disturbance_summary_by_decade.csv
#   - 06_analysis/figures/supplementary/FigS18_disturbance_summary.{png,pdf}
#
# Author: Detmer & Stier Lab
################################################################################

source("06_analysis/scripts/utils/shared_utilities.R")

project_root <- get_project_root()
dirs <- setup_output_dirs(project_root)
tables_dir <- file.path(project_root, "07_reporting/manuscript/tables")
dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

pal <- MANUSCRIPT_PALETTE

timeline_file <- file.path(project_root, "05_data/standardized",
                           "apal_disturbance_stressor_timeline.csv")

if (!file.exists(timeline_file)) {
  stop("Missing disturbance timeline: ", timeline_file)
}

type_palette <- c(
  "Hurricane" = pal$surv_dark,
  "Bleaching" = pal$accent,
  "Disease" = "#9c2f2f",
  "Cold snap" = pal$slate_mid,
  "Sargassum" = "#8b5a2b",
  "Pollution" = "#556b2f",
  "Vessel grounding" = "#111827",
  "Predator" = "#6b7280"
)

severity_palette <- c(
  "Moderate" = "#9ecae1",
  "Major" = "#3182bd",
  "Catastrophic" = "#08306b"
)

parse_lower_numeric <- function(x) {
  ifelse(
    str_detect(x, "-"),
    readr::parse_number(str_extract(x, "^[0-9.]+")),
    readr::parse_number(x)
  )
}

severity_from_metric <- function(metric, value, impact) {
  metric_low <- str_to_lower(metric)
  value_num <- parse_lower_numeric(value)
  impact_low <- str_to_lower(impact)

  dplyr::case_when(
    metric_low == "category" & value_num >= 5 ~ "Catastrophic",
    metric_low == "category" & value_num >= 4 ~ "Major",
    metric_low %in% c("population loss", "urchin mortality") & value_num >= 80 ~ "Catastrophic",
    metric_low %in% c("population loss", "urchin mortality") & value_num >= 50 ~ "Major",
    metric_low == "dhw" & value_num >= 20 ~ "Catastrophic",
    metric_low == "dhw" & value_num >= 8 ~ "Major",
    metric_low == "dhw" & value_num > 0 ~ "Moderate",
    metric_low == "min temp" & value_num <= 10 ~ "Catastrophic",
    metric_low == "chlorophyll-a" & value_num >= 1 ~ "Major",
    metric_low == "macroalgal cover" & value_num >= 80 ~ "Major",
    metric_low == "caco3 reduction" & value_num >= 25 ~ "Major",
    metric_low == "area" & value_num >= 500 ~ "Major",
    metric_low == "fragments" & value_num >= 1000 ~ "Major",
    metric_low == "peak biomass" & value_num >= 30 ~ "Major",
    metric_low == "tissue loss" & value_num >= 10 ~ "Major",
    metric_low == "frequency" & value_num >= 3 ~ "Major",
    str_detect(impact_low, "functional extinction|100% loss|80% destruction|foundational collapse|no recruitment") ~ "Catastrophic",
    str_detect(impact_low, "mass mortality|severe|devastating|collapse|phase shift") ~ "Major",
    TRUE ~ "Moderate"
  )
}

severity_score <- function(severity_class) {
  dplyr::case_when(
    severity_class == "Moderate" ~ 2,
    severity_class == "Major" ~ 3,
    severity_class == "Catastrophic" ~ 4,
    TRUE ~ NA_real_
  )
}

region_group_from_token <- function(token) {
  token_low <- str_to_lower(token)
  dplyr::case_when(
    token_low %in% c("caribbean-wide", "caribbean") ~ "Caribbean-wide",
    str_detect(token_low, "fl keys|florida") ~ "Florida",
    str_detect(token_low, "usvi") ~ "USVI",
    str_detect(token_low, "puerto rico") ~ "Puerto Rico",
    str_detect(token_low, "mexico") ~ "Mexico",
    str_detect(token_low, "cuba") ~ "Cuba",
    str_detect(token_low, "belize") ~ "Belize",
    TRUE ~ str_to_title(token)
  )
}

timeline <- read_csv(timeline_file, show_col_types = FALSE) %>%
  mutate(
    event_type_label = str_replace_all(str_to_title(Event_Type), "_", " "),
    spatial_scale = str_replace_all(str_to_title(Spatial_Scale), "-", " "),
    analysis_tier = str_replace_all(str_to_title(Analysis_Tier), "_", " "),
    baseline_role = if_else(Exclude_From_Baseline, "Exclude from baseline", "Context only"),
    duration_years = pmax(1, End_Year - Start_Year + 1),
    duration_label = factor(Duration, levels = c("Acute", "Annual", "Chronic")),
    source_count = str_count(Source, fixed(";")) + 1,
    intensity_numeric = parse_lower_numeric(Intensity_Value),
    severity_class = severity_from_metric(Intensity_Metric, Intensity_Value,
                                          Impact_Description),
    severity_score = severity_score(severity_class),
    timeline_xend = if_else(Start_Year == End_Year, Start_Year + 0.45, End_Year),
    intensity_display = paste0(Intensity_Metric, ": ", Intensity_Value),
    period = if_else(Start_Year == End_Year,
                     as.character(Start_Year),
                     paste0(Start_Year, "-", End_Year))
  ) %>%
  arrange(Start_Year, End_Year, desc(severity_score), Event_Name) %>%
  mutate(
    event_factor = factor(Event_Name, levels = rev(unique(Event_Name))),
    event_label = paste0(Event_Name, " (", Region, ")")
  )

timeline_catalog <- timeline %>%
  transmute(
    start_year = Start_Year,
    end_year = End_Year,
    period,
    event_name = Event_Name,
    event_type = event_type_label,
    region = Region,
    spatial_scale,
    duration = as.character(duration_label),
    duration_years,
    analysis_tier,
    baseline_role,
    severity_class,
    severity_score,
    intensity_metric = Intensity_Metric,
    intensity_value = Intensity_Value,
    intensity_display,
    impact_description = Impact_Description,
    source_count,
    source = Source
  )

region_long <- timeline %>%
  transmute(
    event_name = Event_Name,
    event_type = event_type_label,
    severity_class,
    severity_score,
    start_year = Start_Year,
    end_year = End_Year,
    region_token = str_split(Region, "\\s*/\\s*")
  ) %>%
  unnest(region_token) %>%
  mutate(region_group = region_group_from_token(region_token))

summary_by_type <- timeline %>%
  group_by(event_type = event_type_label) %>%
  summarise(
    n_events = n(),
    first_year = min(Start_Year),
    last_year = max(End_Year),
    median_duration_years = median(duration_years),
    catastrophic_events = sum(severity_class == "Catastrophic"),
    total_source_citations = sum(source_count),
    .groups = "drop"
  ) %>%
  arrange(desc(n_events), event_type)

summary_by_region <- region_long %>%
  group_by(region_group) %>%
  summarise(
    n_events = n_distinct(event_name),
    n_types = n_distinct(event_type),
    first_year = min(start_year),
    last_year = max(end_year),
    max_severity = c("Moderate", "Major", "Catastrophic")[max(severity_score, na.rm = TRUE) - 1],
    .groups = "drop"
  ) %>%
  arrange(desc(n_events), region_group)

summary_by_tier <- timeline %>%
  count(analysis_tier, baseline_role, name = "n_events") %>%
  arrange(desc(n_events), analysis_tier, baseline_role)

summary_by_decade <- timeline %>%
  mutate(decade = paste0(floor(Start_Year / 10) * 10, "s")) %>%
  count(decade, event_type = event_type_label, name = "n_events") %>%
  arrange(decade, event_type)

write_csv(timeline_catalog,
          file.path(dirs$output, "disturbance_event_catalog.csv"))
write_csv(summary_by_type,
          file.path(dirs$output, "disturbance_summary_by_type.csv"))
write_csv(summary_by_region,
          file.path(dirs$output, "disturbance_summary_by_region.csv"))
write_csv(summary_by_tier,
          file.path(dirs$output, "disturbance_summary_by_tier.csv"))
write_csv(summary_by_decade,
          file.path(dirs$output, "disturbance_summary_by_decade.csv"))
write_csv(timeline_catalog,
          file.path(tables_dir, "TableS1_disturbance_chronology.csv"))

timeline_plot_data <- timeline %>%
  mutate(
    event_label = factor(
      event_label,
      levels = rev(unique(event_label))
    )
  )

p_timeline <- ggplot(
  timeline_plot_data,
  aes(y = event_label, color = event_type_label)
) +
  geom_segment(
    aes(x = Start_Year, xend = timeline_xend, yend = event_label,
        linewidth = severity_score, linetype = duration_label),
    lineend = "round"
  ) +
  geom_point(
    aes(x = Start_Year, size = source_count, fill = severity_class),
    shape = 21, color = "white", stroke = 0.5
  ) +
  scale_color_manual(values = type_palette, name = "Event type") +
  scale_fill_manual(values = severity_palette, name = "Severity") +
  scale_linetype_manual(values = c("Acute" = "solid", "Annual" = "22",
                                   "Chronic" = "solid"),
                        name = "Duration class") +
  scale_linewidth_continuous(range = c(0.9, 3.0), guide = "none") +
  scale_size_continuous(range = c(2.5, 5.5), breaks = c(1, 2), name = "Cited sources") +
  scale_x_continuous(
    breaks = seq(1960, 2025, 5),
    limits = c(1960, 2026),
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  labs(
    title = "Documented disturbance regime affecting Acropora palmata",
    subtitle = "Event spans show the documented timing window; line thickness tracks inferred severity.",
    x = "Year",
    y = NULL,
    caption = "Multi-region events retain their original geography labels in the event catalog."
  ) +
  theme_manuscript(base_size = 10) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 10, margin = margin(b = 8)),
    plot.caption = element_text(size = 8, color = pal$slate_mid, hjust = 0),
    axis.text.y = element_text(size = 8.5),
    legend.position = "bottom",
    legend.box = "vertical",
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank(),
    plot.margin = margin(8, 10, 6, 6, "mm")
  )

heatmap_data <- region_long %>%
  count(region_group, event_type, name = "n_events") %>%
  complete(region_group, event_type, fill = list(n_events = 0)) %>%
  group_by(region_group) %>%
  mutate(total_region_events = sum(n_events)) %>%
  ungroup() %>%
  mutate(
    region_group = factor(
      region_group,
      levels = summary_by_region$region_group
    ),
    event_type = factor(
      event_type,
      levels = rev(names(type_palette))
    )
  )

p_heatmap <- ggplot(
  heatmap_data,
  aes(x = event_type, y = region_group, fill = n_events)
) +
  geom_tile(color = "white", linewidth = 0.6) +
  geom_text(aes(label = if_else(n_events == 0, "", as.character(n_events))),
            size = 3.2, color = pal$slate_dark) +
  scale_fill_gradientn(
    colours = c("#f8fbff", "#9ecae1", "#3182bd", "#08306b"),
    values = scales::rescale(c(0, 1, 3, 5)),
    breaks = c(0, 1, 3, 5),
    name = "Events"
  ) +
  labs(
    title = "Regional burden by type",
    subtitle = "Counts split multi-region events across the affected broad regions.",
    x = NULL,
    y = NULL
  ) +
  theme_manuscript(base_size = 10) +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 9.5, margin = margin(b = 8)),
    axis.text.x = element_text(angle = 25, hjust = 1),
    legend.position = "right",
    plot.margin = margin(8, 8, 6, 6, "mm")
  )

decade_plot_data <- timeline %>%
  mutate(
    decade = factor(paste0(floor(Start_Year / 10) * 10, "s"),
                    levels = unique(paste0(floor(sort(unique(Start_Year)) / 10) * 10, "s")))
  ) %>%
  count(decade, event_type = event_type_label, name = "n_events")

p_decade <- ggplot(
  decade_plot_data,
  aes(x = decade, y = n_events, fill = event_type)
) +
  geom_col(width = 0.8, color = "white", linewidth = 0.3) +
  scale_fill_manual(values = type_palette, name = "Event type") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05)),
                     breaks = pretty_breaks()) +
  labs(
    title = "Events by decade",
    subtitle = "Documented events rise after 2000 as thermal and chronic stressors accumulate.",
    x = NULL,
    y = "Documented events"
  ) +
  theme_manuscript(base_size = 10) +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 9.5, margin = margin(b = 8)),
    legend.position = "none",
    plot.margin = margin(8, 8, 6, 6, "mm")
  )

p_heatmap_compact <- p_heatmap +
  labs(subtitle = NULL) +
  theme(
    plot.subtitle = element_blank(),
    plot.title = element_text(size = 11)
  )

p_decade_compact <- p_decade +
  labs(subtitle = NULL) +
  theme(
    plot.subtitle = element_blank(),
    plot.title = element_text(size = 11)
  )

p_combined <- p_timeline / (p_heatmap_compact | p_decade_compact) +
  patchwork::plot_layout(heights = c(2.2, 1.2), widths = c(1.1, 0.9)) +
  patchwork::plot_annotation(tag_levels = "A")

pdf_device <- if (capabilities("cairo")) cairo_pdf else "pdf"

ggsave(
  file.path(dirs$figures_supp, "exploratory", "disturbance_timeline_highres.png"),
  p_timeline,
  width = 210, height = 170, units = "mm", dpi = 300, bg = "white"
)
ggsave(
  file.path(dirs$figures_supp, "exploratory", "disturbance_timeline_highres.pdf"),
  p_timeline,
  width = 210, height = 170, units = "mm", bg = "white",
  device = pdf_device
)

ggsave(
  file.path(dirs$figures_supp, "exploratory", "disturbance_regional_severity.png"),
  p_heatmap,
  width = 185, height = 110, units = "mm", dpi = 300, bg = "white"
)
ggsave(
  file.path(dirs$figures_supp, "exploratory", "disturbance_regional_severity.pdf"),
  p_heatmap,
  width = 185, height = 110, units = "mm", bg = "white",
  device = pdf_device
)

ggsave(
  file.path(dirs$figures_supp, "FigS18_disturbance_summary.png"),
  p_combined,
  width = 210, height = 230, units = "mm", dpi = 300, bg = "white"
)
ggsave(
  file.path(dirs$figures_supp, "FigS18_disturbance_summary.pdf"),
  p_combined,
  width = 210, height = 230, units = "mm", bg = "white",
  device = pdf_device
)

table_for_reporting <- timeline_catalog %>%
  transmute(
    Period = period,
    Event = event_name,
    Type = event_type,
    Geography = region,
    Scale = spatial_scale,
    Duration = duration,
    Tier = analysis_tier,
    `Baseline role` = baseline_role,
    Severity = severity_class,
    Intensity = intensity_display,
    `Primary impact` = impact_description,
    Sources = source
  )

md_escape <- function(x) {
  x %>%
    str_replace_all("\\|", "/") %>%
    str_replace_all("\n", " ") %>%
    str_trim()
}

md_lines <- c(
  "# Table S1: Disturbance and stressor chronology used in the demographic synthesis",
  "",
  "Generated from `05_data/standardized/apal_disturbance_stressor_timeline.csv`.",
  "",
  paste0("| ", paste(names(table_for_reporting), collapse = " | "), " |"),
  paste0("|", paste(rep(":---", ncol(table_for_reporting)), collapse = "|"), "|")
)

md_rows <- apply(table_for_reporting, 1, function(row) {
  paste0("| ", paste(md_escape(row), collapse = " | "), " |")
})

md_footer <- c(
  "",
  "---",
  paste0(
    "Summary: ", nrow(timeline_catalog), " documented disturbance entries across ",
    n_distinct(region_long$region_group), " broad regions and ",
    n_distinct(timeline_catalog$event_type), " event classes. ",
    sum(timeline$Exclude_From_Baseline), " entries are treated as baseline exclusions and ",
    sum(!timeline$Exclude_From_Baseline), " are retained as chronic or contextual pressure."
  )
)

writeLines(
  c(md_lines, md_rows, md_footer),
  file.path(tables_dir, "TableS1_disturbance_chronology.md")
)

print_header("DISTURBANCE SUMMARIES COMPLETE")
print_success("Saved: 06_analysis/output/disturbance_event_catalog.csv")
print_success("Saved: 06_analysis/output/disturbance_summary_by_type.csv")
print_success("Saved: 06_analysis/output/disturbance_summary_by_region.csv")
print_success("Saved: 06_analysis/output/disturbance_summary_by_tier.csv")
print_success("Saved: 06_analysis/output/disturbance_summary_by_decade.csv")
print_success("Saved: 07_reporting/manuscript/tables/TableS1_disturbance_chronology.csv")
print_success("Saved: 07_reporting/manuscript/tables/TableS1_disturbance_chronology.md")
print_success("Saved: 06_analysis/figures/supplementary/exploratory/disturbance_timeline_highres.png/.pdf")
print_success("Saved: 06_analysis/figures/supplementary/exploratory/disturbance_regional_severity.png/.pdf")
print_success("Saved: 06_analysis/figures/supplementary/FigS18_disturbance_summary.png/.pdf")
