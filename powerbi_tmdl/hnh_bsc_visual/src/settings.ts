"use strict";

import powerbi from "powerbi-visuals-api";
import { formattingSettings, FormattingSettingsService } from "powerbi-visuals-utils-formattingmodel";
import DataView = powerbi.DataView;
import type { Mode, UiState } from "./render/index";
import { DEFAULT_TITLE } from "./render/header";

import Card = formattingSettings.SimpleCard;
import Slice = formattingSettings.Slice;

export const DEFAULT_SUBTITLE = "How the group is performing against its strategy";

const MODES: { value: Mode; displayName: string }[] = [
    { value: "overview", displayName: "Overview" },
    { value: "board", displayName: "Pillar board" },
    { value: "owner", displayName: "Owner view" },
    { value: "comparison", displayName: "Hospital comparison" },
    { value: "detail", displayName: "KPI detail" },
];

const colour = (name: string, displayName: string, value: string) =>
    new formattingSettings.ColorPicker({ name, displayName, value: { value } });

class ScorecardCard extends Card {
    mode = new formattingSettings.ItemDropdown({ name: "mode", displayName: "View", items: MODES, value: MODES[0] });
    title = new formattingSettings.TextInput({ name: "title", displayName: "Title", value: DEFAULT_TITLE, placeholder: DEFAULT_TITLE });
    subtitle = new formattingSettings.TextInput({ name: "subtitle", displayName: "Subtitle", value: DEFAULT_SUBTITLE, placeholder: DEFAULT_SUBTITLE });
    showHeader = new formattingSettings.ToggleSwitch({ name: "showHeader", displayName: "Show header", value: false });
    name = "scorecard";
    displayName = "Scorecard";
    slices: Slice[] = [this.mode, this.title, this.subtitle, this.showHeader];
}

class ColoursCard extends Card {
    headerStart = colour("headerStart", "Header start", "#13ACE3");
    headerMiddle = colour("headerMiddle", "Header middle", "#1478BE");
    headerEnd = colour("headerEnd", "Header end", "#0A1E32");
    data = colour("data", "Data", "#32A4E5");
    onTrack = colour("onTrack", "On track", "#0E9F8E");
    watch = colour("watch", "Watch", "#EF8B00");
    atRisk = colour("atRisk", "At risk", "#DB280A");
    noData = colour("noData", "No data", "#9AA7B5");
    pillar1 = colour("pillar1", "Pillar 1", "#002E5A");
    pillar2 = colour("pillar2", "Pillar 2", "#1478BE");
    pillar3 = colour("pillar3", "Pillar 3", "#13ACE3");
    pillar4 = colour("pillar4", "Pillar 4", "#6E8196");
    name = "colours";
    displayName = "Colours";
    slices: Slice[] = [this.headerStart, this.headerMiddle, this.headerEnd, this.data, this.onTrack, this.watch, this.atRisk, this.noData, this.pillar1, this.pillar2, this.pillar3, this.pillar4];
}

export class VisualSettings extends formattingSettings.Model {
    scorecard = new ScorecardCard();
    colours = new ColoursCard();
    cards = [this.scorecard, this.colours];
}

const service = new FormattingSettingsService();

export function readSettings(dataView: DataView | undefined): VisualSettings {
    return service.populateFormattingSettingsModel(VisualSettings, dataView);
}

export function buildFormattingModel(settings: VisualSettings): powerbi.visuals.FormattingModel {
    return service.buildFormattingModel(settings);
}

/** The mode and header state the settings choose. The board pillar and the comparison level come from the visual's own picks. */
export function toOptions(s: VisualSettings): { mode: Mode; ui: UiState } {
    const c = s.scorecard;
    return {
        mode: (c.mode.value.value as Mode) ?? "overview",
        ui: { pillar: null, compareLevel: { pillar: null, objective: null }, objective: null, title: c.title.value, subtitle: c.subtitle.value, showHeader: c.showHeader.value },
    };
}

const VARS: [keyof ColoursCard, string][] = [
    ["headerStart", "--hdr-1"], ["headerMiddle", "--hdr-2"], ["headerEnd", "--hdr-3"], ["data", "--sky"],
    ["onTrack", "--good"], ["watch", "--warn"], ["atRisk", "--bad"], ["noData", "--nodata"],
    ["pillar1", "--p1"], ["pillar2", "--p2"], ["pillar3", "--p3"], ["pillar4", "--p4"],
];

/** Write the colour settings as CSS variables on the visual root. In high contrast the host palette wins. */
export function applyColours(root: HTMLElement, s: VisualSettings, highContrast = false): void {
    for (const [key, cssVar] of VARS) {
        const picker = s.colours[key] as formattingSettings.ColorPicker;
        // An inline variable would beat the .hc stylesheet rules, so high contrast clears them.
        if (highContrast) root.style.removeProperty(cssVar);
        else root.style.setProperty(cssVar, picker.value.value);
    }
}
