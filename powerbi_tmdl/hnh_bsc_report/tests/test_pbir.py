"""The PBIP writer: project tree, live connection, theme and visual resources, pages, visuals, determinism, and checks
against Power BI Desktop's own schemas and project reader when Desktop is installed on this machine."""
import datetime
import json
import zipfile
from pathlib import Path

import pytest

from fields import perspective_fields
from model import Filter, Page, Visual, col, meas
from pages import build_pages
from pbir import (REPORT_NAME, SCHEMAS, connection_string, write_pbip)
import pbir_check

HERE = Path(__file__).resolve().parents[1]
REPO = HERE.parents[1]
GUID = "hnhBscVisual431F658EE9D44EA3BD5E1BEA5FAF899D"
SERVER = "HNHANALYTICSSRV\\REPORTSERVERDB"
# Every $schema URL Desktop wrote in the handover project (Hayat_BSC_Full_RS.Report / .pbip / .SemanticModel).
HANDOVER_SCHEMAS = {
    "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
    "https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json",
    "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/versionMetadata/1.0.0/schema.json",
    "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/3.3.0/schema.json",
    "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json",
    "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json",
    "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.12.0/schema.json",
    "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
    "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json",
}
# Not in the handover (it has no live connection): read from Power BI Desktop 2.158's packaging library.
MODEL_REFERENCE_SCHEMA = \
    "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/modelReference/2.0.0/schema.json"

BUILD_DATE = datetime.date(2026, 6, 1)  # fixed: no test depends on the clock
PAGES = build_pages(BUILD_DATE)


def make_pbiviz(path: Path) -> Path:
    """A stand-in for the packaged HNH visual: same zip layout as `pbiviz package` writes."""
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("package.json", json.dumps({
            "version": "1.0.0.0", "resources": [{"resourceId": "rId0", "sourceType": 5,
                                                  "file": f"resources/{GUID}.pbiviz.json"}],
            "visual": {"name": "hnhBscVisual", "guid": GUID, "version": "1.0.0.0"}}, indent="\t"))
        z.writestr(f"resources/{GUID}.pbiviz.json", json.dumps({"visual": {"guid": GUID}, "content": {"js": "x"}}))
    return path


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def project(tmp_path_factory):
    out = tmp_path_factory.mktemp("pbip")
    pbiviz = make_pbiviz(out.parent / "v.pbiviz")
    pbip = write_pbip(PAGES, out, "HNH_Analytics_Test", SERVER, pbiviz=pbiviz)
    return out, pbip


def report_dir(project):
    return project[0] / f"{REPORT_NAME}.Report"


def page_json(project, name):
    return load(report_dir(project) / "definition" / "pages" / name / "page.json")


def visuals(project, page):
    """The page's visual.json files in Visual order (by z)."""
    vdir = report_dir(project) / "definition" / "pages" / page.name / "visuals"
    out = [load(f) for f in vdir.glob("*/visual.json")]
    return sorted(out, key=lambda v: v["position"]["z"])


def lit(prop):
    return prop["expr"]["Literal"]["Value"]


def proj_refs(v):
    return {role: [p["queryRef"] for p in st["projections"]] for role, st in v["visual"]["query"]["queryState"].items()}


# ---- tree, connection, resources -----------------------------------------------------------------------------------

def test_tree_and_live_connection(project):
    out, pbip = project
    assert pbip == out / f"{REPORT_NAME}.pbip"
    assert load(pbip)["artifacts"] == [{"report": {"path": f"{REPORT_NAME}.Report"}}]
    pbir = load(report_dir(project) / "definition.pbir")
    assert pbir["version"] == "4.0"
    # Desktop 2.158: byConnection is for Fabric models only; an Analysis Services model is byPath to a semantic
    # model folder that holds modelReference.json.
    assert pbir["datasetReference"] == {"byPath": {"path": f"../{REPORT_NAME}.SemanticModel"}}
    sm = out / f"{REPORT_NAME}.SemanticModel"
    assert load(sm / "definition.pbism")["version"] == "4.2"
    ref = load(sm / "modelReference.json")
    assert ref == {"$schema": MODEL_REFERENCE_SCHEMA,
                   "connectionString": 'Data Source=HNHANALYTICSSRV\\REPORTSERVERDB;Initial Catalog=HNH_Analytics_Test;'
                                       'Cube="Balanced Scorecard"',
                   "connectionType": "analysisServicesDatabaseLive"}
    assert load(report_dir(project) / "definition" / "version.json")["version"] == "2.0.0"
    for d in (report_dir(project), sm):
        plat = load(d / ".platform")
        assert plat["metadata"]["displayName"] == REPORT_NAME
        assert len(plat["config"]["logicalId"]) == 36


def test_connection_string_quotes_the_perspective():
    assert connection_string("S\\I", "DB", "Balanced Scorecard") == \
        'Data Source=S\\I;Initial Catalog=DB;Cube="Balanced Scorecard"'


