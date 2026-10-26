import type { KpiRow } from "../model/types";
import { met } from "../model/bands";
import { isNum } from "../model/format";
import { svg } from "./dom";

/** The design's missed-month colour (the Watch tint, token --missed-bar). */
export const MISSED_FILL = "#F5B865";
const TOP = 6;

/** "Monthly trend vs target": one bar per month of the actual trend, from zero, in the pillar colour when that month
 * met its target (`targetTrend`) by the KPI's own scoring rule and in the Watch tint when it missed; a month without a
 * target is grey. The monthly targets are a dashed step line. Months without an actual leave their slot empty. */
export function monthlyBars(row: KpiRow, width: number, height: number, colourVar: string): SVGSVGElement {
    const n = row.trend.length;
    const values = [...row.trend, ...row.targetTrend.slice(0, n)].filter(isNum);
    let lo = Math.min(0, ...values), hi = Math.max(0, ...values);
    if (hi === lo) hi = lo + 1;
    hi += (hi - lo) * 0.06;
    const Y = (v: number) => TOP + ((hi - v) / (hi - lo)) * (height - TOP);
    const f = (v: number) => v.toFixed(1);
    const slot = n > 0 ? width / n : width;
    const barW = slot * 0.62;

    let hits = 0, judged = 0;
    const s = svg("svg", { width, height, viewBox: `0 0 ${width} ${height}`, role: "img", class: "bd-bars" });
    const base = Y(0);
    row.trend.forEach((a, i) => {
        if (!isNum(a)) return;
        const t = row.targetTrend[i];
        const ok = isNum(t) ? met(row, a, t) : null;
        if (ok !== null) { judged++; if (ok) hits++; }
        const y = Math.min(Y(a), base), h = Math.max(Math.abs(Y(a) - base), 1);
        const attrs = { x: f(i * slot + (slot - barW) / 2), y: f(y), width: f(barW), height: f(h), rx: 3 };
        if (ok === false) s.appendChild(svg("rect", { ...attrs, class: "bd-bar missed", fill: MISSED_FILL }));
        else s.appendChild(svg("rect", { ...attrs, class: ok ? "bd-bar met" : "bd-bar nt", style: `fill:${ok ? colourVar : "var(--nodata)"}` }));
    });

    let d = "";
    let prev = false;
    for (let i = 0; i < n; i++) {
        const t = row.targetTrend[i];
        if (!isNum(t)) { prev = false; continue; }
        d += `${prev ? "V" : `M${f(i * slot)} `}${f(Y(t))}H${f((i + 1) * slot)}`;
        prev = true;
    }
    if (d) s.appendChild(svg("path", { d, fill: "none", "stroke-width": 2.25, "stroke-dasharray": "6 4.5", class: "bd-tline" }));
    s.setAttribute("aria-label", `Monthly actual against target: ${hits} of ${judged} month${judged === 1 ? "" : "s"} met`);
    return s;
}
