// @vitest-environment jsdom
import { describe, it, expect, vi } from "vitest";
import { Visual } from "../src/visual";
import { makeDataView, payload, FixtureRow } from "./fixtures";

vi.mock("../style/visual.less", () => ({}));

const base = { kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure",
    scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70, objectiveCode: "O1", objectiveTitle: "Grow", objectiveOrder: 1, displayOrder: 1 };
const mk = (code: string, pillar: string, order: number): FixtureRow => ({ ...base, kpi: code, kpiName: code, shortLabel: code, pillar, pillarOrder: order,
    pillarWeight: 0.5, pillarQuestion: "q?", owner: "O", payload: payload({ actual: 0.5, target: 0.5, variance: 0, score: 90, state: "On track", weight: 1 }) });

import type { Mode, UiState } from "../src/render/index";
type Reader = (dv: unknown) => { mode: Mode; ui: UiState };

function setup(opts: { allow?: boolean; hc?: boolean; read?: Reader } = {}) {
    const selects: unknown[][] = [];
    const events: string[] = [];
    const built: unknown[][] = [];
    const host = {
        eventService: {
            renderingStarted: () => events.push("started"),
            renderingFinished: () => events.push("finished"),
            renderingFailed: (_o: unknown, m?: string) => events.push("failed:" + m),
        },
        createSelectionManager: () => ({ select: (...a: unknown[]) => { selects.push(a); return Promise.resolve([]); }, clear: () => Promise.resolve({}), showContextMenu: () => undefined,
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
    const visual = new Visual({ element, host } as never, opts.read as never);
    return { visual, element, events, built, selects };
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

    it("passes the matching group to withSeries for each row", () => {
        const { visual, built } = setup();
        const dv = makeDataView([mk("F1", "Financial", 1)], { branches: ["A", "B"] });
        visual.update(opts(dv));
        const groups = (dv.categorical!.values as unknown as { grouped: () => unknown[] }).grouped();
        expect((built[0] as unknown[][])[1][1]).toBe(groups[0]);
        expect((built[1] as unknown[][])[1][1]).toBe(groups[1]);
    });

    describe("internal picks", () => {
        const reader = (pillar: string | null): Reader => () => ({
            mode: "board", ui: { pillar, focusBranch: null, title: "Balanced scorecard", subtitle: "s", showHeader: false },
        });
        const two = () => makeDataView([mk("F1", "Financial", 1), mk("C1", "Customer", 2)]);
        const active = (el: HTMLElement) => el.querySelector('.tabs [aria-selected="true"]')!.getAttribute("data-pillar");
        const tab = (el: HTMLElement, name: string) => (el.querySelector(`.tabs [data-pillar="${name}"]`) as HTMLElement).dispatchEvent(new MouseEvent("click", { bubbles: true }));

        it("a tab click re-renders without a host selection and survives a plain update", () => {
            const cur = { p: null as string | null };
            const { visual, element, selects } = setup({ read: (dv) => reader(cur.p)(dv) });
            visual.update(opts(two()));
            expect(active(element)).toBe("Financial");
            tab(element, "Customer");
            expect(active(element)).toBe("Customer");
            expect(selects).toEqual([]);
            visual.update(opts(two()));
            expect(active(element)).toBe("Customer");
        });
        it("a changed setting wins over the pick", () => {
            const cur = { p: null as string | null };
            const { visual, element } = setup({ read: (dv) => reader(cur.p)(dv) });
            visual.update(opts(two()));
            tab(element, "Customer");
            cur.p = "Financial";
            visual.update(opts(two()));
            expect(active(element)).toBe("Financial");
        });
        it("a vanished pillar clears the pick", () => {
            const { visual, element } = setup({ read: reader(null) });
            visual.update(opts(two()));
            tab(element, "Customer");
            visual.update(opts(makeDataView([mk("F1", "Financial", 1), mk("I1", "Internal", 3)])));
            expect(active(element)).toBe("Financial");
            visual.update(opts(two()));
            expect(active(element)).toBe("Financial");
        });
        it("keeps keyboard focus on the picked tab after the re-render", () => {
            const { visual, element } = setup({ read: reader(null) });
            document.body.appendChild(element);
            visual.update(opts(two()));
            const old = element.querySelector('.tabs [data-pillar="Customer"]') as HTMLElement;
            old.focus();
            old.dispatchEvent(new MouseEvent("click", { bubbles: true }));
            const now = element.querySelector('.tabs [data-pillar="Customer"]') as HTMLElement;
            expect(now).not.toBe(old);
            expect(document.activeElement).toBe(now);
            element.remove();
        });
        it("keeps keyboard focus on the picked hospital header after Enter", () => {
            const read: Reader = () => ({ mode: "comparison", ui: { pillar: null, focusBranch: null, title: "t", subtitle: "s", showHeader: false } });
            const { visual, element } = setup({ read });
            document.body.appendChild(element);
            visual.update(opts(makeDataView([mk("F1", "Financial", 1)], { branches: ["A", "B"] })));
            const th = element.querySelector('th[data-branch="B"]') as HTMLElement;
            th.focus();
            th.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Enter" }));
            expect((document.activeElement as HTMLElement).dataset.branch).toBe("B");
            expect(document.activeElement).not.toBe(th);
            element.remove();
        });
        it("does not take focus after a mouse pick on an unfocused element", () => {
            const { visual, element } = setup({ read: reader(null) });
            document.body.appendChild(element);
            visual.update(opts(two()));
            (document.activeElement as HTMLElement | null)?.blur();
            tab(element, "Customer");
            expect(document.activeElement).toBe(document.body);
            element.remove();
        });
        it("hospital headers are focusable and Enter picks the hospital", () => {
            const read: Reader = () => ({ mode: "comparison", ui: { pillar: null, focusBranch: null, title: "t", subtitle: "s", showHeader: false } });
            const { visual, element } = setup({ read });
            visual.update(opts(makeDataView([mk("F1", "Financial", 1)], { branches: ["A", "B"] })));
            const th = element.querySelector('th[data-branch="B"]') as HTMLElement;
            expect(th.getAttribute("tabindex")).toBe("0");
            th.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Enter" }));
            expect(element.querySelector("th.focus")!.getAttribute("data-branch")).toBe("B");
        });
    });

    it("clears the view and unwires after a render error", () => {
        const { visual, element, events } = setup();
        visual.update(opts(makeDataView([mk("F1", "Financial", 1)])));
        const bad = makeDataView([mk("F1", "Financial", 1)]);
        (bad.categorical!.values as unknown as { grouped: () => never }).grouped = () => { throw new Error("x"); };
        visual.update(opts(bad));
        expect(events.at(-1)).toBe("failed:x");
        expect(element.children.length).toBe(0);
    });
});
