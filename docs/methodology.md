# Methods and reporter notes

## Source and population

Source: [2024 ACS five-year detailed table B10050](https://data.census.gov/table/ACSDT5Y2024.B10050), covering 2020–2024. B01003 supplies total population for the additional place rate. Settings live in `scripts/00_setup.R`; the pipeline checks B10050 labels against the selected vintage before analysis. Changing years requires reviewing the methodology and geography notes as well as rerunning.

| Measure | Estimate variable | Denominator |
|---|---|---|
| Grandparents living with own grandchildren under 18, age 30+ | B10050_002 | None: count of people |
| Those responsible for own grandchildren | B10050_003 | B10050_002 for `pct_responsible` |
| Responsible for five years or more | B10050_008 | B10050_003 for `percent_responsible_grandparents_five_plus_years` |
| Total place population | B01003_001 | Used only for caregivers per 1,000 residents |

See [duration denominators and field migration](duration_denominators.md) for all five duration categories, their percentages, and additive-count checks.

The suffixes E and M identify estimates and margins of error in the Census API. Tidycensus returns them as separate fields. The full source dictionary is in `docs/b10050_variable_dictionary.csv`.

## Calculations and uncertainty

All `pct_responsible` and `percent_responsible_grandparents_*` estimates use 0–100 units; their `_moe` fields are in percentage points. The historical `moe_ratio` column is a 0–1 ratio of caregiver-count MOE to estimate, **not** a coefficient of variation. `cv_*_percent` and `*_cv_percent` divide the relative MOE by the normal 90% critical value (about 1.645), then multiply by 100.

Derived percentage MOEs use [tidycensus::moe_prop](https://walker-data.com/tidycensus/reference/moe_prop.html), which accounts for a subset numerator and uses the ratio fallback when the subtraction under the square root is negative. This is an approximation. Confidence intervals use estimate ± MOE, bounded at zero for counts and 0–100 for percentages. Bounding the interval does not increase precision. MOEs are at 90% confidence.

County and place percentage rankings exclude unavailable values, nonpositive denominators, undefined relative precision, caregiver-count MOE above 50% of the count, or the specific percentage MOE above 50% of that percentage. A zero percentage has undefined relative precision and is excluded from percentage rankings, but its zero estimate remains in the clean data. The original 30% count-MOE warning and 50% severe warning are retained. These are project screening rules, not official Census reliability classifications; 50% relative MOE corresponds to roughly 30.4% CV.

Count tables retain all available counts, including noisy estimates, and show their flags and MOEs. State rankings include available point estimates for the 50 states and DC, with QA flags alongside. Puerto Rico is explicitly excluded and saved in `state_scope_exclusions.csv`. Ranks share a number for exact ties and skip subsequent positions. A ranking is not a significance test. The U.S. comparison is a direct Census national estimate, not an unweighted mean of state percentages. No significance claim is made for the Georgia-minus-U.S. difference.

The place story-scale view additionally requires at least 100 estimated co-resident grandparents. The brief uses that same view. Every county/place percentage exclusion is saved by GEOID and reason, including records that failed several screens (the first applicable reason is reported). Summary counts reconcile retained and excluded rows to all received geographies.

## Missingness and geographic coverage

Scripts 03 and 04 retrieve all counties/equivalents and Census places in the 50 states and DC, calculate national positions, then extract Georgia. National rank, percentile and decile use each metric's eligible observations; exclusions remain in the data with missing positions. See [national comparisons](national_comparisons.md) for tie handling, eligible denominators, audits and output names. The Georgia county extract must contain 159 unique counties; the national tables must cover all 51 state/DC identifiers. Places include incorporated places and Census-designated places, rather than every local government.

No imputation is performed. Zero is retained as zero; division by zero yields unavailable, never infinity. Negative Census special values are treated as unavailable in calculations. Original tidycensus responses are cached intact; unavailable-input audits preserve whatever the client returned. Tidycensus may already convert Census annotation/sentinel values to NA, so a specific suppression reason cannot always be recovered from these responses. Missing MOEs are not replaced with zero.

GEOIDs are character strings; preserve leading zeroes when opening exports. Counties must contain 159 unique Georgia identifiers; states must contain 51 after excluding Puerto Rico. Duplicate geography-variable keys and incomplete variable coverage stop the pipeline. Each response is at geography × variable grain, pivoted to one row per geography. Geography tables are not appended as interchangeable observations.

Geographies are those supplied by the 2024 ACS release. County maps use matching 2024 Census 1:500,000 cartographic boundaries. Static maps use Web Mercator (EPSG:3857); GeoJSON for Datawrapper uses WGS84 (EPSG:4326), checked after export. See graphics_notes.md for joins and screening. No CRS applies to the rectangular CSV outputs. County and place populations overlap and must not be summed together. The Five Core Counties are flagged using their Census county GEOIDs. This project makes no metro or rural classification.

## Consolidated governments

The place query explicitly checks Athens–Clarke, Augusta–Richmond, Columbus and Macon–Bibb and retains the Census names and GEOIDs. Athens and Augusta appear as **balances**; Columbus appears as a city and Macon–Bibb as a county-named place. A place balance excludes separately incorporated places within a consolidated government. The full county remains available in the county analysis. See [Census geographic definitions](https://www.census.gov/programs-surveys/popest/guidance-geographies/terms-and-definitions.html).

`consolidated_government_check.csv` preserves the four place observations. Do not rename a balance as the entire consolidated government. The comparison audit matches those places to their parent county by explicit identifiers and shows the estimates side by side; a difference is not assumed to be an error or a statistical finding. This does not certify legal boundary equivalence. Review any proposed city-specific story wording with the Census geography definitions.

## Field guide

- `estimate_*`, `moe_*`: counts of people and corresponding 90% margins of error.
- `pct_responsible`: responsible / co-resident grandparents × 100.
- `percent_responsible_grandparents_five_plus_years`: responsible five-plus years / responsible grandparents × 100.
- `caregivers_per_1000_population`: responsible grandparents / all residents × 1,000; its MOE uses the same units.
- `*_ci90_lower`, `*_ci90_upper`: bounded 90% confidence interval endpoints.
- `*_exclusion`: ranking disposition and first applicable exclusion reason.
- `national_average_pct`: retained legacy name, now the direct U.S. percentage.
- `difference_from_average`: Georgia minus that U.S. percentage, in percentage points.
- `rank_*`, `story_rank`, `national_rank`: descriptive point-estimate ranks in the named table's eligible universe.
- `acs_year`, `acs_period`, `acs_product`: release year, full collection period and survey product.

The tables are estimates for reporting and review. They cannot establish causes, legal guardianship, service demand, the number of children being raised without parents, or annual change.
