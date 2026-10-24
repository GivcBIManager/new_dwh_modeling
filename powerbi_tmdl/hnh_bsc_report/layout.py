"""Rebind the template's sample visuals and write pages into the legacy Report/Layout JSON.

Shapes (see LAYOUT_FORMAT.md, "Generator shapes"): prototypeQuery, projections, sort and slicer sync groups follow
Desktop-written files on this server; filters, top N and the drill-through binding follow the standard layout format
and are each written by one small function here (`filter_json`, `top_n_json`, `drill_through`) so they can be
corrected against the real template.
"""
from __future__ import annotations

import copy
import hashlib
import json
from decimal import Decimal

from model import Field, Filter, Page, Visual

SYNC_PREFIX = "bsc "  # sync group per field: "bsc Branch.Branch Name"
PAGE_WIDTH, PAGE_HEIGHT = 1920, 1080
DIRECTION = {"asc": 1, "desc": 2}  # OrderBy Direction
DESCENDING = DIRECTION["desc"]
# singleVisual keys the generator sets itself; any other key that names a field no longer bound is dropped.
_OWN_KEYS = {"visualType", "projections", "prototypeQuery", "objects", "vcObjects", "syncGroup", "columnProperties",
             "showAllRoles", "hasDefaultSort", "drillFilterOtherVisuals"}


def stable_id(*parts) -> str:
    """A 20-hex name like Desktop's, derived from `parts` so a rebuild writes the same names."""
    return hashlib.sha1("|".join(map(str, parts)).encode("utf-8")).hexdigest()[:20]


def _dump(obj) -> str:
    return json.dumps(obj, separators=(",", ":"), ensure_ascii=False)


# ---- expressions -------------------------------------------------------------------------------------------------

def lit(value) -> dict:
    """A query literal: 'text' (quotes doubled), 12L, 1.5D (plain decimal, never an exponent), true / false,
    null."""
    if value is None:
        v = "null"
    elif isinstance(value, bool):
        v = "true" if value else "false"
    elif isinstance(value, int):
        v = f"{value}L"
    elif isinstance(value, float):
        d = format(Decimal(repr(value)), "f")
        if "." in d:
            d = d.rstrip("0").rstrip(".")
        v = f"{d}D"
    else:
        v = "'" + str(value).replace("'", "''") + "'"
    return {"Literal": {"Value": v}}


def _kind(f: Field) -> str:
    return "Measure" if f.kind == "measure" else "Column"


def field_expr(f: Field) -> dict:
    """A field named by its table, as filters, drill-through parameters and format objects write it."""
    return {_kind(f): {"Expression": {"SourceRef": {"Entity": f.table}}, "Property": f.name}}


def source_expr(f: Field, alias: str) -> dict:
    """A field named through a query's From alias."""
    return {_kind(f): {"Expression": {"SourceRef": {"Source": alias}}, "Property": f.name}}


def aliases(tables) -> dict[str, str]:
    """From aliases the way Desktop writes them: the table's first letter in lower case ('_' for _Measures), then
    'p1', 'p2' ... for the next tables with the same letter."""
    out: dict[str, str] = {}
    for t in tables:
        if t in out:
            continue
        base = next((c.lower() for c in t if c.isalpha() or c == "_"), "t")
        a, n = base, 1
        while a in out.values() or a == "subquery":
            a, n = f"{base}{n}", n + 1
        out[t] = a
    return out


def _from(al: dict[str, str]) -> list[dict]:
    return [{"Name": a, "Entity": t, "Type": 0} for t, a in al.items()]


# ---- filters (standard format; see LAYOUT_FORMAT.md) -------------------------------------------------------------

