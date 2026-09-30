# ============================================================================
# Makefile - Detmer 2025 coral parameters
# ----------------------------------------------------------------------------
# CAFI-style workflow wrapper for the existing PRISMA/R analysis layout.
#
# Canonical targets:
#   pipeline       Run the full maintained analysis pipeline.
#   verify         Refresh canonical stats and run manuscript/code/model gates.
#   display-check  Validate the figure/table index against files and legends.
#   submit-check   Pre-submission gate: verify + display-check + strict renv status.
#   test           Alias of verify.
#   help           Print this target list.
# ============================================================================

R ?= Rscript
PY ?= python3

.PHONY: all pipeline verify display-check renv-check submit-check test help

all: pipeline verify

pipeline:
	$(R) 06_analysis/scripts/run_all.R

verify:
	$(R) 06_analysis/scripts/23_verification.R
	$(R) 06_analysis/scripts/48_pipeline_refresh_audit.R
	$(PY) tools/check_canonical_statistics.py
	$(PY) tools/check_claims.py
	$(PY) tools/check_vocabulary.py
	$(PY) tools/check_model_inventory.py

display-check:
	$(PY) tools/check_display_items.py

renv-check:
	$(R) tools/check_r_version.R
	$(R) -e 'status <- renv::status(); if (!isTRUE(status$$synchronized)) quit(status = 1)'

submit-check: verify display-check renv-check
	@echo "OK - submission checks completed."

test: verify

help:
	@echo "Canonical workflow targets:"
	@echo "  pipeline       Run 06_analysis/scripts/run_all.R"
	@echo "  verify         Refresh canonical stats and run source/prose/model gates"
	@echo "  display-check  Validate display_items.tsv against rendered files and legends"
	@echo "  renv-check     Fail if renv lockfile/library state is out of sync"
	@echo "  submit-check   verify + display-check + renv-check"
	@echo "  test           Alias of verify"
	@echo "  all            pipeline -> verify"
