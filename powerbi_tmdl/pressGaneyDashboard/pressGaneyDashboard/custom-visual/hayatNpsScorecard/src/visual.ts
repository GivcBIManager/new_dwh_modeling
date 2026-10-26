"use strict";

import powerbi from "powerbi-visuals-api";
import { FormattingSettingsService } from "powerbi-visuals-utils-formattingmodel";
import "./../style/visual.less";

import VisualConstructorOptions = powerbi.extensibility.visual.VisualConstructorOptions;
import VisualUpdateOptions = powerbi.extensibility.visual.VisualUpdateOptions;
import IVisual = powerbi.extensibility.visual.IVisual;
import IVisualHost = powerbi.extensibility.visual.IVisualHost;
import IVisualEventService = powerbi.extensibility.IVisualEventService;
import ISelectionManager = powerbi.extensibility.ISelectionManager;
import ISelectionId = powerbi.visuals.ISelectionId;
import ITooltipService = powerbi.extensibility.ITooltipService;
import VisualTooltipDataItem = powerbi.extensibility.VisualTooltipDataItem;
import DataView = powerbi.DataView;
import PrimitiveValue = powerbi.PrimitiveValue;

import { VisualFormattingSettingsModel } from "./settings";

// Hayat Healthcare brand palette (Brand Guidelines, section 05).
const BRAND = {
    darkBlue: "#0A1E32",
    blue: "#0A2D6E",
    middleBlue: "#235F96",
    lightBlue: "#32A5E6",
    turquoise: "#23D2C3",
    darkTurquoise: "#05A591",
    lila: "#A0BEFF",
    lightOrange: "#FFB900",
    orange: "#EF8D00",
    red: "#DC280A",
    white: "#FFFFFF"
};

const SVG_NS = "http://www.w3.org/2000/svg";

interface ScoreCard {
    label: string;
    nps: number | null;
    promoters: number | null;
    passives: number | null;
    detractors: number | null;
    benchmark: number | null;
    volume: number | null;
    margin: number | null;
    selectionId: ISelectionId | null;
}

interface RoleNames {
    nps?: string;
    promoters?: string;
    passives?: string;
    detractors?: string;
    benchmark?: string;
    volume?: string;
    margin?: string;
}

function toNumber(v: PrimitiveValue): number | null {
    if (v === null || v === undefined || v === "") {
        return null;
    }
    const n = Number(v);
    return isFinite(n) ? n : null;
}

// Shares may arrive as fractions (0.83) or percentages (83); normalise to 0-100.
function toPercent(v: number | null): number | null {
    if (v === null) {
        return null;
    }
    return Math.abs(v) <= 1 ? v * 100 : v;
}

function fmtScore(v: number | null): string {
    return v === null ? "–" : v.toFixed(1);
}

function fmtPercent(v: number | null): string {
    return v === null ? "–" : `${v.toFixed(1)}%`;
}

// Same bands as the report's [Reliability] measure: ±3 or better High, up to ±7 Moderate, otherwise Low.
function reliabilityLabel(margin: number): string {
    return margin <= 3 ? "High" : margin <= 7 ? "Moderate" : "Low";
}

function fmtDelta(v: number): string {
    return `${v > 0 ? "+" : ""}${v.toFixed(1)}`;
}

function svg<K extends keyof SVGElementTagNameMap>(tag: K, attrs: Record<string, string | number>): SVGElementTagNameMap[K] {
    const el = document.createElementNS(SVG_NS, tag);
    for (const key of Object.keys(attrs)) {
        el.setAttribute(key, String(attrs[key]));
    }
    return el;
}

function div(className: string, text?: string): HTMLDivElement {
    const el = document.createElement("div");
    el.className = className;
    if (text !== undefined) {
        el.textContent = text;
    }
    return el;
}

export class Visual implements IVisual {
    private host: IVisualHost;
    private events: IVisualEventService;
    private selectionManager: ISelectionManager;
    private tooltipService: ITooltipService;
    private root: HTMLElement;
    private formattingSettings: VisualFormattingSettingsModel;
    private formattingSettingsService: FormattingSettingsService;
    private cards: ScoreCard[] = [];
    private roleNames: RoleNames = {};
    private cardElements: HTMLElement[] = [];
    private gradientSeq = 0;

    constructor(options: VisualConstructorOptions) {
        this.host = options.host;
        this.events = options.host.eventService;
        this.selectionManager = options.host.createSelectionManager();
        this.tooltipService = options.host.tooltipService;
        this.formattingSettingsService = new FormattingSettingsService();

        this.root = div("hayat-root");
        options.element.appendChild(this.root);

        this.root.addEventListener("click", () => {
            if (!this.host.hostCapabilities.allowInteractions) {
                return;
            }
            this.selectionManager.clear().then(() => this.syncSelection([]));
        });
        this.root.addEventListener("contextmenu", (e: MouseEvent) => {
            this.selectionManager.showContextMenu({}, { x: e.clientX, y: e.clientY });
            e.preventDefault();
        });
        this.selectionManager.registerOnSelectCallback((ids: ISelectionId[]) => this.syncSelection(ids));
    }

