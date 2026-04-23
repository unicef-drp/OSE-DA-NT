# crosswalk/ — DATA ENTRY

Contains the single editable wide base table:

- `directory_crosswalk_base.csv` — UNICEF-curated country classifications
  (Programme Region, SOWC, LDC_2020, hand-tagged groupings, etc.). Maps 1-to-1
  to the legacy `DIRECTORY_CROSSWALK (Beta).xlsx` sheet.

This is the editable base. The build script
`02_codes/2_build_directory_crosswalk.r` reads it, then merges in external
classifications (UNICEF, WHO, WB, SDGRC, AU, UNSDG, FAO_LIFDC) from the public
`unicef-drp/Country-and-Region-Metadata` repo and the SOFI progress flag, and
writes the wide computed `directory_crosswalk.csv` to
`{githubOutputRoot}/reference_data_manager/`.

The base file and the script-added columns have **zero column-name overlap**,
so each field in the final wide crosswalk has exactly one editable source of
truth (either this file, the external table, or the SOFI csv).

Do **not** put any derived/computed output in this folder.
