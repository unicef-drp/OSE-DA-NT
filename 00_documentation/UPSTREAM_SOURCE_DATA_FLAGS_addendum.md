---

## Flag 2: Hardcoded Fixes and Exceptions in Downstream Pipelines (Projections, DW-Production)

This section catalogs known data fixes and business-rule exceptions currently implemented in the projections pipeline (further_transformation_system/projections_progress_class) and DW-Production nt folder, with recommendations for migration and upstream correction.

### 2.1 BHR Overweight Exclusion
- **Current location:** projections_progress_class/012_codes/1a_import_inputs.r
- **Description:** Excludes Bahrain (BHR) overweight (NT_ANT_WHZ_PO2_MOD) from projections outputs due to known upstream data issue.
- **Recommendation:**
  - **Move to analysis_datasets:** Yes. Implement this exclusion in the analysis_datasets/02_codes build scripts so all downstream consumers receive already-filtered data.
  - **Flag for upstream fix:** Yes. The root cause should be corrected in the CMRS source data so this exclusion is not needed.

### 2.2 Nicaragua (NIC) Assessment Not Possible Flag
- **Current location:** projections_progress_class/012_codes/8_format_output.r
- **Description:** For NIC, sets `assessment_not_possible_flag` and `fullclassification_2030` for NT_ANT_HAZ_NE2_MOD and NT_ANT_WHZ_PO2_MOD due to data limitations.
- **Recommendation:**
  - **Move to analysis_datasets:** Yes, if the limitation is due to a known data issue. Centralize the flagging logic in the build scripts.
  - **Flag for upstream fix:** Yes. The underlying data issue should be addressed in the CMRS source.

### 2.3 Fixed AARR Target Values (Business Rule)
- **Current location:** projections_progress_class/012_codes/3_ane_wra_series.r, 6_bw_lbw_series.r
- **Description:** Uses fixed values (3.78 for 50% reduction, 1.96 for 30% reduction) for required AARR in certain cases. This is a business rule, not a data fix.
- **Recommendation:**
  - **Move to analysis_datasets:** No. This logic is projections-specific and should remain in the projections pipeline.
  - **Flag for upstream fix:** No. Not a data error.

### 2.4 Other Hardcoded Business Rules
- **Current location:** projections_progress_class/012_codes/8_format_output.r and related scripts
- **Description:** Some overrides are business rules requested by the nutrition team for reporting/classification. These are not data corrections.
- **Recommendation:**
  - **Move to analysis_datasets:** No, unless they address a specific, recurring data error.
  - **Flag for upstream fix:** Only if the rule is compensating for a known, correctable data issue.

---

**Action Items:**
- [ ] Move BHR overweight exclusion and NIC assessment-not-possible flagging to analysis_datasets build scripts.
- [ ] Coordinate with upstream data managers to correct these issues in CMRS source files.
- [ ] Keep projections-only business rules in the projections pipeline.

*Last reviewed: 2026-04-14*
