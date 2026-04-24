"""One-time migration: convert source xlsx reference tables to repo CSVs.

Reads from the legacy SharePoint Export folder (read-only) and writes
lowercase_snake_case CSVs into the repo `reference_data_manager/` tree.

The original folder is never modified.

Run once:
    python reference_data_manager/02_codes/_migrate_xlsx_to_csv.py
"""

from __future__ import annotations

import re
from pathlib import Path

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[2]
SRC = Path(
    r"C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/"
    r"Combined Nutrition Databases/Post-Processing System/2 - Reference Data Manager/Sharepoint Export"
)
RDM = REPO_ROOT / "reference_data_manager"
REF_TABLES = RDM / "reference_tables"
CROSSWALK = RDM / "crosswalk"
INDICATORS = RDM / "reference_tables"  # legacy 'indicators/' folder consolidated into reference_tables/

# Map source xlsx (file name, sheet name) -> destination csv path.
# Sheet name is the first sheet unless overridden.
JOBS: list[tuple[str, str | None, Path]] = [
    # Editable reference tables -> reference_tables/
    ("DIRECTORY_COUNTRY.xlsx",                None, REF_TABLES / "directory_country.csv"),
    ("DIRECTORY_REGION.xlsx",                 None, REF_TABLES / "directory_region.csv"),
    ("REFERENCE_BACKGROUND_XTER.xlsx",        None, REF_TABLES / "reference_background_xter.csv"),
    ("REFERENCE_COLLECTION_MECHANISM.xlsx",   None, REF_TABLES / "reference_collection_mechanism.csv"),
    ("REFERENCE_COUNTRY_SURVEY_TYPE.xlsx",    None, REF_TABLES / "reference_country_survey_type.csv"),
    ("REFERENCE_CUSTODIANS.xlsx",             None, REF_TABLES / "reference_custodians.csv"),
    ("REFERENCE_DECISION.xlsx",               None, REF_TABLES / "reference_decision.csv"),
    ("REFERENCE_DECISION_CATEGORY.xlsx",      None, REF_TABLES / "reference_decision_category.csv"),
    ("REFERENCE_DELIVERY_MECHANISM.xlsx",     None, REF_TABLES / "reference_delivery_mechanism.csv"),
    ("REFERENCE_ESTIMATE_TYPE.xlsx",          None, REF_TABLES / "reference_estimate_type.csv"),
    ("REFERENCE_MONTH.xlsx",                  None, REF_TABLES / "reference_month.csv"),
    ("REFERENCE_NUTRITION_DOMAIN.xlsx",       None, REF_TABLES / "reference_nutrition_domain.csv"),
    ("REFERENCE_POP_LIST.xlsx",               None, REF_TABLES / "reference_pop_list.csv"),
    ("REFERENCE_PSAC_CHILD_AGE.xlsx",         None, REF_TABLES / "reference_psac_child_age.csv"),
    ("REFERENCE_SUBDOMAIN.xlsx",              None, REF_TABLES / "reference_subdomain.csv"),
    ("REFERENCE_SURVEY_CATEGORY.xlsx",        None, REF_TABLES / "reference_survey_category.csv"),
    ("REFERENCE_SURVEY_TYPE.xlsx",            None, REF_TABLES / "reference_survey_type.csv"),
    ("REFERENCE_YEAR_ASSIGNMENT_METHOD.xlsx", None, REF_TABLES / "reference_year_assignment_method.csv"),
    ("REFERENCE_YEARS_OF_SURVEY.xlsx",        None, REF_TABLES / "reference_years_of_survey.csv"),

    # Indicator + disaggregations -> reference_tables/ (overwrite existing copies)
    ("DIRECTORY_INDICATOR.xlsx",              None, INDICATORS / "directory_indicator.csv"),
    ("REFERENCE_DISAGGREGATIONS.xlsx",        None, INDICATORS / "reference_disaggregations.csv"),

    # Wide hand-curated crosswalk source -> crosswalk/ (single editable csv)
    ("DIRECTORY_CROSSWALK (Beta).xlsx",       None, CROSSWALK / "directory_crosswalk_base.csv"),
]


def drop_attachments(df: pd.DataFrame) -> pd.DataFrame:
    """SharePoint exports include an 'Attachments' column that is always empty.
    Strip it to keep CSVs lean. Keep all other columns as-is.
    """
    cols = [c for c in df.columns if str(c).strip().lower() != "attachments"]
    return df[cols]


def main() -> None:
    for d in (REF_TABLES, CROSSWALK, INDICATORS):
        d.mkdir(parents=True, exist_ok=True)

    for fname, sheet, dest in JOBS:
        src = SRC / fname
        if not src.exists():
            print(f"SKIP missing source: {fname}")
            continue
        try:
            df = pd.read_excel(src, sheet_name=sheet if sheet is not None else 0, dtype=str)
        except Exception as e:
            print(f"ERR {fname}: {e}")
            continue
        df = drop_attachments(df)
        # Replace Excel artefacts: nan strings written by dtype=str path.
        df = df.replace({"nan": pd.NA})
        dest.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(dest, index=False, lineterminator="\n")
        print(f"OK {fname} -> {dest.relative_to(REPO_ROOT)}  ({df.shape[0]} rows x {df.shape[1]} cols)")


if __name__ == "__main__":
    main()
