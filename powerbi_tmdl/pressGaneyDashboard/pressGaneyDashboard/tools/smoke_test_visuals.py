"""Translates every data-bound visual in the generated report into a DAX query, so
tools/smoke_test_visuals.ps1 can run them against the live model.

    python tools/smoke_test_visuals.py [--define]   # writes tools/.visual_queries.json

By default the queries run the model's deployed measures, guards included, so a guard that fires inside a visual shows
up as text where a number should be (smoke_test_visuals.ps1 flags it). With --define each query carries a DEFINE block
with the query-scoped copy of every Patient Experience measure from the repository's TMDL (tools/model_measures.py),
without the guard wrappers: for trying the visuals before the model is deployed only.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGES = ROOT / "PressGaneyDashboard.Report/definition/pages"
sys.path.insert(0, str(ROOT / "tools"))
from model_measures import define_block  # noqa: E402


def ref(field: dict) -> tuple[str, str]:
    kind = "Column" if "Column" in field else "Measure"
    table = field[kind]["Expression"]["SourceRef"]["Entity"]
    return kind, f"'{table}'[{field[kind]['Property']}]"


def main() -> None:
    define = define_block() if "--define" in sys.argv else ""
    order = json.loads((PAGES / "pages.json").read_text(encoding="utf-8"))["pageOrder"]
    queries = []
    for page_name in order:
        page = json.loads((PAGES / page_name / "page.json").read_text(encoding="utf-8"))
        page_filters = []
        for f in page.get("filterConfig", {}).get("filters", []):
            if f.get("howCreated") == "Drillthrough":  # applied only when a user drills through
                continue
            _, column = ref(f["field"])
            cond = f["filter"]["Where"][0]["Condition"]
            negate = "Not" in cond
            literals = [v[0]["Literal"]["Value"] for v in (cond["Not"]["Expression"] if negate else cond)["In"]["Values"]]
            # 'text' literals are quoted; integers carry an L suffix (e.g. 0L)
            in_list = "{" + ", ".join(json.dumps(v.strip("'")) if v.startswith("'") else v.rstrip("L")
                                      for v in literals) + "}"
            page_filters.append(f"FILTER(ALL({column}), NOT {column} IN {in_list})" if negate
                                else f"TREATAS({in_list}, {column})")
        for vfile in sorted((PAGES / page_name).glob("visuals/*/visual.json")):
            v = json.loads(vfile.read_text(encoding="utf-8"))["visual"]
            state = v.get("query", {}).get("queryState")
            if not state or v["visualType"] == "slicer":
                continue
            columns, measures = [], []
            for role, s in state.items():
                for p in s["projections"]:
                    kind, r = ref(p["field"])
                    if kind == "Column":
                        if r not in columns:
                            columns.append(r)
                    else:
                        measures.append(f'"{p["nativeQueryRef"]}", {r}')
            args = columns + page_filters + measures
            queries.append({
                "page": page["displayName"],
                "visual": f"{v['visualType']}: " + (v.get("visualContainerObjects", {}).get("title", [{}])[0]
                                                     .get("properties", {}).get("text", {}).get("expr", {})
                                                     .get("Literal", {}).get("Value", "").strip("'") or "(untitled)"),
                "query": f"{define}\nEVALUATE TOPN(3, SUMMARIZECOLUMNS({', '.join(args)}))",
                "countQuery": f"{define}\nEVALUATE ROW(\"rows\", COUNTROWS(SUMMARIZECOLUMNS({', '.join(args)})))",
            })
    out = ROOT / "tools/.visual_queries.json"
    out.write_text(json.dumps(queries, indent=1), encoding="utf-8")
    print(f"{len(queries)} visual queries -> {out}")


if __name__ == "__main__":
    main()
