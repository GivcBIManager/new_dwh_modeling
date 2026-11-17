"""Offline tests of referral_snapshot.py's comparisons (no ClickHouse)."""
import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import referral_snapshot as rs  # noqa: E402


def test_map_mismatches_lists_only_differing_rows():
    rows = [
        {"branch_key": "1", "start_month": "202510", "flagged": "12", "in_map": "12"},
        {"branch_key": "1", "start_month": "202511", "flagged": "7", "in_map": "8"},
        {"branch_key": "6", "start_month": "202511", "flagged": "0", "in_map": "0"},
    ]
    assert rs.map_mismatches(rows) == [("1", "202511", "7", "8")]


def test_map_mismatches_empty_when_all_equal():
    assert rs.map_mismatches([{"branch_key": "1", "start_month": "202601", "flagged": "3", "in_map": "3"}]) == []


def test_compare_skips_the_open_month():
    before = {("1", "202610"): "5", ("1", "202611"): "2"}
    after = {("1", "202610"): "5", ("1", "202611"): "9"}
    assert rs.differences(before, after, skip_from="202611") == []
    assert rs.differences(before, after) == [("1", "202611", "2", "9")]


def test_compare_reports_a_closed_month_missing_on_one_side():
    assert rs.differences({("2", "202609"): "4"}, {}, skip_from="202611") == [("2", "202609", "4", "")]


def test_open_month_is_yyyymm():
    assert rs.open_month(datetime.date(2026, 3, 9)) == "202603"
