// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { tooltipItems, wire, selectionKey } from "../src/interactions";
import { renderView } from "../src/render/index";
import { parseDataView } from "../src/model/parse";
import { makeDataView, payload, FixtureRow } from "./fixtures";
import type { KpiRow } from "../src/model/types";

const base = { kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure",
    scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70, objectiveCode: "O1", objectiveTitle: "Grow", objectiveOrder: 1, displayOrder: 1 };
const rows: FixtureRow[] = [
    { ...base, kpi: "F1", kpiName: "Revenue", shortLabel: "Rev", pillar: "Financial", pillarOrder: 1, pillarWeight: 0.5, pillarQuestion: "q?", owner: "CFO",
        payload: payload({ actual: 0.42, target: 0.4, variance: 0.05, score: 87.4, state: "On track", weight: 1, trend: [0.3, 0.42], targetTrend: [0.4, 0.4] }) },
    { ...base, kpi: "F2", kpiName: "Margin", shortLabel: "Mar", pillar: "Financial", pillarOrder: 1, pillarWeight: 0.5, pillarQuestion: "q?", owner: "CFO", valueSource: "manual",
        payload: payload({ actual: 0.3, target: 0.4, variance: -0.25, score: 60, state: "At risk", weight: 1 }) },
    { ...base, kpi: "C1", kpiName: "Satisfaction", shortLabel: "Sat", pillar: "Customer", pillarOrder: 2, pillarWeight: 0.5, pillarQuestion: "q?", owner: "",
        payload: payload({ actual: 0.9, target: 0.9, variance: 0, score: 85, state: "On track", weight: 1 }) },
];

interface Call { fn: string; args: unknown[] }
function fakeHost(allow = true) {
    const calls: Call[] = [];
    let selected: unknown[] = [];
    const sm = {
        select: (id: unknown, multi?: boolean) => { calls.push({ fn: "select", args: [id, multi] }); selected = Array.isArray(id) ? id : [id]; return Promise.resolve(selected); },
        clear: () => { calls.push({ fn: "clear", args: [] }); selected = []; return Promise.resolve({}); },
        showContextMenu: (id: unknown, pos: unknown) => { calls.push({ fn: "showContextMenu", args: [id, pos] }); },
        getSelectionIds: () => selected,
    };
    const ts = {
        show: (o: unknown) => { calls.push({ fn: "show", args: [o] }); },
        hide: (o: unknown) => { calls.push({ fn: "hide", args: [o] }); },
    };
    return { calls, host: { selectionManager: sm, tooltipService: ts, allowInteractions: allow } as never };
}

function setup(allow = true, mode: "overview" | "board" = "board") {
    const root = document.createElement("div");
    document.body.appendChild(root);
    const vm = parseDataView(makeDataView(rows));
    renderView(root, vm, mode, { pillar: null, focusBranch: null, title: "t", subtitle: "s", showHeader: false });
    const all = vm.pillars.flatMap(p => p.kpis);
    const ids = new Map<string, unknown>();
    for (const r of all) ids.set(selectionKey(r.rowIndex, r.seriesIndex), { key: r.code, equals(o: { key: string }) { return o.key === r.code; } });
    const f = fakeHost(allow);
    wire(root, all, ids as never, f.host);
    return { root, ids, all, ...f };
}
const tileOf = (root: HTMLElement, key: number) => root.querySelector(`.tile[data-key="${key}"]`) as HTMLElement;

describe("tooltipItems", () => {
    it("lists the nine items in order with formatted values", () => {
        const r = { name: "Revenue", objectiveTitle: "Grow", actual: 0.42, target: 0.4, variance: 0.05, score: 87.4, stateWord: "On track", owner: "CFO", manual: false, valueFormat: "pct" } as KpiRow;
        const items = tooltipItems(r);
        expect(items.map(i => i.displayName)).toEqual(["KPI", "Objective title", "Actual", "Target", "Variance", "Score", "State", "Owner", "Source"]);
        expect(items.map(i => i.value)).toEqual(["Revenue", "Grow", "42.0%", "40.0%", "+5.0%", "87", "On track", "CFO", "Measure"]);
        expect(tooltipItems({ ...r, manual: true, owner: "", actual: null } as KpiRow).map(i => i.value)).toEqual(["Revenue", "Grow", "–", "40.0%", "+5.0%", "87", "On track", "–", "Manual entry"]);
    });
});

