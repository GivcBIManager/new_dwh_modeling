import type { KpiRow } from "./types";

/** The model's 'BSC Variance %': positive is better than target. */
export function varianceOf(actual: number, target: number, direction: string): number {
    const diff = direction === "higher" ? actual - target
        : direction === "on_target" ? -Math.abs(actual - target)
        : target - actual;
    return target === 0 ? diff : diff / Math.abs(target);
}

/** The KPI's score by its own thresholds; not clamped. */
export function kpiScoreOf(row: KpiRow, actual: number, target: number): number {
    return Math.round(row.scoreBase + row.scoreSlope * 100 * varianceOf(actual, target, row.direction));
}

export function met(row: KpiRow, actual: number, target: number): boolean {
    return kpiScoreOf(row, actual, target) >= row.goodFrom;
}

/** Actual values where the KPI turns On track (good) and Watch (watch); null when no bands can be drawn. */
export function bandEdges(row: KpiRow, target: number): { kind: "above" | "below" | "around"; good: number; watch: number } | null {
    if (!Number.isFinite(target) || !row.scoreSlope) return null;
    const k = row.scoreSlope * 100;
    const vg = (row.goodFrom - row.scoreBase) / k;
    const vw = (row.watchFrom - row.scoreBase) / k;
    const s = target === 0 ? 1 : Math.abs(target);
    if (row.direction === "higher") return { kind: "above", good: target + vg * s, watch: target + vw * s };
    if (row.direction === "on_target") return { kind: "around", good: Math.max(0, -vg * s), watch: Math.max(0, -vw * s) };
    return { kind: "below", good: target - vg * s, watch: target - vw * s };
}
