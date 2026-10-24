"""Generator core: rebinding the template's sample visuals into pages (synthetic template from conftest)."""
import json

import pytest

from conftest import DRILL_FILTER, build_layout, good_parts
from build import build
from model import Filter, Page, Visual, col, meas
from pbix import check_upload_rules, read_pbix

DEPT = col("Department", "Department Name")
REVENUE = meas("Revenue")
BRANCH = col("Branch", "Branch Name")
YEAR_MONTH = col("Date", "Year Month")


def run(tmp_path, template, pages, database="HNH_Analytics"):
    out = tmp_path / "out.pbix"
    build(template, pages, database, out)
    return read_pbix(out)


def containers(layout):
    for s in layout["sections"]:
        for vc in s["visualContainers"]:
            yield s, vc, json.loads(vc["config"])


def page_of(layout, display):
    return next(s for s in layout["sections"] if s["displayName"] == display)


def only_visual(layout, display):
    vcs = page_of(layout, display)["visualContainers"]
    assert len(vcs) == 1
    return vcs[0], json.loads(vcs[0]["config"])


def bar_page(**kw):
    v = Visual("barChart", 10, 20, 300, 200, roles={"Category": [DEPT], "Y": [REVENUE]}, title="Revenue", **kw)
    return Page("p_bar", "Bars", [v])


def test_rebind_bar_chart_writes_query_and_projections(pbix_path, tmp_path):
    p = run(tmp_path, pbix_path, [bar_page()])
    vc, cfg = only_visual(p.layout, "Bars")
    sv = cfg["singleVisual"]
    assert sv["visualType"] == "clusteredBarChart"
    assert sv["projections"] == {"Category": [{"queryRef": "Department.Department Name", "active": True}],
                                 "Y": [{"queryRef": "_Measures.Revenue"}]}
    q = sv["prototypeQuery"]
    assert q["Version"] == 2
    assert q["From"] == [{"Name": "d", "Entity": "Department", "Type": 0},
                         {"Name": "_", "Entity": "_Measures", "Type": 0}]
    assert q["Select"] == [
        {"Column": {"Expression": {"SourceRef": {"Source": "d"}}, "Property": "Department Name"},
         "Name": "Department.Department Name", "NativeReferenceName": "Department Name"},
        {"Measure": {"Expression": {"SourceRef": {"Source": "_"}}, "Property": "Revenue"},
         "Name": "_Measures.Revenue", "NativeReferenceName": "Revenue"}]
    # position on the container and in the layout
    assert (vc["x"], vc["y"], vc["width"], vc["height"]) == (10, 20, 300, 200)
    assert cfg["layouts"] == [{"id": 0, "position": {"x": 10, "y": 20, "z": 0, "width": 300, "height": 200,
                                                     "tabOrder": 0}}]


def test_rebind_leaves_nothing_of_the_sample_fields(pbix_path, tmp_path):
    p = run(tmp_path, pbix_path, [bar_page()])
    vc, cfg = only_visual(p.layout, "Bars")
    text = json.dumps(vc, ensure_ascii=False) + json.dumps(cfg, ensure_ascii=False)
    for old in ("KPI Code", "Score", "BSC KPI", "sample:"):
        assert old not in text
    sv = cfg["singleVisual"]
    assert "query" not in vc and "dataTransforms" not in vc  # Desktop's caches of the sample's query
    assert "columnProperties" not in sv
    assert "OrderBy" not in sv["prototypeQuery"]
    # format settings that name no field survive
    assert sv["objects"]["dataPoint"] == [{"properties": {"showAllDataPoints": {"expr": {"Literal": {
        "Value": "true"}}}}}]


def test_top_n_filter_and_sort(pbix_path, tmp_path):
    p = run(tmp_path, pbix_path, [bar_page(top_n=(REVENUE, 15), sort=REVENUE)])
    vc, cfg = only_visual(p.layout, "Bars")
    q = cfg["singleVisual"]["prototypeQuery"]
    assert q["OrderBy"] == [{"Direction": 2, "Expression": {"Measure": {
        "Expression": {"SourceRef": {"Source": "_"}}, "Property": "Revenue"}}}]
    assert "hasDefaultSort" not in cfg["singleVisual"]
    filters = json.loads(vc["filters"])
    top = [f for f in filters if f["type"] == "TopN"]
    assert len(top) == 1
    t = top[0]
    assert t["expression"] == {"Column": {"Expression": {"SourceRef": {"Entity": "Department"}},
                                          "Property": "Department Name"}}
    sub = t["filter"]["From"][0]
    assert sub["Name"] == "subquery" and sub["Type"] == 2
    inner = sub["Expression"]["Subquery"]["Query"]
    assert inner["Top"] == 15
    assert inner["Select"][0]["Column"]["Property"] == "Department Name"
    assert inner["OrderBy"][0]["Direction"] == 2
    assert inner["OrderBy"][0]["Expression"]["Measure"]["Property"] == "Revenue"
    cond = t["filter"]["Where"][0]["Condition"]["In"]
    assert cond["Table"] == {"SourceRef": {"Source": "subquery"}}
    assert cond["Expressions"][0]["Column"]["Property"] == "Department Name"


