"""Draft the two Press Ganey reference maps (spec 4.1, 4.2) for review:

  static_mappings/pg_question_role.csv       SERVICE, QUESTION_CODE, ROLE
  static_mappings/pg_background_value.csv    SERVICE, QUESTION_CODE, ANSWER_CODE, CONFORMED_VALUE

Roles: 'Hospital NPS' and 'Physician NPS' mark each service's recommend questions; the other roles name the conformed
background attribute a background or routing question feeds. Conformed values come from the option labels:
respondent and booking channel by keyword, Yes/No questions by their first word, the rest by the English label without
its routing note. Only questions that exist in pg_survey_questions are written. LTC csurvey answer code 2 is used in
the responses but missing from the option master; it is drafted as 'Family member' (code 4, Family member, is never
used) and must be confirmed in review (open item O-P6-7).

Usage:  python scripts/draft_pg_maps.py [--out-dir DIR]
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT_DIR = Path(__file__).resolve().parent.parent / "static_mappings"

NPS = {
    ("OP", "o4"): "Hospital NPS", ("OP", "cp10"): "Physician NPS",
    ("TM", "o4"): "Hospital NPS", ("TM", "cp10"): "Physician NPS",
    ("ER", "f4"): "Hospital NPS",
    ("IP", "o3"): "Hospital NPS", ("PIP", "o3"): "Hospital NPS",
    ("DEN", "o12"): "Hospital NPS", ("DEN", "o1"): "Physician NPS",
    ("OR", "o4"): "Hospital NPS",
    ("HHC", "h3"): "Hospital NPS",
    ("LTC", "n10"): "Hospital NPS",
    ("AS", "f3"): "Hospital NPS",
    ("DIA", "e4"): "Hospital NPS", ("ON", "e4"): "Hospital NPS", ("OU", "e4"): "Hospital NPS",
}
ATTRIBUTES = {
    "filling": "respondent", "csurvey": "respondent", "relation": "respondent",
    "fvisit": "first_visit", "fstay": "first_visit",
    "howschvs": "booking_channel", "itsource": "booking_channel", "visadvan": "booking_channel",
    "admther": "admitted_via_er",
    "labtests": "used_lab", "xraytest": "used_radiology", "onstphar": "used_pharmacy", "insurver": "used_insurance_office",
    "physther": "used_physio", "spchther": "used_speech", "complete": "treatment_complete",
    "medshome": "meds_delivered", "telespar": "tele_spared_visit", "visttype": "tele_channel",
    "itservic": "hhc_service",
    "service": "dental_service",
    "dialytim": "dialysis_done",
    "hl_disclaimer": "contact_consent", "hl_disclamer": "contact_consent",
}
RESPONDENT = [(r"^PATIENT", "Patient"), (r"PARENT|GUARDIAN", "Parent or guardian"), (r"FAMILY", "Family member"),
              (r"^OTHER", "Other")]
CHANNEL = [(r"CALL CENT", "Call centre"), (r"RECEPTION", "Reception"), (r"ONLINE|APPLICATION|WEBSITE", "Online"),
           (r"WITHOUT AN APPOINTMENT|WALK-IN", "Walk-in"), (r"REFERRAL", "Referral"), (r"^APPOINTMENT$", "Appointment")]
MISSING_OPTIONS = [("LTC", "csurvey", "2", "Family member")]


def first(rules, text):
    up = text.upper().strip()
    return next((value for pattern, value in rules if re.search(pattern, up)), None)


def clean_label(label):
    # 'No (Go to Next Section)' -> 'No'; 'Voice Call (TMT1)' -> 'Voice Call'; keep descriptive brackets
    return re.sub(r"\s*\((go to|next section|end survey|tmt1|b2)[^)]*\)\s*$", "", label.strip(), flags=re.I).strip()


def conformed(role, label):
    if role == "respondent":
        return first(RESPONDENT, label) or "Other"
    if role == "booking_channel":
        return first(CHANNEL, label) or "Other"
    if role in ("hhc_service", "dental_service", "tele_channel"):
        return clean_label(label)
    word = label.strip().split()[0].strip("()").capitalize() if label.strip() else ""
    return word if word in ("Yes", "No") else clean_label(label)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=str(OUT_DIR))
    args = ap.parse_args()
    out = Path(args.out_dir)
    c = client()
    questions = {(s, q) for s, q in c.query(
        "select upper(trimBoth(service)), trimBoth(question_code) from press_ganey.pg_survey_questions").result_rows}
    roles = sorted([(s, q, r) for (s, q), r in NPS.items() if (s, q) in questions]
                   + [(s, q, ATTRIBUTES[q]) for s, q in questions if q in ATTRIBUTES])
    with open(out / "pg_question_role.csv", "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SERVICE", "QUESTION_CODE", "ROLE"])
        w.writerows(roles)
    role_of = {(s, q): r for s, q, r in roles}
    options = c.query(
        "select upper(trimBoth(service)), trimBoth(question_code), trimBoth(answer_code), label_en "
        "from press_ganey.pg_survey_answer_options where score is null order by 1, 2, sort_order").result_rows
    values = [(s, q, a, conformed(role_of[(s, q)], label)) for s, q, a, label in options if (s, q) in role_of]
    values += [m for m in MISSING_OPTIONS if (m[0], m[1]) in role_of]
    with open(out / "pg_background_value.csv", "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SERVICE", "QUESTION_CODE", "ANSWER_CODE", "CONFORMED_VALUE"])
        w.writerows(values)
    nps = sum(1 for r in roles if r[2].endswith("NPS"))
    unmapped = [(s, q, a) for s, q, a, label in options if (s, q) not in role_of]
    print(f"{len(roles)} question roles ({nps} NPS, {len(roles) - nps} attribute), {len(values)} background values, "
          f"{len(unmapped)} unscored options without a role -> {out}")


if __name__ == "__main__":
    main()
