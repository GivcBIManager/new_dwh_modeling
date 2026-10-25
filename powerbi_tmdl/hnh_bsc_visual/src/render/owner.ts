import type { KpiRow, ViewModel } from "../model/types";
import { formatValue } from "../model/format";
import { el } from "./dom";
import { stateChip } from "./chips";
import { allFirstRows } from "./rows";

const NONE = "Unassigned";

/** One block per person accountable for KPIs: a KPI sits under its owner and, tagged "co-owner", under each co-owner.
 * Information only: owners are shown, nothing filters by them. */
export function owner(vm: ViewModel): HTMLElement {
    const by = new Map<string, { row: KpiRow; co: boolean }[]>();
    const add = (key: string, row: KpiRow, co: boolean) => {
        const g = by.get(key);
        if (g) g.push({ row, co }); else by.set(key, [{ row, co }]);
    };
    for (const r of allFirstRows(vm)) {
        add(r.owner || NONE, r, false);
        for (const c of r.coOwners) add(c, r, true);
    }
    const names = [...by.keys()].sort((a, b) => (a === NONE ? 1 : b === NONE ? -1 : a.localeCompare(b)));
    const wrap = el("div", { class: "owners" });
    for (const n of names) {
        const body = el("tbody");
        for (const { row: r, co } of by.get(n) as { row: KpiRow; co: boolean }[]) {
            const has = r.actual !== null && r.state !== "nodata" && r.state !== "parked";
            body.appendChild(el("tr", { "data-key": r.rowIndex, "data-series": r.seriesIndex, tabindex: 0 }, [
                el("td", {}, co ? [r.name, el("span", { class: "co-tag" }, ["co-owner"])] : [r.name]),
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