def test_top_n_by_a_measure_not_in_the_visual(pbix_path, tmp_path):
    v = Visual("table", 0, 0, 100, 100, roles={"Values": [col("Survey Question", "Question En"), meas("% Promoters")]},
               title=None, top_n=(meas("NPS Answers"), 20))
    p = run(tmp_path, pbix_path, [Page("p", "P", [v])])
    vc, _ = only_visual(p.layout, "P")
    t = json.loads(vc["filters"])[0]
    inner = t["filter"]["From"][0]["Expression"]["Subquery"]["Query"]
    assert inner["Top"] == 20
    assert inner["OrderBy"][0]["Expression"]["Measure"]["Property"] == "NPS Answers"
    assert t["expression"]["Column"]["Property"] == "Question En"


def test_top_n_needs_a_column(pbix_path, tmp_path):
    v = Visual("card", 0, 0, 100, 100, roles={"Values": [REVENUE]}, title=None, top_n=(REVENUE, 5))
    with pytest.raises(ValueError, match="top"):
        build(pbix_path, [Page("p", "P", [v])], "X", tmp_path / "o.pbix")


def test_visual_filter_is_hospital(pbix_path, tmp_path):
    v = Visual("hnhVisual", 0, 0, 100, 100, roles={"dataset": [BRANCH]}, title=None,
               filters=[Filter(col("Branch", "Is Hospital"), "eq", ["Yes"])])
    p = run(tmp_path, pbix_path, [Page("p", "P", [v])])
    vc, _ = only_visual(p.layout, "P")
    (f,) = json.loads(vc["filters"])
    assert f["type"] == "Categorical"
    assert f["expression"] == {"Column": {"Expression": {"SourceRef": {"Entity": "Branch"}}, "Property": "Is Hospital"}}
    assert f["filter"] == {"Version": 2, "From": [{"Name": "b", "Entity": "Branch", "Type": 0}],
                           "Where": [{"Condition": {"In": {
                               "Expressions": [{"Column": {"Expression": {"SourceRef": {"Source": "b"}},
                                                           "Property": "Is Hospital"}}],
                               "Values": [[{"Literal": {"Value": "'Yes'"}}]]}}}]}


def test_measure_filter_is_advanced(pbix_path, tmp_path):
    v = Visual("card", 0, 0, 100, 100, roles={"Values": [REVENUE]}, title=None,
               filters=[Filter(REVENUE, "eq", [0])])
    p = run(tmp_path, pbix_path, [Page("p", "P", [v])])
    vc, _ = only_visual(p.layout, "P")
    (f,) = json.loads(vc["filters"])
    assert f["type"] == "Advanced"
    cmp_ = f["filter"]["Where"][0]["Condition"]["Comparison"]
    assert cmp_["ComparisonKind"] == 0
    assert cmp_["Left"] == {"Measure": {"Expression": {"SourceRef": {"Source": "_"}}, "Property": "Revenue"}}
    assert cmp_["Right"] == {"Literal": {"Value": "0L"}}


def test_page_filter_pillar(pbix_path, tmp_path):
    pg = Page("p_fin", "Financial", [], filters=[Filter(col("BSC KPI", "Pillar"), "eq", ["Financial"])])
    p = run(tmp_path, pbix_path, [pg])
    (f,) = json.loads(page_of(p.layout, "Financial")["filters"])
    assert f["expression"] == {"Column": {"Expression": {"SourceRef": {"Entity": "BSC KPI"}}, "Property": "Pillar"}}
    cond = f["filter"]["Where"][0]["Condition"]["In"]
    assert cond["Values"] == [[{"Literal": {"Value": "'Financial'"}}]]
    assert f["filter"]["From"] == [{"Name": "b", "Entity": "BSC KPI", "Type": 0}]


