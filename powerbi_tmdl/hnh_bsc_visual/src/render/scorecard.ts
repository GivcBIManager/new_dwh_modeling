import type { KpiRow } from "../model/types";
import { formatValue, formatVariance } from "../model/format";
import { selectionKey } from "../interactions";
import { el } from "./dom";
import { stateChip, stateClass } from "./chips";
import { comparator } from "./rows";
import { sparkline } from "./sparkline";

const DASH = "–";
const SPARK_W = 156, SPARK_H = 42;
export const COLUMNS = ["Status", "KPI · objective", "Actual", "Target", "Variance", "Score", "12-mo trend"];

const isNum = (v: number | null | undefined): v is number => typeof v === "number" && Number.isFinite(v);

/** A row with a value to show: an actual, and a state other than no data or parked. */
export const hasValue = (r: KpiRow): boolean => isNum(r.actual) && r.state !== "nodata" && r.state !== "parked";

export function targetText(r: KpiRow): string {
    return isNum(r.target) ? `${comparator(r.direction)} ${formatValue(r.target, r.valueFormat)}` : DASH;
}

function trendCell(r: KpiRow, colourVar: string): HTMLElement {
    const cell = el("span", { class: "c-trend" });
    if (!hasValue(r) || r.trend.filter(isNum).length < 2) return cell;
    const s = sparkline(r.trend, [], SPARK_W, SPARK_H);
    s.querySelector(".spark-line")?.setAttribute("style", `stroke:${colourVar}`);
    s.querySelector(".spark-dot")?.classList.add(stateClass(r.state));
    cell.appendChild(s);
    return cell;
}

function scoreRow(r: KpiRow, selected: boolean, colourVar: string): HTMLElement {
    const value = hasValue(r);
    const cls = stateClass(r.state);
    return el("div", {
        class: selected ? "bd-row selected" : "bd-row", tabindex: 0, "data-key": r.rowIndex, "data-series": r.seriesIndex,
        "aria-label": `${r.name}: ${r.stateWord}`,
    }, [
        el("span", { class: "c-chip" }, [stateChip(r.state, r.stateWord)]),
        el("span", { class: "c-kpi" }, [
            el("span", { class: "bd-name" }, [r.name, r.manual ? el("span", { class: "bd-tag" }, ["Manual"]) : null]),
            el("span", { class: "bd-obj" }, [r.reason ?? r.objectiveTitle]),
        ]),
        el("span", { class: "c-actual" }, [value ? formatValue(r.actual, r.valueFormat) : DASH]),
        el("span", { class: "c-target" }, [targetText(r)]),
        el("span", { class: value && isNum(r.variance) ? `c-var ${cls}` : "c-var" }, [value ? formatVariance(r.variance) : DASH]),
        el("span", { class: "c-score" }, [value && isNum(r.score) ? String(Math.round(r.score)) : DASH]),
        trendCell(r, colourVar),
    ]);
}

/** The KPI scorecard: a fixed header row, then the rows in a body that scrolls on its own. Rows are selectable
 * (`data-key`, `data-series`, a tab stop); the one whose key is `selectedKey` is highlighted. */
export function scorecardTable(rows: KpiRow[], selectedKey: string | null, colourVar: string): HTMLElement {
    const head = el("div", { class: "bd-thead" }, COLUMNS.map(c => el("span", {}, [c])));
    const body = el("div", { class: "bd-tbody" },
        rows.map(r => scoreRow(r, selectedKey !== null && selectionKey(r.rowIndex, r.seriesIndex) === selectedKey, colourVar)));
    if (rows.length === 0) body.appendChild(el("p", { class: "bd-none" }, ["No KPIs for this objective"]));
    return el("div", { class: "bd-grid" }, [head, body]);
}
