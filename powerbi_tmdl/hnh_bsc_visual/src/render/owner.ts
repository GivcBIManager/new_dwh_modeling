import type { KpiRow, ViewModel } from "../model/types";
import { DASH, formatValue, isNum } from "../model/format";
import { ownerCards, type OwnerCard, type OwnerScope, type OwnerTier, type ScoreMode } from "../model/achievement";
import { el } from "./dom";
import { stateChip } from "./chips";
import { allFirstRows, SCORE_WORD, type Group } from "./rows";
import { achievementGauge } from "./gauge";

const NONE = "Unassigned";

/** The owner view's own state (kept by the visual across updates, like the board tab). */
export interface OwnerUi {
    score: ScoreMode;
    tier: OwnerTier;
    scope: OwnerScope;
    /** The owner whose card is picked: the KPI list shows only them. */
    pick: string | null;
}

/** KPI list defaults to Owned + co-owned, so a co-owner's card never opens an empty list. */
export const DEFAULT_OWNER_UI: OwnerUi = { score: "weighted", tier: "csuite", scope: "co", pick: null };

/** The cards the strip shows for this state. */
export function stripCards(vm: ViewModel, ou: OwnerUi): OwnerCard[] {
    return ownerCards(allFirstRows(vm), ou);
}

/** The pick, or null when its card is not in the strip. */
export function validPick(vm: ViewModel, ou: OwnerUi): string | null {
    return ou.pick !== null && stripCards(vm, ou).some(c => c.owner === ou.pick) ? ou.pick : null;
}

const TOGGLES: { group: keyof Omit<OwnerUi, "pick">; label: string; options: [string, string][] }[] = [
    { group: "score", label: "Score", options: [["weighted", "Weighted"], ["hitrate", "On-target"]] },
    { group: "tier", label: "Owners", options: [["csuite", "C-Suite"], ["all", "All owners"]] },
    { group: "scope", label: "KPI list", options: [["owned", "Owned"], ["co", "Owned + co-owned"]] },
];

function toggleBar(ou: OwnerUi): HTMLElement {
    const bar = el("div", { class: "own-bar" });
    for (const t of TOGGLES) {
        bar.appendChild(el("span", { class: "own-lbl" }, [t.label]));
        bar.appendChild(el("div", { class: "seg", role: "group", "aria-label": t.label }, t.options.map(([value, text]) =>
            el("button", { type: "button", "data-owner-toggle": t.group, "data-value": value, "aria-pressed": String(ou[t.group] === value) }, [text]))));
    }
    return bar;
}

/** The achievement's state, as the gauge colours it: 100% and over on track, 85-99% watch, under 85% at risk. */
export function achievementState(value: number | null): Group {
    if (!isNum(value)) return "nodata";
    const shown = Math.round(value);
    return shown >= 100 ? "good" : shown >= 85 ? "warn" : "bad";
}

function card(c: OwnerCard, ou: OwnerUi): HTMLElement {
    const shown = c.value === null ? "no data" : `${Math.round(c.value)}%`;
    const st = achievementState(c.value);
    const sub = ou.score === "hitrate" ? `${c.counted} of ${c.total} KPIs on target` : `${c.counted} of ${c.total} KPIs scored`;
    return el("button", {
        type: "button", class: "own-card", "data-owner-card": c.owner, "aria-pressed": String(ou.pick === c.owner),
        "aria-label": `${c.owner}: achievement ${shown}, ${SCORE_WORD[st]}, ${sub}`,
    }, [
        el("span", { class: "own-name" }, [c.owner]),
        achievementGauge(c.value, 180, c.owner),
        // The gauge's colour as a shape and a word too.
        stateChip(st, SCORE_WORD[st]),
        el("span", { class: "own-sub" }, [sub]),
    ]);
}

function strip(vm: ViewModel, ou: OwnerUi): HTMLElement {
    const cards = stripCards(vm, ou);
    const wrap = el("div", { class: "own-strip", role: "group", "aria-label": "Owners" });
    if (!cards.length) {
        wrap.appendChild(el("p", { class: "own-none" }, [ou.tier === "csuite" ? "No C-suite owner in this selection — choose All owners" : "No owner in this selection"]));
    }
    for (const c of cards) wrap.appendChild(card(c, ou));
    return wrap;
}

/** One block per person accountable for KPIs: a KPI sits under its owner and, with Owned + co-owned, tagged "co-owner"
 * under each co-owner. */
function blocks(vm: ViewModel, only: string | null, scope: OwnerScope): HTMLElement {
    const by = new Map<string, { row: KpiRow; co: boolean }[]>();
    const add = (key: string, row: KpiRow, co: boolean) => {
        const g = by.get(key);
        if (g) g.push({ row, co }); else by.set(key, [{ row, co }]);
    };
    for (const r of allFirstRows(vm)) {
        add(r.owner || NONE, r, false);
        if (scope === "co") for (const c of r.coOwners) add(c, r, true);
    }
    const names = [...by.keys()].filter(n => only === null || n === only)
        .sort((a, b) => (a === NONE ? 1 : b === NONE ? -1 : a.localeCompare(b)));
    const wrap = el("div", { class: "owners" });
    if (only !== null && !names.length) {
        wrap.appendChild(el("p", { class: "own-none" }, [`${only} owns no KPI here — choose KPI list: Owned + co-owned to see the KPIs they co-own`]));
    }
    for (const n of names) {
        const body = el("tbody");
        for (const { row: r, co } of by.get(n) as { row: KpiRow; co: boolean }[]) {
            const has = r.actual !== null && r.state !== "nodata" && r.state !== "parked";
            body.appendChild(el("tr", { "data-key": r.rowIndex, "data-series": r.seriesIndex, tabindex: 0 }, [
                el("td", {}, co ? [r.name, el("span", { class: "co-tag" }, ["co-owner"])] : [r.name]),
                el("td", { class: "num" }, [has ? formatValue(r.actual, r.valueFormat) : DASH]),
                el("td", { class: "num" }, [r.target !== null ? formatValue(r.target, r.valueFormat) : DASH]),
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

/** Ownership overview: toggles, a strip of owner achievement cards, then the KPI blocks (all owners, or the picked one). */
export function owner(vm: ViewModel, ou: OwnerUi = DEFAULT_OWNER_UI): HTMLElement {
    const pick = validPick(vm, ou);
    const state = { ...ou, pick };
    return el("div", { class: "own-ov" }, [
        toggleBar(state),
        strip(vm, state),
        pick === null ? null : el("p", { class: "own-note", role: "status" }, [`Showing ${pick}'s KPIs — click the card again for every owner`]),
        blocks(vm, pick, ou.scope),
    ]);
}
