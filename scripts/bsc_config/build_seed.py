"""Generate the first content of the balanced-scorecard config tables (bsc ssas spec 6.2, plan
2026-10-20-bsc-dwh-config-and-facts Task 1) from the handover project and the decisions of 2026-10-20.

  python scripts/bsc_config/build_seed.py      -> scripts/bsc_config/bsc_config_seed.sql

The SQL is applied once by apply_bsc_config.ps1; after that the ClickHouse tables are the source of truth.
"""
from pathlib import Path

from handover import read_datatable, read_script_block

ROOT = Path(__file__).resolve().parents[2]
HANDOVER = ROOT / "powerbi_tmdl" / "Hayat BSC Deliverable" / "00_Full Access"
TABLES = HANDOVER / "Hayat_BSC_Full_RS.SemanticModel" / "definition" / "tables"
PAGES = HANDOVER / "Hayat_BSC_Full_RS.Report" / "definition" / "pages"
BOARDS = {
    "F": "3f93217509b9ec7f630c/visuals/a426eff5e5550d01304d/visual.json",
    "C": "pg_customer/visuals/41679eda7b26b9741929/visual.json",
    "P": "841254d00da52f0e4df7/visuals/f8c41a03693b9012dff4/visual.json",
    "L": "pg_learning_growth/visuals/793bc3e88c441fadc06b/visual.json",
}
OVERVIEW = "0dab624dcd380d3a0b4d/visuals/dbe9f6407146ab30e25e/visual.json"
SEED_NOTE = "seed from handover 2026-10-20"
SEED_YEAR = 2026

# pillar, order, weight, question (overview texts of the handover)
PILLARS = {
    "F": ("Financial", 1, 0.30, "Are we delivering sustainable financial performance and disciplined capital use?"),
    "C": ("Customer", 2, 0.20, "Are patients choosing us and experiencing excellent care?"),
    "P": ("Internal Process", 3, 0.35, "Are our clinical and operational processes effective?"),
    "L": ("Learning & Growth", 4, 0.15, "Are we building the capabilities to sustain success?"),
}

