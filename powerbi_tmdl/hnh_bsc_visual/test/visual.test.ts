// @vitest-environment jsdom
import { describe, it, expect, vi } from "vitest";
import { Visual } from "../src/visual";
import { makeDataView, payload, FixtureRow } from "./fixtures";

vi.mock("../style/visual.less", () => ({}));

const base = { kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure",
    scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70, objectiveCode: "O1", objectiveTitle: "Grow", objectiveOrder: 1, displayOrder: 1 };
const mk = (code: string, pillar: string, order: number): FixtureRow => ({ ...base, kpi: code, kpiName: code, shortLabel: code, pillar, pillarOrder: order,
    pillarWeight: 0.5, pillarQuestion: "q?", owner: "O", payload: payload({ actual: 0.5, target: 0.5, variance: 0, score: 90, state: "On track", weight: 1 }) });

function setup(opts: { allow?: boolean; hc?: boolean } = {}) {
    const events: string[] = [];
    const built: unknown[][] = [];
    const host = {
        eventService: {
            renderingStarted: () => events.push("started"),
            renderingFinished: () => events.push("finished"),
            renderingFailed: (_o: unknown, m?: string) => events.push("failed:" + m),
        },
        createSelectionManager: () => ({ select: () => Promise.resolve([]), clear: () => Promise.resolve({}), showContextMenu: () => undefined,
            getSelectionIds: () => [], registerOnSelectCallback: () => undefined }),
        createSelectionIdBuilder: () => {
            const rec: unknown[] = [];
            const b = { withCategory: (_c: unknown, i: number) => { rec.push(["cat", i]); return b; },
                withSeries: (_v: unknown, g: unknown) => { rec.push(["series", g]); return b; },
                createSelectionId: () => { built.push(rec); return { equals: () => false }; } };
            return b;
        },
        tooltipService: { show: () => undefined, hide: () => undefined },
        hostCapabilities: { allowInteractions: opts.allow ?? true },
        colorPalette: { isHighContrast: opts.hc ?? false, foreground: { value: "#fff" }, background: { value: "#000" }, foregroundSelected: { value: "#ff0" } },
    };
    const element = document.createElement("div");
    const visual = new Visual({ element, host } as never);
    return { visual, element, events, built };
}
const opts = (dv: unknown, w = 1200, h = 800) => ({ dataViews: dv ? [dv] : [], viewport: { width: w, height: h }, type: 2 }) as never;

describe("Visual", () => {
    it("renders data between started and finished, with an id per row", () => {
        const { visual, element, events, built } = setup();
        visual.update(opts(makeDataView([mk("F1", "Financial", 1), mk("C1", "Customer", 2)])));
        expect(events).toEqual(["started", "finished"]);
        expect(element.querySelectorAll(".pillar").length).toBe(2);
        expect(built.length).toBe(2);
        expect(built[0]).toEqual([["cat", 0]]);
    });
    it("adds the series to the id when branches exist", () => {
        const { visual, built } = setup();
        visual.update(opts(makeDataView([mk("F1", "Financial", 1)], { branches: ["A", "B"] })));
        expect(built.length).toBe(2);
        expect((built[1] as unknown[][])[1][0]).toBe("series");
    });
    it("handles an empty data view", () => {
        const { visual, element, events } = setup();
        visual.update(opts(null));
        expect(events).toEqual(["started", "finished"]);
        expect(element.textContent).toContain("No KPIs");
    });
    it("handles a small viewport", () => {
        const { visual, events } = setup();
        visual.update(opts(makeDataView([mk("F1", "Financial", 1)]), 300, 200));
        expect(events).toEqual(["started", "finished"]);
    });
    it("reports a render error through renderingFailed", () => {
        const { visual, events } = setup();
        const dv = makeDataView([mk("F1", "Financial", 1)]);
        (dv.categorical!.values as unknown as { grouped: () => never }).grouped = () => { throw new Error("boom"); };
        visual.update(opts(dv));
        expect(events).toEqual(["started", "failed:boom"]);
    });
    it("uses the host palette in high-contrast mode", () => {
        const { visual, element } = setup({ hc: true });
        visual.update(opts(makeDataView([mk("F1", "Financial", 1)])));
        expect(element.classList.contains("hc")).toBe(true);
        expect(element.style.getPropertyValue("--hc-fg")).toBe("#fff");
        expect(element.style.getPropertyValue("--hc-sel")).toBe("#ff0");
    });
});
