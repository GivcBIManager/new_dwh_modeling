import csv
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fs_report_alignment as a  # noqa: E402

CONTRACTUAL = ("IS", "Revenue", "Revenue - Discounts", "Revenue - Contractual Discount", "Contractual")
SETTLE = ("IS", "Revenue", "Revenue - Discounts", "Revenue - Settlement Discount", "Rejection")
SM = ("IS", "Expenses", "Selling and marketing expenses", "Advertising", "Advertising")
GA_FEE = ("IS", "Expenses", "General and administrative expenses", "Professional Fee and subscription", "Fees")
GA_OTHER = ("IS", "Expenses", "General and administrative expenses", "Other indirect Expenses", "Other indirect Expenses")
DC_OTHER = ("IS", "Expenses", "Direct Cost", "Other indirect Expenses", "Other")


def test_override_replaces_the_default_row_and_takes_type_and_element_from_the_category():
    rows = [(41310101, None, CONTRACTUAL, "tb2026:abha"), (41310102, None, SETTLE, "tb2026:abha")]
    out = a.apply_overrides(rows, [(41310101, None, "Revenue - Discounts", "Revenue - Settlement Discount",
                                    "Early Payment Discount", "decision 2")])
    assert (41310101, None, ("IS", "Revenue", "Revenue - Discounts", "Revenue - Settlement Discount",
                             "Early Payment Discount"), "pl-report") in out
    assert len(out) == 2 and (41310102, None, SETTLE, "tb2026:abha") in out


def test_branch_override_adds_a_branch_row_and_keeps_the_default():
    rows = [(54101507, None, SM, "tb2026:abha"), (54101599, None, GA_FEE, "tb2026:abha")]
    out = a.apply_overrides(rows, [(54101507, 101, "General and administrative expenses",
                                    "Professional Fee and subscription", "Branding", "decision 2")])
    assert (54101507, None, SM, "tb2026:abha") in out
    assert (54101507, 101, GA_FEE[:4] + ("Branding",), "pl-report") in out


def test_branch_row_equal_to_default_is_dropped():
    rows = [(52105103, None, DC_OTHER, "tb2026:abha"), (52105199, None, GA_OTHER, "tb2026:abha")]
    ov = [(52105103, None, "General and administrative expenses", "Other indirect Expenses",
           "Other indirect Expenses", "r"),
          (52105103, 101, "General and administrative expenses", "Other indirect Expenses",
           "Other indirect Expenses", "r")]
    out = a.apply_overrides(rows, ov)
    assert [r for r in out if r[0] == 52105103] == [(52105103, None, GA_OTHER, "pl-report")]


def test_apply_twice_equals_once():
    rows = [(41310101, None, CONTRACTUAL, "x"), (41310102, None, SETTLE, "x"), (54101507, None, SM, "x"),
            (54101599, None, GA_FEE, "x")]
    ov = [(41310101, None, "Revenue - Discounts", "Revenue - Settlement Discount", "Early Payment Discount", "r"),
          (54101507, 101, "General and administrative expenses", "Professional Fee and subscription", "Branding", "r")]
    once = a.apply_overrides(rows, ov)
    assert a.apply_overrides(once, ov) == once


def test_unknown_caption_is_refused():
    rows = [(41310101, None, CONTRACTUAL, "x")]
    with pytest.raises(SystemExit, match="41310101"):
        a.apply_overrides(rows, [(41310101, None, "Direct Cost", "No Such Caption", "L", "r")])


def test_branch_override_without_default_is_refused():
    rows = [(54101599, None, GA_FEE, "x")]
    with pytest.raises(SystemExit, match="54101507"):
        a.apply_overrides(rows, [(54101507, 101, "General and administrative expenses",
                                  "Professional Fee and subscription", "Branding", "r")])


def test_blank_level_and_duplicate_override_are_refused():
    rows = [(41310101, None, CONTRACTUAL, "x"), (41310102, None, SETTLE, "x")]
    good = (41310101, None, "Revenue - Discounts", "Revenue - Settlement Discount", "L", "r")
    with pytest.raises(SystemExit, match="41310101"):
        a.apply_overrides(rows, [good[:4] + (" ", "r")])
    with pytest.raises(SystemExit, match="41310101"):
        a.apply_overrides(rows, [good, good])


def test_overrides_are_well_formed():
    keys = [(o[0], o[1]) for o in a.OVERRIDES]
    assert len(a.OVERRIDES) == 30 and len(set(keys)) == 30
    for acc, branch, cat, caption, line, reason in a.OVERRIDES:
        assert 10_000_000 <= acc <= 99_999_999
        assert branch is None or 101 <= branch <= 109
        assert all(s.strip() for s in (cat, caption, line, reason))


def test_cli_round_trips_blank_branch_codes(tmp_path):
    cols = ["ORACLE_CODE", "BRANCH_CODE", "FS_TYPE", "FS_ELEMENT", "FS_CATEGORY", "FS_CAPTION", "FS_LINE", "MAPPED_IN"]
    src, dst = tmp_path / "in.csv", tmp_path / "out.csv"
    with open(src, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(cols)
        w.writerow([11101101, "\\N", "BS", "Assets", "Current Assets", "Cash and bank balances", "Cash", "t"])
        w.writerow([11101102, "", "BS", "Assets", "Current Assets", "Cash and bank balances", "Cash", "t"])
    a.main(["--mapping", str(src), "--out", str(dst)], overrides=[])
    got = list(csv.DictReader(open(dst, encoding="utf-8")))
    assert [r["BRANCH_CODE"] for r in got] == ["", ""] and [r["ORACLE_CODE"] for r in got] == ["11101101", "11101102"]
