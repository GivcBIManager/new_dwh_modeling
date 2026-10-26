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
    """`in`: any of `values`; `eq`: the one value; `notblank`: is not blank (no values). A measure takes `eq` or
    `notblank` (Advanced filters)."""
    field: Field
    op: Literal["in", "eq", "notblank"]
    values: list = field(default_factory=list)


@dataclass
class Visual:
    """One visual. `sample` is its kind: card, multiRowCard, table, matrix, barChart, lineChart, slicerDropdown,
    slicerDateRange, textbox, buttonNavigate, buttonDrill, hnhVisual (pbir.VISUAL_TYPES); and two frame kinds
    (frame.py) without fields: panel (a filled rectangle) and image (the logo). The legacy route clones the template
    visual titled `sample:<sample>` and rebinds it to `roles`; it has no sample for panel and image and leaves them
    out (layout.NO_SAMPLE).

    `top_n` = (the measure to rank by, N): keeps the top N of the visual's first column. `sort` (one of the visual's
    fields) sorts `sort_dir`: "desc" (default) or "asc" (time axes).
    `props` merges into the visual's format objects (`singleVisual.objects`, or `vcObjects` when the sample holds
    that object there, as Desktop does for a button's `visualLink`). `date_range` is the saved selection of a
    `slicerDateRange` (a From - To slicer on a date column).
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
    sort_dir: Literal["desc", "asc"] = "desc"
    date_range: tuple[str, str] | None = None  # slicerDateRange: the saved (from, to) as ISO dates, both inclusive


# How a selection in one visual reaches another on the page (PBIR page schema `VisualInteractionFilterType`).
INTERACTION_TYPES = ("Default", "DataFilter", "HighlightFilter", "NoFilter")


@dataclass
class Interaction:
    """How a data-point selection in `source` reaches `target`, both visuals of the same page (found by identity):
    "NoFilter" ignores it, "DataFilter" filters, "HighlightFilter" highlights, "Default" leaves it to the target.
    Written as the page's `visualInteractions` by the generated visual names."""
    source: Visual
    target: Visual
    type: Literal["Default", "DataFilter", "HighlightFilter", "NoFilter"] = "NoFilter"


@dataclass
class Page:
    """`name` is the page's internal name (navigation targets it), `display` the tab name users see. A page with
    `drill_fields` is a drill-through page; `keep_filters` is its "keep all filters": on, every filter of the source
    page arrives; off, only the drill fields' values do (the family pages, Review Focus 4). `interactions` change how
    a selection in one of its visuals reaches another (the default: Power BI's cross-filter or cross-highlight)."""
    name: str
    display: str
    visuals: list[Visual]
    filters: list[Filter] = field(default_factory=list)
    drill_fields: list[Field] | None = None
    hidden: bool = False
    keep_filters: bool = True
    interactions: list[Interaction] = field(default_factory=list)


def visual_index(page: Page, visual: Visual) -> int:
    """The index of `visual` in `page.visuals`, by identity (two visuals may be equal field by field); the generated
    visual name is `stable_id(page.name, "visual", index)` on both routes."""
    for i, v in enumerate(page.visuals):
        if v is visual:
            return i
    raise ValueError(f"page {page.display}: an interaction names a {visual.sample} visual that is not on the page")


def interaction_indexes(page: Page) -> list[tuple[int, int, str]]:
    """(source index, target index, type) of each of the page's interactions, checked."""
    out = []
    for it in page.interactions:
        if it.type not in INTERACTION_TYPES:
            raise ValueError(f"page {page.display}: interaction type must be one of {', '.join(INTERACTION_TYPES)}, "
                             f"got {it.type!r}")
        out.append((visual_index(page, it.source), visual_index(page, it.target), it.type))
    return out


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
