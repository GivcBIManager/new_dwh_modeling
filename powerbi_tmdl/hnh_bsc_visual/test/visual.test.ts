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
    const selected: unknown[] = [];
    const clears: number[] = [];
    const onSelect: { cb: () => void } = { cb: () => undefined };
    const host = {
        eventService: {
            renderingStarted: () => events.push("started"),
            renderingFinished: () => events.push("finished"),
            renderingFailed: (_o: unknown, m?: string) => events.push("failed:" + m),
        },
        // The fake host keeps its selection like Power BI: a plain select replaces it, Ctrl adds, clear empties.
        createSelectionManager: () => ({
            select: (...a: unknown[]) => {
                selects.push(a);
                const ids = Array.isArray(a[0]) ? a[0] : [a[0]];
                selected.splice(0, selected.length, ...(a[1] ? [...selected, ...ids] : ids));
                return Promise.resolve(selected);
            },
            clear: () => { clears.push(1); selected.splice(0); return Promise.resolve({}); },
            showContextMenu: () => undefined,
            getSelectionIds: () => selected, registerOnSelectCallback: (cb: () => void) => { onSelect.cb = cb; },
        }),
        createSelectionIdBuilder: () => {
            const rec: unknown[] = [];
            const b = { withCategory: (_c: unknown, i: number) => { rec.push(["cat", i]); return b; },
                withSeries: (_v: unknown, g: unknown) => { rec.push(["series", g]); return b; },
                createSelectionId: () => { built.push(rec); const id = { equals: (o: unknown) => o === id }; return id; } };
            return b;
        },
        tooltipService: { show: () => undefined, hide: () => undefined },
        hostCapabilities: { allowInteractions: opts.allow ?? true },
        colorPalette: { isHighContrast: opts.hc ?? false, foreground: { value: "#fff" }, background: { value: "#000" }, foregroundSelected: { value: "#ff0" } },
    };
    const element = document.createElement("div");
    const visual = new Visual({ element, host } as never, opts.read as never);
    return { visual, element, events, built, selects, selected, clears, onSelect };
}
const opts = (dv: unknown, w = 1200, h = 800) => ({ dataViews: dv ? [dv] : [], viewport: { width: w, height: h }, type: 2 }) as never;

