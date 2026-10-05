"""Draft static_mappings/fusion_specialty_unified.csv: Fusion GL specialty (COA segment 3) to unified department.

Keyword rules, first match wins, on the lower-cased specialty name. Values without a match stay blank (Unknown in
gold) for the BI manager to complete. Every proposed value must exist in default.map_unified_department_v2.

Usage:  python scripts/draft_fusion_specialty_map.py
"""
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "static_mappings" / "fusion_specialty_unified.csv"

RULES = [
    (r"nicu|picu|neonat|nursery", "NICU/PICU"),
    (r"\bicu\b|critical care|\bhdu\b|high dependency|\bccu\b|step-down", "ICU"),
    (r"emergency", "EMERGENCY ROOM"),
    (r"\bhome\b", "HOME CARE"),
    (r"maxillofacial", "MAXILOFACIAL"),
    (r"dent|orthodont|periodont|prosthodont|endodont|implant", "DENTAL"),
    (r"interventional radiology", "INTERVENTIONAL RADIOLOGY"),
    (r"cardiothoracic", "CARDIOTHORACIC"),
    (r"pediatric|paediatric", "PAEDIATRIC"),
    (r"cardio|echocardio|stress testing|holter|\bcath\b", "CARDIOLOGY"),
    (r"vascular", "VASCULAR SURGERY"),
    (r"neurosurg", "NEUROSURGERY"),
    (r"neuro|stroke|epilep|\beeg\b|\bemg\b|evoked", "NEUROLOGY"),
    (r"bariatric", "BARIATRIC"),
    (r"plastic", "PLASTIC SURGERY"),
    (r"orthop|trauma", "ORTHOPEDIC"),
    (r"urolog|cystoscopy|androl", "UROLOGY"),
    (r"^ent$", "ENT"),
    (r"ophthalm", "OPTHALMOLOGY"),
    (r"oncolog|palliative", "ONCOLOGY"),
    (r"labor|delivery|maternity", "DELIVERY"),
    (r"obstetric|gyn|maternal|ivf|reproductive|women", "OBSTETRICS & GYNA"),
    (r"gastro|endoscopy", "GIT"),
    (r"pulmon|respiratory|bronchoscopy|sleep", "PULMONOLGY"),
    (r"nephrol|dialysis", "NEPHROLOGY"),
    (r"endocrin", "ENDOCRINOLOGY"),
    (r"rheumat", "RHEUMATOLOGY"),
    (r"infectious|infection control", "INFECTIOUS DISEASES"),
    (r"allergy", "ALLERGY & IMMUNOLOGY"),
    (r"blood bank", "BLOOD BANK"),
    (r"hematology", "HEMATOLOGY"),
    (r"radiolog|imaging|x-ray|\bct\b|nuclear", "RADIOLOGY"),
    (r"laborator|patholog|chemistry|microbiology|serology|molecular", "LABORATORY"),
    (r"pharmac|narcotic|iv room|drug warehouse", "PHARMACY"),
    (r"\bfood\b", "CAFETERIA"),
    (r"nutrition|dietet", "DIETITIAN"),
    (r"physiotherapy|rehabilitation|occupational therapy|speech", "PHYSIOTHERAPY"),
    (r"psychiat|psycholog|behavio|addiction|mental", "PSYCHIATRY"),
    (r"dermatolog|laser", "DERMATOLOGY"),
    (r"family|preventive|occupational health|geriatric", "FAMILY MED"),
    (r"long.?stay", "LONG STAY"),
    (r"anesth|\bpain\b|sedation", "ANATHESIA / PAIN MANAGEMENT"),
    (r"general surgery|surgical services|operating room|^or$", "GEN. SURGERY"),
    (r"internal medicine|medicine services", "INTERNAL MEDICINE"),
    (r"audiolog", "AUDIOLOGY DEPT"),
    (r"\bopd\b|outpatient", "OPD SERVICES"),
    (r"inpatient|\bward\b", "INPATIENTS SERVICES"),
]


def main():
    c = client()
    known = {r[0] for r in c.query("select distinct UNIFIED_DEPARTMENT from default.map_unified_department_v2").result_rows}
    for _, value in RULES:
        if value not in known:
            raise SystemExit(f"rule target not in map_unified_department_v2: {value}")
    rows = c.query(
        "select segment_value, ifNull(segment_value_description, '') from fusion.dim_coa_segment_value final "
        "where segment_column_name = 'SEGMENT3' order by segment_value"
    ).result_rows
    out, mapped = [], 0
    for code, name in rows:
        text = " ".join(name.lower().split())
        target = next((v for pattern, v in RULES if re.search(pattern, text)), "")
        mapped += bool(target)
        out.append((code, name.strip(), target))
    with open(OUT, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SPECIALTY_CODE", "SPECIALTY_NAME", "UNIFIED_DEPARTMENT"])
        w.writerows(out)
    print(f"{len(out)} specialties, {mapped} with a proposed unified department -> {OUT}")


if __name__ == "__main__":
    sys.exit(main())
