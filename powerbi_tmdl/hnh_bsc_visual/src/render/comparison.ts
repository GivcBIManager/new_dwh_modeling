import type { KpiRow, PillarSummary, ViewModel } from "../model/types";
import { el } from "./dom";
import { stateClass } from "./chips";
import { empty } from "./empty";
import { hasScore } from "../model/state";
import { objectiveScore } from "../model/score";
import { formatValue, isNum } from "../model/format";
import { scoreState, SCORE_WORD, STATE_WORD } from "./rows";

/** The comparison's drill level: all pillars (both null), a pillar's objectives, or an objective's KPIs. */
export interface CompareLevel { pillar: string | null; objective: string | null }

export const TOP_LEVEL: CompareLevel = { pillar: null, objective: null };

export function median(v: number[]): number | null {
    if (!v.length) return null;
    const s = [...v].sort((a, b) => a - b), m = s.length >> 1;
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}


/** The level to draw: the picked one, or the top when its pillar, or its objective within that pillar, is not in the data. */
export function levelOf(vm: ViewModel, level: CompareLevel): CompareLevel {
    const p = level.pillar === null ? undefined : vm.pillars.find(x => x.name === level.pillar);
    if (!p) return { ...TOP_LEVEL };
    if (level.objective === null) return { pillar: p.name, objective: null };
    return p.kpis.some(k => k.objectiveCode === level.objective) ? { pillar: p.name, objective: level.objective } : { ...TOP_LEVEL };
}

interface Objective { code: string; title: string; order: number; label: string }

/** A pillar's objectives in objective order (then code), labelled "code · title". */
function objectivesOf(p: PillarSummary): Objective[] {
    const seen = new Map<string, Objective>();
    for (const k of p.kpis) {
        if (seen.has(k.objectiveCode)) continue;
        const label = k.objectiveTitle ? `${k.objectiveCode} · ${k.objectiveTitle}` : k.objectiveCode;
        seen.set(k.objectiveCode, { code: k.objectiveCode, title: k.objectiveTitle, order: k.objectiveOrder, label });
    }
    return [...seen.values()].sort((a, b) => (a.order - b.order) || a.code.localeCompare(b.code));
}

/** One score column of the league table: an aggregate (overall, pillar, objective) or a KPI. */
interface Column {
    label: string;
    /** Drill target when the header is a button. */
    drill?: CompareLevel;
    drillSay?: string;
    /** Aggregate score for the branch index, or the KPI row. */
    score?: (bi: number) => number | null;
    kpi?: (bi: number) => KpiRow | undefined;
}

/** "actual / target" in the KPI's value format; the currency is said once ("SAR 41.2M / 48.0M"). */
function actualTarget(r: KpiRow): string {
    const a = formatValue(r.actual, r.valueFormat);
    const t = formatValue(r.target, r.valueFormat);
    return `${a} / ${a.startsWith("SAR ") && t.startsWith("SAR ") ? t.slice(4) : t}`;
}

function drillButton(c: Column): HTMLElement {
    const d = c.drill as CompareLevel;
    return el("button", {
        type: "button", class: "drill", "data-cmp-pillar": d.pillar ?? "", "data-cmp-objective": d.objective ?? "",
        title: c.drillSay, "aria-label": c.drillSay,
    }, [`${c.label} `, el("span", { "aria-hidden": "true" }, ["▸"])]);
}

function crumbs(level: CompareLevel, objectiveLabel: string | null): HTMLElement {
    const items: HTMLElement[] = [];
    const link = (text: string, to: CompareLevel) =>
        el("button", { type: "button", class: "crumb", "data-cmp-pillar": to.pillar ?? "", "data-cmp-objective": to.objective ?? "" }, [text]);
    const here = (text: string) => el("span", { class: "here", "aria-current": "location" }, [text]);
    if (level.pillar === null) items.push(here("All pillars"));
    else {
        items.push(link("All pillars", TOP_LEVEL));
        if (level.objective === null) items.push(here(level.pillar));
        else items.push(link(level.pillar, { pillar: level.pillar, objective: null }), here(objectiveLabel ?? level.objective));
    }
    const nav = el("nav", { class: "crumbs", "aria-label": "Comparison level" });
    items.forEach((item, i) => {
        if (i > 0) nav.appendChild(el("span", { class: "gt", "aria-hidden": "true" }, [" › "]));
        nav.appendChild(item);
    });
    return nav;
}

/**
 * League table: hospitals as ranked rows; the columns drill Pillar > Objective > KPI. Level 1 ranks by the overall score
 * and shows a column per pillar; level 2 ranks by the pillar score with a column per objective; level 3 ranks by the
 * objective score with a column per KPI (score and actual / target). Ties go by hospital name; hospitals without a
 * score at the level go last. A branch without any KPI score (Head Office, a hospital outside the period) is left out.
 * Only KPI cells carry the KPI x branch key (selection, context menu, tooltip); aggregate and dash cells stay inert.
 */
