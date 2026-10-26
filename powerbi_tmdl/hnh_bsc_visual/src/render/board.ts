import type { KpiRow, PillarSummary, ViewModel } from "../model/types";
import { DASH, deltaDirection, formatDelta, isNum } from "../model/format";
import { lastDelta, monthLabels } from "../model/months";
import { selectionKey } from "../interactions";
import { el } from "./dom";
import { pillarColourVar, stateChip, stateMark } from "./chips";
import { firstRows, scoreState, GROUPS, GROUP_WORD, SCORE_WORD, type Group } from "./rows";
import { scorecardTable } from "./scorecard";
import { kpiPanel } from "./kpipanel";



/** The pillar the board shows: the requested one when present, else the first. */
export function boardPillar(vm: ViewModel, wanted: string | null): PillarSummary {
    return vm.pillars.find(p => p.name === wanted) ?? vm.pillars[0];
}

/** The board's rows: the pillar's first hospital, by objective order (objectives with the same order kept apart by
 * code), then primary first, then display order. */
export function boardRows(p: PillarSummary): KpiRow[] {
    return [...firstRows(p)].sort((a, b) => (a.objectiveOrder - b.objectiveOrder) || a.objectiveCode.localeCompare(b.objectiveCode)
        || (Number(b.primary) - Number(a.primary)) || (a.displayOrder - b.displayOrder));
}

/** The pillar's objectives in objective order: [code, title]. */
export function objectivesOf(p: PillarSummary): [string, string][] {
    const seen = new Map<string, string>();
    for (const r of boardRows(p)) if (!seen.has(r.objectiveCode)) seen.set(r.objectiveCode, r.objectiveTitle || r.objectiveCode);
    return [...seen];
}

const block = (label: string, value: Node, labelClass = "bd-fig-l") =>
    el("div", { class: "bd-fig" }, [el("span", { class: labelClass }, [label]), value]);

function strip(vm: ViewModel, p: PillarSummary, colourVar: string): HTMLElement {
    const st = scoreState(p.score, vm.thresholds) as Group;
    const months = monthLabels(vm.label, p.trend.length);
    const d = lastDelta(p.trend);
    const delta = el("span", { class: `bd-delta ${deltaDirection(d)}` }, [formatDelta(d)]);
    const prev = months.length >= 2 ? months[months.length - 2] : null;
    const c = p.counts;
    const counts: Record<Group, number> = { good: c.good, warn: c.warn, bad: c.bad, nodata: c.nodata + c.parked + c.notarget };
    return el("section", { class: "bd-strip", "aria-label": "Pillar summary" }, [
        el("div", { class: "bd-title" }, [
            el("div", { class: "bd-crumb" }, ["Overview", el("span", { "aria-hidden": "true" }, [" › "]), p.name]),
            el("div", { class: "bd-pname" }, [el("span", { class: "bd-sq", style: `background:${colourVar}` }), el("h1", {}, [p.name])]),
        ]),
        el("span", { class: "bd-rule", "aria-hidden": "true" }),
        block("Pillar score", el("span", { class: "bd-fig-row" }, [
            el("span", { class: "bd-pscore" }, [isNum(p.score) ? String(Math.round(p.score)) : DASH]), stateChip(st, SCORE_WORD[st]),
        ])),
        // Without trends (the scores payload) there is no month-on-month change to show.
        p.trend.length >= 2 ? block(prev ? `vs ${prev}` : "vs last month", delta, "bd-fig-l bd-delta-label") : null,
        block("Weight", el("span", { class: "bd-weight" }, [isNum(p.weight) ? `${Math.round(p.weight * 100)}%` : DASH])),
        block("KPI status", el("span", { class: "bd-counts" },
            GROUPS.map(g => el("span", {}, [stateMark(g), el("b", {}, [String(counts[g])]), ` ${GROUP_WORD[g]}`])))),
        p.question ? el("p", { class: "bd-q" }, [p.question]) : null,
    ]);
}

/** Pillar board: the summary strip, then the KPI scorecard (narrowed by the objective picker) beside the selected-KPI
 * panel. The strip always describes the whole pillar. `selectedKey` is the single host-selected row, or null. */
export function board(vm: ViewModel, wanted: string | null, objective: string | null, selectedKey: string | null): HTMLElement {
    const p = boardPillar(vm, wanted);
    const colourVar = pillarColourVar(p.order);
    const rows = boardRows(p);
    const objectives = objectivesOf(p);
    const pick = objective !== null && objectives.some(([code]) => code === objective) ? objective : null;
    const shown = pick === null ? rows : rows.filter(r => r.objectiveCode === pick);

    const picker = el("select", { class: "bd-picker", "data-objective-picker": "", "aria-label": "Objective" }, [
        el("option", { value: "" }, ["All objectives"]),
        ...objectives.map(([code, title]) => el("option", { value: code }, [title])),
    ]);
    picker.value = pick ?? "";
    const table = el("section", { class: "bd-table", "aria-label": "KPI scorecard" }, [
        el("div", { class: "bd-thead-row" }, [
            el("h2", {}, ["KPI scorecard"]),
            el("span", { class: "bd-hint" }, ["Select a KPI to update the panel · right-click › Drill through for full detail"]),
            picker,
        ]),
        scorecardTable(shown, selectedKey, colourVar),
    ]);

    const selected = selectedKey === null ? null : rows.find(r => selectionKey(r.rowIndex, r.seriesIndex) === selectedKey) ?? null;
    const months = selected ? monthLabels(vm.label, selected.trend.length) : [];
    return el("div", { class: "bd" }, [
        strip(vm, p, colourVar),
        el("div", { class: "bd-body" }, [table, kpiPanel(selected, months, colourVar)]),
    ]);
}
