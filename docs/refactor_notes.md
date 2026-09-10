# Analysis workflow and design notes

This document describes the analysis definitions, workflow, outputs and reusable components.

## Measures and validation

The code uses B10050_002 for co-resident grandparents age 30+, _003 for those responsible and _008 for those responsible five years or more. Variable labels are checked against the configured ACS release before analysis.

The current overall caregiving percentage divides responsible grandparents by co-resident grandparents. Each of the five duration percentages divides its category by responsible grandparents. Additive checks verify that duration counts sum to responsible grandparents and that responsible plus not responsible sums to co-resident grandparents. See [duration definitions](duration_denominators.md).

The national comparison uses the direct U.S. estimate. County and place percentage rankings screen uncertainty in the specific percentage as well as the caregiver count. Ties share ranks; missing or ineligible observations retain their exclusion reasons and receive no rank.

## Current workflow and outputs

The root `run_all.R` runs scripts 00 through 08 in order. `helpers.R` is loaded by setup rather than run as a separate step. The workflow includes:

- Variable reconnaissance and a dictionary in CSV, XLSX and Markdown formats.
- Rankings for 50 states and DC, Georgia summaries and a direct U.S. comparison.
- National county and place analyses for the 50 states and DC, with ranks, percentiles, deciles and Georgia extracts. See [national comparisons](national_comparisons.md).
- Georgia count, percentage, duration and minimum-size place views, plus consolidated-government comparisons and reporter seed tables.
- Deterministic reporter briefs, uncertainty flags, reconciliation checks and record-level exclusion audits.
- Six review graphics and geographic exports: Georgia charts and county maps, a national county map and a state/DC map. Static maps use Web Mercator; GeoJSON exports use WGS84.
- Final analytical and output verification using an explicit required-file list. Verification does not require Git.

Existing Georgia output filenames remain available alongside national outputs. GEOIDs remain character strings, missing values are preserved, and percentages use explicit denominators and percentage-point margins of error. See [methodology](methodology.md) for interpretation and limits.

## Reuse and scope

National ACS retrieval uses tidycensus. The shared retrieval helper retains PeeblesToolbox's `get_state_acs()` for Georgia-only queries; scripts 03 and 04 retrieve national data and extract Georgia after assigning national positions. Graphics also use PeeblesToolbox themes, watermarks, boundary retrieval and export helpers.

The project-specific ranking and exclusion-summary helpers may be candidates for future PeeblesToolbox reuse after broader testing. Their screening thresholds are project choices, not universal Census reliability rules.

Successful verification does not guarantee that no undiscovered errors remain. Future corrections should be documented, and publication decisions remain separate from pipeline completion.
