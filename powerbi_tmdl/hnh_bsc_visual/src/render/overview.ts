import type { KpiRow, PillarSummary, ViewModel } from "../model/types";
import { formatValue } from "../model/format";
import { lastDelta, monthLabels } from "../model/months";
import { overallTrend } from "../model/score";
import { el, svg } from "./dom";
import { pillarColourVar, stateChip, stateMark } from "./chips";
import { lineChart } from "./linechart";
import { ring } from "./ring";
import { allFirstRows, firstRows, scoreState } from "./rows";

type Group = "good" | "warn" | "bad" | "nodata";
const GROUPS: Group[] = ["good", "warn", "bad", "nodata"];
/** Words of the distribution: "No data" groups No data yet, Parked and No target. */
const GROUP_WORD: Record<Group, string> = { good: "On track", warn: "Watch", bad: "At risk", nodata: "No data" };
/** Chip words for a score's state; a missing score is "No data yet", as the model says it. */
const SCORE_WORD: Record<Group, string> = { good: "On track", warn: "Watch", bad: "At risk", nodata: "No data yet" };
/** Needs attention rows that fit the bottom row at 66 px each. */
const ATTENTION_ROWS = 6;
/** Trend chart size inside its panel at the report's 1860 x 870 box (the SVG scales down in a smaller one). */
const CHART_W = 1156, CHART_H = 400;

const isNum = (v: number | null | undefined): v is number => typeof v === "number" && Number.isFinite(v);

function groupCounts(ps: PillarSummary[]): Record<Group, number> {
    const out = { good: 0, warn: 0, bad: 0, nodata: 0 };
    for (const p of ps) {
        out.good += p.counts.good; out.warn += p.counts.warn; out.bad += p.counts.bad;
        out.nodata += p.counts.nodata + p.counts.parked + p.counts.notarget;
    }
    return out;
}

const scoreText = (v: number | null) => (isNum(v) ? String(Math.round(v)) : "–");
const weightText = (w: number | null) => (isNum(w) ? `Weight ${Math.round(w * 100)}%` : "Weight –");

/** "▲ 0.3" (with " vs Aug" when the month is known); null without a delta. */
function delta(trend: (number | null)[], vs: string | null): HTMLElement | null {
    const d = lastDelta(trend);
    if (d === null) return null;
    const r = Math.round(d * 10) / 10;
    const dir = r > 0 ? "up" : r < 0 ? "down" : "flat";
    const text = `${r < 0 ? "▼" : "▲"} ${Math.abs(r).toFixed(1)}${vs ? ` vs ${vs}` : ""}`;
    return el("span", { class: `ov-delta ${dir}` }, [text]);
}

const hasTrend = (vm: ViewModel) => vm.pillars.some(p => p.trend.length >= 2 && p.trend.some(isNum));

function overall(vm: ViewModel, trends: boolean): HTMLElement {
    const t = vm.thresholds;
    const st = scoreState(vm.overallScore, t) as Group;
    const trend = trends ? overallTrend(vm.pillars) : [];
    const months = monthLabels(vm.label, trend.length);
    const shown = isNum(vm.overallScore) ? Math.round(vm.overallScore) : null;
    const gap = shown === null ? "" : shown >= t.good ? " · met" : ` · gap ${(t.good - (vm.overallScore as number)).toFixed(1)}`;

    const counts = groupCounts(vm.pillars);
    const total = GROUPS.reduce((n, g) => n + counts[g], 0);
    const bar = el("div", {
        class: "ov-dist-bar", role: "img", "aria-label": GROUPS.map(g => `${counts[g]} ${GROUP_WORD[g]}`).join(", "),
    }, GROUPS.filter(g => counts[g] > 0).map(g => el("i", { class: g, style: `width:${((counts[g] / total) * 100).toFixed(1)}%` })));
    const list = el("div", { class: "ov-dist-counts" },
        GROUPS.map(g => el("span", {}, [stateMark(g), el("b", {}, [String(counts[g])]), ` ${GROUP_WORD[g]}`])));

    const n = vm.pillars.length;
    return el("section", { class: "ov-overall", "aria-label": "Overall score" }, [
        el("div", { class: "ov-head" }, [el("h2", {}, ["Overall BSC score"]), el("span", { class: "ov-sub" }, [`Weighted · ${n} pillar${n === 1 ? "" : "s"}`])]),
        el("div", { class: "ov-ringrow" }, [
            ring(vm.overallScore, 168, "Overall score"),
            el("div", { class: "ov-facts" }, [
                stateChip(st, SCORE_WORD[st]),
                trends ? delta(trend, months.length >= 2 ? months[months.length - 2] : null) : null,
                el("span", { class: "ov-target" }, [`Target ${t.good}${gap}`]),
            ]),
        ]),
        el("div", { class: "ov-dist" }, [bar, list]),
    ]);
}

