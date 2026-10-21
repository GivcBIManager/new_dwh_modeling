import type { KpiRow, ViewModel } from "../model/types";
import { formatValue } from "../model/format";
import { el } from "./dom";
import { stateChip } from "./chips";
import { allFirstRows } from "./rows";

const NONE = "Unassigned";

/** One block per KPI owner. Information only: owners are shown, nothing filters by them. */
export function owner(vm: ViewModel): HTMLElement {
    const by = new Map<string, KpiRow[]>();
    for (const r of allFirstRows(vm)) {
        const key = r.owner || NONE;
        const g = by.get(key);
        if (g) g.push(r); else by.set(key, [r]);
    }
    const names = [...by.keys()].sort((a, b) => (a === NONE ? 1 : b === NONE ? -1 : a.localeCompare(b)));
    const wrap = el("div", { class: "owners" });
    for (const n of names) {
        const body = el("tbody");
        for (const r of by.get(n) as KpiRow[]) {
            const has = r.actual !== null && r.state !== "nodata" && r.state !== "parked";
            body.appendChild(el("tr", { "data-key": r.rowIndex, "data-series": r.seriesIndex, tabindex: 0 }, [
                el("td", {}, [r.name]),
                el("td", { class: "num" }, [has ? formatValue(r.actual, r.valueFormat) : "–"]),
                el("td", { class: "num" }, [r.target !== null ? formatValue(r.target, r.valueFormat) : "–"]),
                el("td", {}, [stateChip(r.state, r.stateWord)]),
            ]));
        }
        wrap.appendChild(el("section", { class: "owner" }, [
            el("h3", {}, [n]),
            el("table", {}, [
                el("thead", {}, [el("tr", {}, ["KPI", "Actual", "Target", "State"].map(h => el("th", {}, [h])))]), body,
            ]),
        ]));
    }
    return wrap;
}
