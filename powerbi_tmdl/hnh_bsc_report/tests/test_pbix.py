BOM = bytes([0xEF, 0xBB, 0xBF])
import json
import zipfile

import pytest

from conftest import SAMPLE_KEYS, build_layout, good_parts
from pbix import check_upload_rules, read_pbix, samples, set_database, write_pbix


def parts_of(path):
    with zipfile.ZipFile(path) as z:
        return {n: z.read(n) for n in z.namelist()}


def test_round_trip_keeps_parts_and_layout(pbix_path, tmp_path):
    out = tmp_path / "out.pbix"
    write_pbix(read_pbix(pbix_path), out)
    a, b = parts_of(pbix_path), parts_of(out)
    assert list(a) == list(b)
    for n in a:
        if n != "Report/Layout":
            assert a[n] == b[n], n
    assert read_pbix(out).layout == read_pbix(pbix_path).layout == build_layout()


def test_layout_encoding_no_bom(pbix_path, tmp_path):
    out = tmp_path / "out.pbix"
    write_pbix(read_pbix(pbix_path), out)
    raw = parts_of(out)["Report/Layout"]
    assert raw[:2] == b"\x7b\x00"
    assert raw[:2] != b"\xff\xfe"


def test_read_tolerates_bom_and_write_drops_it(make_pbix, tmp_path):
    p = read_pbix(make_pbix(good_parts(bom=True)))
    assert p.layout == build_layout()
    out = tmp_path / "o.pbix"
    write_pbix(p, out)
    assert check_upload_rules(out) == []


def test_edited_layout_is_written(pbix_path, tmp_path):
    p = read_pbix(pbix_path)
    p.layout["sections"][0]["displayName"] = "Changed"
    out = tmp_path / "o.pbix"
    write_pbix(p, out)
    assert read_pbix(out).layout["sections"][0]["displayName"] == "Changed"


def test_check_good(pbix_path):
    assert check_upload_rules(pbix_path) == []


def test_check_definition_entry(make_pbix):
    parts = good_parts()
    parts["Report/definition/x"] = b"{}"
    msgs = check_upload_rules(make_pbix(parts))
    assert len(msgs) == 1 and "Report/definition" in msgs[0]


def test_check_bom(make_pbix):
    msgs = check_upload_rules(make_pbix(good_parts(bom=True)))
    assert len(msgs) == 1 and "byte-order mark" in msgs[0]


def test_check_no_layout(make_pbix):
    parts = good_parts()
    del parts["Report/Layout"]
    msgs = check_upload_rules(make_pbix(parts))
    assert len(msgs) == 1 and "Report/Layout" in msgs[0]


def test_check_utf8_layout(make_pbix):
    parts = good_parts()
    parts["Report/Layout"] = b'{"a":1}'
    msgs = check_upload_rules(make_pbix(parts))
    assert any("UTF-16" in m for m in msgs)


def test_set_database_changes_only_catalog(pbix_path, tmp_path):
    p = read_pbix(pbix_path)
    before = json.loads(json.dumps(p.connection))
    set_database(p, "HNH_Analytics")
    c = p.connection["Connections"][0]
    assert "Initial Catalog=HNH_Analytics;" in c["ConnectionString"]
    assert "Data Source=HNHANALYTICSSRV\\REPORTSERVERDB;" in c["ConnectionString"]
    assert c["ConnectionString"].endswith("Cube=Balanced Scorecard")
    assert c["PbiModelDatabaseName"] == "HNH_Analytics"
    after = json.loads(json.dumps(p.connection))
    after["Connections"][0]["ConnectionString"] = before["Connections"][0]["ConnectionString"]
    after["Connections"][0]["PbiModelDatabaseName"] = before["Connections"][0]["PbiModelDatabaseName"]
    assert after == before
    out = tmp_path / "o.pbix"
    write_pbix(p, out)
    assert read_pbix(out).connection == p.connection
    a, b = parts_of(pbix_path), parts_of(out)
    assert all(a[n] == b[n] for n in a if n not in ("Connections", "Report/Layout"))


def test_set_database_without_connection_raises(make_pbix):
    parts = good_parts()
    del parts["Connections"]
    with pytest.raises(ValueError):
        set_database(read_pbix(make_pbix(parts)), "X")


def test_unchanged_connections_bytes_kept(pbix_path, tmp_path):
    out = tmp_path / "o.pbix"
    write_pbix(read_pbix(pbix_path), out)
    assert parts_of(out)["Connections"] == parts_of(pbix_path)["Connections"]


def test_samples_all_keys(pbix_path):
    s = samples(read_pbix(pbix_path))
    assert sorted(s) == sorted(SAMPLE_KEYS)
    assert "config" in s["card"]


