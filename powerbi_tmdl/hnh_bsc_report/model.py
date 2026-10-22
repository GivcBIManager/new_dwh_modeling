"""The page model the report is written in: pages of visuals that name a template sample and the fields to bind."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

MEASURE_TABLE = "_Measures"


@dataclass(frozen=True)
class Field:
    table: str
    name: str
    kind: Literal["column", "measure"]

    @property
    def ref(self) -> str:
        """The queryRef / Select Name Desktop writes: "<Entity>.<Property>"."""
        return f"{self.table}.{self.name}"

    def __str__(self) -> str:
        if self.kind == "measure":
            return f"[{self.name}]" if self.table == MEASURE_TABLE else f"'{self.table}'[{self.name}] (measure)"
        return f"'{self.table}'[{self.name}]"


def col(table: str, name: str) -> Field:
    return Field(table, name, "column")


def meas(name: str, table: str = MEASURE_TABLE) -> Field:
    return Field(table, name, "measure")


@dataclass
class Filter:
    """`in`: any of `values`; `eq`: the one value. A measure takes `eq` only (an Advanced filter)."""
    field: Field
    op: Literal["in", "eq"]
    values: list


@dataclass
class Visual:
    """One visual: a clone of the template visual titled `sample:<sample>`, rebound to `roles`.

    `top_n` = (the measure to rank by, N): keeps the top N of the visual's first column. `sort` sorts descending.
    `props` merges into the visual's format objects (`singleVisual.objects`, or `vcObjects` when the sample holds
    that object there, as Desktop does for a button's `visualLink`).
    """
    sample: str
    x: float
    y: float
    w: float
    h: float
    roles: dict[str, list[Field]] = field(default_factory=dict)
    title: str | None = None
    filters: list[Filter] = field(default_factory=list)
    top_n: tuple[Field, int] | None = None
    sort: Field | None = None
    props: dict = field(default_factory=dict)


@dataclass
class Page:
    """`name` is the page's internal name (navigation targets it), `display` the tab name users see. A page with
    `drill_fields` is a drill-through page with "keep all filters" as on the template's `Drill sample` page."""
    name: str
    display: str
    visuals: list[Visual]
    filters: list[Filter] = field(default_factory=list)
    drill_fields: list[Field] | None = None
    hidden: bool = False


def page_fields(page: Page) -> list[Field]:
    """Every field a page binds, in page order (visual roles, visual filters, top N, sort, page filters, drill)."""
    out: list[Field] = []
    for v in page.visuals:
        for fs in v.roles.values():
            out += fs
        out += [f.field for f in v.filters]
        if v.top_n:
            out.append(v.top_n[0])
        if v.sort:
            out.append(v.sort)
    out += [f.field for f in page.filters]
    out += page.drill_fields or []
    return out
