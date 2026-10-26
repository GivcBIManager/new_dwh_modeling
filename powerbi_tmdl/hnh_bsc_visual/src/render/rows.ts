import type { KpiRow, PillarSummary, StateKey, ViewModel } from "../model/types";

/** The rows a single-hospital view shows: the first branch series, or every row when there is no series. */
export function firstRows(p: PillarSummary): KpiRow[] {
    return p.kpis.filter(k => k.seriesIndex === null || k.seriesIndex === 0);
}

export function allFirstRows(vm: ViewModel): KpiRow[] {
    return vm.pillars.flatMap(firstRows);
}

/** Score-to-state, using the visual's thresholds. */
export function scoreState(score: number | null, t: ViewModel["thresholds"]): StateKey {
    if (score === null || !Number.isFinite(score)) return "nodata";
    const shown = Math.round(score);
    return shown >= t.good ? "good" : shown >= t.watch ? "warn" : "bad";
}

/** The four status groups: No data stands for No data yet, Parked and No target together. */
export type Group = "good" | "warn" | "bad" | "nodata";
export const GROUPS: Group[] = ["good", "warn", "bad", "nodata"];
/** Words of a group, as in the status counts and distributions. */
export const GROUP_WORD: Record<Group, string> = { good: "On track", warn: "Watch", bad: "At risk", nodata: "No data" };
/** Chip words for a score's state; a missing score is "No data yet", as the model says it. */
export const SCORE_WORD: Record<Group, string> = { good: "On track", warn: "Watch", bad: "At risk", nodata: "No data yet" };
/** The state word of a score's class (the same words as the groups). */
export const STATE_WORD: Record<Group, string> = GROUP_WORD;

/** The target's comparison sign: at least (higher), about (on_target), at most (lower and ceiling). */
export function comparator(direction: string): string {
    return direction === "higher" ? "≥" : direction === "on_target" ? "≈" : "≤";
}