# num, kpi_code, objective, type, direction, format, status, target_source, value_source, detail_page (plan table)
KPIS = [
    (1, "FIN_NET_REVENUE", "F1", "Primary", "higher", "sar", "active", "budget", "measure", "revenue"),
    (2, "FIN_REVENUE_GROWTH", "F1", "Supporting", "higher", "sar", "active", "prior_year", "measure", "revenue"),
    (4, "FIN_EBITDA_MARGIN", "F2", "Primary", "higher", "pct", "active", "budget", "measure", "finance"),
    (5, "FIN_COST_TO_REVENUE", "F2", "Supporting", "lower", "pct", "active", "budget", "measure", "finance"),
    (63, "FIN_CONSUMABLES_RATIO", "F2", "Supporting", "lower", "pct", "active", "budget", "measure", "finance"),
    (6, "FIN_DAYS_IN_AR", "F3", "Primary", "lower", "days", "active", "fixed", "measure", "finance"),
    (7, "FIN_NET_COLLECTION", "F3", "Supporting", "higher", "pct", "parked", "none", "measure", "revenue_cycle"),
    (64, "FIN_DAYS_INVENTORY", "F3", "Supporting", "lower", "days", "active", "budget", "measure", "finance"),
    (65, "FIN_BREAKEVEN_GAP", "F3", "Supporting", "higher", "sar", "parked", "none", "measure", "finance"),
    (8, "FIN_REVENUE_PER_BED", "F4", "Primary", "higher", "sar", "active", "budget", "measure", "revenue"),
    (9, "FIN_RETURN_ON_ASSETS", "F4", "Primary", "higher", "pct", "active", "fixed", "measure", "finance"),
    (10, "FIN_EBITDA_PER_BED", "F4", "Supporting", "higher", "sar", "active", "budget", "measure", "finance"),
    (55, "FIN_REVENUE_PER_DOCTOR", "F5", "Supporting", "higher", "sar", "active", "budget", "measure", "revenue"),
    (56, "FIN_EBITDA_PER_DOCTOR", "F5", "Supporting", "higher", "sar", "active", "budget", "measure", "finance"),
    (11, "CUS_MULTI_SPECIALTY_SHARE", "C1", "Primary", "higher", "pct", "active", "budget", "measure", "revenue"),
    (12, "CUS_PAYER_MIX", "C1", "Primary", "higher", "pct", "active", "budget", "measure", "revenue"),
    (13, "CUS_PATIENT_SATISFACTION", "C2", "Primary", "higher", "pct", "active", "none", "measure", "experience"),
    (14, "CUS_PATIENT_RETENTION", "C2", "Supporting", "higher", "pct", "active", "fixed", "measure", "volume"),
    (15, "CUS_NEW_PATIENTS", "C2", "Supporting", "higher", "pct", "active", "fixed", "measure", "volume"),
    (16, "CUS_PREMS", "C2", "Supporting", "higher", "pct", "active", "fixed", "manual", "experience"),
    (17, "CUS_PROMS", "C2", "Supporting", "higher", "pct", "active", "none", "manual", "experience"),
    (66, "CUS_COMPLAINT_RATE", "C2", "Supporting", "lower", "pct", "active", "fixed", "manual", "experience"),
    (67, "CUS_OP_WAIT", "C2", "Supporting", "lower", "mins", "active", "fixed", "measure", "volume"),
    (18, "CUS_NON_MOH_SHARE", "C3", "Primary", "higher", "pct", "active", "budget", "measure", "revenue"),
    (19, "CUS_NON_ELIGIBLE_REFERRAL", "C3", "Supporting", "lower", "pct", "parked", "none", "measure", "volume"),
    (20, "CUS_PAYER_VOLUME", "C3", "Supporting", "higher", "num", "active", "budget", "measure", "volume"),
    (61, "CUS_REFERRAL_CONVERSION", "C3", "Supporting", "higher", "pct", "parked", "none", "measure", "volume"),
    (62, "CUS_ACQUISITION_COST", "C3", "Supporting", "lower", "sar", "active", "none", "measure", "finance"),
    (21, "INT_BED_OCCUPANCY", "P1", "Primary", "higher", "pct", "active", "fixed", "measure", "beds"),
    (22, "INT_OP_UTILIZATION", "P1", "Primary", "higher", "pct", "active", "budget", "measure", "volume"),
    (23, "INT_ALOS", "P1", "Supporting", "lower", "days", "active", "fixed", "measure", "beds"),
    (24, "INT_OP_TO_IP", "P1", "Supporting", "higher", "pct", "active", "budget", "measure", "volume"),
    (42, "INT_PATIENT_VOLUME", "P1", "Supporting", "higher", "num", "active", "budget", "measure", "volume"),
    (57, "INT_ER_GROWTH", "P1", "Supporting", "higher", "pct", "active", "budget", "measure", "volume"),
    (58, "INT_DOCTOR_UTILIZATION", "P1", "Supporting", "higher", "pct", "active", "none", "measure", "volume"),
    (60, "INT_ACTIVATED_BEDS", "P1", "Supporting", "higher", "pct", "active", "none", "measure", "beds"),
    (25, "INT_HIGH_VALUE_REVENUE", "P2", "Primary", "higher", "pct", "active", "fixed", "measure", "revenue"),
    (26, "INT_HIGH_VALUE_CENSUS", "P2", "Primary", "higher", "pct", "active", "fixed", "measure", "volume"),
    (27, "INT_OP_REVENUE_PER_EPISODE", "P2", "Supporting", "higher", "sar", "active", "budget", "measure", "revenue"),
    (28, "INT_ANCILLARY_UTILIZATION", "P2", "Supporting", "higher", "pct", "active", "budget", "measure", "revenue"),
    (29, "INT_REVENUE_LEAKAGE", "P3", "Primary", "lower", "pct", "active", "fixed", "measure", "revenue_cycle"),
    (30, "INT_CLAIM_INITIAL_REJECTION", "P3", "Supporting", "lower", "pct", "active", "fixed", "measure", "revenue_cycle"),
    (31, "INT_ORDER_NOT_DONE", "P3", "Supporting", "lower", "pct", "active", "fixed", "measure", "revenue_cycle"),
    (32, "INT_APPROVAL_TAT", "P3", "Supporting", "lower", "mins", "active", "fixed", "measure", "revenue_cycle"),
    (33, "INT_CLAIM_FINAL_REJECTION", "P3", "Supporting", "lower", "pct", "parked", "none", "measure", "revenue_cycle"),
    (34, "INT_COST_BUDGET_VARIANCE", "P4", "Primary", "lower", "pct", "active", "fixed", "measure", "finance"),
    (35, "INT_GA_RATIO", "P4", "Supporting", "lower", "pct", "active", "budget", "measure", "finance"),
    (36, "INT_READMISSION_30D", "P5", "Primary", "ceiling", "pct", "active", "fixed", "measure", "beds"),
    (37, "INT_READMISSION_48H_CRITICAL", "P5", "Primary", "ceiling", "pct", "active", "fixed", "measure", "beds"),
    (38, "INT_HAI_RATE", "P5", "Supporting", "lower", "pct", "active", "none", "manual", "beds"),
    (39, "INT_FALL_RATE", "P5", "Supporting", "lower", "pct", "active", "none", "manual", "beds"),
    (40, "INT_PAYER_CONTRACT_ACTIVATION", "P6", "Primary", "higher", "pct", "parked", "none", "measure", "revenue"),
    (41, "INT_EXTERNAL_REFERRALS", "P6", "Supporting", "higher", "num", "active", "none", "measure", "volume"),
    (59, "INT_REFERRAL_TO_HUB", "P6", "Supporting", "higher", "pct", "parked", "none", "measure", "volume"),
    (43, "LRN_TURNOVER", "L1", "Primary", "lower", "pct", "active", "fixed", "measure", "workforce"),
    (44, "LRN_REVENUE_PER_FTE", "L1", "Primary", "higher", "sar", "active", "budget", "measure", "workforce"),
    (45, "LRN_STAFF_TO_BED", "L1", "Supporting", "on_target", "num", "active", "fixed", "measure", "workforce"),
    (46, "LRN_SAUDIZATION", "L1", "Supporting", "higher", "pct", "active", "none", "measure", "workforce"),
    (47, "LRN_VACANCY_RATE", "L1", "Supporting", "lower", "pct", "active", "none", "measure", "workforce"),
    (48, "LRN_TIME_TO_FILL", "L1", "Supporting", "lower", "days", "active", "none", "measure", "workforce"),
    (68, "LRN_CLINICAL_TO_DOCTOR", "L1", "Supporting", "higher", "num", "active", "none", "measure", "workforce"),
    (69, "LRN_STAFF_SATISFACTION", "L1", "Supporting", "higher", "pct", "active", "none", "manual", "workforce"),
    (70, "LRN_COST_PER_HIRE", "L1", "Supporting", "lower", "sar", "parked", "none", "measure", "workforce"),
    (71, "LRN_COST_PER_FIRE", "L1", "Supporting", "lower", "sar", "parked", "none", "measure", "workforce"),
    (49, "LRN_DIGITAL_ON_TIME", "L2", "Primary", "higher", "pct", "active", "none", "manual", "workforce"),
    (50, "LRN_TRAINING_COVERAGE", "L2", "Supporting", "higher", "pct", "active", "none", "manual", "workforce"),
    (51, "LRN_MANDATORY_TRAINING", "L2", "Supporting", "higher", "pct", "active", "none", "manual", "workforce"),
    (52, "LRN_COST_PER_LEARNER", "L2", "Supporting", "lower", "sar", "active", "none", "manual", "workforce"),
    (53, "LRN_DOA_COMPLIANCE", "L3", "Primary", "higher", "pct", "active", "none", "manual", "workforce"),
    (54, "LRN_AUDIT_CLOSURE", "L3", "Supporting", "higher", "pct", "active", "none", "manual", "workforce"),
]
RENAMED = {2: "Net Revenue Growth vs Last Year"}
MERGED_INTO = {3: 2}  # catalogue KPI 3 is merged into KPI 2 (spec decision D11)