def test_samples_missing_keys_listed(make_pbix):
    keys = [k for k in SAMPLE_KEYS if k not in ("table", "matrix")]
    p = read_pbix(make_pbix(good_parts(build_layout(keys))))
    with pytest.raises(ValueError) as e:
        samples(p)
    assert "table" in str(e.value) and "matrix" in str(e.value)
    assert "card" not in str(e.value)


def test_samples_no_samples_page(make_pbix):
    lay = build_layout()
    lay["sections"][0]["displayName"] = "Other"
    with pytest.raises(ValueError, match="Samples"):
        samples(read_pbix(make_pbix(good_parts(lay))))


def infos_of(path):
    with zipfile.ZipFile(path) as z:
        return {i.filename: (i.compress_type, i.date_time, i.external_attr) for i in z.infolist()}


def test_round_trip_keeps_zip_entry_metadata(pbix_path, tmp_path):
    p = read_pbix(pbix_path)
    set_database(p, "Other")  # re-encodes Connections too
    out = tmp_path / "o.pbix"
    write_pbix(p, out)
    a, b = infos_of(pbix_path), infos_of(out)
    assert a == b
    assert a["DataModel"][0] == zipfile.ZIP_STORED
    assert a["Report/Layout"][0] == zipfile.ZIP_DEFLATED


def test_round_trip_arabic_and_non_bmp(pbix_path, tmp_path):
    out = tmp_path / "o.pbix"
    write_pbix(read_pbix(pbix_path), out)
    vc = samples(read_pbix(out))["textbox"]
    run = json.loads(vc["config"])["singleVisual"]["objects"]["general"][0]["properties"]["paragraphs"][0]["textRuns"][0]
    assert run["value"] == "".join(chr(c) for c in (0x645, 0x631, 0x62D, 0x628, 0x627, 0x20, 0x1F600))


def test_set_database_leaves_unrelated_model_name(make_pbix):
    parts = good_parts()
    conn = json.loads(parts["Connections"])
    conn["Connections"][0]["PbiModelDatabaseName"] = "some-guid"
    parts["Connections"] = json.dumps(conn).encode()
    p = read_pbix(make_pbix(parts))
    set_database(p, "HNH_Analytics")
    c = p.connection["Connections"][0]
    assert c["PbiModelDatabaseName"] == "some-guid"
    assert "Initial Catalog=HNH_Analytics;" in c["ConnectionString"]


def test_set_database_raises_without_catalog(make_pbix):
    parts = good_parts()
    conn = json.loads(parts["Connections"])
    conn["Connections"][0]["ConnectionString"] = "Data Source=srv;Cube=x"
    parts["Connections"] = json.dumps(conn).encode()
    p = read_pbix(make_pbix(parts))
    with pytest.raises(ValueError, match="catalog"):
        set_database(p, "X")
    assert p.connection["Connections"][0]["PbiModelDatabaseName"] == "HNH_Analytics_Test"


def _set_key(layout, idx, mode, key):
    vc = layout["sections"][0]["visualContainers"][idx]
    cfg = json.loads(vc["config"])
    vco = cfg["singleVisual"]["vcObjects"]
    lit = {"expr": {"Literal": {"Value": f"'{key}'"}}}
    vco.pop("title")
    if mode == "alt":
        vco["general"] = [{"properties": {"altText": lit}}]
    else:
        vco["title"] = [{"properties": {"text": lit}}]
    vc["config"] = json.dumps(cfg)


def test_samples_accepts_alt_text(make_pbix):
    lay = build_layout()
    _set_key(lay, 0, "alt", "sample:card")
    assert "card" in samples(read_pbix(make_pbix(good_parts(lay))))


def test_samples_strips_titles(make_pbix):
    lay = build_layout()
    _set_key(lay, 0, "title", "  sample:card ")
    assert "card" in samples(read_pbix(make_pbix(good_parts(lay))))


def test_samples_duplicate_key_raises(make_pbix):
    lay = build_layout()
    _set_key(lay, 1, "alt", "sample:card")
    with pytest.raises(ValueError, match="duplicate.*card"):
        samples(read_pbix(make_pbix(good_parts(lay))))


def test_connections_utf8_bom_kept(make_pbix, tmp_path):
    parts = good_parts()
    parts["Connections"] = BOM + parts["Connections"]
    p = read_pbix(make_pbix(parts))
    set_database(p, "Z")
    out = tmp_path / "o.pbix"
    write_pbix(p, out)
    raw = parts_of(out)["Connections"]
    assert raw[:3] == BOM and raw[3:4] == b"{"


def test_check_not_a_zip(tmp_path):
    f = tmp_path / "bad.pbix"
    f.write_bytes(b"not a zip")
    msgs = check_upload_rules(f)
    assert len(msgs) == 1 and "zip" in msgs[0]


def test_check_layout_not_json(make_pbix):
    parts = good_parts()
    parts["Report/Layout"] = "{oops".encode("utf-16-le")
    msgs = check_upload_rules(make_pbix(parts))
    assert any("JSON" in m for m in msgs)
