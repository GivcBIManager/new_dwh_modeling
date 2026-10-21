import type { StateKey } from "./types";

export function stateOf(stateText: string | null, kpiStatus: string, valueSource: string): { key: StateKey; word: string; reason: string | null } {
    const manual = valueSource === "manual";
    switch (stateText) {
        case "On track": return { key: "good", word: "On track", reason: null };
        case "Watch": return { key: "warn", word: "Watch", reason: null };
        case "At risk": return { key: "bad", word: "At risk", reason: null };
        case "No target": return { key: "notarget", word: "No target", reason: null };
        case "Parked":
            return {
                key: "parked", word: "Parked",
                reason: kpiStatus === "parked" ? "Definition to be agreed" : manual ? "Waiting for the first entry" : "No data in any month",
            };
        default:
            return {
                key: "nodata", word: "No data yet",
                reason: manual ? "Waiting for this month's entry" : "Not yet calculated for this selection",
            };
    }
}