# Definitions shown on the KPI detail page (spec Appendix B); edited later in map_bsc_kpi.
DEFINITIONS = {
    1: "GL net revenue (Oasis before each branch's Fusion cutover, Fusion including unposted after) against the REV_NET budget.",
    2: "GL net revenue in the selected period against the same period last year.",
    4: "EBITDA (net revenue minus operating expenses excluding depreciation and amortisation) divided by net revenue, combined Oasis and Fusion GL.",
    5: "Operating cost (net revenue minus EBITDA) divided by net revenue.",
    6: "Average trade receivables (opening and closing) times the days in the period, divided by net revenue.",
    7: "Parked: definition to be agreed with finance.",
    8: "Net revenue divided by the average available inpatient beds.",
    9: "Income for the selected months divided by assets at the start of the period, against the annual target.",
    10: "EBITDA divided by the average available inpatient beds.",
    11: "Outpatient plus non-LTC inpatient revenue as a share of GL net revenue.",
    12: "Insurance revenue (episode payer) as a share of GL net revenue.",
    13: "NPS of the Hospital NPS and Physician NPS survey questions: promoters minus detractors.",
    14: "Distinct returning outpatients divided by distinct outpatients (ER excluded).",
    15: "New-patient outpatient visits divided by all arrived outpatient visits.",
    16: "PREMs score entered monthly by the BI manager.",
    17: "PROMs score entered monthly by the BI manager.",
    18: "Revenue from non-MoH payers (episode payer) as a share of GL net revenue.",
    19: "Parked: definition to be agreed.",
    20: "Visits by insurance patients.",
    21: "Occupied bed nights divided by available bed nights in inpatient wards.",
    22: "Arrived outpatient visits divided by clinic capacity slots (legacy capacity rule).",
    23: "Average length of stay of non-LTC discharges.",
    24: "Admissions divided by arrived outpatient visits.",
    25: "Revenue of high-value specialties as a share of GL net revenue.",
    26: "Visits and admissions with a high-value-specialty doctor divided by all visits.",
    27: "Outpatient revenue divided by outpatient episodes.",
    28: "Ancillary revenue (MD, MED, CSM, RTL, MLK, PH, LAB, RAD) as a share of outpatient revenue.",
    29: "Claimed amount of non-manual claims not submitted, divided by the net amount of insurance invoices.",
    30: "Rejected amount divided by submitted amount, latest submission, by statement month.",
    31: "Approved pre-authorised services not delivered, divided by pre-authorised services.",
    32: "Average minutes from sending a pre-authorisation to the payer's response, over all requests.",
    33: "Parked: the final rejection is only known after payer payment reconciliation.",
    34: "Operating expenses against the cost budget (TOTAL_DC + TOTAL_GA).",
    35: "General and administrative expenses divided by net revenue.",
    36: "Readmissions within 30 days divided by discharges.",
    37: "Readmissions to a critical bed within 48 hours divided by discharges from a critical bed.",
    38: "HAI rate entered monthly by the BI manager.",
    39: "Fall rate with harm entered monthly by the BI manager.",
    40: "Parked: definition to be agreed.",
    41: "Visits and admissions under a referral policy.",
    42: "Outpatient visits plus admissions plus ER visits.",
    43: "Resignations (Oasis for branches 1-5, Fusion voluntary leavers for 6-8) divided by average headcount.",
    44: "Net revenue divided by average FTE, part-time doctors at 0.5 FTE.",
    45: "Average FTE divided by average available beds.",
    46: "Saudi heads divided by headcount without part-time doctors.",
    47: "Open requisition openings at month end divided by budgeted FTE.",
    48: "Average days from requisition approval to fill, for requisitions filled in the period.",
    49: "Digital initiatives completed on time, entered monthly by the BI manager.",
    50: "Training coverage entered monthly by the BI manager.",
    51: "Mandatory training completion entered monthly by the BI manager.",
    52: "Cost per learner entered monthly by the BI manager.",
    53: "DOA compliance entered monthly by the BI manager.",
    54: "Audit finding closure rate entered monthly by the BI manager.",
    55: "Net revenue divided by the average number of doctors, part-time doctors included.",
    56: "EBITDA divided by the average number of doctors, part-time doctors included.",
    57: "ER visits against the same period last year.",
    58: "Doctor visits divided by the doctor's clinic slots (legacy capacity rule).",
    59: "Parked: definition to be agreed.",
    60: "Average available beds divided by licensed beds.",
    61: "Parked: definition to be agreed.",
    62: "GL marketing expense divided by new outpatients.",
    63: "GL medical consumables divided by net revenue.",
    64: "Average GL inventory times days, divided by GL cost of medicines and medical consumables.",
    65: "Parked: needs a fixed and variable cost split.",
    66: "Patient complaints (entered monthly) divided by outpatient and ER visits.",
    67: "Average outpatient waiting minutes over visits with a recorded wait.",
    68: "Average nurses and doctors divided by average doctors.",
    69: "Staff satisfaction entered monthly by the BI manager.",
    70: "Parked: needs a recruiting cost source.",
    71: "Parked: needs a separation cost source.",
}

