import type { KpiRow, StateKey } from "../model/types";
import { el } from "./dom";

export const ICON: Record<StateKey, string> = { good: "✓", warn: "!", bad: "▼", nodata: "–", parked: "–", notarget: "–" };

/** CSS class for a state: parked and notarget share the no-data styling. */
export function stateClass(key: StateKey): "good" | "warn" | "bad" | "nodata" {
    return key === "good" || key === "warn" || key === "bad" ? key : "nodata";
}

/** Pill with the state icon, optional text (such as a count) and the state word. */
export function stateChip(key: StateKey, word: string, text?: string): HTMLElement {
    const label = text ? `${ICON[key]} ${text} ${word}` : `${ICON[key]} ${word}`;
    return el("span", { class: `chip ${stateClass(key)}` }, [label]);
}

/** One small square per KPI, coloured by state. */
export function statusStrip(rows: KpiRow[]): HTMLElement {
    const strip = el("div", { class: "strip" });
    for (const k of rows) {
        strip.appendChild(el("i", {
            class: stateClass(k.state), "data-key": k.rowIndex, "data-series": k.seriesIndex,
            role: "img", "aria-label": `${k.name}: ${k.stateWord}`, tabindex: 0,
        }));
    }
    return strip;
}
