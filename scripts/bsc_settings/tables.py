"""Table specs, allowed values and entry hints for the BSC settings page.

Allowed values are copied from docs/bsc_config.md; a test fails if the doc lists a value missing here.
Columns follow scripts/bsc_config/bsc_config_ddl.sql (audit columns excluded).
"""
from dataclasses import asdict, dataclass
from typing import Literal, Optional

AUDIT = ("changed_at", "changed_by", "change_note", "is_deleted")


@dataclass(frozen=True)
class Column:
    name: str
    kind: Literal["str", "int", "float", "flag"]
    label: str
    allowed: Optional[tuple] = None
    ref: Optional[Literal["kpi", "kpi_or_default", "objective", "branch", "branch_or_all"]] = None
    pattern: Optional[str] = None


@dataclass(frozen=True)
class TableSpec:
    name: str
    label: str
    group: str
    key: tuple
    columns: tuple

    def to_json(self) -> dict:
        return {"name": self.name, "label": self.label, "group": self.group,
                "key": list(self.key), "columns": [asdict(c) for c in self.columns]}


def _c(name, kind, label, **kw):
    return Column(name, kind, label, **kw)


KPI = dict(ref="kpi")
BRANCH = dict(ref="branch")
BRANCH_OR_ALL = dict(ref="branch_or_all")

GROUPS = ("Monthly", "Targets & scoring", "KPI setup", "Hospital facts", "Advanced")

_SPECS = (
    TableSpec("map_bsc_manual_value", "Manual values", "Monthly",
              ("kpi_code", "branch_id", "year", "month"), (
                  _c("kpi_code", "str", "KPI", **KPI), _c("branch_id", "int", "Hospital", **BRANCH),
                  _c("year", "int", "Year"), _c("month", "int", "Month"),
                  _c("numerator", "float", "Numerator"), _c("denominator", "float", "Denominator"),
                  _c("note", "str", "Note"))),
    TableSpec("map_bsc_target", "Targets", "Targets & scoring",
              ("kpi_code", "branch_id", "year", "month"), (
                  _c("kpi_code", "str", "KPI", **KPI), _c("branch_id", "int", "Hospital", **BRANCH_OR_ALL),
                  _c("year", "int", "Year"), _c("month", "int", "Month"),
                  _c("target_value", "float", "Target"),
                  _c("scale_with_months", "flag", "Scale with months"),
                  _c("source_basis", "str", "Source / basis"))),
    TableSpec("map_bsc_weight", "Weights", "Targets & scoring", ("profile", "kpi_code"), (
        _c("profile", "str", "Profile", pattern=r"^(corporate|branch:[1-8])$"),
        _c("kpi_code", "str", "KPI", **KPI), _c("weight", "float", "Weight"))),
    TableSpec("map_bsc_threshold", "Thresholds", "Targets & scoring", ("kpi_code",), (
        _c("kpi_code", "str", "KPI (* = default)", ref="kpi_or_default"),
        _c("score_base", "float", "Score at target"), _c("score_slope", "float", "Points per 1%"),
        _c("good_from", "float", "On track from"), _c("watch_from", "float", "On watch from"))),
    TableSpec("map_bsc_kpi", "KPIs", "KPI setup", ("kpi_code",), (
        _c("kpi_code", "str", "KPI code", **KPI), _c("kpi_num", "int", "KPI number"),
        _c("kpi_name", "str", "Name"), _c("short_label", "str", "Short label"),
        _c("objective_code", "str", "Objective", ref="objective"),
        _c("kpi_type", "str", "Type", allowed=("Primary", "Supporting")),
        _c("direction", "str", "Direction", allowed=("higher", "lower", "ceiling", "on_target")),
        _c("value_format", "str", "Value format", allowed=("sar", "pct", "days", "mins", "num")),
        _c("chart_hint", "str", "Chart",
           allowed=("line", "bullet", "bulletN", "gauge", "hbar", "stat", "signed")),
        _c("display_order", "int", "Display order"), _c("definition", "str", "Definition"),
        _c("status", "str", "Status", allowed=("active", "parked")),
        _c("target_source", "str", "Target source", allowed=("fixed", "budget", "prior_year", "none")),
        _c("value_source", "str", "Value source", allowed=("measure", "manual")),
        _c("detail_page", "str", "Detail page",
           allowed=("revenue", "finance", "volume", "beds", "revenue_cycle", "workforce", "experience")))),
    TableSpec("map_bsc_objective", "Objectives & pillars", "KPI setup", ("objective_code",), (
        _c("objective_code", "str", "Objective code"),
        _c("pillar", "str", "Pillar",
           allowed=("Financial", "Customer", "Internal Process", "Learning & Growth")),
        _c("pillar_order", "int", "Pillar order"), _c("pillar_weight", "float", "Pillar weight"),
        _c("pillar_question", "str", "Pillar question"), _c("objective_title", "str", "Objective title"),
        _c("objective_question", "str", "Objective question"), _c("objective_order", "int", "Objective order"))),
    TableSpec("map_bsc_owner", "Owners", "KPI setup", ("kpi_code", "branch_id"), (
        _c("kpi_code", "str", "KPI", **KPI), _c("branch_id", "int", "Hospital", **BRANCH_OR_ALL),
        _c("owner", "str", "Owner"), _c("co_owners", "str", "Co-owners (separated by |)"))),
    TableSpec("map_bsc_hospital_category", "Hospital categories", "Hospital facts", ("branch_id",), (
        _c("branch_id", "int", "Hospital", **BRANCH),
        _c("category", "str", "Category",
           allowed=("Scale & Optimize", "Anchor & Protect", "Ramp-Up & Prove")))),
    TableSpec("map_bsc_licensed_beds", "Licensed beds", "Hospital facts", ("branch_id", "year"), (
        _c("branch_id", "int", "Hospital", **BRANCH), _c("year", "int", "Year"),
        _c("licensed_beds", "float", "Licensed beds"))),
    TableSpec("map_bsc_budgeted_fte", "Budgeted FTE", "Hospital facts", ("branch_id", "year"), (
        _c("branch_id", "int", "Hospital", **BRANCH), _c("year", "int", "Year"),
        _c("budgeted_fte", "float", "Budgeted FTE"))),
    TableSpec("map_bsc_parameter", "Parameters", "Advanced", ("name",), (
        _c("name", "str", "Name"), _c("value", "float", "Value"))),
    TableSpec("map_bsc_code_list", "Code lists", "Advanced", ("list_name", "code"), (
        _c("list_name", "str", "List", allowed=("ancillary_category", "satisfaction_nps_role")),
        _c("code", "str", "Code"))),
)

TABLES = {t.name: t for t in _SPECS}

RATE_FORMAT = "pct"
COMPLAINTS_KPI = "CUS_COMPLAINT_RATE"
DEFAULT_MANUAL_HINT = ("Numerator and denominator; for a rate already worked out, "
                       "the rate in numerator and 1 in denominator.")
MANUAL_HINTS = {
    COMPLAINTS_KPI: "Count in numerator, 0 in denominator (the measure divides by OP and ER visits).",
}