def test_in_filter_and_quotes(pbix_path, tmp_path):
    pg = Page("p", "P", [], filters=[Filter(col("Branch", "Branch Name"), "in", ["A's", "B"])])
    p = run(tmp_path, pbix_path, [pg])
    (f,) = json.loads(page_of(p.layout, "P")["filters"])
    assert f["filter"]["Where"][0]["Condition"]["In"]["Values"] == [
        [{"Literal": {"Value": "'A''s'"}}], [{"Literal": {"Value": "'B'"}}]]


@pytest.mark.parametrize("where", ["pods", "pageBinding"])
def test_drill_through_page(make_pbix, tmp_path, where):
    template = make_pbix(good_parts(build_layout(drill=where)))
    pg = Page("p_rev", "Revenue detail", [Visual("card", 0, 0, 100, 100, roles={"Values": [REVENUE]}, title=None)],
              drill_fields=[BRANCH, YEAR_MONTH], hidden=True)
    p = run(tmp_path, template, [Page("p_home", "Home", []), pg])
    sec = page_of(p.layout, "Revenue detail")
    cfg = json.loads(sec["config"])
    assert cfg["visibility"] == 1
    flt = json.loads(sec["filters"])
    exprs = [f["expression"] for f in flt]
    assert exprs == [{"Column": {"Expression": {"SourceRef": {"Entity": "Branch"}}, "Property": "Branch Name"}},
                     {"Column": {"Expression": {"SourceRef": {"Entity": "Date"}}, "Property": "Year Month"}}]
    assert all(f["howCreated"] == 5 and f["type"] == "Categorical" and "filter" not in f for f in flt)
    if where == "pods":
        pods = p.layout["pods"]
        assert [x["boundSection"] for x in pods] == ["p_rev"]  # the Drill sample's pod is gone
        pod = pods[0]
        assert pod["config"] == "{}" and pod["type"] == 1  # the template's settings (keep all filters) are kept
        params = json.loads(pod["parameters"])
    else:
        assert "pods" not in p.layout
        binding = cfg["pageBinding"]
        assert binding["type"] == "Drillthrough"
        params = binding["parameters"]
    assert [x["boundFilter"] for x in params] == [f["name"] for f in flt]
    assert [x["fieldExpr"] for x in params] == exprs
    assert [x["name"] for x in params] == ["Param_" + f["name"] for f in flt]
    text = json.dumps(p.layout)
    assert DRILL_FILTER not in text and "KPI Code" not in text


def test_drill_keeps_template_keep_all_filters_setting(make_pbix, tmp_path):
    lay = build_layout()
    lay["pods"][0]["config"] = json.dumps({"acceptsFilterContext": "Default"})
    pg = Page("p_d", "D", [], drill_fields=[BRANCH])
    p = run(tmp_path, make_pbix(good_parts(lay)), [pg])
    assert json.loads(p.layout["pods"][0]["config"]) == {"acceptsFilterContext": "Default"}


@pytest.mark.parametrize("where", ["pods", "pageBinding"])
def test_drill_page_without_keep_filters_turns_it_off(make_pbix, tmp_path, where):
    """A page with keep_filters=False (the family pages) gets the cloned binding with keep all filters off
    (acceptsFilterContext None, PBIR's name); a page that keeps filters keeps the template's setting."""
    lay = build_layout(drill=where)
    if where == "pods":
        lay["pods"][0]["config"] = json.dumps({"acceptsFilterContext": "Default"})
    else:
        cfg = json.loads(lay["sections"][1]["config"])
        cfg["pageBinding"]["acceptsFilterContext"] = "Default"
        lay["sections"][1]["config"] = json.dumps(cfg)
    pages = [Page("keep", "Keep", [], drill_fields=[BRANCH]),
             Page("only", "Only", [], drill_fields=[BRANCH, YEAR_MONTH], keep_filters=False)]
    p = run(tmp_path, make_pbix(good_parts(lay)), pages)
    if where == "pods":
        cfgs = {x["boundSection"]: json.loads(x["config"]) for x in p.layout["pods"]}
        assert cfgs == {"keep": {"acceptsFilterContext": "Default"}, "only": {"acceptsFilterContext": "None"}}
    else:
        binding = {s["name"]: json.loads(s["config"])["pageBinding"] for s in p.layout["sections"]}
        assert binding["keep"]["acceptsFilterContext"] == "Default"
        assert binding["only"]["acceptsFilterContext"] == "None"


