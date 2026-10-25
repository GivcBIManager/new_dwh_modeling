// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { renderView, type UiState } from "../src/render/index";
import { DEFAULT_OWNER_UI, type OwnerUi } from "../src/render/owner";
import { parseDataView } from "../src/model/parse";
import type { ViewModel } from "../src/model/types";
import { makeDataView, payload, FixtureRow } from "./fixtures";

const base = { kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure",
    scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70 };
const ui = (o: Partial<UiState> = {}): UiState => ({ pillar: null, compareLevel: { pillar: null, objective: null }, title: "Balanced scorecard", subtitle: "How the group is performing against its strategy", showHeader: true, ...o });

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

describe("owner view with co-owners", () => {
    const coRows: FixtureRow[] = [
        row("K1", "Financial", 1, 0.5, { owner: "COO", coOwners: "CFO", payload: ok(90) }),
        row("K2", "Financial", 1, 0.5, { owner: "COO", coOwners: "", displayOrder: 2, payload: ok(80, "Watch") }),
    ];
    const blocks = () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(coRows)), "owner", ui());
        const bs = [...root.querySelectorAll(".owner")];
        return new Map(bs.map(b => [b.querySelector("h3")!.textContent, b]));
    };
    it("lists a KPI under its owner and under each co-owner, tagged in the co-owner block", () => {
        const m = blocks();
        expect([...m.keys()]).toEqual(["CFO", "COO"]);
        const cfo = m.get("CFO")!, coo = m.get("COO")!;
        expect(cfo.querySelectorAll("tbody tr").length).toBe(1);
        expect(cfo.querySelector("tbody tr")!.textContent).toContain("K1 name");
        expect(cfo.querySelectorAll(".co-tag").length).toBe(1);
        expect(cfo.querySelector(".co-tag")!.textContent).toBe("co-owner");
        expect(coo.querySelectorAll("tbody tr").length).toBe(2);
        expect(coo.querySelectorAll(".co-tag").length).toBe(0);
    });
    it("shows a KPI without co-owners once", () => {
        const all = [...blocks().values()].flatMap(b => [...b.querySelectorAll("tbody tr")]).filter(r => r.textContent!.includes("K2 name"));
        expect(all.length).toBe(1);
    });
});

