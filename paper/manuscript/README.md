# Manuscript compendium

This directory follows the `Stier-CAFI-Pocillopora-2026` pattern: editable
manuscript source, BibTeX citations, an assembled Markdown artifact, deterministic
DOCX/PDF rendering, and build checks. The current canonical prose source is
`../../07_reporting/manuscript/acropora_palmata_demography_manuscript_draft.md`.

Run `make manuscript-assemble`, then `make manuscript-render`. The render only
succeeds when every Pandoc citation key resolves in `references.bib`. Add and verify
new bibliography records before replacing any remaining narrative author--year
citations with Pandoc keys.
