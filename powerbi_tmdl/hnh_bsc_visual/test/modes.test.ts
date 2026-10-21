// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { renderView, type UiState } from "../src/render/index";
import { parseDataView } from "../src/model/parse";
import type { ViewModel } from "../src/model/types";
import { makeDataView, payload, FixtureRow } from "./fixtures";

const base = { kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure",
    scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70 };
const ui = (o: Partial<UiState> = {}): UiState => ({ pillar: null, focusBranch: null, title: "Balanced scorecard", subtitle: "How the group is performing against its strategy", showHeader: true, ...o });

function row(code: string, pillar: string, order: number, w: number, extra: FixtureRow = {}): FixtureRow {
    return { ...base, kpi: code, kpiName: code + " name", shortLabel: code, pillar, pillarOrder: order, pillarWeight: w, pillarQuestion: pillar + " question?",
        objectiveCode: "O1", objectiveTitle: "Obj", objectiveOrder: 1, displayOrder: 1, owner: "Someone", ...extra };
}
const ok = (score: number, st = "On track") =>
    payload({ actual: 0.5, target: 0.5, variance: 0, score, state: st, weight: 1, trend: [score - 1, score], targetTrend: [0.5, 0.5], scoreTrend: [score - 1, score] });

const rows: FixtureRow[] = [
    row("F2", "Financial", 1, 0.3, { kpiType: "Supporting", displayOrder: 1, payload: ok(90), owner: "CFO" }),
    row("F1", "Financial", 1, 0.3, { displayOrder: 2, payload: ok(60, "At risk"), owner: "CFO" }),
    row("F3", "Financial", 1, 0.3, { displayOrder: 3, objectiveCode: "O2", objectiveTitle: "Second", payload: ok(80, "Watch"), owner: "Controller" }),
    row("C1", "Customer", 2, 0.2, { payload: ok(88) }),
    row("I1", "Internal Process", 3, 0.35, { payload: ok(75, "Watch") }),
    row("L1", "Learning & Growth", 4, 0.15, { payload: ok(95) }),
];
const mount = () => document.createElement("div");
const emptyVm = (guard: string | null): ViewModel => ({
    pillars: [], overallScore: null, overallByBranch: [], label: "",
    thresholds: { base: 85, slope: 0.6, good: 85, watch: 70 }, branches: [], guardMessage: guard,
});

describe("overview", () => {
    it("draws the header, the overall gauge, the legend and four pillar cards in order", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(rows)), "overview", ui());
        expect(root.classList.contains("hnh-bsc")).toBe(true);
        expect(root.querySelector(".band h1")!.textContent).toBe("Balanced scorecard");
        const cards = [...root.querySelectorAll(".pillar")];
        expect(cards.map(c => c.querySelector("h3")!.textContent)).toEqual(["Financial", "Customer", "Internal Process", "Learning & Growth"]);
        expect(cards[0].getAttribute("data-pillar")).toBe("Financial");
        expect(root.querySelectorAll(".overall svg.gauge").length).toBe(1);
        const legend = root.querySelector(".legend")!.textContent!;
        expect(legend).toContain("85");
        expect(legend).toContain("0.6");
        expect(legend).toContain("Financial 30%");
        expect(cards[0].textContent).toContain("1 at risk");
        expect(cards[0].textContent).toContain("3 of 3 KPIs reporting");
        expect(cards[0].querySelectorAll(".strip i").length).toBe(3);
    });
    it("hides the header when showHeader is false", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(rows)), "overview", ui({ showHeader: false }));
        expect(root.querySelector(".band")).toBeNull();
    });
    it("redraws instead of appending", () => {
        const root = mount();
        const vm = parseDataView(makeDataView(rows));
        renderView(root, vm, "overview", ui());
        renderView(root, vm, "overview", ui());
        expect(root.querySelectorAll(".overall").length).toBe(1);
    });
});

describe("header label", () => {
    const withLabel = (label: string) => {
        const vm = parseDataView(makeDataView(rows.map(r => ({ ...r, selectionLabel: label }))));
        const root = mount();
        renderView(root, vm, "overview", ui());
        return root.querySelector(".band .ctx")!;
    };
    it("splits on the first middle dot: hospitals bold, period below", () => {
        const ctx = withLabel("Corporate · Jul 2026 – Sep 2026");
        expect(ctx.querySelector("b")!.textContent).toBe("Corporate");
        expect(ctx.querySelector(".period")!.textContent).toBe("Jul 2026 – Sep 2026");
    });
    it("puts a label without the separator wholly in the bold line", () => {
        const ctx = withLabel("Corporate");
        expect(ctx.querySelector("b")!.textContent).toBe("Corporate");
        expect(ctx.querySelector(".period")).toBeNull();
    });
});