    public update(options: VisualUpdateOptions) {
        this.events.renderingStarted(options);
        try {
            const dataView: DataView | undefined = options.dataViews && options.dataViews[0];
            this.formattingSettings = this.formattingSettingsService.populateFormattingSettingsModel(VisualFormattingSettingsModel, dataView);
            this.cards = this.parse(dataView);
            this.render(options.viewport.width, options.viewport.height);
            this.events.renderingFinished(options);
        } catch (error) {
            this.events.renderingFailed(options, String(error));
        }
    }

    public getFormattingModel(): powerbi.visuals.FormattingModel {
        return this.formattingSettingsService.buildFormattingModel(this.formattingSettings);
    }

    private parse(dataView: DataView | undefined): ScoreCard[] {
        const categorical = dataView && dataView.categorical;
        if (!categorical || !categorical.values || categorical.values.length === 0) {
            return [];
        }

        const columns: { [role: string]: PrimitiveValue[] } = {};
        this.roleNames = {};
        for (const col of categorical.values) {
            for (const role of Object.keys(col.source.roles || {})) {
                columns[role] = col.values;
                this.roleNames[role as keyof RoleNames] = col.source.displayName;
            }
        }

        const category = categorical.categories && categorical.categories[0];
        const count = category ? category.values.length : 1;
        const pick = (role: string, i: number) => (columns[role] ? toNumber(columns[role][i]) : null);
        const result: ScoreCard[] = [];

        for (let i = 0; i < count; i++) {
            result.push({
                label: category ? String(category.values[i] ?? "(Blank)") : this.formattingSettings.labels.scoreLabel.value,
                nps: pick("nps", i),
                promoters: toPercent(pick("promoters", i)),
                passives: toPercent(pick("passives", i)),
                detractors: toPercent(pick("detractors", i)),
                benchmark: pick("benchmark", i),
                volume: pick("volume", i),
                margin: pick("margin", i),
                selectionId: category
                    ? this.host.createSelectionIdBuilder().withCategory(category, i).createSelectionId()
                    : null
            });
        }
        return result;
    }

    private render(width: number, height: number) {
        this.root.replaceChildren();
        this.cardElements = [];

        const style = this.formattingSettings.cardStyle;
        const mode = String(style.mode.value.value);
        this.root.className = `hayat-root mode-${mode}`;

        if (this.cards.length === 0) {
            const empty = div("hayat-empty");
            empty.appendChild(this.logo(36));
            empty.appendChild(div("hayat-empty-title", "Hayat NPS Scorecard"));
            empty.appendChild(div("hayat-empty-text", "Add an NPS score measure, and optionally a category such as Branch."));
            this.root.appendChild(empty);
            return;
        }

        const gap = 10;
        const minCardWidth = 160;
        const maxCols = Math.max(1, Math.round(style.maxColumns.value));
        const cols = Math.max(1, Math.min(maxCols, this.cards.length, Math.floor((width + gap) / (minCardWidth + gap)) || 1));
        const rows = Math.ceil(this.cards.length / cols);
        const cardW = Math.max(120, (width - gap * (cols - 1)) / cols);
        const cardH = Math.max(120, (height - gap * (rows - 1)) / rows);

        this.root.style.gridTemplateColumns = `repeat(${cols}, ${cardW}px)`;
        this.root.style.gridAutoRows = `${cardH}px`;
        this.root.style.gap = `${gap}px`;
        this.root.style.overflowY = cardH * rows + gap * (rows - 1) > height + 1 ? "auto" : "hidden";

        for (const card of this.cards) {
            const el = this.renderCard(card, cardW, cardH, mode);
            this.root.appendChild(el);
            this.cardElements.push(el);
        }
        this.syncSelection(this.selectionManager.getSelectionIds() as ISelectionId[]);
    }

    private bandColor(v: number | null, mode: string): string {
        const bands = this.formattingSettings.scoreBands;
        if (!bands.colorByBand.value) {
            return mode === "light" ? BRAND.lightBlue : BRAND.white;
        }
        if (v === null) {
            return BRAND.lila;
        }
        if (v >= bands.goodThreshold.value) {
            return mode === "light" ? BRAND.darkTurquoise : BRAND.turquoise;
        }
        if (v >= bands.warningThreshold.value) {
            // Light amber lacks contrast on white cards, so light mode uses the brand orange.
            return mode === "light" ? BRAND.orange : BRAND.lightOrange;
        }
        return mode === "light" ? BRAND.red : BRAND.orange;
    }

