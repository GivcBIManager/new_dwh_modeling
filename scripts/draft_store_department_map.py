"""Draft static_mappings/store_department_mapping.csv: store type and unified department of every Oasis store and Fusion
store (spec 4.2).

Fusion stores (organisation + subinventory, and '<org>/*' for the organisation level) take the organisation type
(suffix 01-03 warehouses, 04 pharmacy, 05 operating rooms, 06 wards, 07 clinics, 08 laboratory, 09 radiology,
10 administration, 11 support, 12 assets; Alrabwah N01-N04 pharmacy, ward, clinics, radiology). Oasis stores take the
type and department of the Fusion store they map to through the integration (the pair with the most transactions);
unpaired Oasis stores are typed by keywords in their name. Expiry, damaged and recall stores are recognised by code
(EXMED, EXMS, DMED, DAMS, RMED, RMS) and by the name keywords EXPIR, DAMAG, RECALL. Unified departments are drafted by
keywords; 'Not Mapped' and STORE_TYPE 'Unmapped' are left for the BI manager (open item O-P5-4).

Usage:  python scripts/draft_store_department_map.py [--out PATH]
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "static_mappings" / "store_department_mapping.csv"
INTEGRATION_TYPES = "(300000012981824, 300000012981825, 300000012981826, 300000012981827)"
EXPIRY_CODES = {"EXMED", "EXMS", "DMED", "DAMS", "RMED", "RMS"}
EXPIRY_WORDS = r"EXPIR|EXIRED|DAMAG|RECALL"
ORG_TYPES = {"01": "Warehouse", "02": "Warehouse", "03": "Warehouse", "04": "Pharmacy", "05": "Operating room",
             "06": "Ward", "07": "Clinic", "08": "Laboratory", "09": "Radiology", "10": "Administration",
             "11": "Support", "12": "Asset", "00": "Warehouse"}
NAME_TYPES = [
    (EXPIRY_WORDS, "Expiry/damaged/recall"),
    (r"PHARM", "Pharmacy"),
    (r"ASSET", "Asset"),
    (r"WAREHOUSE|\bSTORES?\b|SUBSTORE", "Warehouse"),
    (r"OPERATING|THEATRE|\bOT\b|\bOR\b|CATH", "Operating room"),
    (r"\bLAB\b|LABORATORY", "Laboratory"),
    (r"RADIOLOG|X-RAY|XRAY|IMAGING|NUCLEAR|\bMRI\b|\bCT\b", "Radiology"),
    (r"WARD|ICU|NICU|PICU|CCU|EMERGENCY|A&E|\bER\b|LABOUR|DELIVERY|DIALYSIS|ENDOSCOPY|INPATIENT|SHORT STAY|RECOVERY|NURSERY", "Ward"),
    (r"KITCHEN|DIET|CAFETERIA|LAUNDRY|HOUSEKEEPING|MAINTENANCE|SECURITY|TRANSPORT|HOUSING|FACILITY|BIO MEDICAL|CSSD", "Support"),
    (r"FINANCE|PAYROLL|\bHR\b|PERSONEL|PERSONNEL|\bIT\b|PURCHAS|SUPPLY CHAIN|ACCOUNT|BILLING|RECORDS|QUALITY|\bCME\b|RECRUIT|"
     r"GOVERMENT|GOVERNMENT|BUSINESS|CALL CENTER|MARKETING|AUDIT|ADMIN|\bCEO\b|\bCMO\b|CODING|INFECTION CONTROL|RECEPTION|"
     r"PATIENT SERVICE|PATIENT ACCOUNTING|SAFTY|SAFETY", "Administration"),
    (r"CLINIC|CARDIO|DERMA|\bENT\b|DENTAL|OPTHAL|OPHTHAL|ORTHO|UROLOG|NEURO|GASTRO|\bOB\b|GYN|PEDIATRIC|PAEDIATRIC|"
     r"INTERNAL MEDICINE|SURGERY|ONCOLOG|HEMATOLOG|ENDOCR|PULMON|PHYSIO|PSYCH|RHEUMAT|NEPHRO|ALLERGY|PAIN|BARIATRIC|"
     r"VASCULAR|PLASTIC|FAMILY|HOME|DIETITIAN|\bDEPT\b", "Clinic"),
]
DEPARTMENTS = [
    (r"ICU|NICU|PICU|CCU|CRITICAL|INTENSIVE", "ICU"),
    (r"EMERGENCY|A&E|\bER\b", "EMERGENCY ROOM"),
    (r"LABOUR|DELIVERY|L&D", "DELIVERY"),
    (r"PHARM", "PHARMACY"),
    (r"CARDIOTHORAC", "CARDIOTHORACIC"),
    (r"CARDIO|CATH", "CARDIOLOGY"),
    (r"\bLAB\b|LABORATORY", "LABORATORY"),
    (r"RADIOLOG|X-RAY|XRAY|IMAGING|NUCLEAR", "RADIOLOGY"),
    (r"DERMA", "DERMATOLOGY"),
    (r"\bENT\b", "ENT"),
    (r"DENT", "DENTAL"),
    (r"OPTHAL|OPHTHAL", "OPTHALMOLOGY"),
    (r"ORTHO", "ORTHOPEDIC"),
    (r"UROLOG", "UROLOGY"),
    (r"NEUROSURG", "NEUROSURGERY"),
    (r"NEURO", "NEUROLOGY"),
    (r"GASTRO|ENDOSCOPY", "GIT"),
    (r"\bOB\b|GYN|MATERNITY", "OBSTETRICS & GYNA"),
    (r"PEDIATRIC|PAEDIATRIC|NURSERY|\bPED\b", "PAEDIATRIC"),
    (r"INTERNAL MED", "INTERNAL MEDICINE"),
    (r"GENERAL SURG", "GEN. SURGERY"),
    (r"ONCOLOG", "ONCOLOGY"),
    (r"HEMATOLOG", "HEMATOLOGY"),
    (r"ENDOCR", "ENDOCRINOLOGY"),
    (r"PULMON|RESPIRATORY", "PULMONOLGY"),
    (r"PHYSIO", "PHYSIOTHERAPY"),
    (r"PSYCH", "PSYCHIATRY"),
    (r"RHEUMAT", "RHEUMATOLOGY"),
    (r"NEPHRO|DIALYSIS", "NEPHROLOGY"),
    (r"ALLERGY", "ALLERGY & IMMUNOLOGY"),
    (r"PAIN|ANAES|ANESTH", "ANATHESIA / PAIN MANAGEMENT"),
    (r"VASCULAR", "VASCULAR SURGERY"),
    (r"PLASTIC", "PLASTIC SURGERY"),
    (r"FAMILY", "FAMILY MED"),
    (r"HOME", "HOME CARE"),
    (r"DIET", "DIETITIAN"),
    (r"INFECTIOUS", "INFECTIOUS DISEASES"),
]
TYPE_DEPARTMENTS = {"Pharmacy": "PHARMACY", "Laboratory": "LABORATORY", "Radiology": "RADIOLOGY"}

ORG_BRANCH_SQL = """
select o.organization_id as organization_id, o.organization_code as organization_code,
       ifNull(o.organization_name, '') as organization_name, ifNull(b.branch_key, 0) as branch_key