/** Area sparkline of a pillar's score trend, in the pillar's colour. */
function areaSpark(values: (number | null)[], colour: string): SVGSVGElement {
    const s = svg("svg", { width: "100%", height: 60, viewBox: "0 0 200 40", preserveAspectRatio: "none", "aria-hidden": "true", class: "spark ov-spark" });
    const pts = values.map((v, i) => (isNum(v) ? { i, v } : null)).filter((p): p is { i: number; v: number } => p !== null);
    if (pts.length < 2) return s;
    const mn = Math.min(...pts.map(p => p.v)), mx = Math.max(...pts.map(p => p.v)), r = mx - mn || 1;
    const X = (i: number) => (values.length <= 1 ? 100 : (i * 200) / (values.length - 1));
    const Y = (v: number) => 36 - ((v - mn) / r) * 32;
    const line = pts.map((p, k) => `${k ? "L" : "M"}${X(p.i).toFixed(1)} ${Y(p.v).toFixed(1)}`).join(" ");
    const area = `${line} L${X(pts[pts.length - 1].i).toFixed(1)} 40 L${X(pts[0].i).toFixed(1)} 40 Z`;
    s.appendChild(svg("path", { d: area, stroke: "none", "fill-opacity": 0.08, class: "ov-spark-area", style: `fill:${colour}` }));
    s.appendChild(svg("path", {
        d: line, fill: "none", "stroke-width": 3, "vector-effect": "non-scaling-stroke", "stroke-linejoin": "round", class: "ov-spark-line", style: `stroke:${colour}`,
    }));
    return s;
}

function card(p: PillarSummary, vm: ViewModel, trends: boolean): HTMLElement {
    const t = vm.thresholds;
    const colour = pillarColourVar(p.order);
    const st = scoreState(p.score, t) as Group;
    const fill = isNum(p.score) ? Math.min(Math.max(p.score, 0), 100) : 0;
    const counts = (["good", "warn", "bad"] as Group[]).map(g =>
        el("span", { class: "ov-n", title: `${p.counts[g]} ${GROUP_WORD[g]}`, "aria-label": `${p.counts[g]} ${GROUP_WORD[g]}` }, [stateMark(g), String(p.counts[g])]));
    const kpis = firstRows(p).length;
    return el("article", { class: "ov-pillar", "data-pillar": p.name, "aria-label": `${p.name} pillar` }, [
        // The weight sits under the name: in Segoe UI "Learning & Growth" and its weight do not fit one line of the card.
        el("div", { class: "ov-phead" }, [
            el("span", { class: "ov-sq", style: `background:${colour}` }),
            el("div", { class: "ov-pname" }, [el("h3", {}, [p.name]), el("span", { class: "ov-sub" }, [weightText(p.weight)])]),
        ]),
        el("div", { class: "ov-scorerow" }, [el("span", { class: "ov-score" }, [scoreText(p.score)]), stateChip(st, SCORE_WORD[st])]),
        el("div", { class: "ov-bar", role: "img", "aria-label": `${p.name} score ${scoreText(p.score)}, target ${t.good}` }, [
            el("i", { style: `width:${fill}%;background:${colour}` }),
            el("b", { style: `left:${Math.min(Math.max(t.good, 0), 100)}%` }),
        ]),
        trends && p.trend.filter(isNum).length >= 2 ? areaSpark(p.trend, colour) : null,
        el("div", { class: "ov-counts" }, [...counts, trends ? delta(p.trend, null) : null]),
        el("span", { class: "ov-drill", style: `color:${colour}` }, [`Drill into ${kpis} KPI${kpis === 1 ? "" : "s"} →`]),
    ]);
}

