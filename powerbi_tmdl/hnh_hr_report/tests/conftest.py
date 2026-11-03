"""Puts the BSC generator's shared modules (frame, model, pbir, fields) on the path, after this report's folder.

Both report folders have a `pages.py` and a `build.py`, and the BSC tests import theirs by those names, also inside
test functions. So that `python -m pytest powerbi_tmdl` can run both suites in one session, the HR tests never
import this folder's `pages` by that name (test_hr_pages.py loads it as `hr_pages`), and this folder is a package
(`tests/__init__.py`), so this conftest does not replace the BSC's `conftest` module.
"""
import sys
from pathlib import Path

HR = Path(__file__).resolve().parents[1]
BSC = HR.parent / "hnh_bsc_report"

for p in (str(HR), str(BSC)):
    if p not in sys.path:
        sys.path.append(p)
