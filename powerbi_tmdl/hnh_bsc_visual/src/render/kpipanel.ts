import type { KpiRow } from "../model/types";
import { formatValue } from "../model/format";
import { directionNote } from "../model/parse";
import { el } from "./dom";
import { stateChip, stateMark, stateClass } from "./chips";
import { monthlyBars } from "./bars";
import { hasValue } from "./scorecard";

const DASH = "–";
/** Bars size inside the panel's 432 px at the report's 1860 x 870 box (the SVG scales down in a smaller one). */
const BARS_W = 606, BARS_H = 126;
export const EMPTY_PANEL = "Select a KPI in the table to see its monthly trend and hospitals";

const isNum = (v: number | null | undefined): v is number => typeof v === "number" && Number.isFinite(v);

/** "Higher is better", "Lower is better", "At most the target", "Closest to the target is best". */
export function polarity(direction: string): string {
    const note = directionNote(direction) ?? "higher is better";
    return note.charAt(0).toUpperCase() + note.slice(1);
}

const fact = (label: string, value: string, extra: HTMLElement | null = null) =>
    el("div", { class: "bd-fact" }, [el("span", { class: "bd-fact-l" }, [label]), el("span", { class: "bd-fact-row" }, [el("span", { class: "bd-fact-v" }, [value]), extra])]);

function trend(row: KpiRow, months: string[], colourVar: string): HTMLElement {
    const n = row.trend.length;
    const names = months.slice(-n);
    return el("div", { class: "bd-trend" }, [
        el("div", { class: "bd-trend-head" }, [
            el("h3", {}, ["Monthly trend vs target"]),
            el("span", { class: "bd-key" }, [el("i", { style: `background:${colourVar}` }), "Met"]),
            el("span", { class: "bd-key" }, [el("i", { class: "missed" }), "Missed"]),
            el("span", { class: "bd-key" }, [el("i", { class: "dash" }), "Target"]),
        ]),
        el("div", { class: "bd-chart" }, [monthlyBars(row, BARS_W, BARS_H, colourVar)]),
        names.length === n ? el("div", { class: "bd-months", "aria-hidden": "true" }, names.map(m => el("span", {}, [m.charAt(0)]))) : null,
    ]);
}

/** The selected-KPI panel: its drawn part (`.bd-panel-main`, the top 432 px) and two empty slots under it where the
 * report places the native "By hospital" chart and the drill-through button. Without a row it asks for one. A KPI
 * without a score shows its chip and reason, "–" values and no bars. */
export function kpiPanel(row: KpiRow | null, months: string[], colourVar: string): HTMLElement {
    const main = el("div", { class: "bd-panel-main" });
    if (!row) {
        main.appendChild(el("p", { class: "bd-empty" }, [EMPTY_PANEL]));
    } else {
        const value = hasValue(row);
        const scored = value && isNum(row.score);
        const cls = stateClass(row.state);
        main.appendChild(el("div", { class: "bd-phead" }, [
            el("span", { class: "bd-eyebrow" }, ["Selected KPI"]),
            el("h2", {}, [row.name]),
            el("span", { class: "bd-sub" }, [`${row.objectiveTitle} · ${polarity(row.direction)}`]),
        ]));
        main.appendChild(el("div", { class: "bd-facts" }, [
            fact("Actual", value ? formatValue(row.actual, row.valueFormat) : DASH),
            fact("Target", isNum(row.target) ? formatValue(row.target, row.valueFormat) : DASH),
            fact("Score", scored ? String(Math.round(row.score as number)) : DASH,
                scored ? el("span", { class: `bd-state ${cls}` }, [stateMark(row.state), row.stateWord]) : null),
        ]));
        const judged = value && (row.state === "good" || row.state === "warn" || row.state === "bad");
        // Without trends (the scores payload) a scored KPI has no bars to draw; one without a score says why.
        if (judged && row.trend.some(isNum)) main.appendChild(trend(row, months, colourVar));
        else if (!judged) main.appendChild(el("div", { class: "bd-why" }, [stateChip(row.state, row.stateWord), row.reason ?? (row.state === "notarget" ? "No target set" : null)]));
    }
    return el("section", { class: "bd-panel", "aria-label": "Selected KPI" }, [
        main,
        el("div", { class: "bd-slot-chart" }),
        el("div", { class: "bd-slot-button" }),
    ]);
}