def test_drill_needs_a_template_binding(make_pbix, tmp_path):
    lay = build_layout()
    del lay["pods"]
    with pytest.raises(ValueError, match="drill-through"):
        build(make_pbix(good_parts(lay)), [Page("p", "P", [], drill_fields=[BRANCH])], "X", tmp_path / "o.pbix")


def test_two_drill_pages_get_their_own_pods(pbix_path, tmp_path):
    pages = [Page("a", "A", [], drill_fields=[BRANCH]), Page("b", "B", [], drill_fields=[YEAR_MONTH])]
    p = run(tmp_path, pbix_path, pages)
    pods = p.layout["pods"]
    assert [x["boundSection"] for x in pods] == ["a", "b"]
    assert len({x["name"] for x in pods}) == 2


def many_pages():
    vis = [Visual(k, 10 * i, 0, 50, 50, roles=r, title=f"T{i}") for i, (k, r) in enumerate([
        ("card", {"Values": [REVENUE]}), ("table", {"Values": [DEPT, REVENUE]}),
        ("slicerDropdown", {"Values": [BRANCH]}), ("textbox", {}), ("buttonNavigate", {})])]
    return [Page("p1", "One", vis), Page("p2", "Two", vis), Page("p3", "Three", list(vis), hidden=True)]


def test_every_visual_gets_a_unique_name_and_builds_repeat(pbix_path, tmp_path):
    p = run(tmp_path, pbix_path, many_pages())
    names = [cfg["name"] for _, _, cfg in containers(p.layout)]
    assert len(names) == 15 and len(set(names)) == 15
    sample_names = {json.loads(vc["config"])["name"] for vc in build_layout()["sections"][0]["visualContainers"]}
    assert not set(names) & sample_names
    again = run(tmp_path / "..", pbix_path, many_pages())
    assert again.layout == p.layout  # deterministic


def test_pages_in_order_samples_removed_report_config_kept(pbix_path, tmp_path):
    p = run(tmp_path, pbix_path, many_pages())
    secs = p.layout["sections"]
    assert [s["displayName"] for s in secs] == ["One", "Two", "Three"]
    assert [s["name"] for s in secs] == ["p1", "p2", "p3"]
    assert [s["ordinal"] for s in secs] == [0, 1, 2]
    assert [s["id"] for s in secs] == [0, 1, 2]
    assert all((s["width"], s["height"]) == (1920, 1080) for s in secs)
    assert json.loads(secs[2]["config"]) == {"visibility": 1} and json.loads(secs[0]["config"]) == {}
    tpl = build_layout()
    cfg = json.loads(p.layout["config"])
    assert cfg["themeCollection"] == json.loads(tpl["config"])["themeCollection"]
    assert cfg["activeSectionIndex"] == 0
    assert p.layout["resourcePackages"] == tpl["resourcePackages"]
    assert p.parts["Report/CustomVisuals/hnh/package.json"] == good_parts()["Report/CustomVisuals/hnh/package.json"]


def test_database_switched_and_upload_rules_pass(pbix_path, tmp_path):
    p = run(tmp_path, pbix_path, many_pages(), database="HNH_Analytics")
    assert "Initial Catalog=HNH_Analytics;" in p.connection["Connections"][0]["ConnectionString"]
    assert check_upload_rules(tmp_path / "out.pbix") == []


def test_every_slicer_joins_sync_group(pbix_path, tmp_path):
    slicers = [Visual("slicerDropdown", 0, 0, 50, 50, roles={"Values": [BRANCH]}, title=None),
               Visual("slicerRelativeDate", 0, 0, 50, 50, roles={"Values": [col("Date", "Date")]}, title=None)]
    p = run(tmp_path, pbix_path, [Page("a", "A", slicers), Page("b", "B", list(slicers))])
    found = [cfg["singleVisual"] for _, _, cfg in containers(p.layout) if cfg["singleVisual"]["visualType"] == "slicer"]
    assert len(found) == 4
    groups = [sv["syncGroup"] for sv in found]
    assert groups[0] == groups[2] == {"groupName": "bsc Branch.Branch Name", "fieldChanges": True,
                                      "filterChanges": True}  # the same slicer on two pages syncs
    assert groups[1] == groups[3] == {"groupName": "bsc Date.Date", "fieldChanges": True, "filterChanges": True}
    assert groups[0] != groups[1]  # different slicers never sync with each other
    for sv in found:
        assert sv["projections"]["Values"][0]["active"] is True


