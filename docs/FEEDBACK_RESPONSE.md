# Feedback Response Summary

> **Note:** Web platform feedback has been moved to the [platform repository](https://github.com/stier-lab/Detmer-2025-coral-platform).

Date: January 2026
Reviewer: MB
Source: comments_MB_Acropora_Palmata_Demographics.pdf

## Issues Addressed

### Completed

#### 1. Size Variance Explanation (Issue #8 - Overall feedback)
**Status:** Addressed
**Note:** The question "If size explains only 8.6% of survival variance, why base decisions on it?" is answered comprehensively in the manuscript discussion. Size is a controllable variable at the point of outplanting, whereas other predictors (depth, distance to shore, ocean chemistry) are site-specific and not systematically measured across studies.

#### 2. Survival Timing Clarification (Issue #9 - Overall feedback)
**Status:** Addressed
**Changes:**
- Clarified that survival estimates are annualized (original study intervals range from 6 months to 2 years)
- Added explanation distinguishing short-term vs long-term survival
- Example: 80% annual survival = ~33% 5-year survival if rate is stable

---

## Issues Requiring Further Investigation

### Data Quality

#### Issue #5: Navassa Growth Outlier
**Problem:** Navassa mean growth = 826.1 cm²/yr (vs 20-100 typical for other regions)
**Impact:** Misleading regional comparison
**Possible Causes:**
- Data entry error (possibly mislabeled units)
- Methodology mismatch (linear extension vs planar area)
- Study-specific measurement protocol difference
**Next Steps:**
- Review raw Navassa growth data
- Check source study methodology
- Either correct the data or flag as unreliable with caveat in the manuscript

---

## Overall Feedback Themes

### Positive
- Tangible size comparisons ("laptop", "beach blanket") are helpful for communicating size classes
- Clear presentation of uncertainty and data limitations

### Questions Raised
1. **Better metrics than size?** Reviewer asks if there are better predictors (depth, distance to shore, ocean chemistry)
   - **Response:** Size is the only controllable variable at the point of outplanting. Other factors are site-specific and not systematically measured across studies. This is discussed in the manuscript.

2. **Survivability timing?** Reviewer unclear about 1yr vs 5yr vs 10yr survival
   - **Response:** Addressed by clarifying annualized estimates in the manuscript methods.

---

## Next Actions

**Data Quality:**
1. Investigate Navassa growth outlier — verify raw data and source study methodology

**Manuscript:**
2. Ensure discussion adequately addresses why size is used despite low R² (8.6% McFadden for survival GLM; 5.8% GAM deviance explained)
3. Ensure methods section clearly states that survival estimates are annualized and that study intervals vary (6 months to 2 years)