def filter_json(name: str, flt: Filter) -> dict:
    """A user filter for a visual's or a page's `filters` list. A column `in` / `eq`: Categorical In (what the filter
    pane writes for ticked values). A measure `eq`: Advanced, is the value. `notblank` (column or measure):
    Advanced, Not (is blank), the filter pane's "is not blank"."""
    f = flt.field
    values = list(flt.values) if isinstance(flt.values, (list, tuple, set)) else [flt.values]
    if flt.op == "notblank":
        if values:
            raise ValueError(f"filter on {f}: notblank takes no values, got {values}")
    elif flt.op not in ("in", "eq") or (flt.op == "eq" and len(values) != 1) or not values:
        raise ValueError(f"filter on {f}: op must be 'in' (values), 'eq' (one value) or 'notblank', "
                         f"got {flt.op} {values}")
    al = aliases([f.table])
    src = source_expr(f, al[f.table])
    if flt.op == "notblank":
        cond = {"Not": {"Expression": {"Comparison": {"ComparisonKind": 0, "Left": src, "Right": lit(None)}}}}
        ftype = "Advanced"
    elif f.kind == "measure":
        if flt.op != "eq":
            raise ValueError(f"filter on {f}: a measure filter takes 'eq' or 'notblank'")
        cond, ftype = {"Comparison": {"ComparisonKind": 0, "Left": src, "Right": lit(values[0])}}, "Advanced"
    else:
        cond, ftype = {"In": {"Expressions": [src], "Values": [[lit(v)] for v in values]}}, "Categorical"
    return {"name": name, "expression": field_expr(f),
            "filter": {"Version": 2, "From": _from(al), "Where": [{"Condition": cond}]},
            "type": ftype, "howCreated": 1}


def top_n_json(name: str, column: Field, by: Field, n: int) -> dict:
    """Top N filter on `column` by `by` descending (standard format: an In over a Top-N subquery)."""
    al = aliases([column.table, by.table])
    inner = {"Version": 2, "From": _from(al),
             "Select": [{**source_expr(column, al[column.table]), "Name": "field"}],
             "OrderBy": [{"Direction": DESCENDING, "Expression": source_expr(by, al[by.table])}],
             "Top": int(n)}
    outer = {"Name": al[column.table], "Entity": column.table, "Type": 0}
    return {"name": name, "expression": field_expr(column),
            "filter": {"Version": 2,
                       "From": [{"Name": "subquery", "Expression": {"Subquery": {"Query": inner}}, "Type": 2}, outer],
                       "Where": [{"Condition": {"In": {"Expressions": [source_expr(column, al[column.table])],
                                                       "Table": {"SourceRef": {"Source": "subquery"}}}}}]},
            "type": "TopN", "howCreated": 1}


# ---- drill-through (copied from the template's Drill sample page) ------------------------------------------------

def drill_through(layout: dict, sample: dict, page: Page) -> tuple[list[dict], dict, list[dict]]:
    """(drill filters for the page, page config, pods) for a drill-through page, cloned from the template's
    `Drill sample` page so its settings (keep all filters) carry over; a page with `keep_filters` off gets it turned
    off (`keep_filters_off`). The binding is read from a root `pods` entry bound to that page or from the page
    config's `pageBinding`; its parameters and the drill filters they name are rewritten for `page.drill_fields`. Not
    confirmed by a real file: check against the real template."""
    fields = page.drill_fields or []
    if any(f.kind != "column" for f in fields):
        raise ValueError(f"page {page.display}: drill-through fields must be columns")
    cfg = json.loads(sample.get("config") or "{}")
    cfg.pop("relationships", None)
    pods = [p for p in layout.get("pods", []) if p.get("boundSection") == sample["name"]]
    if pods:
        binding = copy.deepcopy(pods[0])
    elif isinstance(cfg.get("pageBinding"), dict):
        binding = cfg["pageBinding"]
    else:
        raise ValueError("the template's 'Drill sample' page has no drill-through binding (no pods entry bound to "
                         "it and no pageBinding): set its drill-through field and save the template again")
    raw = binding.get("parameters") or []
    params = json.loads(raw) if isinstance(raw, str) else raw
    sample_filters = json.loads(sample.get("filters") or "[]")
    bound = {p.get("boundFilter") for p in params}
    base = next((f for f in sample_filters if f.get("name") in bound), None) \
        or next((f for f in sample_filters if f.get("howCreated") == 5), None)
    if not params or base is None:
        raise ValueError("the template's 'Drill sample' page has no drill-through field")
    new_filters, new_params = [], []
    for i, f in enumerate(fields):
        name = stable_id(page.name, "drill", i)
        flt = copy.deepcopy(base)
        flt.pop("filter", None)
        flt.update(name=name, expression=field_expr(f))
        new_filters.append(flt)
        prm = copy.deepcopy(params[0])
        prm.update(name="Param_" + name, boundFilter=name, fieldExpr=field_expr(f))
        new_params.append(prm)
    binding["parameters"] = _dump(new_params) if isinstance(raw, str) else new_params
    binding["name"] = stable_id(page.name, "pod")
    if not page.keep_filters:
        keep_filters_off(binding, in_config=bool(pods))
    if pods:
        binding["boundSection"] = page.name
        return new_filters, cfg, [binding]
    return new_filters, cfg, []