def test_slicer_selection_on_old_field_dropped_relative_date_kept(pbix_path, tmp_path):
    slicers = [Visual("slicerDropdown", 0, 0, 50, 50, roles={"Values": [BRANCH]}, title=None),
               Visual("slicerRelativeDate", 0, 0, 50, 50, roles={"Values": [col("Date", "Date")]}, title=None)]
    p = run(tmp_path, pbix_path, [Page("a", "A", slicers)])
    drop, rel = [cfg["singleVisual"] for _, _, cfg in containers(p.layout)]
    assert "general" not in drop["objects"] and "FIN_01" not in json.dumps(drop)
    assert drop["objects"]["data"][0]["properties"]["mode"]["expr"]["Literal"]["Value"] == "'Dropdown'"
    assert "Between" in json.dumps(rel["objects"]["general"])  # "this calendar year" stays on 'Date'[Date]


def test_titles_set_or_removed(pbix_path, tmp_path):
    vis = [Visual("card", 0, 0, 50, 50, roles={"Values": [REVENUE]}, title="Revenue (SAR)"),
           Visual("lineChart", 0, 0, 50, 50, roles={"Category": [YEAR_MONTH], "Y": [REVENUE]}, title=None)]
    p = run(tmp_path, pbix_path, [Page("a", "A", vis)])
    t1, t2 = [cfg["singleVisual"]["vcObjects"]["title"][0]["properties"] for _, _, cfg in containers(p.layout)]
    assert t1["text"] == {"expr": {"Literal": {"Value": "'Revenue (SAR)'"}}}
    assert t1["show"] == {"expr": {"Literal": {"Value": "true"}}}
    assert "text" not in t2 and t2["show"] == {"expr": {"Literal": {"Value": "false"}}}
    assert "sample:" not in json.dumps(p.layout)


def test_alt_text_sample_key_removed(make_pbix, tmp_path):
    lay = build_layout()
    vc = lay["sections"][0]["visualContainers"][0]
    cfg = json.loads(vc["config"])
    cfg["singleVisual"]["vcObjects"] = {"general": [{"properties": {
        "altText": {"expr": {"Literal": {"Value": "'sample:card'"}}}}}]}
    vc["config"] = json.dumps(cfg)
    p = run(tmp_path, make_pbix(good_parts(lay)), [Page("a", "A", [
        Visual("card", 0, 0, 50, 50, roles={"Values": [REVENUE]}, title=None)])])
    assert "sample:" not in json.dumps(p.layout)


def test_props_merge_into_objects_and_vc_objects(pbix_path, tmp_path):
    mode = {"scorecard": [{"properties": {"mode": {"expr": {"Literal": {"Value": "'board'"}}}}}]}
    nav = {"visualLink": [{"properties": {"navigationSection": {"expr": {"Literal": {"Value": "'p_fin'"}}}}}]}
    vis = [Visual("hnhVisual", 0, 0, 50, 50, roles={"dataset": [meas("BSC Visual Payload")]}, title=None, props=mode),
           Visual("buttonNavigate", 0, 0, 50, 50, title="Financial", props=nav),
           Visual("barChart", 0, 0, 50, 50, roles={"Category": [DEPT], "Y": [REVENUE]}, title=None,
                  props={"dataPoint": [{"properties": {"showAllDataPoints": {"expr": {"Literal": {"Value": "false"}}}}}]})]
    p = run(tmp_path, pbix_path, [Page("a", "A", vis)])
    hv, btn, bar = [cfg["singleVisual"] for _, _, cfg in containers(p.layout)]
    assert hv["objects"]["scorecard"] == mode["scorecard"]
    link = btn["vcObjects"]["visualLink"][0]["properties"]  # the sample keeps its action under vcObjects
    assert link["navigationSection"]["expr"]["Literal"]["Value"] == "'p_fin'"
    assert link["type"]["expr"]["Literal"]["Value"] == "'PageNavigation'"
    assert "visualLink" not in btn.get("objects", {})
    assert bar["objects"]["dataPoint"] == [
        {"properties": {"showAllDataPoints": {"expr": {"Literal": {"Value": "false"}}}}}]


def test_unknown_sample_and_duplicate_page_names_raise(pbix_path, tmp_path):
    with pytest.raises(ValueError, match="nope"):
        build(pbix_path, [Page("a", "A", [Visual("nope", 0, 0, 1, 1, title=None)])], "X", tmp_path / "o.pbix")
    with pytest.raises(ValueError, match="duplicate"):
        build(pbix_path, [Page("a", "A", []), Page("a", "B", [])], "X", tmp_path / "o.pbix")
    with pytest.raises(ValueError, match="duplicate"):
        build(pbix_path, [Page("a", "A", []), Page("b", "A", [])], "X", tmp_path / "o.pbix")


