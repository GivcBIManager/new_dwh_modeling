"use strict";

import { formattingSettings } from "powerbi-visuals-utils-formattingmodel";

import FormattingSettingsCard = formattingSettings.SimpleCard;
import FormattingSettingsSlice = formattingSettings.Slice;
import FormattingSettingsModel = formattingSettings.Model;

const modeItems = [
    { value: "dark", displayName: "Dark blue gradient" },
    { value: "light", displayName: "Light (white)" },
    { value: "blue", displayName: "Light blue gradient" }
];

class CardStyleSettings extends FormattingSettingsCard {
    mode = new formattingSettings.ItemDropdown({
        name: "mode",
        displayName: "Card style",
        items: modeItems,
        value: modeItems[0]
    });

    showLogo = new formattingSettings.ToggleSwitch({
        name: "showLogo",
        displayName: "Show Hayat mark",
        value: true
    });

    cornerRadius = new formattingSettings.NumUpDown({
        name: "cornerRadius",
        displayName: "Corner radius",
        value: 14
    });

    maxColumns = new formattingSettings.NumUpDown({
        name: "maxColumns",
        displayName: "Max cards per row",
        value: 4
    });

    name: string = "cardStyle";
    displayName: string = "Card style";
    slices: Array<FormattingSettingsSlice> = [this.mode, this.showLogo, this.cornerRadius, this.maxColumns];
}

class ScoreBandSettings extends FormattingSettingsCard {
    goodThreshold = new formattingSettings.NumUpDown({
        name: "goodThreshold",
        displayName: "Good from",
        value: 70
    });

    warningThreshold = new formattingSettings.NumUpDown({
        name: "warningThreshold",
        displayName: "Watch from",
        value: 50
    });

    colorByBand = new formattingSettings.ToggleSwitch({
        name: "colorByBand",
        displayName: "Color gauge by band",
        value: true
    });

    name: string = "scoreBands";
    displayName: string = "Score bands";
    slices: Array<FormattingSettingsSlice> = [this.goodThreshold, this.warningThreshold, this.colorByBand];
}

class LabelSettings extends FormattingSettingsCard {
    scoreLabel = new formattingSettings.TextInput({
        name: "scoreLabel",
        displayName: "Score label",
        placeholder: "NPS",
        value: "NPS"
    });

    benchmarkLabel = new formattingSettings.TextInput({
        name: "benchmarkLabel",
        displayName: "Benchmark label",
        placeholder: "vs network",
        value: "vs network"
    });

    showSplit = new formattingSettings.ToggleSwitch({
        name: "showSplit",
        displayName: "Show promoter split",
        value: true
    });

    name: string = "labels";
    displayName: string = "Labels";
    slices: Array<FormattingSettingsSlice> = [this.scoreLabel, this.benchmarkLabel, this.showSplit];
}

export class VisualFormattingSettingsModel extends FormattingSettingsModel {
    cardStyle = new CardStyleSettings();
    scoreBands = new ScoreBandSettings();
    labels = new LabelSettings();

    cards = [this.cardStyle, this.scoreBands, this.labels];
}
