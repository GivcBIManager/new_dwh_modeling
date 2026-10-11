"""Rewrite the _Measures block of every perspective from tables/_Measures.tmdl, without ClickHouse (KPI catalogue plan).
generate.py writes the same blocks when it regenerates the whole model.

Usage: python ssas/tools/sync_perspectives.py
"""
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

import hnh_tmdl as t  # noqa: E402
import model_config as cfg  # noqa: E402

MODEL_DIR = TOOLS.parents[1] / "ssas" / "HNH_Analytics"


def main():
    folders = t.measure_folders((MODEL_DIR / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8"))
    for name in cfg.PERSPECTIVES:
        path = MODEL_DIR / "perspectives" / f"{name}.tmdl"
        text = path.read_text(encoding="utf-8")
        new = t.replace_perspective_measures(text, t.perspective_measures(name, folders, cfg.PERSPECTIVE_MEASURE_DOMAINS))
        if new != text:
            path.write_text(new, encoding="utf-8", newline="\n")
            print(f"updated {path.name}")


if __name__ == "__main__":
    main()