def test_review_focus_1_no_show_items_with_no_data_on_branch(pbix_path, tmp_path):
    """Review Focus 1: "show items with no data" on a Branch field would list hospitals the user cannot see."""
    vis = [Visual("barChart", 0, 0, 50, 50, roles={"Category": [BRANCH], "Y": [REVENUE]}, title=None),
           Visual("barChart", 0, 0, 50, 50, roles={"Category": [DEPT], "Y": [REVENUE]}, title=None),
           Visual("matrix", 0, 0, 50, 50, roles={"Rows": [BRANCH, DEPT]}, title=None),
           Visual("slicerDropdown", 0, 0, 50, 50, roles={"Values": [BRANCH]}, title=None)]
    p = run(tmp_path, pbix_path, [Page("a", "A", vis)])
    for _, _, cfg in containers(p.layout):
        sv = cfg["singleVisual"]
        assert "showAllRoles" not in sv
        for items in sv.get("projections", {}).values():
            assert all("showAll" not in item for item in items)
    assert "showAll\"" not in json.dumps(p.layout)


def test_show_all_check_catches_branch(pbix_path):
    from layout import show_all_on_branch
    sv = {"projections": {"Category": [{"queryRef": "Branch.Branch Name", "showAll": True}]}}
    lay = {"sections": [{"displayName": "A", "visualContainers": [
        {"config": json.dumps({"name": "x", "singleVisual": sv})}]}]}
    assert show_all_on_branch(lay) == ["A: x"]
    sv = {"projections": {"Category": [{"queryRef": "Branch.Branch Name"}]}, "showAllRoles": ["Category"]}
    lay["sections"][0]["visualContainers"][0]["config"] = json.dumps({"name": "x", "singleVisual": sv})
    assert show_all_on_branch(lay) == ["A: x"]


def test_cli_writes_and_prints_upload_check(pbix_path, tmp_path, monkeypatch, capsys):
    import types
    import build as build_mod
    pages = types.ModuleType("pages")
    pages.PAGES = [Page("a", "A", [Visual("card", 0, 0, 50, 50, roles={"Values": [meas("BSC Actual")]}, title="x")])]
    monkeypatch.setitem(__import__("sys").modules, "pages", pages)
    out = tmp_path / "dist" / "r.pbix"
    assert build_mod.main(["--format", "pbix", "--template", str(pbix_path), "--database", "HNH_Analytics_Test",
                          "--out", str(out)]) == 0
    assert "check_upload_rules: passed" in capsys.readouterr().out
    assert out.exists()
    pages.PAGES = [Page("a", "A", [Visual("card", 0, 0, 50, 50, roles={"Values": [meas("Nope")]}, title="x")])]
    assert build_mod.main(["--format", "pbix", "--template", str(pbix_path), "--database", "X", "--out", str(out)]) == 1
    assert "[Nope]" in capsys.readouterr().out


def test_sort_must_be_a_visual_field(pbix_path, tmp_path):
    v = Visual("barChart", 0, 0, 1, 1, roles={"Category": [DEPT], "Y": [REVENUE]}, title=None, sort=meas("Other"))
    with pytest.raises(ValueError, match="sort"):
        build(pbix_path, [Page("p", "P", [v])], "X", tmp_path / "o.pbix")


def test_title_none_hides_a_title_the_sample_did_not_set(make_pbix, tmp_path):
    lay = build_layout()
    vc = lay["sections"][0]["visualContainers"][0]
    cfg = json.loads(vc["config"])
    cfg["singleVisual"]["vcObjects"] = {"general": [{"properties": {
        "altText": {"expr": {"Literal": {"Value": "'sample:card'"}}}}}]}
    vc["config"] = json.dumps(cfg)
    p = run(tmp_path, make_pbix(good_parts(lay)), [Page("a", "A", [
        Visual("card", 0, 0, 50, 50, roles={"Values": [REVENUE]}, title=None)])])
    (_, _, cfg), = containers(p.layout)
    assert cfg["singleVisual"]["vcObjects"]["title"] == [{"properties": {"show": {"expr": {"Literal": {
        "Value": "false"}}}}}]


# ---- fix round 1 -------------------------------------------------------------------------------------------------

