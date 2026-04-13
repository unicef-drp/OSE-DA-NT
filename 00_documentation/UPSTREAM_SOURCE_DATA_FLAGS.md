# Upstream Source Data Flags

This document records known source-data issues detected during the CMRS2 build pipeline.
These are cataloguing errors in the upstream Combined Nutrition Database (CND) that produce
duplicate analytical keys in the analysis datasets.

The pipeline now auto-deduplicates these during the build (see `dedup_analytical_key()` in
`analysis_datasets/02_codes/0_layer2_utils.r`), but the root causes should be corrected
upstream so the dedup step becomes a no-op.

---

## Flag 1: TGO 2008 (Survey 671) — Savanes region double-entered

| Field | Value |
|---|---|
| **Source file** | CMRS_ANT.dta |
| **UNICEF_Survey_ID** | 671 |
| **REF_AREA** | TGO |
| **TIME_PERIOD** | 2008 |
| **Survey** | Togo National Nutrition Survey using SMART Methodology, December 2008 |
| **Indicator affected** | ANT_WHZ_NE2_T_NE3 (Weight-for-height < -2 SD and >= -3 SD) |
| **BackgroundCharacteristics** | Subnational Region |
| **warehouse_strat_label** | Savanes |
| **Detected** | 2026-04-13 |

### Description

The same observation for the Savanes region is entered as two separate rows with different
`standard_disagg` IDs:

| Row | entryid | standard_disagg | StandardDisaggregations |
|---|---|---|---|
| 1 | 1178876 | 39 | Region 8 |
| 2 | 1024313 | 36 | Region 5 |

Both rows have identical values:

- r = 0.074
- ll = 0.051, ul = 0.107
- weighted_N = 645
- DataSourceDecisionCategory = Accepted

Both `standard_disagg` IDs (36 = "Region 5", 39 = "Region 8") map to
`Background Characteristics = Subnational Region` in `reference_disaggregations.csv`
with no dimension-specific HELIX/OSE mappings. Since `warehouse_strat_label` is "Savanes"
for both, the REGION dimension resolves to "Savanes" for both rows — producing an
identical analytical key with identical values.

### Impact

Without dedup, this produces 2 duplicate rows in the output `cmrs2_ant.parquet` and
`cmrs2_ant_accepted.parquet`.

### Recommended fix

Remove the duplicate entry from CMRS_ANT.dta — either entryid 1178876 or 1024313.
The Savanes region should appear under only one Region slot for this survey.

---

*To add new flags, copy the template above and increment the flag number.*