describe("Visual", () => {
    it("renders data between started and finished, with an id per row", () => {
        const { visual, element, events, built } = setup();
        visual.update(opts(makeDataView([mk("F1", "Financial", 1), mk("C1", "Customer", 2)])));
        expect(events).toEqual(["started", "finished"]);
        expect(element.querySelectorAll(".ov-pillar").length).toBe(2);
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

    describe("board picks (host selection drives the panel; the objective picker is the visual's own state)", () => {
        const reader = (pillar: string | null): Reader => () => ({
            mode: "board", ui: { pillar, compareLevel: { pillar: null, objective: null }, objective: null, title: "Balanced scorecard", subtitle: "s", showHeader: false },
        });
        const obj = (code: string, title: string, order: number) => ({ objectiveCode: code, objectiveTitle: title, objectiveOrder: order });
        const data = (withO2 = true) => makeDataView([
            { ...mk("F1", "Financial", 1), ...obj("O1", "Grow", 1) },
            { ...mk("F2", "Financial", 1), ...obj("O1", "Grow", 1), displayOrder: 2 },
            ...(withO2 ? [{ ...mk("F3", "Financial", 1), ...obj("O2", "Save", 2) }] : []),
            { ...mk("C1", "Customer", 2), ...obj("C1", "Serve", 1) },
        ]);
        const flush = () => new Promise(r => setTimeout(r, 0));
        const rowEl = (el: HTMLElement, name: string) => [...el.querySelectorAll<HTMLElement>(".bd-row")].find(r => r.querySelector(".bd-name")!.firstChild!.textContent === name)!;
        const names = (el: HTMLElement) => [...el.querySelectorAll(".bd-row .bd-name")].map(n => n.firstChild!.textContent);
        const panel = (el: HTMLElement) => el.querySelector(".bd-panel-main")!;
        const click = (n: HTMLElement, o: MouseEventInit = {}) => n.dispatchEvent(new MouseEvent("click", { bubbles: true, ...o }));
        const pick = (el: HTMLElement, value: string) => {
            const sel = el.querySelector("select[data-objective-picker]") as HTMLSelectElement;
            sel.value = value;
            sel.dispatchEvent(new Event("change", { bubbles: true }));
        };

        it("a row click selects the KPI for the host and, once the selection is back, the panel shows that row", async () => {
            const { visual, element, selects } = setup({ read: reader(null) });
            visual.update(opts(data()));
            expect(panel(element).textContent).toContain("Select a KPI");
            click(rowEl(element, "F2"));
            expect(selects.length).toBe(1);
            await flush();
            expect(panel(element).querySelector("h2")!.textContent).toBe("F2");
            expect(rowEl(element, "F2").classList.contains("selected")).toBe(true);
        });
        it("two selected KPIs (Ctrl+click) empty the panel; a clear empties it too", async () => {
            const { visual, element } = setup({ read: reader(null) });
            visual.update(opts(data()));
            click(rowEl(element, "F1"));
            await flush();
            click(rowEl(element, "F2"), { ctrlKey: true });
            await flush();
            expect(panel(element).textContent).toContain("Select a KPI");
            expect(element.querySelectorAll(".bd-row.selected").length).toBe(2);
            click(rowEl(element, "F1"));
            await flush();
            expect(panel(element).querySelector("h2")!.textContent).toBe("F1");
            click(element.querySelector(".bd-strip") as HTMLElement);
            await flush();
            expect(panel(element).textContent).toContain("Select a KPI");
        });
        it("a selection made outside the visual (the host's select callback) updates the panel", () => {
            const { visual, element, selected, onSelect } = setup({ read: reader(null) });
            visual.update(opts(data()));
            const ids = (visual as unknown as { ids: Map<string, unknown> }).ids;
            selected.push(ids.get(rowEl(element, "F3").dataset.key + ":"));
            onSelect.cb();
            expect(panel(element).querySelector("h2")!.textContent).toBe("F3");
        });
        it("keyboard: Enter selects and focus stays on the row after the re-render", async () => {
            const { visual, element } = setup({ read: reader(null) });
            document.body.appendChild(element);
            visual.update(opts(data()));
            const old = rowEl(element, "F2");
            old.focus();
            old.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Enter" }));
            await flush();
            const now = rowEl(element, "F2");
            expect(now).not.toBe(old);
            expect(document.activeElement).toBe(now);
            element.remove();
        });
        it("the table keeps its scroll position when a selection re-renders the board", async () => {
            const { visual, element } = setup({ read: reader(null) });
            visual.update(opts(data()));
            (element.querySelector(".bd-tbody") as HTMLElement).scrollTop = 120;
            click(rowEl(element, "F3"));
            await flush();
            expect(panel(element).querySelector("h2")!.textContent).toBe("F3");
            expect((element.querySelector(".bd-tbody") as HTMLElement).scrollTop).toBe(120);
            visual.update(opts(data()));
            expect((element.querySelector(".bd-tbody") as HTMLElement).scrollTop).toBe(120);
            pick(element, "O1");
            expect((element.querySelector(".bd-tbody") as HTMLElement).scrollTop).toBe(0);
        });
        it("changing the objective picker narrows the table without a host selection and keeps the pick across a plain update", () => {
            const { visual, element, selects, clears } = setup({ read: reader(null) });
            visual.update(opts(data()));
            expect(names(element)).toEqual(["F1", "F2", "F3"]);
            pick(element, "O2");
            expect(names(element)).toEqual(["F3"]);
            expect((element.querySelector("select[data-objective-picker]") as HTMLSelectElement).value).toBe("O2");
            expect(selects).toEqual([]);
            expect(clears).toEqual([]);
            visual.update(opts(data()));
            expect(names(element)).toEqual(["F3"]);
            pick(element, "");
            expect(names(element)).toEqual(["F1", "F2", "F3"]);
        });
        it("a click on the picker neither selects nor clears", () => {
            const { visual, element, selects, clears } = setup({ read: reader(null) });
            visual.update(opts(data()));
            click(element.querySelector("select[data-objective-picker]") as HTMLElement);
            expect(selects).toEqual([]);
            expect(clears).toEqual([]);
        });
        it("keyboard: focus stays on the picker after a change", () => {
            const { visual, element } = setup({ read: reader(null) });
            document.body.appendChild(element);
            visual.update(opts(data()));
            (element.querySelector("select[data-objective-picker]") as HTMLSelectElement).focus();
            pick(element, "O2");
            expect(document.activeElement).toBe(element.querySelector("select[data-objective-picker]"));
            element.remove();
        });
        it("a vanished objective resets the pick", () => {
            const { visual, element } = setup({ read: reader(null) });
            visual.update(opts(data()));
            pick(element, "O2");
            visual.update(opts(data(false)));
            expect(names(element)).toEqual(["F1", "F2"]);
            visual.update(opts(data()));
            expect(names(element)).toEqual(["F1", "F2", "F3"]);
            expect((element.querySelector("select[data-objective-picker]") as HTMLSelectElement).value).toBe("");
        });
        it("a change of pillar resets the pick", () => {
            const cur = { p: null as string | null };
            const { visual, element } = setup({ read: (dv) => reader(cur.p)(dv) });
            visual.update(opts(data()));
            pick(element, "O2");
            cur.p = "Customer";
            visual.update(opts(data()));
            cur.p = "Financial";
            visual.update(opts(data()));
            expect(names(element)).toEqual(["F1", "F2", "F3"]);
        });
        it("the picker is disabled when the host does not allow interactions", () => {
            const { visual, element } = setup({ read: reader(null), allow: false });
            visual.update(opts(data()));
            expect((element.querySelector("select[data-objective-picker]") as HTMLSelectElement).disabled).toBe(true);
            pick(element, "O2");
            expect(names(element)).toEqual(["F1", "F2", "F3"]);
        });
        it("the chart and button slots stay empty for the report's native visuals", async () => {
            const { visual, element } = setup({ read: reader(null) });
            visual.update(opts(data()));
            click(rowEl(element, "F1"));
            await flush();
            expect(element.querySelector(".bd-slot-chart")!.childNodes.length).toBe(0);
            expect(element.querySelector(".bd-slot-button")!.childNodes.length).toBe(0);
        });
    });

    describe("comparison drill (Pillar > Objective > KPI)", () => {
        const cmp: Reader = () => ({ mode: "comparison", ui: { pillar: null, compareLevel: { pillar: null, objective: null }, objective: null, title: "t", subtitle: "s", showHeader: false } });
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

    describe("owner overview (strip toggles and owner filter)", () => {
        const own: Reader = () => ({ mode: "owner", ui: { pillar: null, compareLevel: { pillar: null, objective: null }, objective: null, title: "t", subtitle: "s", showHeader: false } });
        const r = (code: string, owner: string, actual: number, extra: FixtureRow = {}): FixtureRow => ({ ...mk(code, "Financial", 1), owner,
            payload: payload({ actual, target: 1, variance: actual - 1, score: 85, state: "On track", weight: 1 }), ...extra });
        const data = () => makeDataView([r("K1", "CFO", 1.2), r("K2", "CFO", 0.6), r("K3", "CEO", 1, { coOwners: "CFO" }), r("K4", "Quality Manager", 0.9)]);
        const click = (el: HTMLElement, sel: string) => (el.querySelector(sel) as HTMLElement).dispatchEvent(new MouseEvent("click", { bubbles: true }));
        const value = (el: HTMLElement, owner: string) => el.querySelector(`.own-card[data-owner-card="${owner}"] .gauge text`)!.textContent;
        const owners = (el: HTMLElement) => [...el.querySelectorAll<HTMLElement>(".own-card")].map(c => c.dataset.ownerCard);
        const blocks = (el: HTMLElement) => [...el.querySelectorAll(".owners .owner h3")].map(h => h.textContent);

        it("the score, owner and KPI-list toggles change the view without a host selection and survive an update", () => {
            const { visual, element, selects } = setup({ read: own });
            visual.update(opts(data()));
            expect(value(element, "CFO")).toBe("93%");
            click(element, 'button[data-owner-toggle="score"][data-value="hitrate"]');
            expect(value(element, "CFO")).toBe("67%");
            click(element, 'button[data-owner-toggle="tier"][data-value="all"]');
            expect(owners(element)).toEqual(["CEO", "CFO", "Quality Manager"]);
            expect(element.querySelectorAll(".owners .co-tag").length).toBe(1);
            click(element, 'button[data-owner-toggle="scope"][data-value="owned"]');
            expect(value(element, "CFO")).toBe("67%");
            expect(element.querySelectorAll(".owners .co-tag").length).toBe(0);
            expect(selects).toEqual([]);
            visual.update(opts(data()));
            expect(value(element, "CFO")).toBe("67%");
            expect(owners(element)).toEqual(["CEO", "CFO", "Quality Manager"]);
            expect(element.querySelectorAll(".owners .co-tag").length).toBe(0);
        });
        it("a card click filters the KPI list to that owner; a second click shows every owner again", () => {
            const { visual, element, selects } = setup({ read: own });
            visual.update(opts(data()));
            expect(blocks(element)).toEqual(["CEO", "CFO", "Quality Manager"]);
            click(element, '.own-card[data-owner-card="CFO"]');
            expect(blocks(element)).toEqual(["CFO"]);
            expect(element.querySelector('.own-card[data-owner-card="CFO"]')!.getAttribute("aria-pressed")).toBe("true");
            visual.update(opts(data()));
            expect(blocks(element)).toEqual(["CFO"]);
            click(element, '.own-card[data-owner-card="CFO"]');
            expect(blocks(element)).toEqual(["CEO", "CFO", "Quality Manager"]);
            expect(selects).toEqual([]);
        });
        it("the pick is dropped when its card leaves the strip", () => {
            const { visual, element } = setup({ read: own });
            visual.update(opts(data()));
            click(element, 'button[data-owner-toggle="tier"][data-value="all"]');
            click(element, '.own-card[data-owner-card="Quality Manager"]');
            expect(blocks(element)).toEqual(["Quality Manager"]);
            click(element, 'button[data-owner-toggle="tier"][data-value="csuite"]');
            expect(blocks(element)).toEqual(["CEO", "CFO", "Quality Manager"]);
        });
        it("KPI rows under the strip still select on click", () => {
            const { visual, element, selects } = setup({ read: own });
            visual.update(opts(data()));
            click(element, ".owners tr[data-key]");
            expect(selects.length).toBe(1);
        });
        it("keyboard: focus stays on the card or toggle after the re-render", () => {
            const { visual, element } = setup({ read: own });
            document.body.appendChild(element);
            visual.update(opts(data()));
            const card = element.querySelector('.own-card[data-owner-card="CFO"]') as HTMLButtonElement;
            card.focus();
            card.click();
            expect((document.activeElement as HTMLElement).dataset.ownerCard).toBe("CFO");
            const tog = element.querySelector('button[data-owner-toggle="score"][data-value="hitrate"]') as HTMLButtonElement;
            tog.focus();
            tog.click();
            expect((document.activeElement as HTMLElement).dataset.value).toBe("hitrate");
            element.remove();
        });
        it("ignores card and toggle clicks when the host does not allow interactions", () => {
            const { visual, element } = setup({ read: own, allow: false });
            visual.update(opts(data()));
            click(element, '.own-card[data-owner-card="CFO"]');
            click(element, 'button[data-owner-toggle="score"][data-value="hitrate"]');
            expect(blocks(element)).toEqual(["CEO", "CFO", "Quality Manager"]);
            expect(value(element, "CFO")).toBe("93%");
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
        const view = (mode: Mode): Reader => () => ({ mode, ui: { pillar: null, compareLevel: { pillar: null, objective: null }, objective: null, title: "t", subtitle: "s", showHeader: false } });

        it("the overview leaves out the sparklines, the deltas and the trend panel; Needs attention takes the row", () => {
            const { visual, element } = setup({ read: view("overview") });
            visual.update(opts(makeDataView(rows())));
            expect(element.querySelectorAll(".ov-pillar").length).toBe(2);
            expect(element.querySelector(".ov-trend")).toBeNull();
            expect(element.querySelectorAll(".spark").length).toBe(0);
            expect(element.querySelectorAll(".ov-delta").length).toBe(0);
            expect(element.querySelector(".ov-row2")!.classList.contains("no-trend")).toBe(true);
            expect(element.querySelector(".ov-row2 > .ov-attention")).not.toBeNull();
            expect(element.textContent).toContain("of 100");
        });
        it("the overview draws the trend panel, sparklines and deltas when the payload carries trends", () => {
            const { visual, element } = setup({ read: view("overview") });
            visual.update(opts(makeDataView(withTrends())));
            expect(element.querySelector(".ov-trend")).not.toBeNull();
            expect(element.querySelectorAll(".ov-pillar svg.spark").length).toBe(2);
            expect(element.querySelector(".ov-row2")!.classList.contains("no-trend")).toBe(false);
        });
        it("board rows have no sparkline but keep value, target and score", () => {
            const { visual, element } = setup({ read: view("board") });
            visual.update(opts(makeDataView(rows())));
            const t = element.querySelector(".bd-row")!;
            expect(element.querySelectorAll(".bd-row svg").length).toBe(0);
            expect(t.querySelector(".c-actual")!.textContent).toBe("50.0%");
            expect(t.querySelector(".c-target")!.textContent).toBe("≥ 50.0%");
            expect(t.querySelector(".c-score")!.textContent).toBe("90");
        });
    });
});
