import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_fs_account_mapping as b  # noqa: E402

DC = ("IS", "Expenses", "Direct Cost", "Employee Costs", "Employee Costs")
GA = ("IS", "Expenses", "General and administrative expenses", "Employee Cost", "Employee Cost")


def test_position_cleans_labels_and_aligns_the_element():
    assert b.position(["is", "Revenue", "Other income", "Other income", " Rental  Income "]) == \
        ("IS", "Other income", "Other income, net", "Other income, net", "Rental Income")
    assert b.position(["BS", "Liabilities", "Non Current Liabilities", "Govnernment grant", "Loan"])[3] == "Government grant"
    assert b.position(["IS", "Expenses", "Direct Cost", "Maintenance Expense", "Medical\xa0Equipments Maintenance"])[4] == \
        "Medical Equipment Maintenance"


def test_default_is_what_the_hospitals_use_and_head_office_only_when_alone():
    assert b.pick_default(52101101, {"Head Office": GA, "Abha": DC, "Jazan": DC}, {}) == DC
    assert b.pick_default(52101112, {"Head Office": GA}, {}) == GA


def test_a_tie_goes_to_the_line_named_like_the_fusion_account():
    rej = DC[:4] + ("Provision for Rejection - Government",)
    ppd = DC[:4] + ("Provision for Prompt Payment Discounts - Insurance",)
    names = {11308103: "Provision for Prompt Payment Discounts - Insurance"}
    assert b.pick_default(11308103, {"Abha": rej, "Unaizah": ppd}, names) == ppd


def test_asset_line_translates_the_class_between_families():
    classes = {f: defaultdict(set) for f in b.ASSET_TEMPLATES}
    classes["cost"]["12"] = {"Catering & Laundry"}
    classes["cost"]["13"] = {"Catering & Laundry"}
    classes["dep"]["12"] = {"Catering"}
    classes["cost"]["06"] = {"Office Equipment"}
    names = {55101115: "Depr. Exp. PP&E - Cleaning", 12203115: "PP&E - Cleaning Clearing Accounts"}
    assert b.asset_line(55101113, "dep", classes, names) == "Depreciation Expense - Catering"
    assert b.asset_line(55101106, "dep", classes, names) == "Depreciation Expense - Office Equipment"
    assert b.asset_line(55101115, "dep", classes, names) == "Depreciation Expense - Cleaning"
    assert b.asset_line(12203115, "cost", classes, names) == "Cleaning Cost"


def test_infer_takes_a_group_position_only_when_two_siblings_agree():
    bank = ("BS", "Assets", "Current Assets", "Cash and bank balances", "Bank")
    mapped = {11103116: bank, 11103117: bank, 21501101: DC, 21501102: GA}
    out = b.infer([11103139, 21501105, 43102501], mapped, {})
    assert out == {11103139: bank}


def test_build_rows_applies_the_overrides():
    contractual = ("IS", "Revenue", "Revenue - Discounts", "Revenue - Contractual Discount", "Contractual")
    settle = ("IS", "Revenue", "Revenue - Discounts", "Revenue - Settlement Discount", "Rejection")
    rows = b.build_rows({41310101: {"Abha": contractual}, 41310102: {"Abha": settle}}, [], {},
                       overrides=b.OVERRIDES[:1])
    assert (41310101, None, settle[:4] + ("Early Payment Discount",), "pl-report") in rows
    assert (41310102, None, settle, "tb2026:abha") in rows


CONTRACTUAL = ("IS", "Revenue", "Revenue - Discounts", "Revenue - Contractual Discount", "Contractual")
SETTLE = ("IS", "Revenue", "Revenue - Discounts", "Revenue - Settlement Discount", "Rejection")
EARLY = SETTLE[:4] + ("Early Payment Discount",)


def test_build_rows_reports_an_override_the_workbook_positions_differently(capsys):
    conflicts = []
    rows = b.build_rows({41310101: {"Abha": CONTRACTUAL}, 41310102: {"Abha": SETTLE}}, [], {},
                        overrides=b.OVERRIDES[:1], conflicts=conflicts)
    assert (41310101, None, EARLY, "pl-report") in rows  # the override still wins
    assert conflicts == [("override vs workbook", 41310101, None, CONTRACTUAL, "tb2026:abha", EARLY)]
    assert "41310101" in capsys.readouterr().out
    quiet = []
    b.build_rows({41310101: {"Abha": EARLY}, 41310102: {"Abha": SETTLE}}, [], {},
                 overrides=b.OVERRIDES[:1], conflicts=quiet)
    assert quiet == []


def test_build_rows_reports_a_workbook_branch_row_kept_under_an_overridden_default():
    other = SETTLE[:4] + ("Other",)
    conflicts = []
    wb = {41310101: {"Abha": CONTRACTUAL, "Unaizah": CONTRACTUAL, "Jazan": other}, 41310102: {"Abha": SETTLE}}
    rows = b.build_rows(wb, [], {}, overrides=b.OVERRIDES[:1], conflicts=conflicts)
    assert (41310101, 105, other, "tb2026:jazan") in rows  # the override does not move the branch row
    assert ("workbook branch row kept", 41310101, 105, other, "tb2026:jazan", EARLY) in conflicts


def test_build_rows_does_not_carry_a_previous_pl_report_row_forward():
    def prev(acc, pos, mapped_in):
        return {"ORACLE_CODE": str(acc), "BRANCH_CODE": "", **dict(zip(b.LEVELS, pos)), "MAPPED_IN": mapped_in}
    previous = [prev(43102302, EARLY, "pl-report"), prev(43102399, SETTLE, "tb2026:abha")]
    rows = b.build_rows({41310102: {"Abha": SETTLE}}, previous, {}, overrides=[])
    assert not [r for r in rows if r[0] == 43102302]  # deleting the override reverts the account
    assert (43102399, None, SETTLE, "tb2026:abha") in rows
