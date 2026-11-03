"""The BSC report builds byte-identical: SHA-256 of every file `write_pbip` writes, against the fixture recorded
before the generator was parameterised (frame, report identity and perspective as parameters for the HR report).
Regenerate the fixture only for an intended change to the BSC output:

    python powerbi_tmdl/hnh_bsc_report/tests/test_bsc_unchanged.py --record
"""
import hashlib
import json
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

FIXTURE = HERE / "bsc_build_hashes.json"


def build_hashes() -> dict[str, str]:
    import pages
    from pbir import write_pbip
    with tempfile.TemporaryDirectory() as tmp:
        write_pbip(pages.PAGES, tmp, "HNH_Analytics_Test", report_filters=getattr(pages, "REPORT_FILTERS", []))
        root = Path(tmp)
        return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(root.rglob("*")) if p.is_file()}


def test_bsc_build_is_deterministic():
    assert build_hashes() == build_hashes()


def test_bsc_build_unchanged():
    expected = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert build_hashes() == expected


# ---- the parameters ---------------------------------------------------------------------------------------------

def _other_report(**kw):
    import dataclasses
    from pbir import BSC_REPORT
    return dataclasses.replace(BSC_REPORT, name="Other Report", perspective="Other", **kw)


def _tiny_pages(height=1080):
    from model import Page
    return [Page("p1", "One", [], height=height)]


def test_report_without_custom_visual_has_no_visual_package(tmp_path):
    from pbir import project_files
    files = project_files(_tiny_pages(), "DB", pbiviz=tmp_path / "missing.pbiviz", report=_other_report(custom_visual=False))
    assert not [f for f in files if "CustomVisuals" in f]
    report = json.loads(files["Other Report.Report/definition/report.json"])
    assert [p["name"] for p in report["resourcePackages"]] == ["SharedResources", "RegisteredResources"]
    assert "Other Report.pbip" in files and "Other Report.Report/definition.pbir" in files
    model_ref = json.loads(files["Other Report.SemanticModel/modelReference.json"])
    assert model_ref["connectionString"].endswith('Cube="Other"')


def test_report_with_custom_visual_needs_the_package(tmp_path):
    import pytest
    from pbir import project_files
    with pytest.raises(FileNotFoundError):
        project_files(_tiny_pages(), "DB", pbiviz=tmp_path / "missing.pbiviz", report=_other_report(custom_visual=True))


def test_page_height_defaults_to_1080_and_can_be_set():
    from pbir import page_json
    assert page_json(_tiny_pages()[0])["height"] == 1080
    assert page_json(_tiny_pages(1400)[0])["height"] == 1400


def test_frame_spec_drives_title_tabs_and_help():
    import frame
    spec = frame.FrameSpec("HR", "Sub", [("a", "Alpha"), ("b", "Beta")], [("h", "Help", (1, 2, 3, 4))])
    assert frame.frame("a", [], spec=spec) != frame.frame(None, [])
    text = json.dumps([v.props for v in frame.frame("b", [], spec=spec)])
    assert "Sub" in text and "Beta" in text and "Help" in text and "Balanced Scorecard" not in text


if __name__ == "__main__":
    if "--record" in sys.argv:
        FIXTURE.write_text(json.dumps(build_hashes(), indent=1, sort_keys=True) + "\n", encoding="utf-8")
        print(f"wrote {FIXTURE}")
