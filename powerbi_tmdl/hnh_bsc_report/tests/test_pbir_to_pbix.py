"""The legacy-package writer on the two PBIP reports of this repository (read only; writes to tmp_path)."""
import json
import zipfile
from pathlib import Path

import pytest

import pbir_to_pbix
from pbix import check_upload_rules, read_pbix

ROOT = Path(__file__).resolve().parents[1]
PRESS_GANEY = ROOT.parent / "pressGaneyDashboard" / "pressGaneyDashboard" / "PressGaneyDashboard.pbip"
SCORECARD = ROOT / "HNH Balanced Scorecard.pbip"


@pytest.mark.parametrize("pbip", [p for p in (PRESS_GANEY, SCORECARD) if p.exists()], ids=lambda p: p.stem)
def test_package_passes_the_upload_rules_and_keeps_every_page_and_visual(pbip, tmp_path):
    out = tmp_path / "report.pbix"
    layout = pbir_to_pbix.write(pbip, out)
    assert check_upload_rules(out) == []
    report_dir = pbir_to_pbix.report_dir_of(pbip)
    order = json.loads((report_dir / "definition/pages/pages.json").read_text(encoding="utf-8"))["pageOrder"]
    assert [s["name"] for s in layout["sections"]] == order
    for s in layout["sections"]:
        n = len(list((report_dir / "definition/pages" / s["name"]).glob("visuals/*/visual.json")))
        assert len(s["visualContainers"]) == n
    with zipfile.ZipFile(out) as z:
        names = z.namelist()
    assert "Report/Layout" in names and not any(n.startswith("Report/definition") for n in names)
    assert names[0] == "Version"
    pbix = read_pbix(out)
    assert pbix.connection["Connections"][0]["ConnectionType"] == "analysisServicesDatabaseLive"
    assert 'Cube="' in pbix.connection["Connections"][0]["ConnectionString"]
    assert "Provider" not in pbix.connection["Connections"][0]["ConnectionString"]


def test_scorecard_report_filter_becomes_the_layout_filter_locked(tmp_path):
    layout = pbir_to_pbix.write(SCORECARD, tmp_path / "r.pbix")
    flts = json.loads(layout["filters"])
    assert len(flts) == 1
    f = flts[0]
    assert f["expression"] == {"Column": {"Expression": {"SourceRef": {"Entity": "Date"}}, "Property": "Year Offset"}}
    assert f["isLockedInViewMode"] is True and f["howCreated"] == 1
    assert [v[0]["Literal"]["Value"] for v in f["filter"]["Where"][0]["Condition"]["In"]["Values"]] == ["0L", "1L"]


@pytest.mark.skipif(not PRESS_GANEY.exists(), reason="Press Ganey report not checked out")
def test_press_ganey_shapes(tmp_path):
    layout = pbir_to_pbix.write(PRESS_GANEY, tmp_path / "r.pbix")
    config = json.loads(layout["config"])
    assert config["themeCollection"]["baseTheme"]["name"] == "CY26SU05"
    assert config["themeCollection"]["customTheme"]["name"].startswith("HayatHealthcare")
    kinds = {p["resourcePackage"]["type"] for p in layout["resourcePackages"]}
    assert kinds == {0, 1, 2}  # custom visual, registered resources, shared resources
    home = layout["sections"][0]
    containers = [json.loads(c["config"]) for c in home["visualContainers"]]
    gauge = next(c["singleVisual"] for c in containers if c["singleVisual"]["visualType"].startswith("hayatNpsScorecard"))
    assert gauge["prototypeQuery"]["From"] == [{"Name": "_", "Entity": "_Measures", "Type": 0}]
    assert gauge["projections"]["nps"] == [{"queryRef": "_Measures.NPS (5-point)"}]
    slicer = next(c["singleVisual"] for c in containers if c["singleVisual"]["visualType"] == "slicer"
                  and c["singleVisual"]["projections"]["Values"][0]["queryRef"] == "Date.Date")
    assert slicer["prototypeQuery"]["From"][0]["Name"] == "d"
    date_slicer = next(c for c in home["visualContainers"]
                       if '"queryRef":"Date.Date"' in c["config"])
    assert json.loads(date_slicer["filters"])[0]["howCreated"] == 1
    hidden = [s for s in layout["sections"] if json.loads(s["config"]).get("visibility") == 1]
    assert len(hidden) == 2 and all(json.loads(s["config"])["type"] == 2 for s in hidden)  # Drillthrough page
    assert {p["boundSection"] for p in layout["pods"]} == {s["name"] for s in hidden}
    assert all(json.loads(s["filters"])[0]["howCreated"] == 5 for s in hidden)
    participation = layout["sections"][1]
    assert participation["displayOption"] == 2  # FitToWidth
    assert json.loads(participation["config"])["relationships"][0]["type"] == 3  # NoFilter


def test_scorecard_drillthrough_and_interactions_in_the_legacy_shape(tmp_path):
    # As Desktop for Report Server reads the legacy layout (desktop.min.js, LayoutSerializer): the drill-through
    # binding is a root `pods` entry bound to its section, with parameters and config as JSON strings, pod type
    # Drillthrough = 1, section config type Drillthrough = 2; visual interactions are the section's `relationships`.
    # A PBIR `pageBinding` or `visualInteractions` in the section config is ignored ("not a valid drill-through
    # destination", the hospital chart not filtered), as on the server on 2026-11-04.
    layout = pbir_to_pbix.write(SCORECARD, tmp_path / "r.pbix")
    sections = {s["name"]: s for s in layout["sections"]}
    for s in layout["sections"]:
        cfg = json.loads(s["config"])
        assert "pageBinding" not in cfg and "visualInteractions" not in cfg
    pod = next(p for p in layout["pods"] if p["boundSection"] == "kpi_detail")
    assert pod["type"] == 1
    assert json.loads(pod["config"]) == {"acceptsFilterContext": 0}
    [param] = json.loads(pod["parameters"])
    assert param["boundFilter"] == "7431cc738d9ea1004850"
    assert param["fieldExpr"] == {"Column": {"Expression": {"SourceRef": {"Entity": "BSC KPI"}}, "Property": "KPI Code"}}
    assert json.loads(sections["kpi_detail"]["config"])["type"] == 2
    relationships = json.loads(sections["financial"]["config"])["relationships"]
    assert {"source": "b9fa694d2041eaeb8a7d", "target": "f5d5edb844ccd8462460", "type": 1} in relationships  # DataFilter
    assert {"source": "f5d5edb844ccd8462460", "target": "b9fa694d2041eaeb8a7d", "type": 3} in relationships  # NoFilter
    assert "type" not in json.loads(sections["financial"]["config"])


def test_report_level_measures_are_refused(tmp_path):
    pbip = tmp_path / "r.pbip"
    (tmp_path / "r.Report" / "definition").mkdir(parents=True)
    pbip.write_text(json.dumps({"artifacts": [{"report": {"path": "r.Report"}}]}), encoding="utf-8")
    (tmp_path / "r.Report" / "definition" / "reportExtensions.json").write_text("{}", encoding="utf-8")
    with pytest.raises(pbir_to_pbix.Unsupported):
        pbir_to_pbix.convert(pbip)