def test_theme_and_visual_registered(project):
    rd = report_dir(project)
    rep = load(rd / "definition" / "report.json")
    tc = rep["themeCollection"]
    assert tc["baseTheme"]["name"] == "CY26SU05" and tc["baseTheme"]["type"] == "SharedResources"
    assert tc["customTheme"]["type"] == "RegisteredResources"
    packages = {p["name"]: p for p in rep["resourcePackages"]}
    (theme_item,) = [i for i in packages["RegisteredResources"]["items"] if i["type"] == "CustomTheme"]
    assert theme_item["name"] == tc["customTheme"]["name"]
    theme = load(rd / "StaticResources" / "RegisteredResources" / theme_item["path"])
    assert theme == load(HERE / "theme" / "hnh_bsc_theme.json")
    (base_item,) = packages["SharedResources"]["items"]
    assert base_item == {"name": "CY26SU05", "path": "BaseThemes/CY26SU05.json", "type": "BaseTheme"}
    assert load(rd / "StaticResources" / "SharedResources" / base_item["path"])["name"] == "CY26SU05"
    # private visual: a CustomVisual resource package plus CustomVisuals/<guid>/, as Desktop for Report Server
    # writes it in Report/CustomVisuals of a pbix; not an AppSource (public) visual
    assert packages[GUID] == {"name": GUID, "type": "CustomVisual", "items": [
        {"name": f"{GUID}.pbiviz.json", "path": f"{GUID}.pbiviz.json", "type": "CustomVisualMetadata"}]}
    assert GUID not in rep.get("publicCustomVisuals", [])
    cv = rd / "CustomVisuals" / GUID
    pkg = load(cv / "package.json")
    assert pkg["visual"]["guid"] == GUID
    assert (cv / pkg["resources"][0]["file"]).is_file()
    assert load(cv / "resources" / f"{GUID}.pbiviz.json")["visual"]["guid"] == GUID


def test_every_json_file_has_its_schema(project):
    out = project[0]
    files = [f for f in out.rglob("*") if f.is_file() and (f.suffix in (".json", ".pbir", ".pbism", ".pbip")
                                                          or f.name == ".platform")]
    skip = {"hnh_bsc_theme.json", "CY26SU05.json", "package.json", f"{GUID}.pbiviz.json"}
    checked = 0
    for f in files:
        if f.name in skip:
            continue
        schema = load(f)["$schema"]
        assert schema in HANDOVER_SCHEMAS | {MODEL_REFERENCE_SCHEMA}, f
        checked += 1
    assert checked > 100
    assert set(SCHEMAS.values()) <= HANDOVER_SCHEMAS | {MODEL_REFERENCE_SCHEMA}


def test_files_are_crlf_two_space_json(project):
    rep = (report_dir(project) / "definition" / "report.json").read_bytes()
    assert rep.startswith(b'{\r\n  "$schema": ')
    assert b"\n" not in rep.replace(b"\r\n", b"")
    assert not rep.startswith(b"\xef\xbb\xbf")


# ---- pages ----------------------------------------------------------------------------------------------------------

def test_pages_in_order(project):
    meta = load(report_dir(project) / "definition" / "pages" / "pages.json")
    assert meta["pageOrder"] == [p.name for p in PAGES]
    assert meta["activePageName"] == PAGES[0].name
    dirs = {d.name for d in (report_dir(project) / "definition" / "pages").iterdir() if d.is_dir()}
    assert dirs == {p.name for p in PAGES}


def test_page_settings(project):
    for p in PAGES:
        pj = page_json(project, p.name)
        assert (pj["name"], pj["displayName"], pj["width"], pj["height"]) == (p.name, p.display, 1920, 1080)
        assert pj["displayOption"] == "FitToPage"
        assert pj.get("visibility") == ("HiddenInViewMode" if p.hidden else None)
        assert len(list((report_dir(project) / "definition" / "pages" / p.name / "visuals").iterdir())) == \
            len(p.visuals)


def test_page_filter(project):
    pj = page_json(project, "financial")
    (f,) = pj["filterConfig"]["filters"]
    assert f["field"] == {"Column": {"Expression": {"SourceRef": {"Entity": "BSC KPI"}}, "Property": "Pillar"}}
    assert f["type"] == "Categorical" and f["howCreated"] == "User"
    cond = f["filter"]["Where"][0]["Condition"]["In"]
    assert cond["Values"] == [[{"Literal": {"Value": "'Financial'"}}]]
    assert "filterConfig" not in page_json(project, "bsc")


def test_drill_through_pages(project):
    for p in PAGES:
        pj = page_json(project, p.name)
        if not p.drill_fields:
            assert "pageBinding" not in pj and "type" not in pj
            continue
        assert pj["type"] == "Drillthrough"
        b = pj["pageBinding"]
        # Default = keep all filters (KPI detail); None = only the drill fields pass (family pages, Review Focus 4)
        assert b["type"] == "Drillthrough"
        assert b["acceptsFilterContext"] == ("Default" if p.keep_filters else "None"), p.display
        filters = {f["name"]: f for f in pj["filterConfig"]["filters"]}
        assert [prm["fieldExpr"]["Column"]["Property"] for prm in b["parameters"]] == [f.name for f in p.drill_fields]
        for prm in b["parameters"]:
            f = filters[prm["boundFilter"]]
            assert f["howCreated"] == "Drillthrough" and f["type"] == "Categorical" and "filter" not in f
            assert f["field"] == prm["fieldExpr"]
            assert prm["name"] == "Param_" + prm["boundFilter"]
    names = [page_json(project, p.name)["pageBinding"]["name"] for p in PAGES if p.drill_fields]
    assert len(names) == len(set(names))


