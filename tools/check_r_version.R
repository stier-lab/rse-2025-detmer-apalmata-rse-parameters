#!/usr/bin/env Rscript

# Fail fast before a potentially long renv restore or pipeline run.  The lockfile
# was generated under a specific R version, so a different major/minor version
# is not treated as a reproducible environment.

lockfile <- "renv.lock"
if (!file.exists(lockfile)) {
  stop("Missing renv.lock", call. = FALSE)
}

lock <- renv::lockfile_read(lockfile)
expected <- lock$R$Version
actual <- paste(R.version$major, R.version$minor, sep = ".")

if (!identical(actual, expected)) {
  stop(
    sprintf(
      "R %s is installed, but renv.lock requires R %s. Install or select R %s before running renv::restore() or the analysis pipeline.",
      actual, expected, expected
    ),
    call. = FALSE
  )
}

cat(sprintf("PASS - R %s matches renv.lock.\n", actual))
