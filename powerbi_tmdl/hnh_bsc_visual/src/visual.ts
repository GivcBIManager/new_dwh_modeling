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
import { levelOf, TOP_LEVEL, type CompareLevel } from "./render/comparison";
import { applyColours, buildFormattingModel, readSettings, toOptions, VisualSettings } from "./settings";
import { INTERNAL_SELECTOR, markSelected, selectionKey, wire } from "./interactions";

/** Mode, header state and (when read from the format pane) the full settings. Tests may supply a reader without settings. */
export interface Options { mode: Mode; ui: UiState; settings?: VisualSettings }

export function readOptions(dataView: DataView | undefined): Options {
    const settings = readSettings(dataView);
    return { ...toOptions(settings), settings };
}

export class Visual implements IVisual {
    private root: HTMLElement;
    private host: IVisualHost;
    private selectionManager: ISelectionManager;
    private unwire: () => void = () => undefined;
    private ids = new Map<string, ISelectionId>();
    private vm: ViewModel | null = null;
    private mode: Mode = "overview";
    private setUi: UiState = toOptions(new VisualSettings()).ui;
    private settings: VisualSettings = new VisualSettings();
    private pick: { pillar: string | null; compare: CompareLevel } = { pillar: null, compare: { ...TOP_LEVEL } };
    private interactive = true;

    constructor(options: VisualConstructorOptions, private read: typeof readOptions = readOptions) {
        this.root = options.element;
        this.host = options.host;
        this.selectionManager = options.host.createSelectionManager();
        this.selectionManager.registerOnSelectCallback(() => this.refreshSelection());
        // Tabs, drill headers and breadcrumb links are buttons: Enter and Space reach this handler as clicks.
        this.root.addEventListener("click", e => this.onInternalClick(e));
    }

    public update(options: VisualUpdateOptions): void {
        const events = this.host.eventService;
        events.renderingStarted(options);
        try {
            const dv = options.dataViews && options.dataViews[0];
            const opt = this.read(dv);
            // A changed setting wins over an earlier tab or hospital click.
            if (opt.ui.pillar !== this.setUi.pillar) this.pick.pillar = null;
            this.setUi = opt.ui;
            if (opt.settings) this.settings = opt.settings;
            this.mode = opt.mode;
            this.vm = parseDataView(dv as DataView);
            if (this.pick.pillar !== null && !this.vm.pillars.some(p => p.name === this.pick.pillar)) this.pick.pillar = null;
            // A comparison level whose pillar or objective is gone goes back to the top.
            this.pick.compare = levelOf(this.vm, this.pick.compare);
            this.ids = this.buildIds(dv, this.vm);
            this.render();
            events.renderingFinished(options);
        } catch (error) {
            this.unwire();
            this.vm = null;
            this.ids = new Map();
            this.root.replaceChildren();
            events.renderingFailed(options, error instanceof Error ? error.message : String(error));
        }
    }

    private render(): void {
        if (!this.vm) return;
        this.unwire();
        this.interactive = this.host.hostCapabilities?.allowInteractions !== false;
        this.applyPalette();
        applyColours(this.root, this.settings, !!this.host.colorPalette?.isHighContrast);
        const ui: UiState = { ...this.setUi, pillar: this.pick.pillar ?? this.setUi.pillar, compareLevel: this.pick.compare };
        renderView(this.root, this.vm, this.mode, ui);
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

    public getFormattingModel(): powerbi.visuals.FormattingModel {
        return buildFormattingModel(this.settings);
    }

    private refreshSelection(): void {
        markSelected(this.root, this.ids, this.selectionManager.getSelectionIds() as ISelectionId[]);
    }

    /** Board tab, comparison drill header and breadcrumb: internal view state, no host selection. */
    private onInternalClick(e: MouseEvent): void {
        if (!this.interactive || !this.vm || !(e.target instanceof Element)) return;
        const hit = e.target.closest(INTERNAL_SELECTOR) as HTMLElement | null;
        if (hit) this.pickFrom(hit);
    }

    private pickFrom(hit: HTMLElement): void {
        if (!this.interactive || !this.vm) return;
        const hadFocus = hit.ownerDocument.activeElement === hit;
        if (hit.dataset.cmpPillar !== undefined) {
            const from = this.pick.compare;
            this.pick.compare = levelOf(this.vm, { pillar: hit.dataset.cmpPillar || null, objective: hit.dataset.cmpObjective || null });
            this.render();
            if (hadFocus) this.refocusCompare(from, this.pick.compare);
            return;
        }
        const value = hit.dataset.pillar as string;
        this.pick.pillar = value;
        this.render();
        // The re-render replaced the tab: give focus back to its successor, so keyboard users keep their place.
        if (hadFocus) {
            const same = Array.from(this.root.querySelectorAll<HTMLElement>("button[data-pillar]")).find(e => e.dataset.pillar === value);
            same?.focus();
        }
    }

    /** After a keyboard drill: down lands on the breadcrumb's last link (the way back); up lands on the header drilled from. */
    private refocusCompare(from: CompareLevel, to: CompareLevel): void {
        const depth = (l: CompareLevel) => (l.pillar === null ? 0 : l.objective === null ? 1 : 2);
        const crumbs = Array.from(this.root.querySelectorAll<HTMLElement>(".crumbs button"));
        const heads = Array.from(this.root.querySelectorAll<HTMLElement>("thead button[data-cmp-pillar]"));
        const at = (p: string | null, o: string | null) => heads.find(h => h.dataset.cmpPillar === (p ?? "") && h.dataset.cmpObjective === (o ?? ""));
        const target = depth(to) > depth(from) ? crumbs[crumbs.length - 1]
            : at(from.pillar, from.objective) ?? at(from.pillar, null) ?? heads[0] ?? crumbs[0];
        target?.focus();
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