def test_family_pages_do_not_accept_filter_context(project):
    """KPI detail keeps all filters; a family page takes only its drill fields (Branch Name, Year Month Name) and
    filters hospitals itself, so the 'BSC KPI' drill filter never reaches the domain measures' guards."""
    accepts = {p.display: page_json(project, p.name)["pageBinding"]["acceptsFilterContext"]
               for p in PAGES if p.drill_fields}
    assert accepts.pop("KPI detail") == "Default"
    assert len(accepts) == 7 and set(accepts.values()) == {"None"}
    pj = page_json(project, "fam_revenue")
    flts = pj["filterConfig"]["filters"]
    assert [f["howCreated"] for f in flts] == ["Drillthrough", "Drillthrough", "User"]
    assert [f["field"]["Column"]["Property"] for f in flts] == ["Branch Name", "Year Month Name", "Is Hospital"]
    assert flts[2]["filter"]["Where"][0]["Condition"]["In"]["Values"] == [[{"Literal": {"Value": "'Yes'"}}]]


# ---- visuals --------------------------------------------------------------------------------------------------------

TYPES = {"card": "card", "multiRowCard": "multiRowCard", "table": "tableEx", "matrix": "pivotTable",
         "barChart": "clusteredBarChart", "lineChart": "lineChart", "slicerDropdown": "slicer",
         "slicerDateRange": "slicer", "textbox": "textbox", "buttonNavigate": "actionButton",
         "buttonDrill": "actionButton", "hnhVisual": GUID, "panel": "textbox", "image": "image"}


def test_visual_position_type_roles(project):
    for p in PAGES:
        vs = visuals(project, p)
        assert len({v["name"] for v in vs}) == len(vs)
        for i, (vis, vj) in enumerate(zip(p.visuals, vs)):
            pos = vj["position"]
            assert (pos["x"], pos["y"], pos["width"], pos["height"]) == (vis.x, vis.y, vis.w, vis.h)
            assert pos["z"] == pos["tabOrder"] == i * 1000
            assert vj["visual"]["visualType"] == TYPES[vis.sample]
            folder = report_dir(project) / "definition" / "pages" / p.name / "visuals" / vj["name"]
            assert (folder / "visual.json").is_file()
            if vis.roles:
                assert proj_refs(vj) == {r: [f.ref for f in fs] for r, fs in vis.roles.items()}
            else:
                assert "query" not in vj["visual"]


def test_projection_field_shape(project):
    kpi = next(p for p in PAGES if p.name == "kpi_detail")
    vs = visuals(project, kpi)
    bar = vs[[v.sample for v in kpi.visuals].index("barChart")]
    cat, = bar["visual"]["query"]["queryState"]["Category"]["projections"]
    assert cat == {"field": {"Column": {"Expression": {"SourceRef": {"Entity": "Branch"}}, "Property": "Branch Name"}},
                   "queryRef": "Branch.Branch Name", "nativeQueryRef": "Branch Name", "active": True}
    y = bar["visual"]["query"]["queryState"]["Y"]["projections"][0]
    assert y["field"] == {"Measure": {"Expression": {"SourceRef": {"Entity": "_Measures"}}, "Property": "BSC Actual"}}
    assert "active" not in y
    assert bar["visual"]["query"]["sortDefinition"] == {"sort": [{"field": y["field"], "direction": "Descending"}]}
    matrix = vs[[v.sample for v in kpi.visuals].index("matrix")]
    assert all(r.get("active") for r in matrix["visual"]["query"]["queryState"]["Rows"]["projections"])
    assert lit(matrix["visual"]["visualContainerObjects"]["title"][0]["properties"]["text"]) == \
        "'Select a hospital and month, then Open detail'"
    assert lit(bar["visual"]["visualContainerObjects"]["title"][0]["properties"]["text"]) == "'By hospital'"
    fam = next(p for p in PAGES if p.name == "fam_revenue")
    card = visuals(project, fam)[[v.sample for v in fam.visuals].index("card")]
    assert lit(card["visual"]["visualContainerObjects"]["title"][0]["properties"]["show"]) == "false"  # untitled


def test_top_n_and_visual_filters(project):
    rev = next(p for p in PAGES if p.name == "fam_revenue")
    vs = visuals(project, rev)
    i = next(i for i, v in enumerate(rev.visuals) if v.top_n)
    flts = vs[i]["filterConfig"]["filters"]
    (top,) = [f for f in flts if f["type"] == "TopN"]
    assert top["field"]["Column"]["Property"] == "Department Name"
    sub = top["filter"]["From"][0]["Expression"]["Subquery"]["Query"]
    assert sub["Top"] == 15 and sub["OrderBy"][0]["Direction"] == 2
    assert vs[i]["visual"]["query"]["sortDefinition"]["sort"][0]["direction"] == "Descending"


def test_nps_department_chart_ranks_by_answers_and_sorts_by_nps(project):
    exp = next(p for p in PAGES if p.name == "fam_experience")
    i = [v.title for v in exp.visuals].index("NPS by department (15 with most answers)")
    j = visuals(project, exp)[i]
    (top,) = [f for f in j["filterConfig"]["filters"] if f["type"] == "TopN"]
    sub = top["filter"]["From"][0]["Expression"]["Subquery"]["Query"]
    assert sub["Top"] == 15 and sub["OrderBy"][0]["Expression"]["Measure"]["Property"] == "NPS Answers"
    (sort,) = j["visual"]["query"]["sortDefinition"]["sort"]
    assert (sort["field"]["Measure"]["Property"], sort["direction"]) == ("NPS (5-point)", "Descending")
    objs = j["visual"]["objects"]
    assert lit(objs["valueAxis"][0]["properties"]["show"]) == "false"
    assert lit(objs["labels"][0]["properties"]["show"]) == "true"