# handover hospital_view aliases -> branch id (Sabya and Al Kharj are left out, spec D9)
ALIASES = {
    "Alrabwah": 1, "Riyadh - Al Rabwah": 1, "Riyadh Al Rabwah": 1,
    "Khamis": 2, "Khamis Mushait": 2, "Jazan": 3,
    "Unaizah": 4, "Qassim - Unaiza": 4, "Qassim (Unayzah)": 4, "Madinah": 5, "Abha": 6,
    "Ghirnata": 7, "Ghirnatah": 7, "Riyadh - Ghirnatah": 7, "Muhayil": 8, "Muhayil Asir": 8,
}
CATEGORIES = {1: "Scale & Optimize", 4: "Scale & Optimize", 5: "Scale & Optimize",
              2: "Anchor & Protect", 3: "Anchor & Protect",
              6: "Ramp-Up & Prove", 7: "Ramp-Up & Prove", 8: "Ramp-Up & Prove"}
CODE_LISTS = {"ancillary_category": ["MD", "MED", "CSM", "RTL", "MLK", "PH", "LAB", "RAD"],
              "satisfaction_nps_role": ["Hospital NPS", "Physician NPS"]}
# targets that were DAX constants in the handover, and KPI 15's per-hospital rate
CONSTANT_TARGETS = [(14, 0, 0.65, "Handover constant"), (34, 0, 0.0, "Handover constant")]
CONSTANT_TARGETS += [(15, b, 0.7 if b in (6, 7, 8) else 0.3, "Handover constant (ramp-up hospitals 0.7)") for b in range(1, 9)]