export function comparison(vm: ViewModel, picked: CompareLevel = TOP_LEVEL): HTMLElement {
    if (vm.branches.length === 0) return empty("Add a hospital field to compare hospitals");
    const every = vm.pillars.flatMap(p => p.kpis);
    const scored = vm.branches.map((b, bi) => ({ b, bi })).filter(x => every.some(r => r.seriesIndex === x.bi && hasScore(r)));
    if (scored.length === 0) return empty("No hospital has a KPI score in this selection");

    const level = levelOf(vm, picked);
    const t = vm.thresholds;
    const pillar = vm.pillars.find(p => p.name === level.pillar);
    let lead: Column;
    let cols: Column[];
    let objectiveLabel: string | null = null;
    let hint: string;
    if (!pillar) {
        lead = { label: "Overall", score: bi => vm.overallByBranch[bi]?.score ?? null };
        cols = vm.pillars.map((p, pi) => ({
            label: p.name, drill: { pillar: p.name, objective: null }, drillSay: `${p.name}: compare its objectives`,
            score: bi => vm.pillars[pi].byBranch[bi]?.score ?? null,
        }));
        hint = "Click a pillar to compare its objectives.";
    } else {
        const objectives = objectivesOf(pillar);
        const objScore = (code: string) => (bi: number) => objectiveScore(pillar.kpis.filter(k => k.seriesIndex === bi && k.objectiveCode === code));
        if (level.objective === null) {
            lead = { label: pillar.name, score: bi => pillar.byBranch[bi]?.score ?? null };
            cols = objectives.map(o => ({
                label: o.label, drill: { pillar: pillar.name, objective: o.code }, drillSay: `${o.label}: compare its KPIs`, score: objScore(o.code),
            }));
            hint = "Click an objective to compare its KPIs.";
        } else {
            const o = objectives.find(x => x.code === level.objective) as Objective;
            objectiveLabel = o.label;
            lead = { label: o.label, score: objScore(o.code) };
            // KPI order as on the pillar board: primary first, then display order.
            const kpis = pillar.kpis.filter(k => k.objectiveCode === o.code && (k.seriesIndex === 0 || k.seriesIndex === null));
            cols = kpis.map(k => ({ label: k.name, kpi: bi => pillar.kpis.find(r => r.code === k.code && r.seriesIndex === bi) }));
            hint = "Right-click a KPI cell to drill through to KPI detail for that hospital.";
        }
    }

    // Rank by the shown (rounded) lead score; equal shown scores share the rank and go by name; no score goes last.
    const ranked = scored.map(x => {
        const s = (lead.score as (bi: number) => number | null)(x.bi);
        return { ...x, score: isNum(s) ? s : null, shown: isNum(s) ? Math.round(s) : null };
    }).sort((a, c) => {
        if (a.shown === null || c.shown === null) {
            if (a.shown !== c.shown) return a.shown === null ? 1 : -1;
        } else if (a.shown !== c.shown) return c.shown - a.shown;
        return a.b.localeCompare(c.b);
    });

    const scoreCell = (b: string, label: string, s: number | null, extra = ""): HTMLElement => {
        const st = scoreState(s, t);
        const cls = stateClass(st) + extra;
        const say = isNum(s) ? `${b}: ${label} ${Math.round(s)} · ${STATE_WORD[stateClass(st)]}` : `${b}: ${label} ${SCORE_WORD.nodata}`;
        return el("td", { class: cls, title: say, "aria-label": say }, [isNum(s) ? String(Math.round(s)) : "–"]);
    };
    const kpiCell = (b: string, label: string, r: KpiRow | undefined): HTMLElement => {
        if (!hasScore(r)) {
            const say = `${b}: ${label} ${SCORE_WORD.nodata}`;
            return el("td", { class: "nodata", title: say, "aria-label": say }, ["–"]);
        }
        const shown = String(Math.round(r.score as number));
        const at = isNum(r.actual) || isNum(r.target) ? actualTarget(r) : null;
        const say = `${b}: ${label} ${shown} · ${r.stateWord}` + (at ? ` · ${at}` : "");
        return el("td", { class: stateClass(r.state), title: say, "aria-label": say, "data-key": r.rowIndex, "data-series": r.seriesIndex, tabindex: 0 },
            [el("span", { class: "sc" }, [shown]), at ? el("span", { class: "at" }, [at]) : null]);
    };

    const head = el("tr", {}, [
        el("th", { class: "rank", scope: "col" }, ["#"]),
        el("th", { class: "hosp", scope: "col" }, ["Hospital"]),
        el("th", { class: "lead", scope: "col" }, [lead.label]),
        ...cols.map(c => el("th", { scope: "col", title: c.drill ? null : c.label }, [c.drill ? drillButton(c) : c.label])),
        el("th", { class: "peer", scope: "col" }, ["Peer median"]),
    ]);
    const body = el("tbody");
    for (const x of ranked) {
        const rank = x.shown === null ? "–" : String(1 + ranked.filter(y => y.shown !== null && y.shown > (x.shown as number)).length);
        const tr = el("tr", {}, [el("td", { class: "rank" }, [rank]), el("th", { class: "hosp", scope: "row" }, [x.b]), scoreCell(x.b, lead.label, x.score, " lead")]);
        for (const c of cols) tr.appendChild(c.kpi ? kpiCell(x.b, c.label, c.kpi(x.bi)) : scoreCell(x.b, c.label, (c.score as (bi: number) => number | null)(x.bi)));
        const m = median(ranked.filter(y => y !== x && y.score !== null).map(y => y.score as number));
        tr.appendChild(el("td", { class: "peer", title: `Median ${lead.label} of the other hospitals` }, [m === null ? "–" : String(Math.round(m))]));
        body.appendChild(tr);
    }
    const legend = el("div", { class: "cmp-legend" }, [
        `Scores are points out of 100: ${t.good} and over on track, ${t.watch}–${t.good - 1} watch, under ${t.watch} at risk; – means no data yet. ${hint}`,
    ]);
    return el("div", { class: "cmp" }, [crumbs(level, objectiveLabel), legend, el("div", { class: "cmp-scroll" }, [el("table", {}, [el("thead", {}, [head]), body])])]);
}