def _title_box(project, page):
    """The page's title text box (the one at the top of the content box, x 30, y 186)."""
    (j,) = [j for v, j in zip(page.visuals, visuals(project, page))
            if v.sample == "textbox" and (v.x, v.y) == (30, 186)]
    return j["visual"]


def test_table_word_wrap_and_title_style_land_in_objects(project):
    defs = next(p for p in PAGES if p.name == "definitions")
    table = visuals(project, defs)[[v.sample for v in defs.visuals].index("table")]["visual"]
    assert table["visualType"] == "tableEx"
    assert lit(table["objects"]["values"][0]["properties"]["wordWrap"]) == "true"
    assert lit(table["objects"]["columnHeaders"][0]["properties"]["wordWrap"]) == "true"
    fam = next(p for p in PAGES if p.name == "fam_finance")
    tb = _title_box(project, fam)
    run = tb["objects"]["general"][0]["properties"]["paragraphs"][0]["textRuns"][0]
    assert run["textStyle"] == {"fontFamily": "Segoe UI", "fontSize": "22pt", "fontWeight": "bold",
                                "color": "#0A1E32"}
    assert lit(tb["visualContainerObjects"]["background"][0]["properties"]["show"]) == "false"


def test_slicers(project):
    bsc = PAGES[0]
    vs = visuals(project, bsc)
    sl = [(v, j) for v, j in zip(bsc.visuals, vs) if v.sample.startswith("slicer")]
    assert len(sl) == 3
    for v, j in sl:
        f = next(iter(v.roles.values()))[0]
        assert j["visual"]["syncGroup"] == {"groupName": f"bsc {f.ref}", "fieldChanges": True, "filterChanges": True}
        mode = lit(j["visual"]["objects"]["data"][0]["properties"]["mode"])
        assert mode == ("'Between'" if v.sample == "slicerDateRange" else "'Dropdown'")
    branch = sl[0][1]
    assert lit(branch["visual"]["objects"]["selection"][0]["properties"]["selectAllCheckboxEnabled"]) == "true"
    assert branch["filterConfig"]["filters"][0]["field"]["Column"]["Property"] == "Is Hospital"
    rng = next(j for v, j in sl if v.sample == "slicerDateRange")["visual"]["objects"]
    flt = rng["general"][0]["properties"]["filter"]["filter"]
    assert flt["From"] == [{"Name": "d", "Entity": "Date", "Type": 0}]
    (cond,) = flt["Where"]
    lo, hi = cond["Condition"]["And"]["Left"]["Comparison"], cond["Condition"]["And"]["Right"]["Comparison"]
    year = BUILD_DATE.year
    assert (lo["ComparisonKind"], hi["ComparisonKind"]) == (2, 4)  # GreaterThanOrEqual, LessThanOrEqual
    for c, day in ((lo, f"{year}-01-01"), (hi, f"{year}-12-31")):
        assert c["Left"] == {"Column": {"Expression": {"SourceRef": {"Source": "d"}}, "Property": "Date"}}
        assert c["Right"] == {"Literal": {"Value": f"datetime'{day}T00:00:00'"}}
    # the dropdown look: the header in the slicer's objects, the border on its container
    for _, j in sl:
        assert lit(j["visual"]["objects"]["header"][0]["properties"]["textSize"]) == "11D"
        border = j["visual"]["visualContainerObjects"]["border"][0]["properties"]
        assert (lit(border["radius"]), lit(border["color"]["solid"]["color"])) == ("6D", "'#CBD3DC'")
    # every scorecard page's slicers join the same groups (synced by field across pages); KPI detail has none
    groups = {j["visual"]["syncGroup"]["groupName"] for _, j in sl}
    for p in PAGES[1:7]:
        assert {j["visual"]["syncGroup"]["groupName"] for j in visuals(project, p) if "syncGroup" in j["visual"]} \
            == groups
    kpi = next(p for p in PAGES if p.name == "kpi_detail")
    assert not [j for j in visuals(project, kpi) if "syncGroup" in j["visual"]]


def _link(j):
    return j["visual"]["visualContainerObjects"]["visualLink"][0]["properties"]


