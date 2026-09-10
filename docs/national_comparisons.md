# National county and place comparisons

Scripts 03 and 04 now analyze counties and places across the **50 states and DC**, respectively. Territories are excluded and saved in scope-exclusion audits. Counties compete only with counties; places compete only with places. Places include incorporated places, Census-designated places and consolidated-government balances, not every jurisdiction someone might call a city or town. County equivalents follow the configured ACS release (including Connecticut planning regions).

## Start here

- `county_national_rankings` and `place_national_rankings`: full national dataframes, ordered by the overall caregiving percentage's national rank, with unranked rows last.
- `georgia_county_national_comparison` and `georgia_place_national_comparison`: all Georgia observations, retaining their NATIONAL positions.
- CSVs: `outputs/georgia_county_national_comparison.csv`, `outputs/georgia_place_national_comparison.csv`.
- Full national CSVs: `data_clean/us_counties_grandparents.csv`, `data_clean/us_places_grandparents.csv`.
- Reporter summary: `outputs/georgia_national_comparison_brief.md`.

The historical script filenames remain `03_georgia_counties.R` and `04_georgia_places.R`. Inside them, `county_raw`/`county_wide` and `place_raw`/`place_wide` now cover the national scope. Existing Georgia-only filenames and named ranking objects retain their Georgia scope and downstream uses. Georgia files add national-position columns alongside local ranks; the national columns are calculated BEFORE subsetting to Georgia.

## Position definitions

`national_rank_caregiving_percent`: descending competition rank, with 1 highest; ties share ranks and leave gaps. `national_percentile_caregiving_percent`: 100 times (number of eligible values below this value + half the number tied at this value) / eligible N. Higher means a larger value, not a better outcome. This midrank percentile gives all tied observations the same position; a singleton or all-equal group has percentile 50.

`national_decile_caregiving_percent`: ceiling(percentile / 10), bounded to 1-10. Decile 1 is the lowest percentile bracket and 10 the highest. Brackets are (0,10], (10,20], ... (90,100]. Ties stay together, so decile groups need not be equal in size. Small datasets may leave some deciles empty. This is a percentile position, not a raw percentage or a confidence interval.

`eligible_n_caregiving_percent` is the number actually eligible for this ranking. `exclusion_reason_caregiving_percent` explains unavailable positions. Excluded rows retain estimates and flags, but their rank, percentile and decile are NA. An eligible set of size zero produces no positions.

The same five position/disposition columns are provided for `caregiver_count` and each of the five duration suffixes. Places also have `story_scale_caregiving_percent`, requiring at least the configured co-resident-grandparent threshold in addition to precision eligibility. Duration percentages still use responsible grandparents as their denominator; the overall caregiving percentage uses co-resident grandparents.

## Eligibility and limits

Percentage rankings use each metric's existing uncertainty screen: both caregiver-count and metric MOEs must be available and no more than the configured severe threshold (50% by default) of their estimates. Nonpositive denominators and undefined relative precision are excluded. The five duration categories are screened separately. Count rankings include all available counts with uncertainty flags alongside; they are not filtered for precision.

The unthresholded place ranking and the minimum-size place ranking are separate comparisons. Comparisons are sensitive to which observations meet the screen; do not call a rank among eligible counties a rank among every county without explaining the exclusions. Deciles and percentile gaps are descriptive; no statistical significance or causation is established.

No geometry is needed for the national place analysis. The existing national county map now reads script 03's national data rather than overwriting it. Georgia maps and the consolidated-government comparison still use Georgia subsets. Raw cache names explicitly separate `us_county` and `us_place` from the older Georgia-only caches; verification now checks Georgia extracts against the national caches. The old Georgia caches and source notes may remain on disk as historical downloads, but these steps no longer read them.

Machine-readable audit files `outputs/national_county_ranking_audit.csv` and `outputs/national_place_ranking_audit.csv` have one row per geography and metric, with exclusion reason, eligible N, rank, percentile and decile. Their summary files account for every received geography for each metric. Preserve GEOIDs and state FIPS as character strings when importing CSVs.
