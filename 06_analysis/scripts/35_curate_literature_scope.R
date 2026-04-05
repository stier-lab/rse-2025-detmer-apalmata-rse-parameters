#!/usr/bin/env Rscript
################################################################################
# 35_CURATE_LITERATURE_SCOPE.R
# Add scope metadata to literature support tables and write analysis-only views
################################################################################

library(dplyr)
library(readr)
library(stringr)

project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
data_dir <- file.path(project_root, "05_data", "standardized")

disturbance_file <- file.path(data_dir, "literature_disturbance_evidence.csv")
life_history_file <- file.path(data_dir, "apal_life_history_parameters.csv")

if (!file.exists(disturbance_file)) {
  stop("Missing file: ", disturbance_file)
}

if (!file.exists(life_history_file)) {
  stop("Missing file: ", life_history_file)
}

disturbance <- read_csv(disturbance_file, show_col_types = FALSE)
life_history <- read_csv(life_history_file, show_col_types = FALSE)

disturbance <- disturbance %>%
  select(-any_of(c("analysis_include", "relevance_class", "scope_note"))) %>%
  mutate(
    relevance_class = case_when(
      Paper_Title == "Alvarez-Filip 2022" ~ "indirect_habitat_context",
      Paper_Title == "Aronson 2001" & Event_Name == "Hurricane Greta" ~ "other_species_context",
      Paper_Title == "Aronson 2001" ~ "historical_acroporid_context",
      Paper_Title == "Hughes 1984" ~ "out_of_scope_other_taxa",
      Paper_Title == "Hughes 1994" ~ "historical_acroporid_context",
      Paper_Title == "Hughes 2017" ~ "out_of_scope_non_caribbean",
      Paper_Title == "Muller 2025b" & Event_Name == "2014-2015 Bleaching event" ~ "genus_level_context",
      Paper_Title == "Speare 2022" ~ "out_of_scope_non_caribbean",
      str_detect(Reported_Mortality_Impact, regex("acroporid|shallow branching", ignore_case = TRUE)) ~
        "historical_acroporid_context",
      TRUE ~ "direct_apal"
    ),
    analysis_include = !relevance_class %in% c(
      "other_species_context",
      "out_of_scope_other_taxa",
      "out_of_scope_non_caribbean"
    ),
    scope_note = case_when(
      relevance_class == "indirect_habitat_context" ~
        "Indirect reef-framework context relevant to A. palmata habitat and recruitment.",
      relevance_class == "historical_acroporid_context" ~
        "Caribbean acroporid context retained as historical disturbance evidence.",
      relevance_class == "genus_level_context" ~
        "Florida Acropora spp. context retained; not species-exclusive to A. palmata.",
      relevance_class == "other_species_context" ~
        "Excluded from analysis rows because the evidence is explicitly for another coral species.",
      relevance_class == "out_of_scope_other_taxa" ~
        "Excluded from analysis rows because the evidence is for non-acroporid taxa.",
      relevance_class == "out_of_scope_non_caribbean" ~
        "Excluded from analysis rows because the study is outside the Caribbean / A. palmata system.",
      TRUE ~ "Direct Caribbean A. palmata evidence retained for analysis."
    )
  ) %>%
  relocate(analysis_include, relevance_class, scope_note, .after = Reported_Mortality_Impact)

life_history <- life_history %>%
  select(-any_of(c("analysis_include", "relevance_class", "scope_note"))) %>%
  mutate(
    relevance_class = case_when(
      Study == "Alvarez-Filip 2022" ~ "indirect_habitat_context",
      Study == "Mumby 2007" ~ "indirect_habitat_context",
      Study == "Weil 2020" ~ "other_species_context",
      Study == "Speare 2022" ~ "out_of_scope_non_caribbean",
      TRUE ~ "direct_apal"
    ),
    analysis_include = !relevance_class %in% c(
      "other_species_context",
      "out_of_scope_non_caribbean"
    ),
    scope_note = case_when(
      relevance_class == "indirect_habitat_context" ~
        "Indirect Caribbean habitat-process context retained for analysis support.",
      relevance_class == "other_species_context" ~
        "Excluded from analysis rows because the value is explicitly for A. cervicornis, not A. palmata.",
      relevance_class == "out_of_scope_non_caribbean" ~
        "Excluded from analysis rows because the study is Pacific / non-Caribbean context.",
      TRUE ~ "Direct Caribbean A. palmata life-history evidence retained for analysis."
    )
  ) %>%
  relocate(analysis_include, relevance_class, scope_note, .after = Context)

disturbance_analysis <- disturbance %>%
  filter(analysis_include)

life_history_analysis <- life_history %>%
  filter(analysis_include)

write_csv(disturbance, disturbance_file)
write_csv(life_history, life_history_file)
write_csv(
  disturbance_analysis,
  file.path(data_dir, "literature_disturbance_evidence_analysis.csv")
)
write_csv(
  life_history_analysis,
  file.path(data_dir, "apal_life_history_parameters_analysis.csv")
)

cat("Curated disturbance rows:\n")
print(disturbance %>% count(analysis_include, relevance_class, sort = TRUE))
cat("\nCurated life-history rows:\n")
print(life_history %>% count(analysis_include, relevance_class, sort = TRUE))

cat("\nSaved:\n")
cat("  - 05_data/standardized/literature_disturbance_evidence.csv\n")
cat("  - 05_data/standardized/literature_disturbance_evidence_analysis.csv\n")
cat("  - 05_data/standardized/apal_life_history_parameters.csv\n")
cat("  - 05_data/standardized/apal_life_history_parameters_analysis.csv\n")