def keep_filters_off(binding: dict, in_config: bool) -> None:
    """Turn "keep all filters" off in a cloned binding (only the drill fields arrive): acceptsFilterContext "None",
    PBIR's name for it, in a pod's `config` JSON string (`in_config`) or on a pageBinding itself. Not confirmed by a
    real file: check against a Desktop-saved drill page with keep all filters off."""
    if in_config:
        cfg = json.loads(binding.get("config") or "{}")
        cfg["acceptsFilterContext"] = "None"
        binding["config"] = _dump(cfg)
    else:
        binding["acceptsFilterContext"] = "None"


# ---- rebinding one visual ----------------------------------------------------------------------------------------

def _field_refs(obj) -> set[tuple[str, str]]:
    """(table, field) of every field named inside `obj`: by table (`SourceRef.Entity`) or through an alias of a
    `From` list inside `obj` (a slicer's selection filter); hierarchy levels as (table, level)."""
    alias: dict[str, str] = {}
    refs: set[tuple[str, str]] = set()

    def froms(o):
        if isinstance(o, dict):
            for f in o.get("From") or []:
                if isinstance(f, dict) and isinstance(f.get("Entity"), str):
                    alias[f.get("Name")] = f["Entity"]
            for v in o.values():
                froms(v)
        elif isinstance(o, list):
            for v in o:
                froms(v)

    def walk(o):
        if isinstance(o, dict):
            prop = o.get("Property") if isinstance(o.get("Property"), str) else o.get("Level")
            if isinstance(prop, str) and isinstance(o.get("Expression"), dict):
                expr = o["Expression"]
                if "Level" in o and isinstance(expr.get("Hierarchy"), dict):
                    expr = expr["Hierarchy"].get("Expression") or {}
                ref = expr.get("SourceRef") or {}
                entity = ref.get("Entity") or alias.get(ref.get("Source"))
                if entity:
                    refs.add((entity, prop))
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    froms(obj)
    walk(obj)
    return refs


def _strings(obj, out: set | None = None) -> set:
    out = set() if out is None else out
    if isinstance(obj, dict):
        for v in obj.values():
            _strings(v, out)
    elif isinstance(obj, list):
        for v in obj:
            _strings(v, out)
    elif isinstance(obj, str):
        out.add(obj)
    return out


def _foreign(obj, allowed: set, gone_refs: set) -> bool:
    """True when `obj` names a field the new binding does not have: any field reference outside `allowed`, or a
    sample queryRef no longer bound (e.g. `selector.metadata`)."""
    return bool(_field_refs(obj) - allowed) or bool(gone_refs & _strings(obj))


def _scrub(objects: dict, allowed: set, gone_refs: set) -> dict:
    """Format objects without field-based rules on fields the visual no longer has: such a property is removed
    (static formatting in the same entry stays); an entry whose selector names such a field, or that held only such
    properties, is removed."""
    out = {}
    for name, entries in objects.items():
        if not isinstance(entries, list):
            out[name] = entries
            continue
        kept = []
        for e in entries:
            if not isinstance(e, dict):
                kept.append(e)
                continue
            if _foreign(e.get("selector"), allowed, gone_refs):
                continue
            e = dict(e)
            props = e.get("properties")
            if isinstance(props, dict):
                clean = {k: v for k, v in props.items() if not _foreign(v, allowed, gone_refs)}
                if props and not clean:
                    continue
                e["properties"] = clean
            kept.append(e)
        if kept:
            out[name] = kept
    return out


