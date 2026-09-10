# Public-release review

This document describes the repository's release preparation. It does not change GitHub visibility or constitute editorial approval.

## Analysis readiness

[Workflow and design notes](refactor_notes.md) describe the measures, outputs and validation approach.

The full pipeline has run successfully locally. Verification checks the analysis and an explicit list of required artifacts. Passing checks do not guarantee that no undiscovered errors remain.

## Decisions and checks before publication

- Read the regenerated [reporter brief](../outputs/reporter_brief.md), [Georgia national comparison brief](../outputs/georgia_national_comparison_brief.md) and [methodology](methodology.md). Confirm the age-30-plus population, explicit denominators and distinction between responsibility and legal custody.
- Review city-specific wording against the consolidated-place/county comparison. National percentage ranks are among eligible observations, with exclusions shown; rankings are not significance tests.
- Review the six graphics and geographic exports. Outputs retain internal-review wording and watermarks pending Jennifer's publication decision.
- Choose a code license and confirm any applicable newsroom requirements before inviting public reuse. No code license is currently included; Census data provenance is separate from the code license.
- Review the exact files staged for the first commit for credentials, unrelated reporting material and unintended local files. Keep API keys in a user-level `.Renviron`; raw caches, session files and the unrelated reporting note are excluded by `.gitignore`.
- Follow the README's dependency setup, including PeeblesToolbox. A fresh download requires network access and a Census API key; committed tables and briefs can be read without running R.
- Confirm the intended GitHub destination and visibility before pushing or publishing. Jennifer controls the release decision; this document does not certify that a push or public release has occurred.

## Verification and reproducibility

The pipeline covers states/DC, the direct U.S. estimate, national counties and national places, with Georgia subsets. Raw response caches support reruns. Current checks cover variable definitions, additive counts, duration denominators, uncertainty screens, national positions, Georgia comparisons, map joins, geographic exports and required output files. Results are recorded in [verification.txt](verification.txt); local package versions are recorded in the ignored `logs/session_info.txt`.

The Windows locale guard addresses unsupported character locales. The full runner treats warnings as errors, and CSV exports make limited retries for temporary file-open failures before stopping with a file-specific error. The reporter brief is checked for the configured ACS period and deterministic regeneration.

The full analysis must be reviewed alongside its checks. No independent legal-boundary certification, significance tests, trend analysis or final editorial signoff is established by pipeline completion.
