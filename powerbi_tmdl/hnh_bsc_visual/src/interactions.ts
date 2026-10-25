import powerbi from "powerbi-visuals-api";
import VisualTooltipDataItem = powerbi.extensibility.VisualTooltipDataItem;
import ISelectionId = powerbi.visuals.ISelectionId;
import type { KpiRow } from "./model/types";
import { formatValue, formatVariance } from "./model/format";

/** The parts of the host the wiring uses (the real ISelectionManager and ITooltipService satisfy it). */
export interface WireHost {
    selectionManager: {
        select(id: ISelectionId | ISelectionId[], multiSelect?: boolean): PromiseLike<unknown>;
        clear(): PromiseLike<unknown>;
        showContextMenu(id: ISelectionId, position: { x: number; y: number }): void;
        getSelectionIds(): readonly unknown[];
    };
    tooltipService: {
        show(options: powerbi.extensibility.TooltipShowOptions): void;
        hide(options: powerbi.extensibility.TooltipHideOptions): void;
    };
    allowInteractions: boolean;
}

/** Clicks on these are handled by the visual itself (board tab, comparison drill header and breadcrumb, owner card and
 * owner-view toggle), never as selection or clear. */
export const INTERNAL_SELECTOR = "button[data-pillar], button[data-cmp-pillar], button[data-owner-card], button[data-owner-toggle]";

export const selectionKey = (rowIndex: number, seriesIndex: number | null): string => `${rowIndex}:${seriesIndex ?? ""}`;

const DASH = "–";

export function tooltipItems(row: KpiRow): VisualTooltipDataItem[] {
    const has = (v: number | null) => v !== null && v !== undefined && Number.isFinite(v);
    const item = (displayName: string, value: string): VisualTooltipDataItem => ({ displayName, value });
    return [
        item("KPI", row.name || DASH),
        ...(row.branch ? [item("Hospital", row.branch)] : []),
        item("Objective title", row.objectiveTitle || DASH),
        item("Actual", has(row.actual) ? formatValue(row.actual, row.valueFormat) : DASH),
        item("Target", has(row.target) ? formatValue(row.target, row.valueFormat) : DASH),
        item("Variance", has(row.variance) ? formatVariance(row.variance) : DASH),
        item("Score", has(row.score) ? String(Math.round(row.score as number)) : DASH),
        item("State", row.stateWord || DASH),
        item("Owner", row.owner || DASH),
        item("Source", row.manual ? "Manual entry" : "Measure"),
    ];
}

/** Mark the selected tiles and strip cells, and dim the rest while something is selected. */
export function markSelected(root: HTMLElement, ids: Map<string, ISelectionId>, selected: ISelectionId[]): void {
    const cells = root.querySelectorAll<HTMLElement>("[data-key]");
    cells.forEach(c => {
        const id = ids.get(selectionKey(Number(c.dataset.key), c.dataset.series === undefined ? null : Number(c.dataset.series)));
        const on = !!id && selected.some(s => s.equals(id));
        c.classList.toggle("selected", on);
        c.classList.toggle("dimmed", selected.length > 0 && !on);
    });
}

/**
 * Attach click, context-menu, keyboard and hover handling to the root by delegation.
 * Returns a function that removes the handlers (call it before the next render's wire).
 */
export function wire(root: HTMLElement, rows: KpiRow[], ids: Map<string, ISelectionId>, host: WireHost): () => void {
    if (!host.allowInteractions) return () => undefined;
    const sm = host.selectionManager;
    const rowOf = new Map(rows.map(r => [selectionKey(r.rowIndex, r.seriesIndex), r]));
    const keyOf = (c: HTMLElement) => selectionKey(Number(c.dataset.key), c.dataset.series === undefined ? null : Number(c.dataset.series));
    const cellOf = (t: EventTarget | null) => (t instanceof Element ? (t.closest("[data-key]") as HTMLElement | null) : null);
    const cardOf = (t: EventTarget | null) => (t instanceof Element ? (t.closest(".pillar[data-pillar]") as HTMLElement | null) : null);
    const refresh = () => markSelected(root, ids, sm.getSelectionIds() as ISelectionId[]);
    const select = (target: ISelectionId | ISelectionId[], multi: boolean) => { sm.select(target, multi).then(refresh); };
    const pillarIds = (name: string): ISelectionId[] => rows
        .filter(r => r.pillar === name && (r.seriesIndex === null || r.seriesIndex === 0))
        .map(r => ids.get(selectionKey(r.rowIndex, r.seriesIndex)))
        .filter((i): i is ISelectionId => !!i);

    const onClick = (e: MouseEvent) => {
        if (e.target instanceof Element && e.target.closest(INTERNAL_SELECTOR)) return;
        const multi = e.ctrlKey || e.metaKey;
        const cell = cellOf(e.target);
        if (cell) {
            const id = ids.get(keyOf(cell));
            if (id) select(id, multi);
            e.stopPropagation();
            return;
        }
        const card = cardOf(e.target);
        if (card) {
            const list = pillarIds(card.dataset.pillar as string);
            if (list.length) select(list, multi);
            return;
        }
        sm.clear().then(refresh);
    };
    const onContext = (e: MouseEvent) => {
        e.preventDefault();
        const cell = cellOf(e.target);
        const id = cell ? ids.get(keyOf(cell)) : undefined;
        sm.showContextMenu(id ?? ({} as ISelectionId), { x: e.clientX, y: e.clientY });
    };
    const onKey = (e: KeyboardEvent) => {
        const cell = cellOf(e.target);
        const card = cardOf(e.target);
        const holder = cell ?? card;
        if (!holder || (e.target !== holder)) return;
        if (e.key === "ContextMenu" || (e.key === "F10" && e.shiftKey)) {
            const id = cell ? ids.get(keyOf(cell)) : undefined;
            if (!id) return;
            const box = holder.getBoundingClientRect();
            e.preventDefault();
            sm.showContextMenu(id, { x: box.left + 12, y: box.top + 12 });
        } else if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            if (cell) { const id = ids.get(keyOf(cell)); if (id) select(id, e.ctrlKey || e.metaKey); }
            else if (card) { const list = pillarIds(card.dataset.pillar as string); if (list.length) select(list, e.ctrlKey || e.metaKey); }
        }
    };
    const onMove = (e: MouseEvent) => {
        const cell = cellOf(e.target);
        const key = cell ? keyOf(cell) : null;
        const row = key ? rowOf.get(key) : undefined;
        const id = key ? ids.get(key) : undefined;
        if (!row || !id) { host.tooltipService.hide({ immediately: false, isTouchEvent: false }); return; }
        host.tooltipService.show({ dataItems: tooltipItems(row), identities: [id], coordinates: [e.clientX, e.clientY], isTouchEvent: false });
    };
    const onLeave = (e: MouseEvent) => {
        const from = cellOf(e.target);
        if (from && e.relatedTarget instanceof Node && from.contains(e.relatedTarget)) return;
        host.tooltipService.hide({ immediately: false, isTouchEvent: false });
    };

    root.addEventListener("click", onClick);
    root.addEventListener("contextmenu", onContext);
    root.addEventListener("keydown", onKey);
    root.addEventListener("mousemove", onMove);
    root.addEventListener("mouseout", onLeave);
    return () => {
        root.removeEventListener("click", onClick);
        root.removeEventListener("contextmenu", onContext);
        root.removeEventListener("keydown", onKey);
        root.removeEventListener("mousemove", onMove);
        root.removeEventListener("mouseout", onLeave);
    };
}