def _set_title(sv: dict, title: str | None) -> None:
    vco = sv.setdefault("vcObjects", {})
    for e in vco.get("general", []):  # a sample key kept in Alt text
        alt = e.get("properties", {}).get("altText")
        if "sample:" in json.dumps(alt or ""):
            e["properties"].pop("altText")
    entries = vco.setdefault("title", [])
    if not any("selector" not in e for e in entries):
        entries.append({"properties": {}})
    for e in entries:
        props = e.setdefault("properties", {})
        if title is None:
            props.pop("text", None)
            if "selector" not in e:
                props["show"] = {"expr": lit(False)}
        elif "selector" not in e:
            props.update(show={"expr": lit(True)}, text={"expr": lit(title)})


def merge_props(sv: dict, props: dict) -> None:
    """Merge format objects: into `vcObjects` when the sample holds that object there (a button's visualLink),
    else into `objects`; an entry with the same selector has its properties updated, others are appended."""
    for obj, entries in props.items():
        target = "vcObjects" if obj in sv.get("vcObjects", {}) and obj not in sv.get("objects", {}) else "objects"
        current = sv.setdefault(target, {}).setdefault(obj, [])
        for e in copy.deepcopy(entries):
            match = next((x for x in current if x.get("selector") == e.get("selector")), None)
            if match is None:
                current.append(e)
            else:
                match.setdefault("properties", {}).update(e.get("properties", {}))


def rebind(sample: dict, visual: Visual, page: Page, index: int) -> dict:
    """A new visual container: the sample's own JSON (deep copy) bound to `visual`'s fields, position and title."""
    vc = copy.deepcopy(sample)
    vc.pop("query", None)           # Desktop's caches of the sample's query; it rebuilds them
    vc.pop("dataTransforms", None)
    cfg = json.loads(vc["config"])
    sv = cfg.setdefault("singleVisual", {})
    fields: list[Field] = []
    for fs in visual.roles.values():
        fields += [f for f in fs if f not in fields]
    if visual.sort and visual.sort not in fields:
        raise ValueError(f"page {page.display}: sort field {visual.sort} is not one of the {visual.sample}'s fields")
    if visual.sort_dir not in DIRECTION:
        raise ValueError(f"page {page.display}: sort_dir must be 'desc' or 'asc', got {visual.sort_dir!r}")
    if visual.top_n and visual.top_n[0].kind != "measure":
        raise ValueError(f"page {page.display}: top N ranks by a measure, got {visual.top_n[0]}")
    allowed = {(f.table, f.name) for f in fields}
    old_refs = {s.get("Name") for s in (sv.get("prototypeQuery") or {}).get("Select", [])}
    gone_refs = {r for r in old_refs if isinstance(r, str)} - {f.ref for f in fields}

    # projections and query
    old_proj = sv.pop("projections", {}) or {}
    old_query = sv.pop("prototypeQuery", None)
    sv.pop("showAllRoles", None)    # never "show items with no data" (Review Focus 1)
    if fields:
        proj = {}
        for role, fs in visual.roles.items():
            items = []
            for i, f in enumerate(fs):
                base = (old_proj.get(role) or [])[i:i + 1]
                extra = {k: v for k, v in (base[0] if base else {}).items() if k not in ("queryRef", "showAll")}
                if sv.get("visualType") == "pivotTable" and role == "Rows":
                    extra["active"] = True  # every row level expanded
                items.append({"queryRef": f.ref, **extra})
            proj[role] = items
        sv["projections"] = proj
        al = aliases(f.table for f in fields)
        q = {"Version": (old_query or {}).get("Version", 2), "From": _from(al),
             "Select": [{**source_expr(f, al[f.table]), "Name": f.ref, "NativeReferenceName": f.name}
                        for f in fields]}
        if visual.sort:
            q["OrderBy"] = [{"Direction": DIRECTION[visual.sort_dir],
                             "Expression": source_expr(visual.sort, al[visual.sort.table])}]
            sv.pop("hasDefaultSort", None)
        sv["prototypeQuery"] = q
    elif visual.sort or visual.top_n:
        raise ValueError(f"page {page.display}: a {visual.sample} visual without fields cannot sort or take a top N")
    refs = {f.ref for f in fields}
    cp = {k: v for k, v in (sv.pop("columnProperties", None) or {}).items() if k in refs}
    if cp:
        sv["columnProperties"] = cp
    for key in [k for k in sv if k not in _OWN_KEYS]:
        if _foreign(sv[key], allowed, gone_refs):
            del sv[key]
    for key in ("objects", "vcObjects"):
        if key in sv:
            sv[key] = _scrub(sv[key], allowed, gone_refs)

    _set_title(sv, visual.title)
    merge_props(sv, visual.props)
    if "slicer" in str(sv.get("visualType", "")).lower() and fields:
        # one group per field: the same slicer syncs across pages, different slicers never sync with each other
        sv["syncGroup"] = {"groupName": SYNC_PREFIX + fields[0].ref, "fieldChanges": True, "filterChanges": True}
    else:
        sv.pop("syncGroup", None)

    # visual-level filters: the visual's own, then top N
    flts = [filter_json(stable_id(page.name, index, "filter", j), f) for j, f in enumerate(visual.filters)]
    if visual.top_n:
        by, n = visual.top_n
        column = next((f for f in fields if f.kind == "column"), None)
        if column is None:
            raise ValueError(f"page {page.display}: top N on a {visual.sample} visual needs a column to rank")
        flts.append(top_n_json(stable_id(page.name, index, "topn"), column, by, n))
    vc["filters"] = _dump(flts)

    # name and position
    z = index * 1000
    pos = {"x": visual.x, "y": visual.y, "z": z, "width": visual.w, "height": visual.h, "tabOrder": z}
    vc.update(x=visual.x, y=visual.y, z=z, width=visual.w, height=visual.h)
    if "tabOrder" in vc:
        vc["tabOrder"] = z
    cfg["name"] = stable_id(page.name, "visual", index)
    cfg["layouts"] = [{"id": 0, "position": pos}]
    cfg.pop("parentGroupName", None)
    vc["config"] = _dump(cfg)
    return vc


