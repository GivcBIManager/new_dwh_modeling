import type { KpiRow, ViewModel } from "../model/types";
import { bandEdges, met } from "../model/bands";
import { DASH, formatValue, formatVariance, isNum } from "../model/format";
import { monthLabels } from "../model/months";
import { el, svg } from "./dom";
import { pillarColourVar, stateChip, stateClass, stateMark } from "./chips";
import { empty } from "./empty";
import { polarity } from "./kpipanel";
import { allFirstRows, GROUP_WORD } from "./rows";
import { hasValue, targetText } from "./scorecard";

/** Chart size inside the trend panel at the report's 1920 x 996 box (the SVG scales down in a smaller one). */
const CHART_W = 1278, CHART_H = 300;
/** The band tints: On track, Watch, At risk (tokens --good-bg, --warn-bg, --bad-bg; high contrast replaces them in CSS). */
export const BAND_FILL = { good: "#E3F6F3", warn: "#FFF2E0", bad: "#FDE9E5" } as const;
type Band = keyof typeof BAND_FILL;
const BAND_WORD: Record<Band, string> = GROUP_WORD;
const FONT = 16.5;

/** A KPI the model judged this period: On track, Watch or At risk with a value. */
const judged = (r: KpiRow) => hasValue(r) && (r.state === "good" || r.state === "warn" || r.state === "bad");

/** "Corporate · Jan 2026 – Sep 2026" -> the hospital part and the period; a label without " · " is one part. */
function labelParts(label: string): { part: string | null; period: string | null } {
    const s = String(label ?? "").trim();
    if (!s) return { part: null, period: null };
    const i = s.indexOf(" · ");
    if (i < 0) return { part: s, period: null };
    return { part: s.slice(0, i).trim() || null, period: s.slice(i + 3).trim() || null };
}

function subBar(row: KpiRow, label: string, kpis: number): HTMLElement {
    const sep = () => el("span", { class: "dt-sep", "aria-hidden": "true" }, [" › "]);
    const { part, period } = labelParts(label);
    const chips = [row.name, period, part].filter((c): c is string => !!c).map(c => el("span", { class: "dt-chip", title: c }, [c]));
    return el("div", { class: "dt-sub" }, [
        el("div", { class: "dt-where" }, [
            el("nav", { class: "dt-crumb", "aria-label": "Breadcrumb" }, [
                el("span", { class: "dt-up" }, ["Overview"]), sep(), el("span", { class: "dt-up" }, [row.pillar]), sep(),
                el("span", { class: "dt-here" }, [row.name]),
            ]),
            kpis > 1 ? el("p", { class: "dt-hint", role: "note" }, [`Showing ${row.name}; open KPI detail from one KPI`]) : null,
        ]),
        el("div", { class: "dt-filters", role: "group", "aria-label": "Drill-through filters" }, [
            el("span", { class: "dt-filters-l" }, ["Drill-through filters"]), ...chips,
        ]),
    ]);
}

/** The three performance bands as text in the KPI's units, from the current target; null without bands. */
export function bandTexts(row: KpiRow): [Band, string][] | null {
    if (!isNum(row.target)) return null;
    const e = bandEdges(row, row.target);
    if (!e) return null;
    const g = formatValue(e.good, row.valueFormat), w = formatValue(e.watch, row.valueFormat);
    if (e.kind === "above") return [["good", `≥ ${g}`], ["warn", `${w} – ${g}`], ["bad", `< ${w}`]];
    if (e.kind === "below") return [["good", `≤ ${g}`], ["warn", `${g} – ${w}`], ["bad", `> ${w}`]];
    return [["good", `within ± ${g}`], ["warn", `within ± ${w}`], ["bad", `beyond ± ${w}`]];
}

