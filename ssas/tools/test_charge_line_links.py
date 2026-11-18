"""Charge Lines link to the service department, policy and five doctor roles; facts are never related to each other."""
import re
from pathlib import Path

MODEL = Path(__file__).resolve().parents[1] / "HNH_Analytics"
RELATIONSHIPS = (MODEL / "relationships.tmdl").read_text(encoding="utf-8")
BLOCKS = re.split(r"(?m)^relationship ", RELATIONSHIPS)[1:]
FACTS = {"Charge Lines", "Order Lines", "Encounters", "Episodes"}
LINKS = {
    "service_department_key": "Service Department", "policy_key": "Policy", "ordering_staff_key": "Ordering Doctor",
    "mrp_1_staff_key": "MRP 1", "mrp_2_staff_key": "MRP 2", "mrp_3_staff_key": "MRP 3",
    "charged_by_staff_key": "Charged By",
}


def _ref(text):
    """Split a TMDL column reference ('Table'.'Column' with optional quotes) into (table, column)."""
    m = re.fullmatch(r"('[^']+'|[^.']+)\.('[^']+'|[^.']+)", text.strip())
    return m.group(1).strip("'"), m.group(2).strip("'")


def _ends(block):
    return (_ref(re.search(r"fromColumn: (.+)", block).group(1)),
            _ref(re.search(r"toColumn: (.+)", block).group(1)))


def _col(key):
    """TMDL column name the generator gives a snake_case key."""
    return " ".join(w.capitalize() for w in key.split("_"))


def test_charge_lines_new_links():
    for col, dim in LINKS.items():
        hits = [b for b in BLOCKS if _ends(b)[0] == ("Charge Lines", _col(col))]
        assert len(hits) == 1, col
        assert _ends(hits[0])[1][0] == dim
        assert "isActive: false" not in hits[0]
        assert "crossFilteringBehavior: bothDirections" not in hits[0]


def test_no_fact_to_fact():
    bad = [b.splitlines()[0] for b in BLOCKS if _ends(b)[0][0] in FACTS and _ends(b)[1][0] in FACTS]
    assert bad == []


def _column_block(table, col):
    text = (MODEL / "tables" / f"{table}.tmdl").read_text(encoding="utf-8")
    m = re.search(rf"(?ms)^\tcolumn '?{_col(col)}'?\r?\n(.*?)(?=^\t\w|\Z)", text)
    return m.group(1) if m else None


def test_hidden_link_keys():
    # The by-charges measures count distinct visits / episodes on these keys; they relate to nothing.
    for table, col in [("Charge Lines", "encounter_key"), ("Charge Lines", "episode_key"), ("Order Lines", "encounter_key")]:
        block = _column_block(table, col)
        assert block is not None and "isHidden" in block, (table, col)
        assert not [b for b in BLOCKS if _ends(b)[0] == (table, _col(col))], (table, col)


def test_visit_keys_not_in_encounters_or_episodes():
    # Only the charge and order lines carry visit keys (about 380 MB of hash keys at G2 were on these two tables).
    assert _column_block("Encounters", "encounter_key") is None
    assert _column_block("Episodes", "episode_key") is None


def test_visit_dates_are_inactive_date_roles():
    cases = [("Charge Lines", "visit_date_key"), ("Charge Lines", "episode_start_date_key"),
             ("Order Lines", "visit_date_key")]
    for table, col in cases:
        hits = [b for b in BLOCKS if _ends(b)[0] == (table, _col(col))]
        assert len(hits) == 1, (table, col)
        assert _ends(hits[0])[1] == ("Date", "Date Key")
        assert "isActive: false" in hits[0], (table, col)


def test_policy_class_column():
    # Policy class (REF, VIP, A, B, C, Not classified) is a visible text column on Charge Lines, related to nothing.
    block = _column_block("Charge Lines", "policy_class")
    assert block is not None
    assert "isHidden" not in block
    assert "dataType: string" in block
    assert not [b for b in BLOCKS if _ends(b)[0] == ("Charge Lines", "Policy Class")]
