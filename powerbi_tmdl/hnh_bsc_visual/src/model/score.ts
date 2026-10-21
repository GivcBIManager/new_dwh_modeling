import type { KpiRow, PillarSummary } from "./types";

/** Weighted mean of scores over items that have a score and weight > 0; null when none. */
function weighted(items: { score: number | null; weight: number | null }[]): number | null {
    let num = 0;
    let den = 0;
    for (const i of items) {
        if (i.score === null || i.score === undefined || i.weight === null || i.weight === undefined || !(i.weight > 0)) continue;
        num += i.score * i.weight;
        den += i.weight;
    }
    return den > 0 ? num / den : null;
}

export function pillarScore(rows: KpiRow[]): number | null {
    return weighted(rows);
}

export function overallScore(pillars: PillarSummary[]): number | null {
    return weighted(pillars);
}

/** Pillar score month by month from each row's score trend. */
export function pillarTrend(rows: KpiRow[]): (number | null)[] {
    const len = rows.reduce((m, r) => Math.max(m, r.scoreTrend.length), 0);
    const out: (number | null)[] = [];
    for (let i = 0; i < len; i++) {
        out.push(weighted(rows.map(r => ({ score: r.scoreTrend[i] ?? null, weight: r.weight }))));
    }
    return out;
}
