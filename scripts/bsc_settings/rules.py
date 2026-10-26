"""Current values, batch rows and checks for the BSC settings page. Pure logic: no network.

The tables are insert-only change logs: the current row of a key is the one with the greatest
changed_at (keys compared after trimming), and a current row with is_deleted = 1 means removed.
"""
import math
import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Literal, Optional

from tables import AUDIT, COMPLAINTS_KPI, RATE_FORMAT, TABLES, TableSpec

TS_FORMAT = "%Y-%m-%d %H:%M:%S.%f"
_NUMBER = re.compile(r"^-?\d+(\.\d+)?$")
_INT = re.compile(r"^-?\d+$")
_BRANCHES = range(1, 9)
YEARS = (2020, 2100)


@dataclass
class Change:
    table: str
    op: Literal["upsert", "remove"]
    row: dict
    base_changed_at: Optional[str] = None


@dataclass
class Issue:
    level: Literal["error", "warning"]
    table: str
    key: tuple
    message: str


@dataclass
class Context:
    data: dict
    hospitals: dict


class _Bad(ValueError):
    pass


def _number(value):
    """int/float or a clean decimal string -> float; anything else raises _Bad."""
    if isinstance(value, bool):
        raise _Bad("is not a number")
    if isinstance(value, (int, float)):
        if isinstance(value, float) and not math.isfinite(value):
            raise _Bad("is not a number")
        return value
    if isinstance(value, str) and _NUMBER.match(value.strip()):
        return float(value.strip())
    raise _Bad("is not a number")


def _coerce(col, value):
    """Coerce one value to the column's kind; raise _Bad with the reason."""
    if col.kind == "str":
        if value is None:
            return ""
        if isinstance(value, (dict, list)):
            raise _Bad("is not text")
        return str(value)
    if col.kind == "int":
        n = _number(value)
        if n != int(n):
            raise _Bad("is not a whole number")
        return int(n)
    if col.kind == "float":
        n = _number(value)
        return float(n) if isinstance(n, float) else n
    if col.kind == "flag":
        if isinstance(value, str):
            value = value.strip().lower()
            value = {"true": 1, "false": 0}.get(value, value)
        if value in (0, 1, "0", "1") and not isinstance(value, float):
            return int(value)
        raise _Bad("must be 0 or 1")
    raise _Bad("unknown column kind")


def _key_value(col, value):
    if col.kind == "str":
        return "" if value is None else str(value).strip()
    n = _number(value)
    if n != int(n):  # never truncate 1.5 to the key 1
        raise _Bad("is not a whole number")
    return int(n)


def key_of(spec: TableSpec, row: dict) -> tuple:
    cols = {c.name: c for c in spec.columns}
    return tuple(_key_value(cols[k], row.get(k)) for k in spec.key)


def _ordered(spec, rows):
    """(key, changed_at, position, row) sorted so that the last one per key is the current."""
    items = [(key_of(spec, r), r["changed_at"], i, r) for i, r in enumerate(rows)]
    items.sort(key=lambda t: (t[1], t[2]))
    return items


def current(spec: TableSpec, rows: list, include_removed: bool = False) -> dict:
    latest = {}
    for key, _, _, row in _ordered(spec, rows):
        latest[key] = row
    if include_removed:
        return latest
    return {k: r for k, r in latest.items() if not int(r.get("is_deleted") or 0)}


def history(spec: TableSpec, rows: list, key: tuple) -> list:
    items = [t for t in _ordered(spec, rows) if t[0] == tuple(key)]
    return [t[3] for t in reversed(items)]


def batch_changed_at(server_now: str, latest: list) -> str:
    now = datetime.strptime(server_now, TS_FORMAT)
    if latest:
        floor = max(datetime.strptime(s, TS_FORMAT) for s in latest) + timedelta(milliseconds=1)
        now = max(now, floor)
    return now.strftime(TS_FORMAT)[:-3]


def _default(col):
    return "" if col.kind == "str" else 0


