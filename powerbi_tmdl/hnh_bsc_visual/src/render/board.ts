import type { KpiRow, PillarSummary, ViewModel } from "../model/types";
import { el } from "./dom";
import { tile } from "./tile";
import { firstRows } from "./rows";

/** The pillar the board shows: the requested one when present, else the first. */
export function boardPillar(vm: ViewModel, wanted: string | null): PillarSummary {
    return vm.pillars.find(p => p.name === wanted) ?? vm.pillars[0];
}

export function tabs(vm: ViewModel, current: string, question: string): HTMLElement | null {
    if (vm.pillars.length < 2) return null;
    const bar = el("div", { class: "tabs", role: "tablist" });
    for (const p of vm.pillars) {
        bar.appendChild(el("button", { type: "button", role: "tab", "aria-selected": String(p.name === current), "data-pillar": p.name }, [p.name]));
    }
    bar.appendChild(el("span", { class: "q" }, [question]));
    return bar;
}

export function board(vm: ViewModel, wanted: string | null): HTMLElement {
    const p = boardPillar(vm, wanted);
    const rows = firstRows(p);
    const groups = new Map<string, KpiRow[]>();
    for (const r of rows) {
        const g = groups.get(r.objectiveCode);
        if (g) g.push(r); else groups.set(r.objectiveCode, [r]);
    }
    const ordered = [...groups.values()].sort((a, b) => a[0].objectiveOrder - b[0].objectiveOrder);
    const grid = el("div", { class: "grid" });
    for (const g of ordered) {
        grid.appendChild(el("div", { class: "sec" }, [`${g[0].objectiveCode} · ${g[0].objectiveTitle}`, el("span", {}, [`${g.length} KPIs`])]));
        for (const r of g) grid.appendChild(tile(r));
    }
    return el("div", { class: "board" }, [tabs(vm, p.name, p.question), grid]);
}