MANUAL_SQL = f"""INSERT INTO default.map_bsc_manual_value
    (kpi_code, branch_id, year, month, numerator, denominator, note, changed_at, changed_by, change_note, is_deleted)
SELECT 'CUS_PREMS', hospital_id, year, month, toFloat64(prems_score_actual), 1, source_sheet, now64(3), 'seed', '{SEED_NOTE}', 0
FROM default.bsc_patient_satisfaction WHERE prems_score_actual IS NOT NULL AND hospital_id BETWEEN 1 AND 8
UNION ALL
SELECT 'CUS_COMPLAINT_RATE', hospital_id, year, month, toFloat64(patient_complaint_rate_actual), 0, source_sheet, now64(3), 'seed', '{SEED_NOTE}', 0
FROM default.bsc_patient_satisfaction WHERE patient_complaint_rate_actual IS NOT NULL AND hospital_id BETWEEN 1 AND 8;
"""


def build_rows(handover_dir: Path = HANDOVER) -> dict:
    tables = handover_dir / "Hayat_BSC_Full_RS.SemanticModel" / "definition" / "tables"
    pages = handover_dir / "Hayat_BSC_Full_RS.Report" / "definition" / "pages"
    catalog = {r["kpi_num"]: r for r in read_datatable(tables / "KPI Catalog.tmdl", "KPI Catalog")}
    code = {k[0]: k[1] for k in KPIS}
    for old, new in MERGED_INTO.items():
        code[old] = code[new]
    rows = {}

    charts, objectives = {}, []
    for prefix, rel in BOARDS.items():
        domain = read_script_block(pages / rel, "_DOMAIN")
        charts.update(domain.get("kpiCharts", {}))
        pillar, porder, pweight, pquestion = PILLARS[prefix]
        for i, obj in enumerate(domain["objOrder"], 1):
            o = domain["objectives"][obj]
            title = o["title"].split(" - ", 1)[1] if " - " in o["title"] else o["title"]
            objectives.append({"objective_code": obj, "pillar": pillar, "pillar_order": porder, "pillar_weight": pweight,
                               "pillar_question": pquestion, "objective_title": title,
                               "objective_question": o.get("question", ""), "objective_order": i})
    rows["map_bsc_objective"] = objectives

    kpi_rows = []
    for num, kcode, obj, ktype, direction, fmt, status, tsource, vsource, page in KPIS:
        name = RENAMED.get(num, catalog[num]["kpi_name"])
        kpi_rows.append({"kpi_code": kcode, "kpi_num": num, "kpi_name": name, "short_label": name,
                         "objective_code": obj, "kpi_type": ktype, "direction": direction, "value_format": fmt,
                         "chart_hint": charts.get(catalog[num]["kpi_name"], "line"), "display_order": num,
                         "definition": DEFINITIONS[num], "status": status, "target_source": tsource,
                         "value_source": vsource, "detail_page": page})
    rows["map_bsc_kpi"] = kpi_rows

    targets = []
    for t in read_datatable(tables / "TARGETS_INDUSTRY.tmdl", "TARGETS_INDUSTRY"):
        targets.append({"kpi_code": code[t["kpi_num"]], "branch_id": 0, "year": SEED_YEAR, "month": 0,
                        "target_value": float(t["annual_target"]), "scale_with_months": int(bool(t.get("scale_with_months"))),
                        "source_basis": t.get("source_basis") or ""})
    for num, branch, value, basis in CONSTANT_TARGETS:
        targets.append({"kpi_code": code[num], "branch_id": branch, "year": SEED_YEAR, "month": 0,
                        "target_value": value, "scale_with_months": 0, "source_basis": basis})
    rows["map_bsc_target"] = targets

    profiles = read_script_block(pages / OVERVIEW, "_V9_WEIGHT_PROFILES")
    sheet_of_branch = {int(k): v for k, v in read_script_block(pages / OVERVIEW, "_V9_HOSP_ID_TO_SHEET").items()}
    weights = []
    for profile, sheet in [("corporate", "Corporate")] + [(f"branch:{b}", s) for b, s in sorted(sheet_of_branch.items())]:
        merged = {}
        for num, cat in catalog.items():
            w = profiles[sheet].get(cat["kpi_name"])
            if w is not None and num in code:
                merged[code[num]] = merged.get(code[num], 0.0) + float(w["w"])
        weights += [{"profile": profile, "kpi_code": k, "weight": round(v, 6)} for k, v in merged.items()]
    rows["map_bsc_weight"] = weights

    owners = {}
    for num, kcode, *_ in KPIS:
        c = catalog[num]
        owners[(kcode, 0)] = {"kpi_code": kcode, "branch_id": 0, "owner": c["owner"] or "", "co_owners": c["co_owners"] or ""}
    for r in read_datatable(tables / "KPI Ownership.tmdl", "KPI Ownership"):
        branch = ALIASES.get(r["hospital_view"])
        if branch is None or r["kpi_num"] not in code or r["kpi_num"] in MERGED_INTO:
            continue
        kcode = code[r["kpi_num"]]
        corp = owners[(kcode, 0)]
        if (r["owner"] or "", r["co_owners"] or "") != (corp["owner"], corp["co_owners"]):
            owners[(kcode, branch)] = {"kpi_code": kcode, "branch_id": branch, "owner": r["owner"] or "", "co_owners": r["co_owners"] or ""}
    rows["map_bsc_owner"] = list(owners.values())

    rows["map_bsc_threshold"] = [{"kpi_code": "*", "score_base": 85.0, "score_slope": 0.6, "good_from": 85.0, "watch_from": 70.0}]
    rows["map_bsc_hospital_category"] = [{"branch_id": b, "category": c} for b, c in sorted(CATEGORIES.items())]
    rows["map_bsc_code_list"] = [{"list_name": n, "code": c} for n, codes in CODE_LISTS.items() for c in codes]
    rows["map_bsc_budgeted_fte"] = []
    return rows