def test_buttons(project):
    bsc = PAGES[0]
    vs = visuals(project, bsc)
    # the tabs: the navigation buttons on the header bar, one per scorecard page, labelled with its display name
    tabs = [j for v, j in zip(bsc.visuals, vs) if v.sample == "buttonNavigate" and v.y + v.h <= 84]
    assert len(tabs) == 7
    for j, page in zip(tabs, PAGES[:7]):
        link = _link(j)
        assert (lit(link["type"]), lit(link["navigationSection"])) == ("'PageNavigation'", f"'{page.name}'")
        assert "visualLink" not in j["visual"].get("objects", {})
        (label,) = [e for e in j["visual"]["objects"]["text"] if e.get("selector") == {"id": "default"}]
        assert lit(label["properties"]["text"]).strip("'") == page_json(project, page.name)["displayName"]
    # the Overview's buttons over the pillar cards: a tooltip, no label
    over = [j for v, j in zip(bsc.visuals, vs) if v.sample == "buttonNavigate" and v.y >= 186]
    assert [lit(_link(j)["navigationSection"]) for j in over] == [f"'{p.name}'" for p in PAGES[1:5]]
    assert [lit(_link(j)["tooltip"]) for j in over] == [f"'Open {p.display}'" for p in PAGES[1:5]]
    assert all(lit(j["visual"]["objects"]["text"][0]["properties"]["show"]) == "false" for j in over)
    # a pillar page's drill-through button: a literal destination page
    fin = PAGES[1]
    (drill,) = [j for v, j in zip(fin.visuals, visuals(project, fin)) if v.sample == "buttonDrill"]
    assert lit(_link(drill)["type"]) == "'Drillthrough'"
    assert _link(drill)["drillthroughSection"] == {"expr": {"Literal": {"Value": "'kpi_detail'"}}}
    kpi = next(p for p in PAGES if p.name == "kpi_detail")
    kv = visuals(project, kpi)
    backs = [j for v, j in zip(kpi.visuals, kv) if v.sample == "buttonNavigate" and lit(_link(j)["type"]) == "'Back'"]
    assert len(backs) == 1
    props = _link(kv[[v.sample for v in kpi.visuals].index("buttonDrill")])
    assert lit(props["type"]) == "'Drillthrough'"
    assert props["drillthroughSection"] == {"expr": {"Measure": {
        "Expression": {"SourceRef": {"Entity": "_Measures"}}, "Property": "BSC Detail Page"}}}


def test_hnh_visual_and_textbox(project):
    for p in PAGES[:8]:
        vs = visuals(project, p)
        (j,) = [j for v, j in zip(p.visuals, vs) if v.sample == "hnhVisual"]
        (v,) = [v for v in p.visuals if v.sample == "hnhVisual"]
        assert j["visual"]["visualType"] == GUID
        assert j["visual"]["objects"]["scorecard"] == v.props["scorecard"]
        container = j["visual"]["visualContainerObjects"]
        assert lit(container["background"][0]["properties"]["show"]) == "false"
        assert lit(container["border"][0]["properties"]["show"]) == "false"
    fam = next(p for p in PAGES if p.name == "fam_finance")
    tb = _title_box(project, fam)
    assert tb["visualType"] == "textbox"
    assert tb["objects"]["general"][0]["properties"]["paragraphs"][0]["textRuns"][0]["value"] == "Finance detail"


# ---- fields, determinism, errors ------------------------------------------------------------------------------------

def _fields(obj, alias=None, out=None):
    """(kind, table, name) of every field reference: by Entity or through a From alias."""
    out = set() if out is None else out
    alias = dict(alias or {})
    if isinstance(obj, dict):
        for f in obj.get("From") or []:
            if isinstance(f, dict) and "Entity" in f:
                alias[f["Name"]] = f["Entity"]
        for kind in ("Column", "Measure"):
            ref = obj.get(kind)
            if isinstance(ref, dict) and "Property" in ref:
                src = ref["Expression"]["SourceRef"]
                out.add((kind.lower(), src.get("Entity") or alias[src["Source"]], ref["Property"]))
        for v in obj.values():
            _fields(v, alias, out)
    elif isinstance(obj, list):
        for v in obj:
            _fields(v, alias, out)
    return out


def test_no_field_outside_the_perspective(project):
    columns, measures = perspective_fields()
    used = set()
    for f in (report_dir(project) / "definition").rglob("*.json"):
        used |= _fields(load(f))
    assert len(used) > 50
    bad = sorted(u for u in used if (u[1], u[2]) not in (columns if u[0] == "column" else measures))
    assert bad == []


def test_two_writes_are_identical(project, tmp_path):
    out, _ = project
    write_pbip(PAGES, tmp_path, "HNH_Analytics_Test", SERVER, pbiviz=out.parent / "v.pbiviz")

    def tree(root):
        return {str(f.relative_to(root)): f.read_bytes() for f in root.rglob("*") if f.is_file()}
    assert tree(out) == tree(tmp_path)


def test_rewrite_removes_pages_that_are_gone(tmp_path):
    pbiviz = make_pbiviz(tmp_path / "v.pbiviz")
    out = tmp_path / "o"
    write_pbip([Page("a", "A", []), Page("b", "B", [])], out, "X", SERVER, pbiviz=pbiviz)
    write_pbip([Page("a", "A", [])], out, "X", SERVER, pbiviz=pbiviz)
    pages = out / f"{REPORT_NAME}.Report" / "definition" / "pages"
    assert sorted(d.name for d in pages.iterdir() if d.is_dir()) == ["a"]


def test_errors(tmp_path):
    pbiviz = make_pbiviz(tmp_path / "v.pbiviz")
    with pytest.raises(ValueError, match="duplicate page name"):
        write_pbip([Page("a", "A", []), Page("a", "B", [])], tmp_path / "o", "X", SERVER, pbiviz=pbiviz)
    with pytest.raises(ValueError, match="unknown visual kind 'nope'"):
        write_pbip([Page("a", "A", [Visual("nope", 0, 0, 1, 1)])], tmp_path / "o", "X", SERVER, pbiviz=pbiviz)
    with pytest.raises(ValueError, match="sort field"):
        write_pbip([Page("a", "A", [Visual("card", 0, 0, 1, 1, roles={"Values": [meas("A")]}, sort=meas("B"))])],
                   tmp_path / "o", "X", SERVER, pbiviz=pbiviz)
    with pytest.raises(FileNotFoundError, match="pbiviz"):
        write_pbip([Page("a", "A", [])], tmp_path / "o", "X", SERVER, pbiviz=tmp_path / "missing.pbiviz")