# ---- pages -------------------------------------------------------------------------------------------------------

def page_section(page: Page, index: int, samples: dict, layout: dict, drill_sample: dict | None,
                 base: dict) -> tuple[dict, list[dict]]:
    """(section, pods) for one page. `base` is the template page whose page-level keys are kept."""
    containers = []
    for i, v in enumerate(page.visuals):
        if v.sample not in samples:
            raise ValueError(f"page {page.display}: unknown sample '{v.sample}' (template has: "
                             f"{', '.join(sorted(samples))})")
        containers.append(rebind(samples[v.sample], v, page, i))
    filters = [filter_json(stable_id(page.name, "page-filter", j), f) for j, f in enumerate(page.filters)]
    cfg, pods = {}, []
    if page.drill_fields:
        if drill_sample is None:
            raise ValueError("the template has no 'Drill sample' page")
        drill_filters, cfg, pods = drill_through(layout, drill_sample, page)
        filters = drill_filters + filters
    if page.hidden:
        cfg["visibility"] = 1
    else:
        cfg.pop("visibility", None)
    section = {k: v for k, v in base.items() if k not in ("visualContainers", "filters", "config")}
    section.update(id=index, name=page.name, displayName=page.display, filters=_dump(filters), ordinal=index,
                   visualContainers=containers, config=_dump(cfg), width=PAGE_WIDTH, height=PAGE_HEIGHT)
    return section, pods


def show_all_on_branch(layout: dict) -> list[str]:
    """Visuals that set "show items with no data" on a Branch field (Review Focus 1), as "<page>: <visual>"."""
    found = []
    for s in layout.get("sections", []):
        for vc in s.get("visualContainers", []):
            cfg = json.loads(vc["config"])
            sv = cfg.get("singleVisual", {})
            proj = sv.get("projections", {}) or {}
            roles = set(sv.get("showAllRoles") or [])
            for role, items in proj.items():
                if any(str(it.get("queryRef", "")).startswith("Branch.") and (it.get("showAll") or role in roles)
                       for it in items):
                    found.append(f"{s.get('displayName')}: {cfg.get('name')}")
                    break
    return found