def test_page_binding_names_differ_per_drill_page(make_pbix, tmp_path):
    template = make_pbix(good_parts(build_layout(drill="pageBinding")))
    p = run(tmp_path, template, [Page("a", "A", [], drill_fields=[BRANCH]), Page("b", "B", [], drill_fields=[BRANCH])])
    names = [json.loads(s["config"])["pageBinding"]["name"] for s in p.layout["sections"]]
    assert names[0] != names[1] and "Pod" not in names


def _with_card_objects(objects):
    lay = build_layout()
    vc = lay["sections"][0]["visualContainers"][0]  # sample:card
    cfg = json.loads(vc["config"])
    cfg["singleVisual"]["objects"] = objects
    vc["config"] = json.dumps(cfg)
    return lay


RULE = {"expr": {"Measure": {"Expression": {"SourceRef": {"Entity": "_Measures"}}, "Property": "Colour Rule"}}}
SIZE = {"expr": {"Literal": {"Value": "12D"}}}


def test_field_based_formatting_on_a_field_not_bound_is_dropped(make_pbix, tmp_path):
    lay = _with_card_objects({
        "labels": [{"properties": {"color": {"solid": {"color": RULE}}, "fontSize": SIZE}}],
        "rule": [{"properties": {"fill": {"solid": {"color": RULE}}}}],
        "dataPoint": [{"properties": {"fill": SIZE}, "selector": {"data": [{"scopeId": {"Comparison": {
            "ComparisonKind": 0, "Left": {"Column": {"Expression": {"SourceRef": {"Entity": "Payer"}},
                                                     "Property": "Category"}},
            "Right": {"Literal": {"Value": "'Cash'"}}}}}]}}]})
    p = run(tmp_path, make_pbix(good_parts(lay)), [Page("a", "A", [
        Visual("card", 0, 0, 50, 50, roles={"Values": [REVENUE]}, title=None)])])
    (_, _, cfg), = containers(p.layout)
    objects = cfg["singleVisual"]["objects"]
    assert objects == {"labels": [{"properties": {"fontSize": SIZE}}]}  # static formatting stays
    assert "Colour Rule" not in json.dumps(p.layout) and "Payer" not in json.dumps(p.layout)


def test_field_based_formatting_on_a_bound_field_is_kept(make_pbix, tmp_path):
    lay = _with_card_objects({"labels": [{"properties": {"color": {"solid": {"color": RULE}}}}]})
    p = run(tmp_path, make_pbix(good_parts(lay)), [Page("a", "A", [
        Visual("card", 0, 0, 50, 50, roles={"Values": [REVENUE, meas("Colour Rule")]}, title=None)])])
    (_, _, cfg), = containers(p.layout)
    assert cfg["singleVisual"]["objects"]["labels"][0]["properties"]["color"]["solid"]["color"] == RULE


def test_drill_button_destination_stripped_then_set_by_props(pbix_path, tmp_path):
    dest = {"visualLink": [{"properties": {"drillthroughSection": {"expr": {"Measure": {
        "Expression": {"SourceRef": {"Entity": "_Measures"}}, "Property": "BSC Detail Page 2"}}}}}]}
    p = run(tmp_path, pbix_path, [Page("a", "A", [
        Visual("buttonDrill", 0, 0, 50, 50, title="Open detail"),
        Visual("buttonDrill", 0, 0, 50, 50, title="Open detail", props=dest)])])
    (_, _, c1), (_, _, c2) = containers(p.layout)
    link1 = c1["singleVisual"]["vcObjects"]["visualLink"][0]["properties"]
    assert "drillthroughSection" not in link1 and link1["type"]["expr"]["Literal"]["Value"] == "'Drillthrough'"
    link2 = c2["singleVisual"]["vcObjects"]["visualLink"][0]["properties"]
    assert link2["drillthroughSection"] == dest["visualLink"][0]["properties"]["drillthroughSection"]


def test_top_n_by_must_be_a_measure(pbix_path, tmp_path):
    with pytest.raises(ValueError, match="top N"):
        build(pbix_path, [bar_page(top_n=(DEPT, 5))], "X", tmp_path / "o.pbix")


def test_sort_ascending_for_time_axes(pbix_path, tmp_path):
    v = Visual("lineChart", 0, 0, 50, 50, roles={"Category": [YEAR_MONTH], "Y": [REVENUE]}, title=None,
               sort=YEAR_MONTH, sort_dir="asc")
    p = run(tmp_path, pbix_path, [Page("a", "A", [v])])
    (_, _, cfg), = containers(p.layout)
    assert cfg["singleVisual"]["prototypeQuery"]["OrderBy"] == [{"Direction": 1, "Expression": {"Column": {
        "Expression": {"SourceRef": {"Source": "d"}}, "Property": "Year Month"}}}]
    with pytest.raises(ValueError, match="sort_dir"):
        build(pbix_path, [bar_page(sort=REVENUE, sort_dir="down")], "X", tmp_path / "o.pbix")