def prepare(changes: list, note: str, user: str, ctx: Context, server_now: str):
    issues: list = []
    out: dict = {}

    def issue(level, table, key, message):
        issues.append(Issue(level, table, tuple(key), message))

    if not (note or "").strip():
        issue("error", "", (), "note is required")

    # pass 1: coerce each change, collect rows (without audit columns) and per-change errors
    items = []  # (change, spec, key, values-or-None, current-with-removed row or None)
    seen = set()
    for ch in changes:
        spec = TABLES.get(ch.table)
        if spec is None:
            issue("error", ch.table, (), f"unknown table {ch.table}")
            continue
        if ch.op not in ("upsert", "remove"):
            issue("error", ch.table, (), f"unknown operation {ch.op}")
            continue
        raw_key = tuple(ch.row.get(k) for k in spec.key)
        cols = {c.name: c for c in spec.columns}
        bad = False
        key_vals = []
        for k in spec.key:
            v = ch.row.get(k)
            try:
                kv = _key_value(cols[k], v)
            except _Bad as e:
                issue("error", ch.table, raw_key, f"{k} {e}")
                bad = True
                continue
            if cols[k].kind == "str" and kv == "":
                issue("error", ch.table, raw_key, f"{k} is required")
                bad = True
            key_vals.append(kv)
        if bad:
            continue
        key = tuple(key_vals)
        if (ch.table, key) in seen:
            issue("error", ch.table, key, "changed twice in this batch")
            continue
        seen.add((ch.table, key))
        existing = current(spec, ctx.data.get(ch.table, []), include_removed=True).get(key)
        items.append([ch, spec, key, existing])

    prepared = []  # (ch, spec, key, values, existing)
    for ch, spec, key, existing in items:
        if ch.op == "remove":
            live = existing if existing and not int(existing.get("is_deleted") or 0) else None
            if live is None:
                issue("error", ch.table, key, "nothing to remove")
                continue
            values = {c.name: live[c.name] for c in spec.columns}
            values.update(dict(zip(spec.key, key)))
            prepared.append((ch, spec, key, values, existing))
            continue
        values = dict(zip(spec.key, key))
        ok = True
        for col in spec.columns:
            if col.name in spec.key:
                continue
            if col.name in ch.row:
                try:
                    values[col.name] = _coerce(col, ch.row[col.name])
                except _Bad as e:
                    issue("error", ch.table, key, f"{col.name} {e}")
                    ok = False
            elif existing is not None:
                values[col.name] = existing[col.name]
            else:
                values[col.name] = _default(col)
        if not ok:
            continue
        for col in spec.columns:
            v = values[col.name]
            if col.allowed is not None and v not in col.allowed:
                issue("error", ch.table, key, f"{col.name} '{v}' is not one of: {', '.join(col.allowed)}")
                ok = False
            if col.pattern is not None and not re.fullmatch(col.pattern, str(v)):
                issue("error", ch.table, key, f"{col.name} '{v}' is not a valid value")
                ok = False
            if col.ref in ("branch", "branch_or_all"):
                low = 0 if col.ref == "branch_or_all" else 1
                if not low <= v <= 8:
                    issue("error", ch.table, key, f"{col.name} must be {low} to 8")
                    ok = False
            if col.name == "month":
                low = 1 if ch.table == "map_bsc_manual_value" else 0
                if not low <= v <= 12:
                    issue("error", ch.table, key, f"month must be {low} to 12")
                    ok = False
            if col.name == "year" and not YEARS[0] <= v <= YEARS[1]:
                issue("error", ch.table, key, f"year must be {YEARS[0]} to {YEARS[1]}")
                ok = False
        if ok:
            prepared.append((ch, spec, key, values, existing))

    # the batch changed_at, then the rows
    latest = [h["changed_at"] for _, spec, key, _, _ in prepared
              for h in history(spec, ctx.data.get(spec.name, []), key)[:1]]
    stamp = batch_changed_at(server_now, latest)
    for ch, spec, key, values, existing in prepared:
        row = dict(values)
        row.update(changed_at=stamp, changed_by=user, change_note=note,
                   is_deleted=1 if ch.op == "remove" else 0)
        out.setdefault(spec.name, []).append(row)

    # state with the batch applied, for parent checks and totals
    def applied(name):
        return list(ctx.data.get(name, [])) + out.get(name, [])

    kpis = current(TABLES["map_bsc_kpi"], applied("map_bsc_kpi"))
    objectives = current(TABLES["map_bsc_objective"], applied("map_bsc_objective"))
    kpi_codes = {k[0] for k in kpis}
    objective_codes = {k[0] for k in objectives}

    for ch, spec, key, values, existing in prepared:
        if ch.op == "remove":
            continue
        name = spec.name
        for col in spec.columns:
            v = values[col.name]
            if col.ref == "kpi" and name != "map_bsc_kpi" and v not in kpi_codes:
                issue("error", name, key, f"{col.name} '{v}' is not a current KPI")
            elif col.ref == "kpi_or_default" and v != "*" and v not in kpi_codes:
                issue("error", name, key, f"{col.name} '{v}' is not a current KPI")
            elif col.ref == "objective" and v not in objective_codes:
                issue("error", name, key, f"{col.name} '{v}' is not a current objective")

        if existing is not None and int(existing.get("is_deleted") or 0):
            issue("warning", name, key, f"restores a key removed on {existing['changed_at'][:10]}")
        if name == "map_bsc_kpi":
            before = current(TABLES["map_bsc_kpi"], ctx.data.get("map_bsc_kpi", []))
            if key not in before:
                issue("warning", name, key, "new KPI: needs its SSAS measure (add it parked until deployed)")

        kpi_code = values.get("kpi_code")
        fmt = (kpis.get((kpi_code,)) or {}).get("value_format")
        if name == "map_bsc_target" and fmt == RATE_FORMAT and values["target_value"] > 1:
            issue("warning", name, key, "target_value above 1 for a percent KPI; a whole-number percent?")
        if name == "map_bsc_manual_value":
            num, den = values["numerator"], values["denominator"]
            if den == 0 and kpi_code != COMPLAINTS_KPI:
                issue("warning", name, key, "denominator 0")
            if fmt == RATE_FORMAT and den != 0 and num / den > 1:
                issue("warning", name, key, "value above 1 for a percent KPI; a whole-number percent?")

    # stale base: the key changed since the page loaded
    for ch, spec, key, existing in items:
        if ch.base_changed_at and existing is not None and existing["changed_at"] > ch.base_changed_at:
            issue("warning", spec.name, key,
                  f"changed by {existing['changed_by']} at {existing['changed_at']} since this page loaded")

    # weight totals for the profiles in the batch
    profiles = {key[0] for ch, spec, key, _, _ in prepared if spec.name == "map_bsc_weight"}
    if profiles:
        weights = current(TABLES["map_bsc_weight"], applied("map_bsc_weight"))
        for p in sorted(profiles):
            mine = [r for k, r in weights.items() if k[0] == p]
            if not mine and p != "corporate":  # docs/bsc_config.md: a hospital without rows uses corporate
                issue("warning", "map_bsc_weight", (p,),
                      f"profile {p}: no weights left, so the hospital uses the corporate profile")
                continue
            total = round(sum(r["weight"] for r in mine), 4)
            if total != 1.0:
                issue("warning", "map_bsc_weight", (p,), f"profile {p}: total {total:.4f}, should be 1.0000")

    return out, issues
