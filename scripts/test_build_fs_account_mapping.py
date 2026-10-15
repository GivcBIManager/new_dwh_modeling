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