    private renderCard(card: ScoreCard, w: number, h: number, mode: string): HTMLElement {
        const style = this.formattingSettings.cardStyle;
        const labels = this.formattingSettings.labels;
        const scale = Math.max(0.7, Math.min(1.6, Math.min(w / 240, h / 220)));
        const color = this.bandColor(card.nps, mode);

        const el = div("hayat-card");
        el.style.borderRadius = `${style.cornerRadius.value}px`;
        el.style.setProperty("--s", String(scale));

        const header = div("hayat-card-header");
        header.appendChild(div("hayat-card-label", card.label));
        if (style.showLogo.value) {
            header.appendChild(this.logo(18 * scale));
        }
        el.appendChild(header);

        el.appendChild(this.gauge(card, color, mode));

        const showSplit = labels.showSplit.value && (card.promoters !== null || card.detractors !== null);
        if (showSplit) {
            el.appendChild(this.splitBar(card));
        }

        const footer = div("hayat-card-footer");
        if (card.benchmark !== null && card.nps !== null) {
            const delta = card.nps - card.benchmark;
            const chip = div(`hayat-chip ${delta >= 0 ? "up" : "down"}`, `${delta >= 0 ? "▲" : "▼"} ${fmtDelta(delta)} ${labels.benchmarkLabel.value}`);
            footer.appendChild(chip);
        }
        if (card.volume !== null || card.margin !== null) {
            const parts: string[] = [];
            if (card.volume !== null) {
                parts.push(`n = ${Math.round(card.volume).toLocaleString("en-US")}`);
            }
            if (card.margin !== null) {
                parts.push(`±${card.margin.toFixed(1)}`);
            }
            footer.appendChild(div("hayat-volume", parts.join("  ·  ")));
        }
        el.appendChild(footer);

        el.addEventListener("click", (e: MouseEvent) => {
            e.stopPropagation();
            if (!card.selectionId || !this.host.hostCapabilities.allowInteractions) {
                return;
            }
            this.selectionManager
                .select(card.selectionId, e.ctrlKey || e.metaKey)
                .then((ids: ISelectionId[]) => this.syncSelection(ids));
        });
        el.addEventListener("contextmenu", (e: MouseEvent) => {
            e.stopPropagation();
            e.preventDefault();
            this.selectionManager.showContextMenu(card.selectionId || {}, { x: e.clientX, y: e.clientY });
        });
        el.addEventListener("mousemove", (e: MouseEvent) => {
            this.tooltipService.show({
                coordinates: [e.clientX, e.clientY],
                isTouchEvent: false,
                dataItems: this.tooltipItems(card),
                identities: card.selectionId ? [card.selectionId] : []
            });
        });
        el.addEventListener("mouseleave", () => this.tooltipService.hide({ isTouchEvent: false, immediately: true }));
        return el;
    }

    private tooltipItems(card: ScoreCard): VisualTooltipDataItem[] {
        const n = this.roleNames;
        const items: VisualTooltipDataItem[] = [{ displayName: n.nps || "NPS", value: fmtScore(card.nps), header: card.label }];
        if (card.benchmark !== null) {
            items.push({ displayName: n.benchmark || "Benchmark", value: fmtScore(card.benchmark) });
        }
        if (card.promoters !== null) {
            items.push({ displayName: n.promoters || "Promoters", value: fmtPercent(card.promoters), color: BRAND.turquoise });
        }
        if (card.passives !== null) {
            items.push({ displayName: n.passives || "Passives", value: fmtPercent(card.passives), color: BRAND.lila });
        }
        if (card.detractors !== null) {
            items.push({ displayName: n.detractors || "Detractors", value: fmtPercent(card.detractors), color: BRAND.orange });
        }
        if (card.volume !== null) {
            items.push({ displayName: n.volume || "Volume", value: Math.round(card.volume).toLocaleString("en-US") });
        }
        if (card.margin !== null) {
            items.push({ displayName: n.margin || "Margin of error", value: `±${card.margin.toFixed(1)} (${reliabilityLabel(card.margin)} reliability)` });
        }
        return items;
    }