describe("board", () => {
    it("shows the pillar question once: in the header when shown, in the tab bar when hidden", () => {
        const vm = parseDataView(makeDataView(rows));
        const a = mount();
        renderView(a, vm, "board", ui());
        expect(a.querySelector(".tabs .q")).toBeNull();
        expect(a.querySelector(".band .sub")!.textContent).toBe("Financial question?");
        const b = mount();
        renderView(b, vm, "board", ui({ showHeader: false }));
        expect(b.querySelector(".tabs .q")!.textContent).toBe("Financial question?");
    });
    it("lists objectives as sections with primaries first, and tabs for every pillar", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(rows)), "board", ui());
        expect(root.querySelectorAll(".tabs button").length).toBe(4);
        expect(root.querySelector('.tabs button[aria-selected="true"]')!.textContent).toBe("Financial");
        const secs = [...root.querySelectorAll(".sec")];
        expect(secs.map(s => s.textContent)).toEqual(["O1 · Obj2 KPIs", "O2 · Second1 KPIs"]);
        const tiles = [...root.querySelectorAll(".grid > .tile")];
        expect(tiles.length).toBe(3);
        expect(tiles[0].classList.contains("primary")).toBe(true);
        expect(root.querySelector(".band h1")!.textContent).toBe("Financial");
    });
    it("follows ui.pillar and has no tabs with one pillar", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(rows)), "board", ui({ pillar: "Customer" }));
        expect(root.querySelectorAll(".tile").length).toBe(1);
        const one = mount();
        renderView(one, parseDataView(makeDataView(rows.filter(r => r.pillar === "Financial"))), "board", ui());
        expect(one.querySelector(".tabs button")).toBeNull();
    });
    it("keeps a custom title", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(rows)), "board", ui({ title: "Group view" }));
        expect(root.querySelector(".band h1")!.textContent).toBe("Group view");
    });
});

describe("overview rounding and target line", () => {
    it("shows 85 as on track in the pillar chip and gauge, and draws the good threshold on the pillar trend", () => {
        const root = mount();
        const rs = [row("F1", "Financial", 1, 0.3, { payload: payload({ actual: 1, target: 1, variance: 0, score: 84.6, state: "Watch", weight: 1, trend: [80, 82, 84.6], scoreTrend: [80, 82, 84.6] }) })];
        renderView(root, parseDataView(makeDataView(rs)), "overview", ui());
        const card = root.querySelector(".pillar")!;
        expect(card.querySelector(".facts .chip")!.className).toContain("good");
        expect(card.querySelector(".gauge-arc")!.getAttribute("stroke")).toBe("var(--good)");
        expect(card.querySelector(".facts .spark-target")).not.toBeNull();
    });
});

describe("owner", () => {
    it("groups KPIs by owner", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(rows)), "owner", ui());
        const blocks = [...root.querySelectorAll(".owner")];
        const names = blocks.map(b => b.querySelector("h3")!.textContent);
        expect(names).toContain("CFO");
        expect(names).toContain("Controller");
        const cfo = blocks[names.indexOf("CFO")];
        expect(cfo.querySelectorAll("tbody tr").length).toBe(2);
        expect(cfo.querySelector(".chip")).not.toBeNull();
    });
});

describe("comparison", () => {
    const brRows: FixtureRow[] = [
        row("F1", "Financial", 1, 0.3, { displayOrder: 1, payload: [ok(90), ok(60, "At risk")] }),
        row("F2", "Financial", 1, 0.3, { displayOrder: 2, payload: [ok(80, "Watch"), payload({ state: "No data yet" })] }),
    ];
    it("puts the focus hospital first with a peer median", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(brRows, { branches: ["Abha", "Jazan"] })), "comparison", ui({ focusBranch: "Jazan" }));
        const heads = [...root.querySelectorAll("thead th")].map(h => h.textContent);
        expect(heads).toEqual(["KPI", "Jazan", "Abha", "Peer median"]);
        expect(root.querySelector("thead th.focus")!.textContent).toBe("Jazan");
        const first = root.querySelectorAll("tbody tr")[0];
        const cells = [...first.querySelectorAll("th,td")].map(c => c.textContent);
        expect(cells.slice(1)).toEqual(["60", "90", "90"]);
        expect(first.querySelector("td.bad")).not.toBeNull();
        const second = [...root.querySelectorAll("tbody tr")[1].querySelectorAll("th,td")].map(c => c.textContent);
        expect(second.slice(1)).toEqual(["–", "80", "80"]);
        expect(root.querySelector(".topline")!.textContent).toContain("Jazan");
        expect(root.querySelector(".cmp-legend")!.textContent).toContain("no data yet");
        expect(root.querySelector(".cmp-scroll table")).not.toBeNull();
        const td = first.querySelectorAll("td");
        expect(td[0].getAttribute("title")).toBe("Jazan: 60 · At risk");
        expect(td[0].getAttribute("aria-label")).toBe("Jazan: 60 · At risk");
        const nod = root.querySelectorAll("tbody tr")[1].querySelectorAll("td")[0];
        expect(nod.getAttribute("aria-label")).toBe("Jazan: No data yet");
        expect(nod.textContent).toBe("–");
    });
    it("defaults focus to the first hospital", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(brRows, { branches: ["Abha", "Jazan"] })), "comparison", ui());
        expect(root.querySelector("thead th.focus")!.textContent).toBe("Abha");
    });
    it("handles one hospital with a missing KPI", () => {
        const root = mount();
        const r = [row("F1", "Financial", 1, 0.3, { payload: [payload({ state: "No data yet" })] })];
        renderView(root, parseDataView(makeDataView(r, { branches: ["Abha"] })), "comparison", ui());
        const cells = [...root.querySelectorAll("tbody tr")[0].querySelectorAll("th,td")].map(c => c.textContent);
        expect(cells).toEqual(["F1 name", "–", "–"]);
        expect(root.querySelectorAll("thead th.focus").length).toBe(1);
    });
});

describe("empty states", () => {
    it("shows only the guard message", () => {
        const root = mount();
        renderView(root, emptyVm("Pick a KPI"), "overview", ui());
        expect(root.querySelectorAll(".empty").length).toBe(1);
        expect(root.textContent).toBe("Pick a KPI");
    });
    it("shows a message for zero rows in every mode", () => {
        for (const m of ["overview", "board", "owner", "comparison"] as const) {
            const root = mount();
            renderView(root, emptyVm(null), m, ui());
            expect(root.querySelector(".empty")!.textContent).toBe("No KPIs in this selection");
        }
    });
});
