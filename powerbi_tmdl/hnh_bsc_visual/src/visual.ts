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
import { boardPillar, objectivesOf } from "./render/board";
import { DEFAULT_OWNER_UI, validPick, type OwnerUi } from "./render/owner";
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
    /** Internal view state, kept across updates: the comparison drill level and the board's objective pick. */
    private pick: { compare: CompareLevel; objective: string | null } = { compare: { ...TOP_LEVEL }, objective: null };
    /** The pillar the objective pick belongs to; a different pillar drops the pick. */
    private objectivePillar: string | null = null;
    /** Owner view toggles and card pick: internal state, kept across updates. */
    private ownerUi: OwnerUi = { ...DEFAULT_OWNER_UI };
    private interactive = true;

    constructor(options: VisualConstructorOptions, private read: typeof readOptions = readOptions) {
        this.root = options.element;
        this.host = options.host;
        this.selectionManager = options.host.createSelectionManager();
        this.selectionManager.registerOnSelectCallback(() => this.refreshSelection());
        // Drill headers, breadcrumb links, owner cards and toggles are buttons: Enter and Space reach this handler as clicks.
        this.root.addEventListener("click", e => this.onInternalClick(e));
        // The objective picker is a native select: a pick arrives as a change, not as a click.
        this.root.addEventListener("change", e => this.onPickerChange(e));
    }

    public update(options: VisualUpdateOptions): void {
        const events = this.host.eventService;
        events.renderingStarted(options);
        try {
            const dv = options.dataViews && options.dataViews[0];
            const opt = this.read(dv);
            this.setUi = opt.ui;
            if (opt.settings) this.settings = opt.settings;
            this.mode = opt.mode;
            this.vm = parseDataView(dv as DataView);
            // A comparison level whose pillar or objective is gone goes back to the top.
            this.pick.compare = levelOf(this.vm, this.pick.compare);
            const samePillar = this.checkObjective(this.vm);
            this.ids = this.buildIds(dv, this.vm);
            this.render(samePillar);
            events.renderingFinished(options);
        } catch (error) {
            this.unwire();
            this.vm = null;
            this.ids = new Map();
            this.root.replaceChildren();
            events.renderingFailed(options, error instanceof Error ? error.message : String(error));
        }
    }

    /** Redraw. With keepScroll the scorecard body stays where it was scrolled (selection changes, plain updates); a
     * new objective pick or pillar starts at the top. */
    private render(keepScroll = true): void {
        if (!this.vm) return;
        const scroll = keepScroll ? this.root.querySelector<HTMLElement>(".bd-tbody")?.scrollTop ?? 0 : 0;
        this.unwire();
        this.interactive = this.host.hostCapabilities?.allowInteractions !== false;
        this.applyPalette();
        applyColours(this.root, this.settings, !!this.host.colorPalette?.isHighContrast);
        // A picked owner whose card is no longer in the strip (data or toggle change) is dropped.
        this.ownerUi.pick = validPick(this.vm, this.ownerUi);
        const selected = this.selectionManager.getSelectionIds() as ISelectionId[];
        const ui: UiState = {
            ...this.setUi, compareLevel: this.pick.compare, objective: this.pick.objective, owner: { ...this.ownerUi },
            selectedKey: this.mode === "board" ? this.singleSelectedKey(selected) : null,
        };
        renderView(this.root, this.vm, this.mode, ui);
        const body = this.root.querySelector<HTMLElement>(".bd-tbody");
        if (body && scroll) body.scrollTop = scroll;
        this.root.classList.toggle("hc", !!this.host.colorPalette?.isHighContrast);
        const picker = this.root.querySelector<HTMLSelectElement>("select[data-objective-picker]");
        if (picker) picker.disabled = !this.interactive;
        const rows = this.vm.pillars.flatMap(p => p.kpis);
        this.unwire = wire(this.root, rows, this.ids, {
            selectionManager: this.selectionManager, tooltipService: this.host.tooltipService, allowInteractions: this.interactive,
            onSelected: () => this.refreshSelection(),
        });
        markSelected(this.root, this.ids, selected);
    }

    /** The key of the one row the host has selected; null when none or several are. */
    private singleSelectedKey(selected: ISelectionId[]): string | null {
        if (selected.length === 0) return null;
        const keys = [...this.ids].filter(([, id]) => selected.some(s => s.equals(id))).map(([k]) => k);
        return keys.length === 1 ? keys[0] : null;
    }

    /** The objective pick belongs to one pillar: a different board pillar, or an objective no longer in the data, drops
     * it. Returns false when the board's pillar changed (its table then starts at the top). */
    private checkObjective(vm: ViewModel): boolean {
        if (this.mode !== "board" || vm.pillars.length === 0) return true;
        const p = boardPillar(vm, this.setUi.pillar);
        const same = p.name === this.objectivePillar;
        if (!same) { this.objectivePillar = p.name; this.pick.objective = null; }
        if (this.pick.objective !== null && !objectivesOf(p).some(([code]) => code === this.pick.objective)) this.pick.objective = null;
        return same;
    }

    /** Re-render, then give keyboard focus back to the successor of the row or picker that had it. */
    private renderKeepingFocus(keepScroll: boolean): void {
        const doc = this.root.ownerDocument;
        const had = doc.activeElement instanceof HTMLElement && this.root.contains(doc.activeElement) ? doc.activeElement : null;
        this.render(keepScroll);
        if (!had) return;
        const next = had.matches("select[data-objective-picker]")
            ? this.root.querySelector<HTMLElement>("select[data-objective-picker]")
            : had.dataset.key === undefined ? null
            : Array.from(this.root.querySelectorAll<HTMLElement>("[data-key]")).find(e => e.dataset.key === had.dataset.key && e.dataset.series === had.dataset.series);
        // The scroll position was restored: focusing must not move it again.
        next?.focus({ preventScroll: true });
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

    /** After a selection change: the board re-renders so its panel follows the selection; other modes re-mark. */
    private refreshSelection(): void {
        if (!this.vm) return;
        if (this.mode === "board") this.renderKeepingFocus(true);
        else markSelected(this.root, this.ids, this.selectionManager.getSelectionIds() as ISelectionId[]);
    }

    /** The board's objective picker: internal view state, never a host selection. */
    private onPickerChange(e: Event): void {
        if (!this.interactive || !this.vm || !(e.target instanceof HTMLSelectElement) || !e.target.matches("select[data-objective-picker]")) return;
        this.pick.objective = e.target.value || null;
        this.renderKeepingFocus(false);
    }

    /** Comparison drill header and breadcrumb, owner card and owner toggle: internal view state, no host selection. */
    private onInternalClick(e: MouseEvent): void {
        if (!this.interactive || !this.vm || !(e.target instanceof Element)) return;
        const hit = e.target.closest(INTERNAL_SELECTOR) as HTMLElement | null;
        if (hit) this.pickFrom(hit);
    }

    private pickFrom(hit: HTMLElement): void {
        if (!this.interactive || !this.vm) return;
        const hadFocus = hit.ownerDocument.activeElement === hit;
        if (hit.dataset.ownerCard !== undefined || hit.dataset.ownerToggle !== undefined) {
            this.pickOwner(hit, hadFocus);
            return;
        }
        if (hit.dataset.cmpPillar !== undefined) {
            const from = this.pick.compare;
            this.pick.compare = levelOf(this.vm, { pillar: hit.dataset.cmpPillar || null, objective: hit.dataset.cmpObjective || null });
            this.render();
            if (hadFocus) this.refocusCompare(from, this.pick.compare);
        }
        // The objective picker reacts to its change event (onPickerChange); a click on it does nothing here.
    }

    /** An owner card picks that owner (a second click clears); a toggle sets its group. Focus follows the re-rendered button. */
    private pickOwner(hit: HTMLElement, hadFocus: boolean): void {
        const card = hit.dataset.ownerCard;
        const group = hit.dataset.ownerToggle;
        const value = hit.dataset.value as string;
        if (card !== undefined) this.ownerUi.pick = this.ownerUi.pick === card ? null : card;
        else if (group === "score") this.ownerUi.score = value === "hitrate" ? "hitrate" : "weighted";
        else if (group === "tier") this.ownerUi.tier = value === "all" ? "all" : "csuite";
        else if (group === "scope") this.ownerUi.scope = value === "co" ? "co" : "owned";
        this.render();
        if (!hadFocus) return;
        const same = Array.from(this.root.querySelectorAll<HTMLElement>("button[data-owner-card], button[data-owner-toggle]"))
            .find(e => card !== undefined ? e.dataset.ownerCard === card : e.dataset.ownerToggle === group && e.dataset.value === value);
        same?.focus();
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