    // Semicircular gauge on the NPS scale (-100 .. +100).
    private gauge(card: ScoreCard, color: string, mode: string): HTMLElement {
        const wrap = div("hayat-gauge");
        const W = 200, H = 126, cx = 100, cy = 104, r = 84, stroke = 14;
        const s = svg("svg", { viewBox: `0 0 ${W} ${H}`, preserveAspectRatio: "xMidYMid meet" });

        const pointAt = (value: number, radius: number) => {
            const clamped = Math.max(-100, Math.min(100, value));
            const angle = Math.PI * (1 - (clamped + 100) / 200);
            return { x: cx + radius * Math.cos(angle), y: cy - radius * Math.sin(angle) };
        };
        const arc = (from: number, to: number) => {
            const a = pointAt(from, r), b = pointAt(to, r);
            return `M ${a.x} ${a.y} A ${r} ${r} 0 0 1 ${b.x} ${b.y}`;
        };

        s.appendChild(svg("path", { d: arc(-100, 100), class: "hayat-gauge-track", "stroke-width": stroke, fill: "none", "stroke-linecap": "round" }));

        if (card.nps !== null) {
            s.appendChild(svg("path", { d: arc(-100, card.nps), stroke: color, "stroke-width": stroke, fill: "none", "stroke-linecap": "round" }));
        }

        if (card.benchmark !== null) {
            const inner = pointAt(card.benchmark, r - stroke / 2 - 4), outer = pointAt(card.benchmark, r + stroke / 2 + 4);
            s.appendChild(svg("line", { x1: inner.x, y1: inner.y, x2: outer.x, y2: outer.y, class: "hayat-gauge-benchmark", "stroke-width": 3, "stroke-linecap": "round" }));
        }

        // On the light-blue gradient the band colours lack contrast, so the number stays white there.
        const valueFill = card.nps === null || mode === "blue" ? "currentColor" : color;
        const value = svg("text", { x: cx, y: cy - 14, "text-anchor": "middle", class: "hayat-gauge-value", fill: valueFill });
        value.textContent = fmtScore(card.nps);
        s.appendChild(value);
        const caption = svg("text", { x: cx, y: cy + 8, "text-anchor": "middle", class: "hayat-gauge-caption" });
        caption.textContent = this.formattingSettings.labels.scoreLabel.value;
        s.appendChild(caption);

        for (const tick of [-100, 100]) {
            const p = pointAt(tick, r);
            const t = svg("text", { x: p.x, y: cy + stroke / 2 + 12, "text-anchor": "middle", class: "hayat-gauge-tick" });
            t.textContent = String(tick);
            s.appendChild(t);
        }

        wrap.appendChild(s);
        return wrap;
    }

    private splitBar(card: ScoreCard): HTMLElement {
        const wrap = div("hayat-split");
        const bar = div("hayat-split-bar");
        const parts: Array<[number | null, string, string]> = [
            [card.promoters, "promoters", "P"],
            [card.passives, "passives", "N"],
            [card.detractors, "detractors", "D"]
        ];
        const total = parts.reduce((acc, p) => acc + (p[0] || 0), 0) || 1;
        for (const [v, cls] of parts) {
            if (!v) {
                continue;
            }
            const seg = div(`hayat-seg ${cls}`);
            seg.style.width = `${(v / total) * 100}%`;
            bar.appendChild(seg);
        }
        wrap.appendChild(bar);

        const legend = div("hayat-split-legend");
        legend.appendChild(div("lg promoters", `Promoters ${fmtPercent(card.promoters)}`));
        legend.appendChild(div("lg detractors", `Detractors ${fmtPercent(card.detractors)}`));
        wrap.appendChild(legend);
        return wrap;
    }

    // Simplified Hayat "H" symbol: three DNA-inspired capsules joined to an upright bar.
    private logo(size: number): SVGSVGElement {
        const id = `hayat-mark-${++this.gradientSeq}`;
        const s = svg("svg", { viewBox: "0 0 100 100", width: size, height: size, class: "hayat-mark" });
        const defs = svg("defs", {});
        const grad = svg("linearGradient", { id, x1: "0", y1: "0", x2: "1", y2: "1" });
        grad.appendChild(svg("stop", { offset: "0", "stop-color": "#1A7FC1" }));
        grad.appendChild(svg("stop", { offset: "1", "stop-color": "#1BAEE5" }));
        defs.appendChild(grad);
        s.appendChild(defs);
        const fill = `url(#${id})`;
        s.appendChild(svg("path", { d: "M17 2 H40 Q33 17 40 32 H17 A15 15 0 0 1 17 2 Z", fill }));
        s.appendChild(svg("path", { d: "M28 34 H54 A15 15 0 0 1 54 64 H28 Q35 49 28 34 Z", fill }));
        s.appendChild(svg("path", { d: "M17 66 H40 Q33 81 40 96 H17 A15 15 0 0 1 17 66 Z", fill }));
        s.appendChild(svg("path", { d: "M66 2 H83 A15 15 0 0 1 98 17 V81 A15 15 0 0 1 83 96 H66 Z", fill }));
        return s;
    }

    private syncSelection(ids: ISelectionId[]) {
        const active = ids && ids.length > 0;
        this.cards.forEach((card, i) => {
            const el = this.cardElements[i];
            if (!el) {
                return;
            }
            const selected = active && card.selectionId !== null && ids.some((id) => id.equals(card.selectionId as ISelectionId));
            el.classList.toggle("dimmed", active && !selected);
            el.classList.toggle("selected", !!selected);
        });
    }
}