function profile(row: KpiRow): HTMLElement {
    const value = hasValue(row);
    const scored = value && isNum(row.score);
    const cls = stateClass(row.state);
    const fact = (term: string, text: string) => [el("dt", {}, [term]), el("dd", {}, [text || DASH])];
    const weight = isNum(row.weight) ? formatValue(row.weight, "pct") : DASH;
    const bands = judged(row) ? bandTexts(row) : null;
    const note = row.manual && row.manualNote.trim() ? row.manualNote.trim() : null;
    return el("section", { class: "dt-profile", "aria-label": "KPI profile" }, [
        el("div", { class: "dt-head" }, [
            el("span", { class: "dt-eyebrow", style: `color:${pillarColourVar(row.pillarOrder)}` }, [
                el("span", { class: "dt-sq", style: `background:${pillarColourVar(row.pillarOrder)}` }),
                row.objectiveTitle ? `${row.pillar} · ${row.objectiveTitle}` : row.pillar,
            ]),
            el("h1", {}, [row.name]),
        ]),
        el("div", { class: "dt-figure" }, [
            el("span", { class: `dt-actual ${cls}` }, [value ? formatValue(row.actual, row.valueFormat) : DASH]),
            el("div", { class: "dt-figure-r" }, [
                stateChip(row.state, row.stateWord),
                // The line breaks between its three parts, never inside one ("score" and its number stay together).
                el("span", { class: "dt-tline-text" }, [
                    el("span", {}, [`Target ${targetText(row)}`]), " · ",
                    el("strong", { class: value && isNum(row.variance) ? cls : "" }, [value ? formatVariance(row.variance) : DASH]), " · ",
                    el("span", {}, [`score ${scored ? String(Math.round(row.score as number)) : DASH}`]),
                ]),
            ]),
        ]),
        judged(row) ? null : el("p", { class: "dt-why" }, [row.reason ?? (row.state === "notarget" ? "No target set" : DASH)]),
        el("dl", { class: "dt-facts" }, [
            ...fact("Definition", row.definition.trim()),
            ...fact("Better when", polarity(row.direction)),
            ...fact("Target basis", row.targetBasis.trim()),
            ...fact("Weight", weight),
            ...fact("Owner", row.owner.trim()),
            ...fact("Co-owners", row.coOwners.join(", ")),
            ...fact("Source", row.manual ? "Manual entry" : "Calculated"),
        ]),
        bands ? el("div", { class: "dt-bandlist" }, [
            el("h2", {}, ["Performance bands"]),
            el("ul", { class: "dt-bands" }, bands.map(([k, text]) => el("li", {}, [stateMark(k), el("b", {}, [BAND_WORD[k]]), ` ${text}`]))),
        ]) : null,
        note ? el("div", { class: "dt-note" }, [el("span", { class: "dt-note-l" }, ["Manual entry note"]), el("p", {}, [note])]) : null,
    ]);
}

/** Ticks every `step` on a 1-2-2.5-5 scale, about four of them across the range, never finer than `res` and always a
 * whole multiple of it (2.5 x res becomes 5 x res). */
function niceStep(span: number, res: number): number {
    const raw = Math.max(span / 4, res);
    const p = Math.pow(10, Math.floor(Math.log10(raw)));
    const m = raw / p;
    let step = (m <= 1 ? 1 : m <= 2 ? 2 : m <= 2.5 ? 2.5 : m <= 5 ? 5 : 10) * p;
    if (Math.abs(step / res - Math.round(step / res)) > 1e-9) step = 5 * p;
    return Math.max(step, res);
}
const tidy = (v: number) => Number(v.toPrecision(12));
const fixedText = (v: number, d: number) => v.toLocaleString("en-US", { minimumFractionDigits: d, maximumFractionDigits: d });
/** The fewest decimals (0-6) that print `v` exactly. */
function decimalsOf(v: number): number {
    for (let d = 0; d < 6; d++) if (Math.abs(v * 10 ** d - Math.round(v * 10 ** d)) < 1e-6) return d;
    return 6;
}
/** The smallest tick step each value format can tell apart: whole minutes and riyals, 0.1% and 0.1 days. */
const RESOLUTION: Record<string, number> = { mins: 1, sar: 1, pct: 0.001, days: 0.1 };

/** The y axis in the KPI's units: ticks no finer than the format prints, and one unit for the whole axis (a SAR axis
 * that reaches 1 million says every tick in millions, with as many decimals as the step needs), so no two ticks read
 * the same. */
