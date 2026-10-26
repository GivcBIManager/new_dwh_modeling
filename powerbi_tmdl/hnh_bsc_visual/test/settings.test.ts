// @vitest-environment jsdom
import { describe, it, expect, vi } from "vitest";
import { readOptions } from "../src/visual";
import { VisualSettings, applyColours, readSettings, buildFormattingModel } from "../src/settings";
import { renderView } from "../src/render/index";
import { parseDataView } from "../src/model/parse";
import { makeDataView, payload } from "./fixtures";

vi.mock("../style/visual.less", () => ({}));

const withObjects = (objects: unknown) => ({ metadata: { columns: [], objects } }) as never;

describe("format pane settings", () => {
    it("defaults to the brand values", () => {
        const s = new VisualSettings();
        expect(s.scorecard.mode.value.value).toBe("overview");
        expect(s.scorecard.title.value).toBe("Balanced scorecard");
        expect(s.scorecard.subtitle.value).toBe("How the group is performing against its strategy");
        expect(s.scorecard.showHeader.value).toBe(false);
        const c = s.colours;
        expect([c.headerStart, c.headerMiddle, c.headerEnd, c.data, c.onTrack, c.watch, c.atRisk, c.noData].map(x => x.value.value))
            .toEqual(["#13ACE3", "#1478BE", "#0A1E32", "#32A4E5", "#0E9F8E", "#EF8B00", "#DB280A", "#9AA7B5"]);
    });
    it("defaults the pillar colours to the brand ramp", () => {
        const c = new VisualSettings().colours;
        expect([c.pillar1, c.pillar2, c.pillar3, c.pillar4].map(x => x.value.value)).toEqual(["#002E5A", "#1478BE", "#13ACE3", "#6E8196"]);
    });
    it("offers the detail mode", () => {
        expect(new VisualSettings().scorecard.mode.items.map(i => i.value)).toContain("detail");
    });
    it("offers the modes with readable names", () => {
        expect(new VisualSettings().scorecard.mode.items.map(i => i.displayName)).toEqual(["Overview", "Pillar board", "Owner view", "Hospital comparison", "KPI detail"]);
    });
    it("reads defaults from an empty data view", () => {
        expect(readOptions(undefined).mode).toBe("overview");
        expect(readOptions({ metadata: { columns: [] } } as never).ui.showHeader).toBe(false);
    });
    it("reads the mode and header settings from the data view objects", () => {
        const o = readOptions(withObjects({ scorecard: { mode: "board", title: "Mine", showHeader: false } }));
        expect(o.mode).toBe("board");
        expect(o.ui.title).toBe("Mine");
        expect(o.ui.showHeader).toBe(false);
    });
    it("reads a colour", () => {
        const s = readSettings(withObjects({ colours: { atRisk: { solid: { color: "#112233" } } } }));
        expect(s.colours.atRisk.value.value).toBe("#112233");
    });
    it("applyColours writes the CSS variables", () => {
        const root = document.createElement("div");
        const s = new VisualSettings();
        s.colours.onTrack.value = { value: "#010203" };
        applyColours(root, s);
        expect(root.style.getPropertyValue("--good")).toBe("#010203");
        expect(root.style.getPropertyValue("--p3")).toBe("#13ACE3");
        for (const v of ["--hdr-1", "--hdr-2", "--hdr-3", "--sky", "--warn", "--bad", "--nodata"]) expect(root.style.getPropertyValue(v)).not.toBe("");
    });
    it("applyColours leaves the variables to the stylesheet in high contrast", () => {
        const root = document.createElement("div");
        applyColours(root, new VisualSettings());
        applyColours(root, new VisualSettings(), true);
        expect(root.style.getPropertyValue("--good")).toBe("");
    });
    it("builds a formatting model with both cards", () => {
        expect(buildFormattingModel(new VisualSettings()).cards.map(c => c.displayName)).toEqual(["Scorecard", "Colours"]);
    });
    it("board mode titles the header with the pillar when the title is the default", () => {
        const row = { kpi: "F1", kpiName: "F1", shortLabel: "F1", pillar: "Financial", pillarOrder: 1, pillarWeight: 1, pillarQuestion: "q?", objectiveCode: "O1", objectiveTitle: "G",
            objectiveOrder: 1, kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure", owner: "O", scoreBase: 85, scoreSlope: 0.6,
            goodFrom: 85, watchFrom: 70, displayOrder: 1, payload: payload({ actual: 0.5, target: 0.5, variance: 0, score: 90, state: "On track", weight: 1 }) };
        const vm = parseDataView(makeDataView([row]));
        const root = document.createElement("div");
        const o = readOptions(withObjects({ scorecard: { showHeader: true } }));
        renderView(root, vm, "board", o.ui);
        expect(root.querySelector("h1")?.textContent).toBe("Financial");
        renderView(root, vm, "board", { ...o.ui, title: "Custom" });
        expect(root.querySelector("h1")?.textContent).toBe("Custom");
    });
});