def test_find_pbiviz_takes_the_highest_version(tmp_path):
    from pbir import find_pbiviz
    for v in ("1.0.0.0", "1.10.0.0", "1.9.3.0"):
        make_pbiviz(tmp_path / f"hnhBscVisual{GUID}.{v}.pbiviz")
    assert find_pbiviz(tmp_path).name == f"hnhBscVisual{GUID}.1.10.0.0.pbiviz"  # not 1.9.3.0, the last by name


def test_find_pbiviz_needs_a_choice_when_versions_are_unclear(tmp_path):
    from pbir import find_pbiviz
    with pytest.raises(FileNotFoundError, match="npm run package"):
        find_pbiviz(tmp_path)
    make_pbiviz(tmp_path / "hnhBscVisual.pbiviz")
    assert find_pbiviz(tmp_path).name == "hnhBscVisual.pbiviz"  # one package: taken
    make_pbiviz(tmp_path / f"hnhBscVisual{GUID}.1.0.0.0.pbiviz")
    with pytest.raises(ValueError, match="--pbiviz"):
        find_pbiviz(tmp_path)


def test_measure_filter_eq(tmp_path):
    pbiviz = make_pbiviz(tmp_path / "v.pbiviz")
    v = Visual("card", 0, 0, 1, 1, roles={"Values": [meas("A")]}, filters=[Filter(meas("A"), "eq", [1])])
    write_pbip([Page("a", "A", [v])], tmp_path, "X", SERVER, pbiviz=pbiviz)
    (vj,) = (tmp_path / f"{REPORT_NAME}.Report" / "definition" / "pages" / "a" / "visuals").glob("*/visual.json")
    f = load(vj)["filterConfig"]["filters"][0]
    assert f["type"] == "Advanced" and f["howCreated"] == "User"
    assert f["filter"]["Where"][0]["Condition"]["Comparison"]["Right"] == {"Literal": {"Value": "1L"}}


# ---- Power BI Desktop's own checks (offline; skipped when Desktop is not installed) ----------------------------------

needs_desktop = pytest.mark.skipif(not pbir_check.desktop_installed(), reason="Power BI Desktop not installed")


@pytest.fixture(scope="module")
def schema_dir(tmp_path_factory):
    return pbir_check.extract_schemas(tmp_path_factory.mktemp("schemas"))


@needs_desktop
def test_report_definition_matches_desktop_schemas(project, schema_dir):
    assert pbir_check.validate_report(report_dir(project), schema_dir) == []


@needs_desktop
def test_validator_catches_a_bad_file(project, schema_dir, tmp_path):
    import shutil
    rd = tmp_path / "r.Report"
    shutil.copytree(report_dir(project), rd)
    pj = rd / "definition" / "pages" / "bsc" / "page.json"
    d = load(pj)
    d["visibility"] = "Hidden"
    del d["displayOption"]
    pj.write_text(json.dumps(d), encoding="utf-8")
    problems = pbir_check.validate_report(rd, schema_dir)
    assert any("visibility" in p for p in problems) and any("displayOption" in p for p in problems)


@needs_desktop
def test_desktop_opens_the_project(project):
    report = pbir_check.desktop_open(project[1])
    assert "FAIL" not in report and "issue:" not in report, report
    assert "modelReference=True" in report
    assert f"cv {GUID}/package.json" in report


def test_cli_default_writes_the_project(tmp_path, monkeypatch, capsys):
    import sys
    import types
    import build as build_mod
    pages = types.ModuleType("pages")
    pages.PAGES = [Page("a", "A", [Visual("card", 0, 0, 50, 50, roles={"Values": [meas("BSC Actual")]})])]
    monkeypatch.setitem(sys.modules, "pages", pages)
    monkeypatch.setattr(pbir_check, "desktop_installed", lambda: False)
    pbiviz = make_pbiviz(tmp_path / "v.pbiviz")
    assert build_mod.main(["--out", str(tmp_path / "p"), "--pbiviz", str(pbiviz)]) == 0
    assert "database HNH_Analytics_Test" in capsys.readouterr().out
    ref = load(tmp_path / "p" / f"{REPORT_NAME}.SemanticModel" / "modelReference.json")
    assert "Initial Catalog=HNH_Analytics_Test;" in ref["connectionString"]
    assert f"Data Source={SERVER};" in ref["connectionString"]
    pages.PAGES = [Page("a", "A", [Visual("card", 0, 0, 50, 50, roles={"Values": [meas("Nope")]})])]
    assert build_mod.main(["--out", str(tmp_path / "p"), "--pbiviz", str(pbiviz)]) == 1
    assert "[Nope]" in capsys.readouterr().out
    assert build_mod.main(["--format", "pbix"]) == 1


def test_drill_page_charts_show_their_titles(project):
    for p in PAGES[7:]:
        for v, j in zip(p.visuals, visuals(project, p)):
            if v.sample in ("lineChart", "barChart", "table", "matrix"):
                t = j["visual"]["visualContainerObjects"]["title"][0]["properties"]
                assert lit(t["show"]) == "true" and lit(t["text"]) == "'" + v.title.replace("'", "''") + "'"


