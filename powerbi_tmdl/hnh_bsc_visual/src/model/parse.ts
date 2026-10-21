import powerbi from "powerbi-visuals-api";
import DataView = powerbi.DataView;
import DataViewCategoryColumn = powerbi.DataViewCategoryColumn;
import DataViewValueColumn = powerbi.DataViewValueColumn;
import DataViewValueColumnGroup = powerbi.DataViewValueColumnGroup;
import { Payload, KpiRow, PillarSummary, StateKey, ViewModel } from "./types";
import { parseNumber, parseTrend } from "./trend";
import { stateOf } from "./state";
import { overallScore, pillarScore, pillarTrend } from "./score";

const GUARD_MARK = "can't be analysed by";

export function isGuard(text: unknown): text is string {
    return typeof text === "string" && text.startsWith("\"") && text.includes(GUARD_MARK);
}

/** Split [BSC Visual Payload]: nine fields separated by "|". A guard text is returned as { guard }. */
export function parsePayload(text: string | null): Payload | { guard: string } {
    if (isGuard(text)) return { guard: text };
    const f = text === null || text === undefined ? [] : String(text).split("|");
    const state = (f[4] ?? "").trim();
    return {
        actual: parseNumber(f[0]),
        target: parseNumber(f[1]),
        variance: parseNumber(f[2]),
        score: parseNumber(f[3]),
        stateText: state === "" ? null : state,
        weight: parseNumber(f[5]),
        trend: parseTrend(f[6] ?? null),
        targetTrend: parseTrend(f[7] ?? null),
        scoreTrend: parseTrend(f[8] ?? null),
    };
}

export function directionNote(direction: string): string | null {
    switch (direction) {
        case "lower": return "lower is better";
        case "ceiling": return "at most the target";
        case "on_target": return "closest to the target is best";
        default: return null;
    }
}

function emptyCounts(): Record<StateKey, number> {
    return { good: 0, warn: 0, bad: 0, nodata: 0, parked: 0, notarget: 0 };
}

function tally(rows: KpiRow[]): Record<StateKey, number> {
    const counts = emptyCounts();
    for (const k of rows) counts[k.state]++;
    return counts;
}

function emptyModel(guard: string | null): ViewModel {
    return { pillars: [], overallScore: null, overallByBranch: [], label: "", thresholds: { base: 85, slope: 0.6, good: 85, watch: 70 }, branches: [], guardMessage: guard };
}

const asStr = (v: unknown): string => (v === null || v === undefined ? "" : String(v));
const asNum = (v: unknown): number | null => {
    if (v === null || v === undefined || v === "") return null;
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
};

