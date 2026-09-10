# Duration denominators and renamed fields

The five duration categories (B10050_004 through B10050_008) partition B10050_003, the grandparents responsible for their own co-resident grandchildren under 18. Every duration percentage uses **responsible_total** as its denominator. These are people age 30 or older, not households, grandchildren, or all grandparents in the geography.

B10050_002 is now named **coresident_grandparents_total**: grandparents age 30+ living with their own grandchildren under 18. `pct_responsible` continues to divide responsible_total by this co-resident total. The five-plus-year formula has not changed; its name and presentation now make the denominator explicit.

| Source | Count alias | Percentage field |
|---|---|---|
| B10050_004 | less_than_six_months | percent_responsible_grandparents_less_than_six_months |
| B10050_005 | six_to_eleven_months | percent_responsible_grandparents_six_to_eleven_months |
| B10050_006 | one_or_two_years | percent_responsible_grandparents_one_or_two_years |
| B10050_007 | three_or_four_years | percent_responsible_grandparents_three_or_four_years |
| B10050_008 | five_plus_years | percent_responsible_grandparents_five_plus_years |

All five percentages use 0-100 units and have `_moe`, `_ci90_lower`, `_ci90_upper`, `_cv_percent` and `_exclusion` fields. Percentage MOEs are in percentage points and use the same subset-proportion method as before. The percentages sum to 100 when all five counts and a positive responsible total are available; rounded percentages may not add to exactly 100. MOEs do not add to the total MOE.

## Reconciliation

Before analysis, each source pull saves two checks by GEOID in `outputs/*_reconciliation.csv` with a companion summary:

1. Sum of all five duration counts equals responsible_total.
2. responsible_total + not_responsible equals coresident_grandparents_total.

Statuses are `Pass`, `Mismatch`, or `Unable to verify`. Summation does not remove missing values. A complete-input mismatch stops processing after saving its audit. Missing inputs are not filled or treated as zero. Checks run on retrieved rows before geographic-scope exclusions; the existing scope-exclusion audits explain any territories omitted from final analysis.

## Output migration

This is an intentional column-name change across clean data, rankings, reporter exports and GeoJSON:

- `grandparents_total` becomes `coresident_grandparents_total`, including `estimate_` and `moe_` versions.
- `pct_five_plus` becomes `percent_responsible_grandparents_five_plus_years`, including uncertainty and exclusion suffixes.
- `map_pct_five_plus` becomes `map_percent_responsible_grandparents_five_plus_years` in the Georgia GeoJSON and mapped CSV.

Old ambiguous aliases are not retained. Update saved spreadsheet formulas or Datawrapper field selections that use the old names. Existing output filenames and ranking behavior are preserved.

`outputs/reporter_duration_composition.csv` provides one row per duration and geography for states/DC, U.S., Georgia counties and Georgia places. It includes the numerator, the explicitly named responsible-grandparent denominator, source code, percentage, MOE and precision disposition. National county data include all five durations in the clean wide table and GeoJSON.

The reporter brief shows Georgia's five-part composition and explicitly introduces long-term county percentages as shares among responsible grandparents. The long-term map uses that same denominator in its subtitle. No additional charts or new denominators were introduced.

QA-flag files now consider all five duration precision flags, so more geographies may appear there. This does not change eligibility for the existing caregiving or five-plus-year rankings, which still use their own metric-specific screens. Fresh downloads passed both reconciliations for every retrieved row. Refresh downloads has been returned to FALSE for routine cached runs.
