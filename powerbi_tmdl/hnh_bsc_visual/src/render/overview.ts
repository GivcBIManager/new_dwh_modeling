import type { PillarSummary, StateKey, ViewModel } from "../model/types";
import { el } from "./dom";
import { gauge } from "./gauge";
import { stateChip, statusStrip } from "./chips";
import { sparkline } from "./sparkline";
import { firstRows, scoreState, STATE_WORD } from "./rows";

const GROUPS: ("good" | "warn" | "bad" | "nodata")[] = ["good", "warn", "bad", "nodata"];

function groupCounts(ps: PillarSummary[]): Record<"good" | "warn" | "bad" | "nodata", number> {
    const out = { good: 0, warn: 0, bad: 0, nodata: 0 };
    for (const p of ps) {
        out.good += p.counts.good; out.warn += p.counts.warn; out.bad += p.counts.bad;
        out.nodata += p.counts.nodata + p.counts.parked + p.counts.notarget;
    }
    return out;
}

function overall(vm: ViewModel): HTMLElement {
    const t = vm.thresholds;
    const counts = groupCounts(vm.pillars);
    const chips = el("div", { class: "chips" }, GROUPS.map(g => stateChip(g, STATE_WORD[g].toLowerCase(), String(counts[g]))));
    const weights = vm.pillars.filter(p => p.weight !== null).map(p => `${p.name} ${Math.round((p.weight as number) * 100)}%`).join(", ");
    const dot = (c: string) => el("span", { class: `dot ${c}` });
    const legend = el("div", { class: "legend" }, [
        weights ? `Pillar weights: ${weights}.` : null, el("br"),
        `A KPI scores ${t.base} at target and moves ${t.slope} points per 1% above or below it.`, el("br"),
        dot("good"), `${t.good} and over `, dot("warn"), `${t.watch}–${t.good - 1} `, dot("bad"), `under ${t.watch}`,
    ]);
    return el("section", { class: "overall", "aria-label": "Overall score" }, [
        el("h2", {}, ["Overall weighted score"]), gauge(vm.overallScore, 360, t.good, "Overall score", t.watch), chips, legend,
    ]);
}

function card(p: PillarSummary, vm: ViewModel): HTMLElement {
    const t = vm.thresholds;
    const rows = firstRows(p);
    const st: StateKey = scoreState(p.score, t);
    const word = STATE_WORD[st as "good" | "warn" | "bad" | "nodata"];
    const risk = p.counts.bad;
    const reporting = rows.filter(k => k.state === "good" || k.state === "warn" || k.state === "bad").length;
    const facts = el("div", { class: "facts" }, [
        stateChip(st, word),
        el("div", {}, [risk ? el("b", { class: "risk" }, [`${risk} at risk`]) : "None at risk", ` · ${reporting} of ${rows.length} KPIs reporting`]),
    ]);
    if (p.trend.filter(v => v !== null).length >= 2) {
        facts.appendChild(el("div", {}, [el("div", { class: "trendcap" }, ["Pillar score, by month"]), sparkline(p.trend, p.trend.map(() => t.good), 300, 46)]));
    }
    facts.appendChild(el("div", {}, [el("div", { class: "trendcap" }, ["Every KPI in this pillar"]), statusStrip(rows)]));
    return el("article", { class: "pillar", tabindex: 0, "data-pillar": p.name, "aria-label": `${p.name} pillar` }, [
        el("header", {}, [
            el("h3", {}, [p.name]), el("p", {}, [p.question]),
            p.weight !== null ? el("span", { class: "w" }, [`${Math.round(p.weight * 100)}% of score`]) : null,
        ]),
        el("div", { class: "body" }, [el("div", {}, [gauge(p.score, 220, t.good, p.name, t.watch)]), facts]),
    ]);
}

export function overview(vm: ViewModel): HTMLElement {
    return el("div", { class: "ov" }, [overall(vm), el("div", { class: "pillars" }, vm.pillars.map(p => card(p, vm)))]);
}