def test_button_style_lands_in_objects(project):
    kpi = next(p for p in PAGES if p.name == "kpi_detail")
    for v, j in zip(kpi.visuals, visuals(project, kpi)):
        if v.sample in ("buttonNavigate", "buttonDrill"):
            objs = j["visual"]["objects"]
            assert {"fill", "outline", "text"} <= set(objs)
            assert "fill" not in j["visual"]["visualContainerObjects"]


def test_gitignore_written_only_when_missing(tmp_path):
    pbiviz = make_pbiviz(tmp_path / "v.pbiviz")
    out = tmp_path / "o"
    write_pbip([Page("a", "A", [])], out, "X", SERVER, pbiviz=pbiviz)
    assert b"localSettings.json" in (out / ".gitignore").read_bytes()
    (out / ".gitignore").write_bytes(b"mine\n")
    write_pbip([Page("a", "A", [])], out, "X", SERVER, pbiviz=pbiviz)
    assert (out / ".gitignore").read_bytes() == b"mine\n"


def test_committed_project_is_current():
    """The project in the repository equals a fresh build for HNH_Analytics_Test: rebuild and commit after a change
    to pages.py, the theme or the writer. CR/LF is ignored (git may check text files out either way). Without the
    packaged visual in hnh_bsc_visual/dist, the stand-in package is used and CustomVisuals is not compared."""
    import tempfile
    from pbir import VISUAL_DIST, committed_year, find_pbiviz, project_files
    year = committed_year(HERE)  # the saved Date range's year is the committed project's, not the clock's
    assert year is not None
    pages = build_pages(datetime.date(year, 1, 1))
    real = sorted(VISUAL_DIST.glob("hnhBscVisual*.pbiviz"))
    with tempfile.TemporaryDirectory() as tmp:
        pbiviz = find_pbiviz() if real else make_pbiviz(Path(tmp) / "v.pbiviz")
        files = project_files(pages, "HNH_Analytics_Test", pbiviz=pbiviz)
    skip = () if real else (f"{REPORT_NAME}.Report/CustomVisuals/",)
    expected = {k: v for k, v in files.items() if not k.startswith(skip) and k != ".gitignore"}
    roots = [HERE / f"{REPORT_NAME}.Report", HERE / f"{REPORT_NAME}.SemanticModel"]
    committed = {f.relative_to(HERE).as_posix(): f.read_bytes() for r in roots for f in r.rglob("*")
                 if f.is_file() and "/.pbi/" not in f.relative_to(HERE).as_posix() + "/"
                 and not f.relative_to(HERE).as_posix().startswith(skip)}
    committed[f"{REPORT_NAME}.pbip"] = (HERE / f"{REPORT_NAME}.pbip").read_bytes()

    def norm(d):
        return {k: v.replace(b"\r\n", b"\n") for k, v in d.items()}
    stale = sorted(set(norm(expected).items()) ^ set(norm(committed).items()))
    assert not stale, "project out of date; run build.py and commit: " + ", ".join(sorted({k for k, _ in stale})[:10])


# ---- the frame: panel and image visuals, the logo, the theme ----------------------------------------------------------

@pytest.fixture(scope="module")
def frame_project(tmp_path_factory):
    """A page with only the frame (Overview current) and a stand-in for the slicers."""
    import frame
    out = tmp_path_factory.mktemp("frame")
    pbiviz = make_pbiviz(out.parent / "fv.pbiviz")
    slicer = Visual("slicerDropdown", 30, 96, 300, 54, roles={"Values": [col("Branch", "Branch Name")]})
    page = Page("bsc", "Overview", frame.frame("bsc", [slicer]))
    pbip = write_pbip([page], out, "HNH_Analytics_Test", SERVER, pbiviz=pbiviz)
    return out, pbip, page


def test_report_registers_the_logo(frame_project):
    import frame
    rd = report_dir(frame_project)
    rep = load(rd / "definition" / "report.json")
    (reg,) = [p for p in rep["resourcePackages"] if p["name"] == "RegisteredResources"]
    assert {"name": "hnh_logo_white.png", "path": "hnh_logo_white.png", "type": "Image"} in reg["items"]
    png = rd / "StaticResources" / "RegisteredResources" / "hnh_logo_white.png"
    assert png.read_bytes() == frame.LOGO.read_bytes()


def test_panel_is_a_textbox_with_a_container_background(frame_project):
    page = frame_project[2]
    vs = visuals(frame_project, page)
    panels = [j for v, j in zip(page.visuals, vs) if v.sample == "panel"]
    assert len(panels) >= 3  # header, filter bar, rule (+ the current tab's underline)
    for j in panels:
        assert j["visual"]["visualType"] == "textbox"
        assert "general" not in j["visual"].get("objects", {})  # no paragraphs
        bg = j["visual"]["visualContainerObjects"]["background"][0]["properties"]
        assert lit(bg["show"]) == "true" and lit(bg["color"]["solid"]["color"]).startswith("'#")
    header = panels[0]["visual"]["visualContainerObjects"]["background"][0]["properties"]
    assert lit(header["color"]["solid"]["color"]) == "'#0A1E32'"