describe("owner overview strip", () => {
    const pay = (actual: number, target: number, variance: number, weight = 1) =>
        payload({ actual, target, variance, score: 85, state: variance >= 0 ? "On track" : "At risk", weight });
    const ovRows: FixtureRow[] = [
        row("K1", "Financial", 1, 0.5, { owner: "CFO", payload: pay(1.2, 1, 0.2, 3) }),
        row("K2", "Financial", 1, 0.5, { owner: "CFO", displayOrder: 2, payload: pay(0.6, 1, -0.4, 1) }),
        row("K3", "Customer", 2, 0.5, { owner: "Quality Manager", coOwners: "CEO", payload: pay(0.9, 1, -0.1) }),
        row("K4", "Customer", 2, 0.5, { owner: "CEO", displayOrder: 2, payload: payload({ state: "" }) }),
        row("K5", "Customer", 2, 0.5, { owner: "COO", displayOrder: 3, payload: pay(1, 1, 0) }),
    ];
    const draw = (o: Partial<OwnerUi> = {}) => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(ovRows)), "owner", ui({ owner: { ...DEFAULT_OWNER_UI, ...o } }));
        return root;
    };
    const cards = (root: HTMLElement) => [...root.querySelectorAll<HTMLElement>(".own-card")];
    const pressed = (root: HTMLElement, group: string) =>
        root.querySelector(`button[data-owner-toggle="${group}"][aria-pressed="true"]`)!.getAttribute("data-value");

    it("defaults to Weighted, C-Suite and KPI list Owned + co-owned", () => {
        expect(DEFAULT_OWNER_UI).toEqual({ score: "weighted", tier: "csuite", scope: "co", pick: null });
        const root = draw();
        expect(pressed(root, "score")).toBe("weighted");
        expect(pressed(root, "tier")).toBe("csuite");
        expect(pressed(root, "scope")).toBe("co");
        expect([...root.querySelectorAll("button[data-owner-toggle]")].map(b => b.textContent))
            .toEqual(["Weighted", "On-target", "C-Suite", "All owners", "Owned", "Owned + co-owned"]);
        expect([...root.querySelectorAll(".own-lbl")].map(l => l.textContent)).toEqual(["Score", "Owners", "KPI list"]);
    });
    it("draws one card per C-suite owner in C-suite order, each with an Achievement gauge in %", () => {
        const root = draw();
        expect(cards(root).map(c => c.dataset.ownerCard)).toEqual(["CEO", "COO", "CFO"]);
        const cfo = cards(root)[2];
        expect(cfo.tagName).toBe("BUTTON");
        expect(cfo.getAttribute("aria-pressed")).toBe("false");
        expect(cfo.querySelector(".gauge text")!.textContent).toBe("105%");
        expect(cfo.textContent).toContain("Achievement");
        expect(cfo.textContent).toContain("2 of 2 KPIs scored");
        // CEO owns only K4 (no data) and co-owns K3: the card counts both.
        expect(cards(root)[0].querySelector(".gauge text")!.textContent).toBe("90%");
        expect(cards(root)[0].textContent).toContain("1 of 2 KPIs scored");
    });
    it("On-target shows the hit rate", () => {
        const root = draw({ score: "hitrate" });
        expect(cards(root)[2].querySelector(".gauge text")!.textContent).toBe("50%");
        expect(cards(root)[2].textContent).toContain("1 of 2 KPIs on target");
    });
    it("All owners adds the other owners after the C-suite", () => {
        expect(cards(draw({ tier: "all" })).map(c => c.dataset.ownerCard)).toEqual(["CEO", "COO", "CFO", "Quality Manager"]);
    });
    it("cards count owned + co-owned KPIs whatever the KPI list toggle says", () => {
        expect(cards(draw())[0].querySelector(".gauge text")!.textContent).toBe("90%");
        expect(cards(draw({ scope: "owned" }))[0].querySelector(".gauge text")!.textContent).toBe("90%");
    });
    it("lists every owner's KPI blocks below the strip until a card is picked; KPI list Owned lists owned KPIs only", () => {
        const root = draw({ scope: "owned" });
        expect([...root.querySelectorAll(".owners .owner h3")].map(h => h.textContent)).toEqual(["CEO", "CFO", "COO", "Quality Manager"]);
        expect(root.querySelector(".owners tr[data-key]")!.getAttribute("tabindex")).toBe("0");
        expect(root.querySelectorAll(".owners .co-tag").length).toBe(0);
    });
    it("KPI list Owned + co-owned (the default) adds the co-owned rows, tagged", () => {
        const root = draw();
        const ceo = root.querySelector(".owners .owner")!;
        expect(ceo.querySelector("h3")!.textContent).toBe("CEO");
        expect(ceo.querySelectorAll("tbody tr").length).toBe(2);
        expect(ceo.querySelectorAll(".co-tag").length).toBe(1);
    });
    it("a picked owner filters the blocks to that owner", () => {
        const root = draw({ pick: "CEO", scope: "owned" });
        const blocks = [...root.querySelectorAll(".owners .owner")];
        expect(blocks.map(b => b.querySelector("h3")!.textContent)).toEqual(["CEO"]);
        expect(blocks[0].querySelectorAll("tbody tr").length).toBe(1);
        expect(root.querySelector('.own-card[data-owner-card="CEO"]')!.getAttribute("aria-pressed")).toBe("true");
        const co = [...draw({ pick: "CEO" }).querySelectorAll(".owners .owner")];
        expect(co.length).toBe(1);
        expect(co[0].querySelectorAll("tbody tr").length).toBe(2);
        expect(co[0].querySelectorAll(".co-tag").length).toBe(1);
    });
    it("a picked co-owner who owns nothing gets a pointer to Owned + co-owned under Owned", () => {
        const root = mount();
        const vm = parseDataView(makeDataView([row("X1", "Financial", 1, 1, { owner: "Quality Manager", coOwners: "CFO", payload: pay(0.96, 1, -0.04) })]));
        renderView(root, vm, "owner", ui({ owner: { ...DEFAULT_OWNER_UI, pick: "CFO", scope: "owned" } }));
        expect(root.querySelector('.own-card[data-owner-card="CFO"] .gauge text')!.textContent).toBe("96%");
        expect(root.querySelectorAll(".owners .owner").length).toBe(0);
        expect(root.querySelector(".owners")!.textContent).toContain("CFO owns no KPI here");
        const co = mount();
        renderView(co, vm, "owner", ui({ owner: { ...DEFAULT_OWNER_UI, pick: "CFO" } }));
        expect(co.querySelectorAll(".owners .owner").length).toBe(1);
        expect(co.querySelectorAll(".owners .owner .co-tag").length).toBe(1);
    });
    it("says so when the selection has no C-suite owner", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView([row("X1", "Financial", 1, 1, { owner: "Quality Manager", payload: pay(1, 1, 0) })])), "owner", ui());
        expect(root.querySelectorAll(".own-card").length).toBe(0);
        expect(root.querySelector(".own-strip")!.textContent).toContain("No C-suite owner");
    });
});

describe("branch hint outside comparison", () => {
    const brRows: FixtureRow[] = [row("F1", "Financial", 1, 0.3, { payload: [ok(90), ok(60, "At risk")] })];
    it("names the hospital shown in overview, board and owner when a branch series exists", () => {
        for (const m of ["overview", "board", "owner"] as const) {
            const root = mount();
            renderView(root, parseDataView(makeDataView(brRows, { branches: ["Abha", "Jazan"] })), m, ui());
            expect(root.querySelector(".hint")!.textContent).toBe("Showing Abha — switch to Hospital comparison to compare hospitals");
        }
    });
    it("is absent in comparison mode and without a branch series", () => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(brRows, { branches: ["Abha", "Jazan"] })), "comparison", ui());
        expect(root.querySelector(".hint")).toBeNull();
        const plain = mount();
        renderView(plain, parseDataView(makeDataView(rows)), "overview", ui());
        expect(plain.querySelector(".hint")).toBeNull();
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
