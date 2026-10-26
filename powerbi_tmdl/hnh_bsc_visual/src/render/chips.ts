import type { KpiRow, StateKey } from "../model/types";
import { el } from "./dom";

export const ICON: Record<StateKey, string> = { good: "✓", warn: "!", bad: "▼", nodata: "–", parked: "–", notarget: "–" };

/** CSS class for a state: parked and notarget share the no-data styling. */
export function stateClass(key: StateKey): "good" | "warn" | "bad" | "nodata" {
    return key === "good" || key === "warn" || key === "bad" ? key : "nodata";
}

/** The state's shape, drawn by CSS: circle on track, diamond watch, square at risk, dash for no score. */
export function stateMark(key: StateKey): HTMLElement {
    return el("span", { class: `mark ${stateClass(key)}`, "aria-hidden": "true" });
}

/** Pill with the state mark, optional text (such as a count) and the state word. */
export function stateChip(key: StateKey, word: string, text?: string): HTMLElement {
    return el("span", { class: `chip ${stateClass(key)}` }, [stateMark(key), text ? `${text} ${word}` : word]);
}

/** CSS colour for a pillar by its order (1-4); other orders use the brand blue. */
export function pillarColourVar(order: number): string {
    return order >= 1 && order <= 4 && Number.isInteger(order) ? `var(--p${order})` : "var(--blue-dk)";
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
