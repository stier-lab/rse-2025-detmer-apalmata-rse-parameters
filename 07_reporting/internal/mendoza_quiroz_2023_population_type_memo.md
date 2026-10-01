# Mendoza-Quiroz et al. (2023) population-origin audit

## Source evidence

The unmodified source workbook is `05_data/original/MendozaQuiroz2023Data.xlsx`.
It distinguishes an in-situ nursery, Cuevones Reef, and Picudas Reef. The reef
worksheets explicitly identify colonies as outplanted; the extraction record
describes the included component as in-situ nursery juveniles and outplanted
colonies. The standardized survival and growth files each contain 52 valid
Mendoza-Quiroz colony intervals: 17 in Puerto Morelos Nursery, 19 at Cuevones
Reef, and 16 at Picudas Reef. All have `fragment = N`.

`fragment` records asexual fragmentation, not biological origin. The included
observations are sexually propagated restoration material, not naturally
recruited wild colonies. The separate ex-situ new-settler component remains
excluded because it represents a non-comparable early life stage.

## Implemented classification

As of the 2026-09-30 provenance correction, the preparation pipeline assigns
all `mendoza_quiroz_et_al_2023` individual records the detailed class
`Restoration outplant (sexual recruit)`. Their physical `fragment = N` flag is
preserved. Analyses requiring the pre-specified two-level contrast collapse
this detailed class with other restoration pathways while retaining the source
class in prepared data.

## Downstream scope

The correction removes these 52 intervals from natural-colony-only transition,
size-dependent survival, and disturbance analyses; includes them in
restoration-aware comparisons; and adds them to the restoration-subtype audit
as `sexual_recruit_outplant`. The complete maintained pipeline and manuscript
artifacts are rebuilt after this change.