export function axisTicks(rawLo: number, rawHi: number, fmt: string): { lo: number; hi: number; ticks: number[]; labels: string[] } {
    const step = niceStep(rawHi - rawLo, RESOLUTION[fmt] ?? 0.01);
    const lo = tidy(Math.floor(rawLo / step) * step), hi = tidy(Math.ceil(rawHi / step) * step);
    const ticks: number[] = [];
    for (let k = 0; lo + k * step <= hi + step * 1e-9; k++) ticks.push(tidy(lo + k * step));
    const big = (limit: number) => ticks.some(v => Math.abs(v) >= limit);
    let label: (v: number) => string;
    if (fmt === "sar") {
        const d = Math.max(1, decimalsOf(step / 1e6));
        label = big(1e6) ? v => `SAR ${fixedText(v / 1e6, d)}M` : v => `SAR ${fixedText(v, 0)}`;
    } else if (fmt === "pct" || fmt === "days" || fmt === "mins") {
        label = v => formatValue(v, fmt);
    } else {
        // Plain numbers: two decimals under 1,000 and none from there, as formatValue prints them, the same for every tick.
        const d = big(1000) ? decimalsOf(step) : 2;
        label = v => fixedText(v, d);
    }
    return { lo, hi, ticks, labels: ticks.map(label) };
}

/** "Monthly trend with performance bands": per month, the three bands from that month's target by the KPI's own
 * scoring rule (`bandEdges`; months without a finite target draw none, nor does a parked or no-target KPI), the
 * dashed monthly target as a step line, and the actual line in the dark blue with a dot per month. The y axis covers
 * the actuals, the targets and the band edges, from 0 when no value is negative; labels are in the KPI's units. */
export function bandChart(row: KpiRow, months: string[], width: number, height: number): SVGSVGElement {
    const n = row.trend.length;
    const banded = row.state !== "parked" && row.state !== "notarget";
    const targets = Array.from({ length: n }, (_, i) => row.targetTrend[i]);
    const edges = targets.map(t => (banded && isNum(t) ? bandEdges(row, t) : null));

    const data = [...row.trend.filter(isNum), ...targets.filter(isNum)];
    const all = [...data];
    edges.forEach((e, i) => {
        if (!e) return;
        const t = targets[i] as number;
        if (e.kind === "around") all.push(t - e.watch, t + e.watch); else all.push(e.good, e.watch);
    });
    let rawLo = all.length ? Math.min(...all) : 0, rawHi = all.length ? Math.max(...all) : 1;
    if (rawHi === rawLo) { const d = Math.abs(rawHi) * 0.1 || 1; rawLo -= d; rawHi += d; }
    const pad = (rawHi - rawLo) * 0.08;
    rawLo -= pad; rawHi += pad;
    if (data.length && Math.min(...data) >= 0) rawLo = Math.max(0, rawLo);
    const { lo, hi, ticks, labels: tickText } = axisTicks(rawLo, rawHi, row.valueFormat);

    const left = Math.max(54, 18 + Math.max(...tickText.map(t => t.length)) * 9.5), right = 12;
    const top = 12, bottom = months.length >= n && n > 0 ? 36 : 12;
    const plotW = Math.max(1, width - left - right), plotH = Math.max(1, height - top - bottom);
    const Y = (v: number) => top + ((hi - Math.min(Math.max(v, lo), hi)) / (hi - lo)) * plotH;
    const f = (v: number) => v.toFixed(1);
    const slot = n > 0 ? plotW / n : plotW;
    const X0 = (i: number) => left + i * slot;
    const XC = (i: number) => left + (i + 0.5) * slot;

    let hits = 0, scoredMonths = 0;
    const s = svg("svg", { width, height, viewBox: `0 0 ${width} ${height}`, role: "img", class: "dt-chart-svg" });

    // Bands: At risk first, Watch over it, On track on top (the centred band of an on-target KPI needs that order).
    edges.forEach((e, i) => {
        if (!e) return;
        const t = targets[i] as number;
        const spans: Record<Band, [number, number]> = e.kind === "above"
            ? { bad: [-Infinity, e.watch], warn: [e.watch, e.good], good: [e.good, Infinity] }
            : e.kind === "below"
                ? { bad: [e.watch, Infinity], warn: [e.good, e.watch], good: [-Infinity, e.good] }
                : { bad: [-Infinity, Infinity], warn: [t - e.watch, t + e.watch], good: [t - e.good, t + e.good] };
        for (const k of ["bad", "warn", "good"] as Band[]) {
            const [a, b] = spans[k];
            const y = Y(Math.min(b, hi)), h = Math.max(0, Y(Math.max(a, lo)) - y);
            s.appendChild(svg("rect", { x: f(X0(i)), y: f(y), width: f(slot), height: f(h), fill: BAND_FILL[k], class: `dt-band ${k}` }));
        }
    });

    ticks.forEach((v, k) => {
        s.appendChild(svg("line", { x1: left, x2: left + plotW, y1: f(Y(v)), y2: f(Y(v)), "stroke-width": 1, class: "dt-grid" }));
        s.appendChild(svg("text", { x: left - 9, y: f(Y(v) + 5.5), "text-anchor": "end", "font-size": FONT, class: "dt-y" }, [tickText[k]]));
    });

    let td = "";
    let prev = false;
    for (let i = 0; i < n; i++) {
        const t = targets[i];
        if (!isNum(t)) { prev = false; continue; }
        td += `${prev ? "V" : `M${f(X0(i))} `}${f(Y(t))}H${f(X0(i + 1))}`;
        prev = true;
    }
    if (td) s.appendChild(svg("path", { d: td, fill: "none", "stroke-width": 2.25, "stroke-dasharray": "7.5 6", class: "dt-tline" }));

    let d = "";
    let pen = false;
    const dots: SVGCircleElement[] = [];
    row.trend.forEach((a, i) => {
        if (!isNum(a)) { pen = false; return; }
        const t = targets[i];
        if (isNum(t)) { scoredMonths++; if (met(row, a, t)) hits++; }
        d += `${pen ? "L" : "M"}${f(XC(i))} ${f(Y(a))}`;
        pen = true;
        dots.push(svg("circle", { cx: f(XC(i)), cy: f(Y(a)), r: 4.5, class: "dt-dot", style: "fill:var(--blue-dk)" }));
    });
    if (d) {
        s.appendChild(svg("path", {
            d, fill: "none", "stroke-width": 3.75, "stroke-linejoin": "round", "stroke-linecap": "round", class: "dt-line", style: "stroke:var(--blue-dk)",
        }));
    }
    for (const c of dots) s.appendChild(c);

    if (bottom > 12) {
        const names = months.slice(-n);
        names.forEach((m, i) => s.appendChild(svg("text", { x: f(XC(i)), y: height - 9, "text-anchor": "middle", "font-size": FONT, class: "dt-month" }, [m])));
    }
    s.setAttribute("aria-label", `${row.name} by month against its performance bands: ${hits} of ${scoredMonths} month${scoredMonths === 1 ? "" : "s"} on track`);
    return s;
}