from fusion.dim_inventory_org o final
left join (select business_unit_id, primary_ledger_id from fusion.dim_business_unit final) bu on bu.business_unit_id = o.business_unit_id
left join (select branch_key, fusion_ledger_id from gold.dim_branch where fusion_ledger_id is not null) b
    on b.fusion_ledger_id = bu.primary_ledger_id
settings join_use_nulls = 1
"""
SUBINVENTORY_SQL = """
select organization_id, upper(trimBoth(secondary_inventory_name)), ifNull(trimBoth(description), '')
from fusion.dim_subinventory final where ifNull(secondary_inventory_name, '') != ''
"""
OASIS_STORE_SQL = """
select toUInt8(branch_id), toInt64(c_id),
       coalesce(nullIf(nullIf(trimBoth(ifNull(description, '')), ''), '0'), nullIf(nullIf(trimBoth(ifNull(control_context, '')), ''), '0'),
                concat('Store ', toString(toInt64(c_id))))
from oasis.control_contexts_data final
"""
PAIR_SQL = f"""
with orgs as ({ORG_BRANCH_SQL.replace('settings join_use_nulls = 1', '')}),
refs as (
    select toUInt8(ob.branch_key) as branch_key, t.organization_id as organization_id, upper(ifNull(t.subinventory_code, '*')) as subinventory,
           toInt64OrNull(extract(ifNull(t.transaction_reference, ''), '^[A-Za-z]+-+([0-9]+)$')) as line_id
    from fusion.fact_inventory_transaction t final
    inner join orgs ob on ob.organization_id = t.organization_id
    where t.transaction_type_id in {INTEGRATION_TYPES}
)
select r.branch_key, toInt64(l.c_id) as store_id, r.organization_id, r.subinventory, count() as n
from refs r
inner join (select branch_id, toInt64(line_id) as line_id, c_id from oasis.docl final
            where doc_date >= '2026-01-01' and c_id is not null) l on l.branch_id = r.branch_key and l.line_id = r.line_id