def _literal(value) -> str:
    if isinstance(value, str):
        return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"
    if isinstance(value, bool):
        return "1" if value else "0"
    return repr(value) if isinstance(value, float) else str(value)


def render_sql(rows: dict) -> str:
    parts = []
    for table, table_rows in rows.items():
        if not table_rows:
            continue
        cols = list(table_rows[0])
        values = ",\n".join("    (" + ", ".join(_literal(r[c]) for c in cols)
                            + f", now64(3), 'seed', {_literal(SEED_NOTE)}, 0)" for r in table_rows)
        parts.append(f"INSERT INTO default.{table} ({', '.join(cols)}, changed_at, changed_by, change_note, is_deleted) VALUES\n{values};\n")
    return "\n".join(parts)


def main():
    rows = build_rows(HANDOVER)
    out = Path(__file__).with_name("bsc_config_seed.sql")
    header = "-- Generated by scripts/bsc_config/build_seed.py from the Hayat BSC handover and the decisions of 2026-10-20.\n" \
             "-- Applied once by apply_bsc_config.ps1; afterwards the default.map_bsc_* tables are the source of truth.\n\n"
    out.write_text(header + render_sql(rows) + "\n" + MANUAL_SQL, encoding="utf-8", newline="\n")
    counts = ", ".join(f"{t} {len(r)}" for t, r in rows.items())
    print(f"{out.name}: {len(rows)} tables, {sum(len(r) for r in rows.values())} rows ({counts})")


if __name__ == "__main__":
    main()