function trendPanel(row: KpiRow, label: string): HTMLElement {
    const chart = bandChart(row, monthLabels(label, row.trend.length), CHART_W, CHART_H);
    const hasBands = !!chart.querySelector(".dt-band");
    const any = row.trend.some(isNum) || row.targetTrend.some(isNum);
    const key = (cls: string, word: string) => el("span", { class: "dt-key" }, [el("i", { class: cls }), word]);
    return el("section", { class: "dt-trend", "aria-label": "Monthly trend with performance bands" }, [
        el("div", { class: "dt-thead" }, [
            el("h2", {}, ["Monthly trend with performance bands"]),
            el("div", { class: "dt-keys" }, [
                key("line", "Actual"), key("dash", "Target"),
                ...(hasBands ? (["good", "warn", "bad"] as Band[]).map(k => key(`swatch ${k}`, BAND_WORD[k])) : []),
            ]),
        ]),
        any ? el("div", { class: "dt-chart" }, [chart]) : el("p", { class: "dt-none" }, ["No monthly values for this selection"]),
    ]);
}

/** KPI detail (the drill-through page): the sub-bar text (breadcrumb, drill-filter chips), the KPI profile and the
 * monthly trend with performance bands, for the first KPI of the first hospital. The report puts its native Back
 * button over the sub-bar's left, its guide buttons over its right, and its by-hospital chart and matrix over the
 * empty lower right of the body. */
export function detail(vm: ViewModel): HTMLElement {
    const rows = allFirstRows(vm);
    const row = rows[0];
    if (!row) return empty("No KPIs in this selection");
    return el("div", { class: "dt" }, [
        subBar(row, vm.label, rows.length),
        el("div", { class: "dt-body" }, [profile(row), trendPanel(row, vm.label)]),
    ]);
}
