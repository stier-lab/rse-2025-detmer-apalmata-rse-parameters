# Mendoza-Quiroz et al. (2023) population-type memo

## Evidence reviewed

The unmodified source workbook is `05_data/original/MendozaQuiroz2023Data.xlsx`.
The standardized individual file records 52 survival intervals for
`mendoza_quiroz_et_al_2023`, all currently coded `fragment = N` and therefore
as `Natural colony` by the preparation script.  The record notes identify
Puerto Morelos nursery observations and field observations at Cuevones and
Picudas; Cuevones records explicitly state `treatment_2 = initial nursery`.
The study-characteristics record describes the study as a multi-step
restoration programme with in-situ nursery juveniles and outplanted colonies,
and separately identifies an ex-situ new-settler component that is excluded
from the meta-analysis.

## Interpretation

The included records are not naturally recruited wild colonies. They are the
field/nursery stages of sexually propagated restoration material. The present
`Natural colony` code therefore describes the absence of a fragment flag, not
the biological origin of the colonies. This memo does not change that code.

## Current analytical consequences

With the present coding, these 52 records enter the natural-colony transition
dataset and size-class synthesis. They also enter the disturbance overlays and
the natural-colony comparison shown in repository FigS8 (ESM Fig. S2). The
leave-one-study-out transition result supplied by the current analysis is
lambda = 0.953 when this study is excluded.

## Decision required

If the records remain coded as natural colonies, the current natural-colony
matrix, Fig. S2 comparison, and disturbance models remain unchanged. If they
are reclassified as restoration material, they should be removed from the
natural-colony matrix and natural-colony panels and included only where the
restoration definition is biologically appropriate; the resulting matrix,
Fig. S2, and disturbance models must then be rerun. The required biological
decision is whether sexually propagated, outplanted/nursery colonies belong in
the restoration population type even when they are not asexually fragmented.