function trendPanel(vm: ViewModel): HTMLElement {
    const n = vm.pillars.reduce((m, p) => Math.max(m, p.trend.length), 0);
    const legend = el("div", { class: "ov-legend" }, [
        ...vm.pillars.map(p => el("span", {}, [el("i", { style: `background:${pillarColourVar(p.order)}` }), p.name])),
        el("span", {}, [el("i", { class: "dash" }), `Target ${vm.thresholds.good}`]),
    ]);
    const chart = lineChart(
        vm.pillars.map(p => ({ name: p.name, colourVar: pillarColourVar(p.order), values: p.trend })),
        { months: monthLabels(vm.label, n), target: vm.thresholds.good, width: CHART_W, height: CHART_H },
    );
    return el("section", { class: "ov-trend", "aria-label": "Pillar score trend" }, [
        el("div", { class: "ov-head" }, [el("h2", {}, [`Pillar score trend · last ${n} months`]), legend]),
        el("div", { class: "ov-chart" }, [chart]),
    ]);
}

function comparator(direction: string): string {
    return direction === "higher" ? "≥" : direction === "on_target" ? "≈" : "≤";
}

function attentionRow(k: KpiRow, vm: ViewModel): HTMLElement {
    const order = vm.pillars.find(p => p.name === k.pillar)?.order ?? k.pillarOrder;
    const target = isNum(k.target) ? `target ${comparator(k.direction)} ${formatValue(k.target, k.valueFormat)}` : "No target";
    return el("div", {
        class: "ov-att-row", tabindex: 0, "data-key": k.rowIndex, "data-series": k.seriesIndex, "aria-label": `${k.name}: ${k.stateWord}`,
    }, [
        el("span", { class: "ov-att-l" }, [
            el("span", { class: "ov-att-name" }, [k.name]),
            el("span", { class: "ov-att-pillar" }, [el("i", { style: `background:${pillarColourVar(order)}` }), k.pillar]),
        ]),
        el("span", { class: "ov-att-r" }, [
            el("span", { class: "ov-att-actual" }, [formatValue(k.actual, k.valueFormat)]),
            el("span", { class: "ov-att-target" }, [target]),
        ]),
    ]);
}

function attention(vm: ViewModel): HTMLElement {
    const rows = allFirstRows(vm);
    const risk = rows.filter(k => k.state === "bad")
        .sort((a, b) => (isNum(a.score) ? a.score : Infinity) - (isNum(b.score) ? b.score : Infinity));
    const watch = rows.filter(k => k.state === "warn").length;
    const list = el("div", { class: "ov-att-list" }, risk.slice(0, ATTENTION_ROWS).map(k => attentionRow(k, vm)));
    if (risk.length === 0) list.appendChild(el("p", { class: "ov-none" }, ["No KPI is at risk."]));
    const foot = watch > 0
        ? el("p", { class: "ov-foot" }, [watch === 1
            ? "1 more KPI is on watch. Open a pillar to review it."
            : `${watch} more KPIs are on watch. Open a pillar to review them.`])
        : null;
    return el("section", { class: "ov-attention", "aria-label": "Needs attention" }, [
        el("div", { class: "ov-head" }, [el("h2", {}, ["Needs attention"]), stateChip("bad", "At risk", String(risk.length))]),
        list, foot,
    ]);
}

/** The Overview: overall panel and four pillar cards on top; the pillar trend and Needs attention below. Without
 * trends (the scores payload) the sparklines, deltas and trend panel are left out and Needs attention takes the row. */
export function overview(vm: ViewModel): HTMLElement {
    const trends = hasTrend(vm);
    return el("div", { class: "ov" }, [
        overall(vm, trends),
        ...vm.pillars.map(p => card(p, vm, trends)),
        el("div", { class: trends ? "ov-row2" : "ov-row2 no-trend" }, [trends ? trendPanel(vm) : null, attention(vm)]),
    ]);
}
