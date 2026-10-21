"use strict";

import powerbi from "powerbi-visuals-api";
import IVisual = powerbi.extensibility.visual.IVisual;
import IVisualHost = powerbi.extensibility.visual.IVisualHost;
import ISelectionId = powerbi.visuals.ISelectionId;
import ISelectionManager = powerbi.extensibility.ISelectionManager;
import VisualConstructorOptions = powerbi.extensibility.visual.VisualConstructorOptions;
import VisualUpdateOptions = powerbi.extensibility.visual.VisualUpdateOptions;
import DataView = powerbi.DataView;
import "./../style/visual.less";

import type { ViewModel } from "./model/types";
import { parseDataView } from "./model/parse";
import { renderView, type Mode, type UiState } from "./render/index";
import { INTERNAL_SELECTOR, markSelected, selectionKey, wire } from "./interactions";

/** Task 7 replaces this with the format-pane settings. */
export function readOptions(_dataView: DataView | undefined): { mode: Mode; ui: UiState } {
    return {
        mode: "overview",
        ui: { pillar: null, focusBranch: null, title: "Balanced scorecard", subtitle: "How the group is performing against its strategy", showHeader: true },
    };
}

export class Visual implements IVisual {
    private root: HTMLElement;
    private host: IVisualHost;
    private selectionManager: ISelectionManager;
    private unwire: () => void = () => undefined;
    private ids = new Map<string, ISelectionId>();
    private vm: ViewModel | null = null;
    private mode: Mode = "overview";
    private ui: UiState = readOptions(undefined).ui;
    private interactive = true;

    constructor(options: VisualConstructorOptions) {
        this.root = options.element;
        this.host = options.host;
        this.selectionManager = options.host.createSelectionManager();
        this.selectionManager.registerOnSelectCallback(() => this.refreshSelection());
        this.root.addEventListener("click", e => this.onInternalClick(e));
    }

    public update(options: VisualUpdateOptions): void {
        const events = this.host.eventService;
        events.renderingStarted(options);
        try {
            const dv = options.dataViews && options.dataViews[0];
            const opt = readOptions(dv);
            // A changed pillar or hospital choice from the settings wins; internal clicks keep their pick until then.
            this.mode = opt.mode;
            this.ui = { ...opt.ui, pillar: this.ui.pillar ?? opt.ui.pillar, focusBranch: this.ui.focusBranch ?? opt.ui.focusBranch };
            this.vm = parseDataView(dv as DataView);
            this.ids = this.buildIds(dv, this.vm);
            this.render();
            events.renderingFinished(options);
        } catch (error) {
            this.root.replaceChildren();
            events.renderingFailed(options, error instanceof Error ? error.message : String(error));
        }
    }

    private render(): void {
        if (!this.vm) return;
        this.unwire();
        this.interactive = this.host.hostCapabilities?.allowInteractions !== false;
        this.applyPalette();
        renderView(this.root, this.vm, this.mode, this.ui);
        this.root.classList.toggle("hc", !!this.host.colorPalette?.isHighContrast);
        const rows = this.vm.pillars.flatMap(p => p.kpis);
        this.unwire = wire(this.root, rows, this.ids, {
            selectionManager: this.selectionManager, tooltipService: this.host.tooltipService, allowInteractions: this.interactive,
        });
        this.refreshSelection();
    }

    private applyPalette(): void {
        const p = this.host.colorPalette;
        const on = !!p?.isHighContrast;
        const set = (name: string, v: string | undefined) => { if (on && v) this.root.style.setProperty(name, v); else this.root.style.removeProperty(name); };
        set("--hc-fg", p?.foreground?.value);
        set("--hc-bg", p?.background?.value);
        set("--hc-sel", p?.foregroundSelected?.value);
    }

    private refreshSelection(): void {
        markSelected(this.root, this.ids, this.selectionManager.getSelectionIds() as ISelectionId[]);
    }

    /** Board tab and comparison hospital header: internal view state, no host selection. */
    private onInternalClick(e: MouseEvent): void {
        if (!this.interactive || !this.vm || !(e.target instanceof Element)) return;
        const hit = e.target.closest(INTERNAL_SELECTOR) as HTMLElement | null;
        if (!hit) return;
        if (hit.dataset.pillar !== undefined) this.ui = { ...this.ui, pillar: hit.dataset.pillar };
        else if (hit.dataset.branch !== undefined) this.ui = { ...this.ui, focusBranch: hit.dataset.branch };
        this.render();
    }

    /** One selection id per row: the KPI category, plus the branch series when there is one with a name. */
    private buildIds(dv: DataView | undefined, vm: ViewModel): Map<string, ISelectionId> {
        const ids = new Map<string, ISelectionId>();
        const cat = dv?.categorical?.categories?.find(c => c.source.roles?.kpi);
        const values = dv?.categorical?.values;
        if (!cat || !values) return ids;
        const groups = values.grouped ? values.grouped() : [];
        for (const r of vm.pillars.flatMap(p => p.kpis)) {
            const builder = this.host.createSelectionIdBuilder().withCategory(cat, r.rowIndex);
            const group = r.seriesIndex === null ? undefined : groups[r.seriesIndex];
            if (group && group.name !== undefined && group.name !== null) builder.withSeries(values, group);
            ids.set(selectionKey(r.rowIndex, r.seriesIndex), builder.createSelectionId());
        }
        return ids;
    }
}