def test_image_visual_points_at_the_registered_logo(frame_project):
    page = frame_project[2]
    (j,) = [j for v, j in zip(page.visuals, visuals(frame_project, page)) if v.sample == "image"]
    assert j["visual"]["visualType"] == "image"
    src = j["visual"]["objects"]["image"][0]["properties"]["sourceFile"]["image"]
    assert src["url"]["expr"]["ResourcePackageItem"] == {
        "PackageName": "RegisteredResources", "PackageType": 1, "ItemName": "hnh_logo_white.png"}
    assert "query" not in j["visual"]


@needs_desktop
def test_frame_matches_desktop_schemas(frame_project, schema_dir):
    assert pbir_check.validate_report(report_dir(frame_project), schema_dir) == []


@needs_desktop
def test_desktop_opens_the_frame_project(frame_project):
    report = pbir_check.desktop_open(frame_project[1])
    assert "FAIL" not in report and "issue:" not in report, report


def test_theme():
    theme = load(HERE / "theme" / "hnh_bsc_theme.json")
    assert theme["dataColors"] == ["#002E5A", "#1478BE", "#13ACE3", "#6E8196",
                                   "#13ACE3", "#32A4E5", "#0E9F8E", "#EF8B00"]
    assert (theme["good"], theme["neutral"], theme["bad"]) == ("#0E9F8E", "#EF8B00", "#DB280A")
    vs = theme["visualStyles"]
    page = vs["page"]["*"]
    assert page["background"] == [{"color": {"solid": {"color": "#F4F7FB"}}, "transparency": 0}]
    assert page["outspace"] == [{"color": {"solid": {"color": "#F4F7FB"}}}]
    # controller ruling R2: no box on every visual (the navy header's tabs and panels would get white boxes)
    assert "background" not in vs.get("*", {}).get("*", {}) and "border" not in vs.get("*", {}).get("*", {})
    for kind in ("card", "multiRowCard", "tableEx", "pivotTable", "clusteredBarChart", "lineChart", "slicer"):
        style = vs[kind]["*"]
        assert style["background"] == [{"show": True, "color": {"solid": {"color": "#FFFFFF"}}, "transparency": 0}]
        assert style["border"] == [{"show": True, "color": {"solid": {"color": "#DCE5EF"}}, "radius": 12,
                                    "width": 1}]
    # the HNH visual draws its own panels on the page surface: no container box (keyed by its type, the guid)
    guid = load(REPO / "powerbi_tmdl" / "hnh_bsc_visual" / "pbiviz.json")["visual"]["guid"]
    assert vs[guid]["*"]["background"] == [{"show": False}]
    assert vs[guid]["*"]["border"] == [{"show": False}]


def test_pbix_route_skips_panel_and_image(pbix_path, tmp_path, capsys):
    import frame
    from build import build
    from pbix import read_pbix
    card = Visual("card", 0, 0, 50, 50, roles={"Values": [meas("BSC Actual")]}, title="x")
    page = Page("p", "P", [frame.panel(0, 0, 1920, 84, "#0A1E32"), card, frame.image(30, 21, 220, 42)])
    out = tmp_path / "o.pbix"
    build(pbix_path, [page], "X", out)
    (section,) = read_pbix(out).layout["sections"]
    assert len(section["visualContainers"]) == 1
    note = capsys.readouterr().out
    assert "2 " in note and "panel" in note and "image" in note


def _desktop_theme_schema() -> dict:
    """Power BI Desktop's report theme schema, as its web bundle embeds it (a JSON.parse('...') string literal)."""
    src = (pbir_check.DESKTOP_BIN / "WebView2Resources" / "minerva" / "scripts" /
           "desktop.reportThemeSchema.json.min.js").read_text(encoding="utf-8")
    raw = src[src.index("JSON.parse('") + len("JSON.parse('"):src.rindex("')}}")]
    out, i = [], 0
    while i < len(raw):  # undo the JS string escapes: backslash-backslash, backslash-quote, backslash-xNN
        if raw[i] == "\\" and raw[i + 1] in ("\\", "'"):
            out.append(raw[i + 1])
            i += 2
        elif raw[i] == "\\" and raw[i + 1] == "x":
            out.append(chr(int(raw[i + 2:i + 4], 16)))
            i += 4
        else:
            out.append(raw[i])
            i += 1
    return json.loads("".join(out))


@needs_desktop
def test_theme_matches_desktop_theme_schema():
    schema = _desktop_theme_schema()
    theme = load(HERE / "theme" / "hnh_bsc_theme.json")
    assert pbir_check._errors(theme, schema, schema, None, "$") == []
    theme["visualStyles"]["card"]["*"]["border"][0]["radius"] = "12"
    assert pbir_check._errors(theme, schema, schema, None, "$") != []  # the check bites


def test_frame_project_converts_to_the_report_server_package(frame_project, tmp_path):
    """The Report Server route (pbir_to_pbix.py) carries the panels, the image and the logo resource."""
    import pbir_to_pbix
    from pbix import check_upload_rules
    out = tmp_path / "frame.pbix"
    layout = pbir_to_pbix.write(frame_project[1], out)
    assert check_upload_rules(out) == []
    (section,) = layout["sections"]
    assert len(section["visualContainers"]) == len(frame_project[2].visuals)
    (reg,) = [p["resourcePackage"] for p in layout["resourcePackages"]
              if p["resourcePackage"]["name"] == "RegisteredResources"]
    assert "hnh_logo_white.png" in {i["name"] for i in reg["items"]}
    with zipfile.ZipFile(out) as z:
        assert "Report/StaticResources/RegisteredResources/hnh_logo_white.png" in z.namelist()