export function parseDataView(dv: DataView): ViewModel {
    const cat = dv?.categorical;
    if (!cat || !cat.categories || !cat.values) return emptyModel(null);

    const cols = new Map<string, DataViewCategoryColumn>();
    for (const c of cat.categories) {
        for (const role of Object.keys(c.source.roles ?? {})) cols.set(role, c);
    }
    const kpiCol = cols.get("kpi");
    if (!kpiCol) return emptyModel(null);

    const groups: DataViewValueColumnGroup[] = cat.values.grouped
        ? cat.values.grouped()
        : [{ values: Array.from(cat.values as unknown as DataViewValueColumn[]) } as DataViewValueColumnGroup];
    const hasBranch = !!cat.values.source?.roles?.branch;
    const find = (g: DataViewValueColumnGroup, role: string) => g.values.find(v => v.source.roles?.[role]);

    // Guard: any measure value that is a guard text blocks the whole view.
    for (const g of groups) {
        for (const v of g.values) {
            for (const x of v.values) if (isGuard(x)) return emptyModel(x);
        }
    }

    const attr = (role: string, i: number): unknown => cols.get(role)?.values[i];
    const rows: KpiRow[] = [];
    let label = "";
    const branches: string[] = [];

    groups.forEach((g, gi) => {
        const branch = hasBranch ? (asStr(g.name) || "(Blank)") : null;
        if (branch !== null) branches.push(branch);
        const payloadCol = find(g, "payload");
        const labelCol = find(g, "selectionLabel");
        for (let i = 0; i < kpiCol.values.length; i++) {
            if (!label && labelCol && labelCol.values[i]) label = asStr(labelCol.values[i]);
            const p = parsePayload(payloadCol ? (payloadCol.values[i] as string | null) : null) as Payload;
            const kpiStatus = asStr(attr("kpiStatus", i));
            const valueSource = asStr(attr("valueSource", i));
            const st = stateOf(p.stateText, kpiStatus, valueSource);
            rows.push({
                code: asStr(attr("kpi", i)),
                name: asStr(attr("kpiName", i)),
                shortLabel: asStr(attr("shortLabel", i)),
                pillar: asStr(attr("pillar", i)),
                pillarOrder: asNum(attr("pillarOrder", i)) ?? 0,
                pillarWeight: asNum(attr("pillarWeight", i)),
                pillarQuestion: asStr(attr("pillarQuestion", i)),
                objectiveCode: asStr(attr("objectiveCode", i)),
                objectiveTitle: asStr(attr("objectiveTitle", i)),
                objectiveOrder: asNum(attr("objectiveOrder", i)) ?? 0,
                primary: asStr(attr("kpiType", i)) === "Primary",
                direction: asStr(attr("direction", i)),
                valueFormat: asStr(attr("valueFormat", i)),
                displayOrder: asNum(attr("displayOrder", i)) ?? 0,
                manual: valueSource === "manual",
                parkedInCatalogue: kpiStatus === "parked",
                owner: asStr(attr("owner", i)),
                actual: p.actual,
                target: p.target,
                variance: p.variance,
                score: p.score,
                weight: p.weight,
                state: st.key,
                stateWord: st.word,
                reason: st.reason,
                trend: p.trend,
                targetTrend: p.targetTrend,
                scoreTrend: p.scoreTrend,
                branch,
                rowIndex: i,
                seriesIndex: hasBranch ? gi : null,
            });
        }
    });

    const byPillar = new Map<string, KpiRow[]>();
    for (const r of rows) {
        const list = byPillar.get(r.pillar);
        if (list) list.push(r); else byPillar.set(r.pillar, [r]);
    }
    const pillars: PillarSummary[] = [];
    for (const [name, list] of byPillar) {
        list.sort((a, b) => (Number(b.primary) - Number(a.primary)) || (a.displayOrder - b.displayOrder) || (a.seriesIndex ?? 0) - (b.seriesIndex ?? 0));
        // counts, score and trend describe the first branch; byBranch carries every branch for the comparison view.
        const firstRows = hasBranch ? list.filter(k => k.seriesIndex === 0) : list;
        const counts = tally(firstRows);
        pillars.push({
            name, order: list[0].pillarOrder, weight: list[0].pillarWeight, question: list[0].pillarQuestion,
            score: pillarScore(firstRows), trend: pillarTrend(firstRows), kpis: list, counts,
            byBranch: branches.map((b, bi) => {
                const br = list.filter(k => k.seriesIndex === bi);
                return { branch: b, score: pillarScore(br), counts: tally(br) };
            }),
        });
    }
    pillars.sort((a, b) => a.order - b.order);

    const first = (role: string, fallback: number) => asNum(cols.get(role)?.values.find(v => v !== null && v !== undefined)) ?? fallback;
    return {
        pillars,
        overallScore: overallScore(pillars),
        overallByBranch: branches.map((b, bi) => ({
            branch: b,
            score: overallScore(pillars.map(p => ({ ...p, score: p.byBranch[bi].score }))),
        })),
        label,
        thresholds: { base: first("scoreBase", 85), slope: first("scoreSlope", 0.6), good: first("goodFrom", 85), watch: first("watchFrom", 70) },
        branches,
        guardMessage: null,
    };
}