describe("wire", () => {
    it("selects the KPI id on click and adds with Ctrl", () => {
        const { root, ids, calls } = setup();
        tileOf(root, 0).dispatchEvent(new MouseEvent("click", { bubbles: true }));
        tileOf(root, 1).dispatchEvent(new MouseEvent("click", { bubbles: true, ctrlKey: true }));
        expect(calls[0]).toEqual({ fn: "select", args: [ids.get("0:"), false] });
        expect(calls[1].args).toEqual([ids.get("1:"), true]);
    });
    it("clears on empty space", () => {
        const { root, calls } = setup();
        root.querySelector(".grid")!.dispatchEvent(new MouseEvent("click", { bubbles: true }));
        expect(calls.map(c => c.fn)).toEqual(["clear"]);
    });
    it("opens the context menu at the mouse position", () => {
        const { root, ids, calls } = setup();
        tileOf(root, 0).dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true, clientX: 40, clientY: 55 }));
        expect(calls).toEqual([{ fn: "showContextMenu", args: [ids.get("0:"), { x: 40, y: 55 }] }]);
    });
    it("Shift+F10 and the context-menu key open the menu at the tile", () => {
        const { root, calls } = setup();
        const t = tileOf(root, 1);
        t.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "F10", shiftKey: true }));
        t.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "ContextMenu" }));
        expect(calls.map(c => c.fn)).toEqual(["showContextMenu", "showContextMenu"]);
    });
    it("Enter and Space select", () => {
        const { root, calls } = setup();
        const t = tileOf(root, 0);
        t.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Enter" }));
        t.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: " " }));
        expect(calls.map(c => c.fn)).toEqual(["select", "select"]);
    });
    it("shows the tooltip on hover and hides it on leave", () => {
        const { root, ids, calls } = setup();
        tileOf(root, 0).dispatchEvent(new MouseEvent("mousemove", { bubbles: true, clientX: 10, clientY: 20 }));
        const arg = calls[0].args[0] as { dataItems: unknown[]; identities: unknown[]; coordinates: number[]; isTouchEvent: boolean };
        expect(calls[0].fn).toBe("show");
        expect(arg.identities).toEqual([ids.get("0:")]);
        expect(arg.coordinates).toEqual([10, 20]);
        expect(arg.isTouchEvent).toBe(false);
        expect(arg.dataItems.length).toBe(9);
        tileOf(root, 0).dispatchEvent(new MouseEvent("mouseout", { bubbles: true }));
        expect(calls[1].fn).toBe("hide");
    });
    it("a pillar card click selects the pillar's KPI ids", () => {
        const { root, ids, calls } = setup(true, "overview");
        (root.querySelector('.pillar[data-pillar="Financial"]') as HTMLElement).dispatchEvent(new MouseEvent("click", { bubbles: true }));
        expect(calls[0].fn).toBe("select");
        expect(calls[0].args[0]).toEqual([ids.get("0:"), ids.get("1:")]);
    });
    it("marks selected and dims the others after a select", async () => {
        const { root } = setup();
        tileOf(root, 0).dispatchEvent(new MouseEvent("click", { bubbles: true }));
        await Promise.resolve(); await Promise.resolve();
        expect(tileOf(root, 0).classList.contains("selected")).toBe(true);
        expect(tileOf(root, 1).classList.contains("dimmed")).toBe(true);
        expect(tileOf(root, 0).classList.contains("dimmed")).toBe(false);
    });
    it("does nothing when interactions are not allowed", () => {
        const { root, calls } = setup(false);
        const t = tileOf(root, 0);
        t.dispatchEvent(new MouseEvent("click", { bubbles: true }));
        t.dispatchEvent(new MouseEvent("contextmenu", { bubbles: true, cancelable: true }));
        t.dispatchEvent(new MouseEvent("mousemove", { bubbles: true }));
        t.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Enter" }));
        root.querySelector(".grid")!.dispatchEvent(new MouseEvent("click", { bubbles: true }));
        expect(calls).toEqual([]);
    });
    it("the returned disposer removes the listeners", () => {
        const root = document.createElement("div");
        const cell = document.createElement("div");
        cell.className = "tile"; cell.dataset.key = "0"; root.appendChild(cell);
        const f = fakeHost();
        const off = wire(root, [{ rowIndex: 0, seriesIndex: null } as KpiRow], new Map([["0:", {}]]) as never, f.host);
        off();
        root.firstElementChild!.dispatchEvent(new MouseEvent("click", { bubbles: true }));
        expect(f.calls).toEqual([]);
    });
    it("removes dimmed after a clear on empty space", async () => {
        const { root } = setup();
        tileOf(root, 0).dispatchEvent(new MouseEvent("click", { bubbles: true }));
        await Promise.resolve(); await Promise.resolve();
        root.querySelector(".grid")!.dispatchEvent(new MouseEvent("click", { bubbles: true }));
        await Promise.resolve(); await Promise.resolve();
        expect(root.querySelectorAll(".dimmed, .selected").length).toBe(0);
    });
    it("does not hide the tooltip when the pointer moves inside the same tile", () => {
        const { root, calls } = setup();
        const t = tileOf(root, 0);
        t.dispatchEvent(new MouseEvent("mouseout", { bubbles: true, relatedTarget: t.querySelector("h4") }));
        expect(calls).toEqual([]);
        t.dispatchEvent(new MouseEvent("mouseout", { bubbles: true, relatedTarget: tileOf(root, 1) }));
        expect(calls.map(c => c.fn)).toEqual(["hide"]);
    });
});