def test_float_literals_are_plain_decimals():
    from layout import lit
    assert lit(1.5) == {"Literal": {"Value": "1.5D"}}
    assert lit(1e-7) == {"Literal": {"Value": "0.0000001D"}}
    assert lit(1e20) == {"Literal": {"Value": "100000000000000000000D"}}
    assert lit(2.0) == {"Literal": {"Value": "2D"}}


def test_bookmarks_on_template_pages_dropped(make_pbix, tmp_path):
    lay = build_layout()
    cfg = json.loads(lay["config"])
    cfg["bookmarks"] = [
        {"name": "bm1", "displayName": "Samples view", "explorationState": {"activeSection": "ReportSection1"}},
        {"name": "grp", "displayName": "Group", "children": [
            {"name": "bm2", "explorationState": {"activeSection": "ReportSection2"}},
            {"name": "bm3", "explorationState": {"activeSection": "a"}}]},
        {"name": "grp2", "children": [{"name": "bm4", "explorationState": {"activeSection": "ReportSection1"}}]},
        {"name": "bm5", "explorationState": {"activeSection": "a"}}]
    lay["config"] = json.dumps(cfg)
    p = run(tmp_path, make_pbix(good_parts(lay)), [Page("a", "A", [])])
    marks = json.loads(p.layout["config"])["bookmarks"]
    assert [m["name"] for m in marks] == ["grp", "bm5"]
    assert [c["name"] for c in marks[0]["children"]] == ["bm3"]


def test_notblank_filter(pbix_path, tmp_path):
    note = meas("BSC Manual Note")
    v = Visual("card", 0, 0, 50, 50, roles={"Values": [note]}, title=None,
               filters=[Filter(note, "notblank", []), Filter(BRANCH, "notblank", [])])
    p = run(tmp_path, pbix_path, [Page("a", "A", [v])])
    vc, _ = only_visual(p.layout, "A")
    f1, f2 = json.loads(vc["filters"])
    assert f1["type"] == f2["type"] == "Advanced"
    assert f1["filter"]["Where"] == [{"Condition": {"Not": {"Expression": {"Comparison": {
        "ComparisonKind": 0,
        "Left": {"Measure": {"Expression": {"SourceRef": {"Source": "_"}}, "Property": "BSC Manual Note"}},
        "Right": {"Literal": {"Value": "null"}}}}}}}]
    assert f2["filter"]["Where"][0]["Condition"]["Not"]["Expression"]["Comparison"]["Left"] == {
        "Column": {"Expression": {"SourceRef": {"Source": "b"}}, "Property": "Branch Name"}}
    with pytest.raises(ValueError, match="notblank"):
        build(pbix_path, [Page("a", "A", [], filters=[Filter(note, "notblank", ["x"])])], "X", tmp_path / "o.pbix")


def test_matrix_row_levels_all_expanded(pbix_path, tmp_path):
    v = Visual("matrix", 0, 0, 50, 50, roles={"Rows": [col("FS Line", "FS Caption"), col("FS Line", "FS Line")],
                                              "Values": [meas("IS Actual")]}, title=None)
    p = run(tmp_path, pbix_path, [Page("a", "A", [v])])
    (_, _, cfg), = containers(p.layout)
    rows = cfg["singleVisual"]["projections"]["Rows"]
    assert rows == [{"queryRef": "FS Line.FS Caption", "active": True}, {"queryRef": "FS Line.FS Line", "active": True}]
    assert cfg["singleVisual"]["projections"]["Values"] == [{"queryRef": "_Measures.IS Actual"}]


def test_server_switched(pbix_path, tmp_path):
    out = tmp_path / "o.pbix"
    build(pbix_path, [Page("a", "A", [])], "HNH_Analytics", out, server="OTHERSRV\\INST")
    cs = read_pbix(out).connection["Connections"][0]["ConnectionString"]
    assert cs.startswith("Data Source=OTHERSRV\\INST;Initial Catalog=HNH_Analytics;")
    build(pbix_path, [Page("a", "A", [])], "HNH_Analytics", out)
    cs = read_pbix(out).connection["Connections"][0]["ConnectionString"]
    assert cs.startswith("Data Source=HNHANALYTICSSRV\\REPORTSERVERDB;")
