# .gitignore Update Proposal

## Problem

Every pipeline run regenerates ~440 files (291 CSVs/RDS in `06_analysis/output/`, 144 figures in `06_analysis/figures/`, 7 parameter files in `parameter_lists/`). These are all tracked by git, producing massive diffs on every run. Additionally, 146 PDFs (487 MB) in `literature/pdfs/` bloat the repository.

The current `.gitignore` also has stale entries targeting `analysis/` (without the `06_` prefix) that do not match the actual directory structure `06_analysis/`.

## Proposed .gitignore Additions

Add the following block to `.gitignore`:

```gitignore
# === Generated pipeline outputs (regenerate with: Rscript 06_analysis/scripts/run_all.R) ===
# 291 tracked files (~35 MB): CSVs and RDS files produced by scripts 01-40
06_analysis/output/*.csv
06_analysis/output/*.rds
06_analysis/output/session_info.txt
!06_analysis/output/README.md

# === Generated figures (regenerate with pipeline) ===
# 144 tracked files (~30 MB): manuscript and supplementary PDFs/PNGs
06_analysis/figures/manuscript/*.pdf
06_analysis/figures/manuscript/*.png
06_analysis/figures/supplementary/*.pdf
06_analysis/figures/supplementary/*.png
06_analysis/figures/supplementary/exploratory/
06_analysis/figures/supplementary/diagnostics/
06_analysis/figures/supplementary/meta_analysis/
# Preserve the figure legends text file (hand-edited for manuscript)
!06_analysis/figures/manuscript/figure_legends.txt

# === Generated parameter lists (regenerate with script 17) ===
# 6 RDS files (~360 KB)
parameter_lists/*.rds
!parameter_lists/README.md

# === Literature PDFs (487 MB, 146 files — move to Git LFS or shared drive) ===
# These should NOT be in the git history. See instructions below.
# literature/pdfs/
```

### Also fix: stale paths in existing .gitignore

The current `.gitignore` has entries for `analysis/figures/...` and `analysis/output/...` (lines 67-74). These should be updated to use the correct `06_analysis/` prefix, or removed since the new rules above supersede them.

## Instructions

**Do these steps in order. Skipping ahead will lose the baseline.**

### Step 1: Commit all current generated outputs

This ensures the current baseline of all outputs, figures, and parameter files is preserved in git history. Anyone who needs the pre-change versions can check out this commit.

```bash
git add -A
git commit -m "Snapshot all generated outputs before .gitignore cleanup"
```

### Step 2: Add the proposed lines to .gitignore

Copy the block above into `.gitignore`. Also remove or update the stale `analysis/` entries on lines 67-74.

### Step 3: Remove newly-ignored files from git tracking

This removes the files from the git index (so they stop being tracked) but keeps them on disk (so the pipeline doesn't need to be re-run).

```bash
# Generated CSVs and RDS outputs
git rm --cached 06_analysis/output/*.csv 06_analysis/output/*.rds 2>/dev/null

# Generated figures
git rm --cached 06_analysis/figures/manuscript/*.pdf 06_analysis/figures/manuscript/*.png 2>/dev/null
git rm --cached 06_analysis/figures/supplementary/*.pdf 06_analysis/figures/supplementary/*.png 2>/dev/null
git rm -r --cached 06_analysis/figures/supplementary/exploratory/ 2>/dev/null
git rm -r --cached 06_analysis/figures/supplementary/diagnostics/ 2>/dev/null
git rm -r --cached 06_analysis/figures/supplementary/meta_analysis/ 2>/dev/null

# Parameter lists
git rm --cached parameter_lists/*.rds 2>/dev/null

# Verify the right files are kept (should still track README.md and figure_legends.txt)
git status
```

### Step 4: Commit the .gitignore change

```bash
git add .gitignore
git commit -m "Stop tracking generated outputs, figures, and parameter files

Regenerate with: Rscript 06_analysis/scripts/run_all.R
Removes ~440 generated files from tracking to eliminate pipeline-run diffs."
```

## literature/pdfs/ — Separate Action Needed

**146 PDFs (487 MB) are currently tracked in `literature/pdfs/`.** These are not in `.gitignore`. This is a significant concern:

- Every clone downloads 487 MB of PDFs
- Binary files in git history can never be fully removed without `git filter-branch` or `git filter-repo`
- The PDFs were first committed on 2025-03-25

**Recommended options (pick one):**

1. **Git LFS** (easiest if staying on GitHub): Track `literature/pdfs/**/*.pdf` with LFS. GitHub free tier includes 1 GB LFS storage.
   ```bash
   git lfs install
   git lfs track "literature/pdfs/**/*.pdf"
   git add .gitattributes
   git add literature/pdfs/
   git commit -m "Move literature PDFs to Git LFS"
   ```

2. **Shared drive / cloud storage**: Move PDFs to Google Drive, Dropbox, or a lab NAS. Add `literature/pdfs/*.pdf` to `.gitignore` and keep a `literature/pdfs/README.md` with the download link. Run `git rm --cached literature/pdfs/*.pdf` after.

3. **Do nothing for now**: If the repo is private and collaborators have fast connections, the 487 MB may be acceptable. But it will grow with each added paper.

The proposed `.gitignore` block above comments out the `literature/pdfs/` line — uncomment it if you choose option 2.

## Impact

| What | Files removed from tracking | Size freed from diffs |
|------|---------------------------|----------------------|
| Pipeline outputs | ~291 | ~35 MB |
| Figures | ~144 | ~30 MB |
| Parameter lists | ~6 | ~360 KB |
| **Total** | **~441** | **~65 MB per pipeline run** |
| Literature PDFs (separate) | 146 | 487 MB (one-time) |
