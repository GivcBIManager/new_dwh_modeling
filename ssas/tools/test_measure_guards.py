import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import measure_guards as g  # noqa: E402

RELATIONSHIPS = (
    "relationship payroll_branch_key\n"
    "\tfromColumn: Payroll.'Branch Key'\n"
    "\ttoColumn: Branch.'Branch Key'\n"
    "\n"
    "relationship payroll_employee_key\n"
    "\tfromColumn: Payroll.'Employee Key'\n"
    "\ttoColumn: Employee.'Employee Key'\n"
    "\n"
    "relationship employee_details_employee_key\n"
    "\tcrossFilteringBehavior: bothDirections\n"
    "\tsecurityFilteringBehavior: oneDirection\n"
    "\tfromColumn: 'Employee Details'.'Employee Key'\n"
    "\ttoColumn: Employee.'Employee Key'\n"
    "\n"
    "relationship encounters_patient_key\n"
    "\tfromColumn: Encounters.'Patient Key'\n"
    "\ttoColumn: Patient.'Patient Key'\n"
    "\n"
    "relationship encounters_branch_key\n"
    "\tfromColumn: Encounters.'Branch Key'\n"
    "\ttoColumn: Branch.'Branch Key'\n"
    "\n"
    "relationship encounters_booking_date_key\n"
    "\tisActive: false\n"
    "\tfromColumn: Encounters.'Booking Date Key'\n"
    "\ttoColumn: Payer.'Payer Key'\n"
)

KINDS = {"Payroll": "fact", "Encounters": "fact", "Branch": "dim", "Employee": "dim", "Employee Details": "dim",
         "Patient": "dim", "Payer": "dim", "Date": "date", "Time Calculation": "calculation_group",
         "User Access": "security"}

MEASURES = (
    "table _Measures\n"
    "\n"
    "\t/// Payroll cost.\n"
    "\tmeasure 'Payroll Cost' = SUM ( Payroll[Cost Amount] )\n"
    "\t\tformatString: #,0\n"
    "\t\tdisplayFolder: Workforce\\Payroll\n"
    "\n"
    "\t/// Visits.\n"
    "\tmeasure Visits =\n"
    "\t\t\tVAR x = COUNTROWS ( Encounters )\n"
    "\t\t\tRETURN x\n"
    "\t\tformatString: #,0\n"
    "\t\tdisplayFolder: Patient Flow\\Visits\n"
    "\n"
    "\t/// Pay per visit.\n"
    "\tmeasure 'Pay per Visit' = DIVIDE ( [Payroll Cost], [Visits] )\n"
    "\t\tformatString: #,0\n"
    "\t\tdisplayFolder: Workforce\\Payroll\n"
    "\n"
    "\t\tannotation hnh_guard_allow = Payer\n"
    "\n"
    "\t/// User.\n"
    "\tmeasure 'Current User' = USERPRINCIPALNAME ()\n"
    "\t\tformatString: General\n"
    "\t\tdisplayFolder: Diagnostics\n"
    "\n"
    "\tcolumn Measure\n"
    "\t\tdataType: string\n"
)


def test_filtering_tables_follow_active_relationships_and_both_directions():
    rels = g.parse_relationships(RELATIONSHIPS)
    assert g.filtering_tables(rels, "Payroll") == {"Payroll", "Branch", "Employee", "Employee Details"}
    assert g.filtering_tables(rels, "Encounters") == {"Encounters", "Branch", "Patient"}


def test_measure_facts_follow_referenced_measures():
    facts = g.measure_facts(MEASURES, KINDS)
    assert facts == {"Payroll Cost": {"Payroll"}, "Visits": {"Encounters"},
                     "Pay per Visit": {"Payroll", "Encounters"}, "Current User": set()}


def test_unrelated_tables_union_over_facts_minus_allowed_and_exempt():
    rels = g.parse_relationships(RELATIONSHIPS)
    assert g.unrelated_tables({"Payroll"}, rels, KINDS, set()) == ["Encounters", "Patient", "Payer"]
    assert g.unrelated_tables({"Payroll", "Encounters"}, rels, KINDS, {"Payer"}) == [
        "Employee", "Employee Details", "Encounters", "Patient", "Payroll"]


