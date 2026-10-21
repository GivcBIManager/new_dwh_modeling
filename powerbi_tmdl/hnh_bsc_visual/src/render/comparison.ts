import type { KpiRow, ViewModel } from "../model/types";
import { el } from "./dom";
import { stateClass } from "./chips";
import { empty } from "./empty";

export function median(v: number[]): number | null {
    if (!v.length) return null;
    const s = [...v].sort((a, b) => a - b), m = s.length >> 1;
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

const num = (v: number | null | undefined): v is number => typeof v === "number" && Number.isFinite(v);
const hasScore = (r: KpiRow | undefined): r is KpiRow => !!r && num(r.score) && r.state !== "nodata" && r.state !== "parked";

/** KPIs as rows, hospitals as columns; focus hospital first; peer median of the other hospitals. */
export function comparison(vm: ViewModel, focus: string | null): HTMLElement {
    if (vm.branches.length === 0) return empty("Add a hospital field to compare hospitals");
    const f = focus && vm.branches.includes(focus) ? focus : vm.branches[0];
    const order = [f, ...vm.branches.filter(b => b !== f)];
    const idx = (b: string) => vm.branches.indexOf(b);

    const top = el("div", { class: "topline" }, order.map(b => {
        const s = vm.overallByBranch.find(x => x.branch === b)?.score;
        return el("span", { class: b === f ? "focus" : "" }, [`${b} `, el("b", {}, [num(s) ? String(Math.round(s)) : "–"])]);
    }));

    const head = el("tr", {}, [el("th", {}, ["KPI"]), ...order.map(b => el("th", { class: b === f ? "focus" : "", "data-branch": b, tabindex: 0 }, [b])), el("th", { class: "peer" }, ["Peer median"])]);
    const body = el("tbody");
    const every = vm.pillars.flatMap(p => p.kpis);
    for (const k of every.filter(r => r.seriesIndex === 0)) {
        const at = (b: string) => every.find(r => r.code === k.code && r.seriesIndex === idx(b));
        const tr = el("tr", {}, [el("th", { scope: "row" }, [k.name])]);
        for (const b of order) {
            const r = at(b);
            const cls = hasScore(r) ? stateClass(r.state) : "nodata";
            tr.appendChild(el("td", { class: b === f ? `${cls} focus` : cls }, [hasScore(r) ? String(Math.round(r.score as number)) : "–"]));
        }
        const m = median(order.slice(1).map(at).filter(hasScore).map(r => r.score as number));
        tr.appendChild(el("td", { class: "peer" }, [m === null ? "–" : String(Math.round(m))]));
        body.appendChild(tr);
    }
    return el("div", { class: "cmp" }, [top, el("table", {}, [el("thead", {}, [head]), body])]);
}
