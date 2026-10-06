"""Draft static_mappings/pay_category_mapping.csv: Oasis pay codes and Fusion pay-value elements to pay categories.

Keyword rules, first match wins. Codes with no rule are written with PAY_CATEGORY 'Unmapped' for the BI manager to
complete. Fusion: only elements that carry a 'Pay Value' input; a deduction element without 'Results' whose
'<name> Results' twin exists is 'Not pay' (the pair records the same deduction twice).

Usage:  python scripts/draft_pay_category_map.py
"""
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "static_mappings" / "pay_category_mapping.csv"

OASIS_RULES = [
    (r"^HOUS_GURNT$", "Other deductions"),
    (r"^STAFF GOSI$|^GOSI_ADJ$", "GOSI employee deduction"),
    (r"^BASIC", "Basic"),
    (r"^HOUS", "Housing"),
    (r"^TRANSP", "Transport"),
    (r"^FOOD", "Food"),
    (r"CRITIC|NUR_ALLW|WRK_NT|WORK_TYPE|WORK TY|^D_H_ALOW", "Clinical allowances"),
    (r"OVERTIM|^FIXOT$", "Overtime"),
    (r"ANN_LEAVE|VAC_PAY|LEAV_PAY|PAY_LEAVE|TIME ?BACK|STUDYLEAVE|MATERNITY|DEATH LEAV", "Leave pay"),
    (r"^PAYAWARD$", "Awards and bonus"),
    (r"HRS_N_WRKD|ABSENCE|^LATE$|SICK|UNPAID|VAC_NOTENT|SHORTAGE|DISPL_DED", "Absence and lateness deduction"),
    (r"^LOAN", "Loans and advances"),
    (r"BANK_CHARG|^WATER$|ELECT|MISC_DED|IQAMA_FEES|WORK_PERM|MCT_EA|EXAM FEES|^MOH$", "Other deductions"),
    (r"SUPV|SUPERV|RECP_ALLOW|DEFC_ALLOW|JZN_ALOWNC|MOBILE|CAR_|SPECIAL|OTHER|ACTINGUP|PROJ_ALLW|B_BANK_ALW|TICK|INSURANCE|ADJ_STAFF|STAFF_ADJ|RETURN_PAY", "Other allowances"),
]

FUSION_NAME_RULES = [
    (r"gosi adjustment deduction", "GOSI employee deduction"),
    (r"loan", "Loans and advances"),
    (r"bank charges|admin penalty|other deductions|shortage", "Other deductions"),
    (r"delay|absence|early leave|one punch|basic salary deduction|allowance deduction|penalty", "Absence and lateness deduction"),
    (r"^basic salary", "Basic"),
    (r"^housing", "Housing"),
    (r"^transportation", "Transport"),
    (r"^food", "Food"),
    (r"critical area|nurse|work nature", "Clinical allowances"),
    (r"overtime", "Overtime"),
    (r"annual leave|encashment|time back", "Leave pay"),
    (r"end of service", "End of service"),
    (r"gosi adjustment|other allowance|supervisor|deficit|department head|special|reception|mobile", "Other allowances"),
]


def first(rules, text):
    return next((cat for pattern, cat in rules if re.search(pattern, text)), "Unmapped")


def main():
    c = client()
    oasis = c.query(
        "select distinct upper(trimBoth(trx_type)), upper(trimBoth(ifNull(payable_type, ''))) "
        "from oasis.account_transactions final where trx_type is not null"
    ).result_rows
    rows = []
    for code, payable in sorted(oasis):
        cat = "GOSI employer charge" if payable == "K" else first(OASIS_RULES, code)
        rows.append(("oasis", code, payable, cat))
    fusion = c.query(
        "select distinct e.element_name, e.classification_name "
        "from fusion.dim_payroll_element e final "
        "join (select distinct element_type_id from fusion.dim_payroll_input_value final "
        "      where input_value_base_name = 'Pay Value') i on i.element_type_id = e.element_type_id "
        "where e.is_current = 'Y' and e.element_name is not null"
    ).result_rows
    names = {n for n, _ in fusion}
    for name, cls in sorted(fusion):
        low = name.lower()
        if cls == "Information":
            cat = "Not pay"
        elif cls == "Employer Charges":
            cat = "GOSI employer charge" if "gosi" in low else "Other employer charges"
        elif cls == "Social Insurance Deductions":
            cat = "GOSI employee deduction"
        elif "deduction" in low and not low.endswith("results") and f"{name} Results" in names:
            cat = "Not pay"
        else:
            cat = first(FUSION_NAME_RULES, low)
        rows.append(("fusion", name, "", cat))
    with open(OUT, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SOURCE", "SOURCE_CODE", "PAYABLE_TYPE", "PAY_CATEGORY"])
        w.writerows(rows)
    unmapped = sum(1 for r in rows if r[3] == "Unmapped")
    print(f"{len(rows)} codes ({len(oasis)} Oasis, {len(fusion)} Fusion), {unmapped} unmapped -> {OUT}")


if __name__ == "__main__":
    main()