def test_render_guards_every_fact_measure_and_is_idempotent():
    rels = g.parse_relationships(RELATIONSHIPS)
    once = g.render(MEASURES, rels, KINDS)
    assert g.render(once, rels, KINDS) == once
    assert "\tmeasure 'Payroll Cost' =\n\t\t\tVAR __Value = ( -- measure body\n\t\t\t\tSUM ( Payroll[Cost Amount] )\n" in once
    assert "\t\t\tVAR __Wrong = [_Guard Payroll]\n" in once
    assert "RETURN IF ( __Wrong = \"\", __Value, \"\"\"Payroll Cost\"\" can't be analysed by \" & __Wrong )" in once
    assert "\tmeasure 'Current User' = USERPRINCIPALNAME ()\n" in once
    assert "& IF ( ISFILTERED ( 'Patient' ), \", \"\"Patient\"\"\" )" in once
    assert "\tmeasure '_Guard Encounters + Payroll | Payer' =\n" in once


def test_render_keeps_the_original_expression_recoverable():
    rels = g.parse_relationships(RELATIONSHIPS)
    once = g.render(MEASURES, rels, KINDS)
    import hnh_tmdl as t
    assert [(m.name, m.expression) for m in t.measures(g.strip_guards(once))] == \
        [(m.name, m.expression) for m in t.measures(MEASURES)]
    assert "\t\t\tVAR x = COUNTROWS ( Encounters )\n\t\t\tRETURN x\n" in g.strip_guards(once)


def test_guard_names_stay_within_100_characters():
    short = g.guard_name({"Encounters"}, set())
    assert short == "_Guard Encounters"
    facts = {f"Fact Table Number {i}" for i in range(12)}
    long_name = g.guard_name(facts, {"BSC KPI"})
    assert len(long_name) <= 100
    assert long_name.startswith("_Guard 12 facts")
    assert long_name == g.guard_name(set(facts), {"BSC KPI"})
    assert long_name != g.guard_name(facts, set())


# A measure that calls the unguarded bodies of two guarded measures (scorecard speed, bsc visual plan Task 10).
WITH_TWINS = MEASURES.replace(
    "\tcolumn Measure\n",
    "\t/// Pay per visit from the bodies.\n"
    "\tmeasure 'Fast Pay per Visit' = DIVIDE ( [_Unguarded Payroll Cost], [_Unguarded Visits] )\n"
    "\t\tformatString: #,0\n"
    "\t\tdisplayFolder: Workforce\\Payroll\n"
    "\n"
    "\tcolumn Measure\n")


def test_measure_facts_follow_unguarded_twins_to_the_measure_they_copy():
    facts = g.measure_facts(WITH_TWINS, KINDS)
    assert facts["Fast Pay per Visit"] == {"Payroll", "Encounters"}


def test_render_adds_a_hidden_unguarded_twin_for_each_referenced_body():
    rels = g.parse_relationships(RELATIONSHIPS)
    once = g.render(WITH_TWINS, rels, KINDS)
    assert g.render(once, rels, KINDS) == once
    assert ("\tmeasure '_Unguarded Visits' =\n\t\t\tVAR x = COUNTROWS ( Encounters )\n\t\t\tRETURN x\n"
            "\t\tformatString: General\n\t\tisHidden\n\t\tdisplayFolder: Diagnostics\\Unguarded\n") in once
    assert "\tmeasure '_Unguarded Payroll Cost' =\n\t\t\tSUM ( Payroll[Cost Amount] )\n\t\tformatString: General\n" in once
    assert "'_Unguarded Pay per Visit'" not in once
    import hnh_tmdl as t
    measures = {m.name: m for m in t.measures(once)}
    assert measures["_Unguarded Visits"].description
    assert "__Wrong" not in measures["_Unguarded Visits"].expression
    assert "VAR __Wrong = [_Guard Encounters + Payroll]" in measures["Fast Pay per Visit"].expression


def test_unguarded_twins_follow_the_measure_they_copy_and_strip_away():
    rels = g.parse_relationships(RELATIONSHIPS)
    once = g.render(WITH_TWINS, rels, KINDS)
    edited = once.replace("\t\t\t\tRETURN x\n", "\t\t\t\tRETURN x + 1\n")
    assert edited.count("RETURN x + 1") == 1
    again = g.render(edited, rels, KINDS)
    assert "\tmeasure '_Unguarded Visits' =\n\t\t\tVAR x = COUNTROWS ( Encounters )\n\t\t\tRETURN x + 1\n" in again
    import hnh_tmdl as t
    assert [m.name for m in t.measures(g.strip_guards(once))] == [m.name for m in t.measures(WITH_TWINS)]
    unused = once.replace("DIVIDE ( [_Unguarded Payroll Cost], [_Unguarded Visits] )", "DIVIDE ( [_Unguarded Visits], 2 )")
    assert "'_Unguarded Payroll Cost'" not in g.render(unused, rels, KINDS)