where r.line_id is not null
group by 1, 2, 3, 4
order by 1, 2, n desc, 3, 4
limit 1 by 1, 2
"""


def first(rules, text, default):
    up = text.upper()
    return next((value for pattern, value in rules if re.search(pattern, up)), default)


def org_type(code):
    code = code or ""
    special = {"N01": "04", "N02": "06", "N03": "07", "N04": "09", "HQ01": "10", "IT_HQ": "10"}
    if code in special:
        return special[code]
    return code[-2:] if re.fullmatch(r"[A-Z]+[0-9]{2}", code) else "00"


def fusion_type(org_code, sub_code, name):
    if sub_code in EXPIRY_CODES or re.search(EXPIRY_WORDS, name.upper()):
        return "Expiry/damaged/recall"
    return ORG_TYPES[org_type(org_code)]


def department(store_type, name):
    found = first(DEPARTMENTS, name, None)
    return found or TYPE_DEPARTMENTS.get(store_type, "Not Mapped")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args()
    c = client()
    orgs = {oid: (code or "", name, int(branch)) for oid, code, name, branch in c.query(ORG_BRANCH_SQL).result_rows}
    rows, fusion_by_key = [], {}
    stores = [(oid, sub, desc) for oid, sub, desc in c.query(SUBINVENTORY_SQL).result_rows]
    # a subinventory code keeps its meaning across organisations: borrow the most common description where one is empty
    seen = {}
    for _, sub, desc in stores:
        if desc:
            seen.setdefault(sub, {}).setdefault(desc, 0)
            seen[sub][desc] += 1
    common = {sub: max(descs, key=descs.get) for sub, descs in seen.items()}
    stores = [(oid, sub, desc or common.get(sub, "")) for oid, sub, desc in stores]
    stores += [(oid, "*", name) for oid, (_, name, _) in orgs.items()]
    for oid, sub, desc in sorted(stores, key=lambda s: (orgs.get(s[0], ("", "", 0))[0], s[1])):
        code, org_name, branch = orgs.get(oid, (str(oid), "", 0))
        name = desc or (org_name if sub == "*" else sub)
        stype = fusion_type(code, sub, name)
        dept = department(stype, name if sub != "*" else org_name)
        fusion_by_key[(oid, sub)] = (stype, dept)
        rows.append(("fusion", branch, f"{code}/{sub}", name, stype, dept))
    pairs = {(int(b), int(s)): (oid, sub) for b, s, oid, sub, _ in c.query(PAIR_SQL).result_rows}
    paired = 0
    for branch, store_id, name in sorted(c.query(OASIS_STORE_SQL).result_rows):
        pair = pairs.get((int(branch), int(store_id)))
        if pair and pair in fusion_by_key and not re.search(EXPIRY_WORDS, name.upper()):
            stype, dept = fusion_by_key[pair]
            paired += 1
        else:
            stype = first(NAME_TYPES, name, "Unmapped")
            dept = department(stype, name)
        rows.append(("oasis", int(branch), str(store_id), name, stype, dept))
    with open(args.out, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SOURCE", "BRANCH_ID", "STORE_CODE", "STORE_NAME", "STORE_TYPE", "UNIFIED_DEPARTMENT"])
        w.writerows(rows)
    n_oasis = sum(1 for r in rows if r[0] == "oasis")
    unmapped = sum(1 for r in rows if r[4] == "Unmapped")
    expiry = sum(1 for r in rows if r[4] == "Expiry/damaged/recall")
    print(f"{len(rows)} stores ({len(rows) - n_oasis} Fusion, {n_oasis} Oasis, {paired} Oasis paired through the integration), "
          f"{expiry} expiry/damaged/recall, {unmapped} unmapped -> {args.out}")


if __name__ == "__main__":
    main()
