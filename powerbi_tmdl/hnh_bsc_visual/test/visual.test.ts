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
            mode: "board", ui: { pillar, compareLevel: { pillar: null, objective: null }, title: "Balanced scorecard", subtitle: "s", showHeader: false },
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
        it("does not take focus after a mouse pick on an unfocused element", () => {
            const { visual, element } = setup({ read: reader(null) });
            document.body.appendChild(element);
            visual.update(opts(two()));
            (document.activeElement as HTMLElement | null)?.blur();
            tab(element, "Customer");
            expect(document.activeElement).toBe(document.body);
            element.remove();
        });
    });

    describe("comparison drill (Pillar > Objective > KPI)", () => {
        const cmp: Reader = () => ({ mode: "comparison", ui: { pillar: null, compareLevel: { pillar: null, objective: null }, title: "t", subtitle: "s", showHeader: false } });
        const row = (code: string, pillar: string, order: number, obj: string, scores: number[]): FixtureRow => ({ ...mk(code, pillar, order), objectiveCode: obj, objectiveTitle: obj + " title",
            payload: scores.map(v => payload({ actual: 0.5, target: 0.5, variance: 0, score: v, state: v >= 85 ? "On track" : "Watch", weight: 1 })) });
        const full = () => makeDataView([row("F1", "Financial", 1, "FO1", [90, 70]), row("F2", "Financial", 1, "FO2", [80, 95]), row("C1", "Customer", 2, "CO1", [88, 72])], { branches: ["A", "B"] });
        const lead = (el: HTMLElement) => el.querySelectorAll("thead th")[2].textContent;
        const click = (el: HTMLElement, sel: string) => (el.querySelector(sel) as HTMLElement).dispatchEvent(new MouseEvent("click", { bubbles: true }));

        it("a pillar header drills to its objectives, an objective header to its KPIs, without a host selection", () => {
            const { visual, element, selects } = setup({ read: cmp });
            visual.update(opts(full()));
            expect(lead(element)).toBe("Overall");
            click(element, 'thead button[data-cmp-pillar="Financial"]');
            expect(lead(element)).toBe("Financial");
            click(element, 'thead button[data-cmp-objective="FO2"]');
            expect(lead(element)).toBe("FO2 · FO2 title");
            expect(element.querySelectorAll("tbody td[data-key]").length).toBe(2);
            expect(selects).toEqual([]);
        });
        it("the breadcrumb goes back up a level or to the top", () => {
            const { visual, element } = setup({ read: cmp });
            visual.update(opts(full()));
            click(element, 'thead button[data-cmp-pillar="Financial"]');
            click(element, 'thead button[data-cmp-objective="FO1"]');
            click(element, '.crumbs button[data-cmp-pillar="Financial"]');
            expect(lead(element)).toBe("Financial");
            click(element, 'thead button[data-cmp-objective="FO1"]');
            click(element, '.crumbs button[data-cmp-pillar=""]');
            expect(lead(element)).toBe("Overall");
        });
        it("keeps the level across updates", () => {
            const { visual, element } = setup({ read: cmp });
            visual.update(opts(full()));
            click(element, 'thead button[data-cmp-pillar="Financial"]');
            click(element, 'thead button[data-cmp-objective="FO1"]');
            visual.update(opts(full()));
            expect(lead(element)).toBe("FO1 · FO1 title");
        });
        it("goes back to the top when the picked objective disappears", () => {
            const { visual, element } = setup({ read: cmp });
            visual.update(opts(full()));
            click(element, 'thead button[data-cmp-pillar="Financial"]');
            click(element, 'thead button[data-cmp-objective="FO2"]');
            visual.update(opts(makeDataView([row("F1", "Financial", 1, "FO1", [90, 70]), row("C1", "Customer", 2, "CO1", [88, 72])], { branches: ["A", "B"] })));
            expect(lead(element)).toBe("Overall");
            visual.update(opts(full()));
            expect(lead(element)).toBe("Overall");
        });
        it("goes back to the top when the picked pillar disappears", () => {
            const { visual, element } = setup({ read: cmp });
            visual.update(opts(full()));
            click(element, 'thead button[data-cmp-pillar="Customer"]');
            visual.update(opts(makeDataView([row("F1", "Financial", 1, "FO1", [90, 70])], { branches: ["A", "B"] })));
            expect(lead(element)).toBe("Overall");
        });
        it("keyboard: a drill puts focus on the breadcrumb's last link; going up puts it back on the header drilled from", () => {
            const { visual, element } = setup({ read: cmp });
            document.body.appendChild(element);
            visual.update(opts(full()));
            const head = element.querySelector('thead button[data-cmp-pillar="Financial"]') as HTMLButtonElement;
            expect(head.tagName).toBe("BUTTON");
            head.focus();
            head.click();
            expect((document.activeElement as HTMLElement).closest(".crumbs")).not.toBeNull();
            expect(document.activeElement!.textContent).toBe("All pillars");
            (document.activeElement as HTMLElement).click();
            expect(lead(element)).toBe("Overall");
            expect((document.activeElement as HTMLElement).dataset.cmpPillar).toBe("Financial");
            expect(document.activeElement!.closest("thead")).not.toBeNull();
            element.remove();
        });
        it("a mouse drill on an unfocused header does not take focus", () => {
            const { visual, element } = setup({ read: cmp });
            document.body.appendChild(element);
            visual.update(opts(full()));
            (document.activeElement as HTMLElement | null)?.blur();
            click(element, 'thead button[data-cmp-pillar="Financial"]');
            expect(document.activeElement).toBe(document.body);
            element.remove();
        });
        it("ignores drill clicks when the host does not allow interactions", () => {
            const { visual, element } = setup({ read: cmp, allow: false });
            visual.update(opts(full()));
            click(element, 'thead button[data-cmp-pillar="Financial"]');
            expect(lead(element)).toBe("Overall");
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
    describe("scores-only payload (the landing page binds [BSC Visual Payload Scores])", () => {
        const scoresOnly = (p: string) => p.split("|").slice(0, 6).join("|") + "|||";
        const rows = (): FixtureRow[] => [mk("F1", "Financial", 1), mk("C1", "Customer", 2)].map(r => ({ ...r, payload: scoresOnly(r.payload as string) }));
        const withTrends = (): FixtureRow[] => [mk("F1", "Financial", 1), mk("C1", "Customer", 2)].map(r => ({ ...r,
            payload: payload({ actual: 0.5, target: 0.5, variance: 0, score: 90, state: "On track", weight: 1, trend: [0.4, 0.5], targetTrend: [0.5, 0.5], scoreTrend: [80, 90] }) }));
        const view = (mode: Mode): Reader => () => ({ mode, ui: { pillar: null, compareLevel: { pillar: null, objective: null }, title: "t", subtitle: "s", showHeader: false } });

        it("the overview pillar card has no trend block, caption or sparkline", () => {
            const { visual, element } = setup({ read: view("overview") });
            visual.update(opts(makeDataView(rows())));
            expect(element.querySelectorAll(".pillar").length).toBe(2);
            expect(element.textContent).not.toContain("Pillar score, by month");
            expect(element.querySelectorAll(".pillar svg.spark, .pillar .sparkbox").length).toBe(0);
            expect(element.textContent).toContain("Every KPI in this pillar");
        });
        it("the overview keeps the trend block when the payload carries trends", () => {
            const { visual, element } = setup({ read: view("overview") });
            visual.update(opts(makeDataView(withTrends())));
            expect(element.textContent).toContain("Pillar score, by month");
        });
        it("board tiles have no sparkline area but keep value, target and score", () => {
            const { visual, element } = setup({ read: view("board") });
            visual.update(opts(makeDataView(rows())));
            const t = element.querySelector(".tile")!;
            expect(element.querySelectorAll(".tile .sparkbox, .tile svg.spark").length).toBe(0);
            expect(t.textContent).toContain("50.0%");
            expect(t.textContent).toContain("Score 90");
        });
    });
});
