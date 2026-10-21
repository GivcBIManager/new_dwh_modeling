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
    return score >= t.good ? "good" : score >= t.watch ? "warn" : "bad";
}

export const STATE_WORD: Record<"good" | "warn" | "bad" | "nodata", string> = {
    good: "On track", warn: "Watch", bad: "At risk", nodata: "No data",
};
