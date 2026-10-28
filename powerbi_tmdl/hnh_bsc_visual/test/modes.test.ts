// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { renderView, type UiState } from "../src/render/index";
import { DEFAULT_OWNER_UI, type OwnerUi } from "../src/render/owner";
import { parseDataView } from "../src/model/parse";
import type { ViewModel } from "../src/model/types";
import { makeDataView, payload, FixtureRow } from "./fixtures";
import { board } from "../src/render/board";
import { monthlyBars } from "../src/render/bars";
import { selectionKey } from "../src/interactions";

const base = { kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure",
    scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70 };
const ui = (o: Partial<UiState> = {}): UiState => ({ pillar: null, compareLevel: { pillar: null, objective: null }, objective: null, title: "Balanced scorecard", subtitle: "How the group is performing against its strategy", showHeader: true, ...o });

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
    const labelled = (rs: FixtureRow[], label = "Corporate · Jan 2026 – Sep 2026") => rs.map(r => ({ ...r, selectionLabel: label }));
    const draw = (rs: FixtureRow[] = labelled(rows)) => {
        const root = mount();
        renderView(root, parseDataView(makeDataView(rs)), "overview", ui({ showHeader: false }));
        return root;
    };
    it("lays out the overall panel, four pillar cards in order, the trend and Needs attention", () => {
        const root = draw();
        expect(root.classList.contains("hnh-bsc")).toBe(true);
        const ov = root.querySelector(".ov")!;
        expect(ov.querySelectorAll(":scope > section.ov-overall").length).toBe(1);
        const cards = [...ov.querySelectorAll<HTMLElement>(":scope > article.ov-pillar")];
        expect(cards.map(c => c.dataset.pillar)).toEqual(["Financial", "Customer", "Internal Process", "Learning & Growth"]);
        expect(cards[0].textContent).toContain("Weight 30%");
        expect(cards[0].textContent).toContain("Drill into 3 KPIs →");
        expect(cards[0].querySelector(".ov-sq")!.getAttribute("style")).toContain("var(--p1)");
        const counts = [...cards[0].querySelectorAll(".ov-counts .ov-n")].map(n => n.textContent);
        expect(counts).toEqual(["1 On track", "1 Watch", "1 At risk"]);
        expect(cards[0].querySelector(".ov-n .sr-only")!.textContent).toBe(" On track");
        expect(cards[0].querySelector(".ov-n")!.hasAttribute("aria-label")).toBe(false);
        expect(ov.querySelector(".ov-row2 > section.ov-trend")).not.toBeNull();
        expect(ov.querySelector(".ov-row2 > section.ov-attention")).not.toBeNull();
    });
    it("shows the overall score of 100, the target and the status distribution", () => {
        const root = draw();
        const overall = root.querySelector(".ov-overall")!;
        expect(overall.querySelector("h2")!.textContent).toBe("Overall BSC score");
        expect(overall.textContent).toContain("Weighted · 4 pillars");
        expect(overall.textContent).toContain("of 100");
        expect(overall.textContent).toContain("Target 85");
        expect(overall.querySelector("svg.ring")).not.toBeNull();
        const counts = [...overall.querySelectorAll(".ov-dist-counts > span")].map(s => s.textContent);
        expect(counts).toEqual(["3 On track", "2 Watch", "1 At risk", "0 No data"]);
        expect(overall.querySelectorAll(".ov-dist-bar > i").length).toBe(3);
    });
    it("lists only the At-risk KPIs in Needs attention, as selectable rows", () => {
        const root = draw();
        const att = root.querySelector(".ov-attention")!;
        const items = [...att.querySelectorAll<HTMLElement>(".ov-att-row")];
        expect(items.map(i => i.querySelector(".ov-att-name")!.textContent)).toEqual(["F1 name"]);
        expect(items[0].getAttribute("data-key")).not.toBeNull();
        expect(items[0].getAttribute("tabindex")).toBe("0");
        expect(items[0].textContent).toContain("Financial");
        expect(items[0].querySelector(".ov-att-target")!.textContent).toBe("target ≥ 50.0%");
        expect(att.querySelector(".chip.bad")!.textContent).toBe("1 At risk");
        expect(att.textContent).toContain("2 more KPIs are on watch. Open a pillar to review them.");
    });
    it("never lists a parked or no-data KPI, and orders the at-risk ones by score", () => {
        const rs = labelled([
            ...rows,
            row("F4", "Financial", 1, 0.3, { displayOrder: 4, payload: payload({ state: "Parked" }) }),
            row("F5", "Financial", 1, 0.3, { displayOrder: 5, payload: payload({ state: "" }) }),
            row("C2", "Customer", 2, 0.2, { displayOrder: 2, direction: "lower", payload: ok(40, "At risk") }),
        ]);
        const names = [...draw(rs).querySelectorAll(".ov-att-row .ov-att-name")].map(n => n.textContent);
        expect(names).toEqual(["C2 name", "F1 name"]);
        expect(draw(rs).querySelector('.ov-att-row .ov-att-target')!.textContent).toBe("target ≤ 50.0%");
    });
    it("fills the ring at 100 and prints a score above 100 in full", () => {
        const big = payload({ actual: 1, target: 1, variance: 0, score: 112, state: "On track", weight: 1, trend: [110, 112], scoreTrend: [110, 112] });
        const root = draw(labelled(rows.map(r => ({ ...r, payload: big }))));
        const ring = root.querySelector(".ov-overall svg.ring")!;
        const r = Number(ring.querySelector(".ring-arc")!.getAttribute("r"));
        const dash = ring.querySelector(".ring-arc")!.getAttribute("stroke-dasharray")!.split(" ").map(Number);
        expect(dash[0]).toBeCloseTo(2 * Math.PI * r, 1);
        expect(ring.querySelector(".ring-score")!.textContent).toBe("112");
        expect(ring.getAttribute("aria-label")).toBe("Overall score 112 of 100");
        const bar = root.querySelector(".ov-pillar .ov-bar > i")!.getAttribute("style")!;
        expect(bar).toContain("width:100%");
    });
    it("draws the pillar trends and the deltas with the previous month's name", () => {
        const root = draw();
        expect(root.querySelectorAll(".ov-trend svg path").length).toBeGreaterThanOrEqual(4);
        expect(root.querySelector(".ov-overall .ov-delta")!.textContent).toMatch(/[▲▼] \d+\.\d vs [A-Z][a-z]{2}/);
        expect(root.querySelector(".ov-overall .ov-delta")!.textContent).toBe("▲ 1.0 vs Aug");
        expect(root.querySelectorAll(".ov-pillar svg.spark").length).toBe(4);
        expect(root.querySelector(".ov-trend")!.textContent).toContain("Target 85");
        expect([...root.querySelectorAll(".ov-trend .lc-month")].map(m => m.textContent)).toEqual(["Aug", "Sep"]);
    });
    it("leaves out month names when the label has none, and still draws", () => {
        const root = draw(labelled(rows, "No hospital"));
        expect(root.querySelectorAll(".ov-trend .lc-month").length).toBe(0);
        expect(root.querySelectorAll(".ov-trend svg path").length).toBeGreaterThanOrEqual(4);
        expect(root.querySelector(".ov-overall .ov-delta")!.textContent).toMatch(/^[▲▼] \d+\.\d/);
    });
    it("prints an unchanged score as 0.0 without an arrow", () => {
        const flat = labelled(rows.map(r => ({ ...r, payload: payload({ actual: 1, target: 1, variance: 0, score: 90, state: "On track", weight: 1, trend: [90, 90], scoreTrend: [90, 90] }) })));
        const root = draw(flat);
        const d = root.querySelector(".ov-overall .ov-delta")!;
        expect(d.textContent).toBe("0.0 vs Aug");
        expect(d.classList.contains("flat")).toBe(true);
        expect(root.querySelector(".ov-pillar .ov-delta")!.textContent).toBe("0.0");
    });
    it("shows 85 as on track in the pillar chip, from the rounded score", () => {
        const rs = [row("F1", "Financial", 1, 0.3, { payload: payload({ actual: 1, target: 1, variance: 0, score: 84.6, state: "Watch", weight: 1, trend: [80, 82, 84.6], scoreTrend: [80, 82, 84.6] }) })];
        const card = draw(rs).querySelector(".ov-pillar")!;
        expect(card.querySelector(".ov-score")!.textContent).toBe("85");
        expect(card.querySelector(".chip")!.className).toContain("good");
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
        expect(root.querySelectorAll(".ov-overall").length).toBe(1);
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
    const label = "Corporate · Jan 2026 – Sep 2026";
    const vmOf = (rs: FixtureRow[] = rows) => parseDataView(makeDataView(rs.map(r => ({ ...r, selectionLabel: label }))));
    const fin = (vm: ViewModel) => vm.pillars[0].kpis;
    const keyOf = (r: { rowIndex: number; seriesIndex: number | null }) => selectionKey(r.rowIndex, r.seriesIndex);
    const draw = (rs: FixtureRow[] = rows, objective: string | null = null, selected: string | null = null) => board(vmOf(rs), null, objective, selected);
    const names = (b: HTMLElement) => [...b.querySelectorAll(".bd-tbody > .bd-row .bd-name")].map(n => n.firstChild!.textContent);

    it("lays out the strip, then the table and the panel side by side", () => {
        const b = draw();
        expect(b.classList.contains("bd")).toBe(true);
        expect(b.querySelector(":scope > section.bd-strip")).not.toBeNull();
        expect(b.querySelector(":scope > .bd-body > section.bd-table")).not.toBeNull();
        expect(b.querySelector(":scope > .bd-body > section.bd-panel")).not.toBeNull();
        const panel = b.querySelector(".bd-panel")!;
        expect([...panel.children].map(c => c.className)).toEqual(["bd-panel-main", "bd-slot-chart", "bd-slot-button"]);
        for (const s of [".bd-slot-chart", ".bd-slot-button"]) {
            expect(panel.querySelector(s)!.childNodes.length).toBe(0);
            expect(panel.querySelector(s)!.textContent).toBe("");
        }
    });
    it("the strip shows the breadcrumb, the pillar, its score, weight, status counts and question", () => {
        const strip = draw().querySelector(".bd-strip")!;
        expect(strip.querySelector(".bd-crumb")!.textContent).toBe("Overview › Financial");
        expect(strip.querySelector("h1")!.textContent).toBe("Financial");
        expect(strip.querySelector(".bd-sq")!.getAttribute("style")).toContain("var(--p1)");
        expect(strip.textContent).toContain("Pillar score");
        expect(strip.querySelector(".bd-pscore")!.textContent).toBe("77");
        expect(strip.querySelector(".chip")!.textContent).toBe("Watch");
        expect(strip.querySelector(".bd-weight")!.textContent).toBe("30%");
        expect(strip.textContent).toContain("Weight");
        const counts = strip.querySelector(".bd-counts")!;
        expect(counts.textContent).toContain("On track");
        expect([...counts.children].map(c => c.textContent)).toEqual(["1 On track", "1 Watch", "1 At risk", "0 No data"]);
        expect(counts.querySelectorAll(".mark").length).toBe(4);
        expect(strip.querySelector(".bd-q")!.textContent).toBe("Financial question?");
        expect(strip.querySelector(".bd-delta-label")!.textContent).toBe("vs Aug");
        expect(strip.querySelector(".bd-delta")!.textContent).toBe("▲ 1.0");
    });
    it("the strip prints an unchanged pillar score as 0.0 without an arrow", () => {
        const flat = rows.map(r => ({ ...r, payload: payload({ actual: 1, target: 1, variance: 0, score: 90, state: "On track", weight: 1, trend: [90, 90], scoreTrend: [90, 90] }) }));
        const d = draw(flat).querySelector(".bd-strip .bd-delta")!;
        expect(d.textContent).toBe("0.0");
        expect(d.classList.contains("flat")).toBe(true);
    });
    it("an objective pick narrows the table only; the strip's score stays the pillar's", () => {
        const all = draw();
        const o2 = draw(rows, "O2");
        expect(o2.querySelector(".bd-pscore")!.textContent).toBe(all.querySelector(".bd-pscore")!.textContent);
        expect(o2.querySelector(".bd-counts")!.textContent).toBe(all.querySelector(".bd-counts")!.textContent);
        expect(names(o2)).toEqual(["F3 name"]);
        expect(names(all)).toEqual(["F1 name", "F3 name", "F2 name"]);
    });
    it("the picker lists All objectives and the pillar's objectives in objective order, the pick selected", () => {
        const rs = [...rows, row("F9", "Financial", 1, 0.3, { objectiveCode: "O0", objectiveTitle: "First", objectiveOrder: 0, payload: ok(90) })];
        const sel = draw(rs, "O2").querySelector<HTMLSelectElement>(".bd-table select[data-objective-picker]")!;
        expect(sel.getAttribute("aria-label")).toBe("Objective");
        expect([...sel.options].map(o => [o.value, o.textContent])).toEqual([["", "All objectives"], ["O0", "First"], ["O1", "Obj"], ["O2", "Second"]]);
        expect(sel.value).toBe("O2");
        expect(draw(rs).querySelector<HTMLSelectElement>("select[data-objective-picker]")!.value).toBe("");
        const head = draw().querySelector(".bd-table .bd-thead-row")!;
        expect(head.querySelector("h2")!.textContent).toBe("KPI scorecard");
        expect(head.textContent).toContain("Select a KPI to update the panel · right-click › Drill through for full detail");
    });
    it("orders rows At risk, Watch, On track, then the rest, whatever their objective", () => {
        const rs = [
            row("G", "Financial", 1, 0.3, { objectiveCode: "O0", objectiveOrder: 0, payload: ok(95) }),
            row("N", "Financial", 1, 0.3, { objectiveCode: "O0", objectiveOrder: 0, payload: ok(0, "No target") }),
            row("W", "Financial", 1, 0.3, { objectiveCode: "O1", objectiveOrder: 1, payload: ok(80, "Watch") }),
            row("P", "Financial", 1, 0.3, { objectiveCode: "O0", objectiveOrder: 0, payload: ok(0, "Parked") }),
            row("R", "Financial", 1, 0.3, { objectiveCode: "O2", objectiveOrder: 2, payload: ok(60, "At risk") }),
            row("D", "Financial", 1, 0.3, { objectiveCode: "O0", objectiveOrder: 0, payload: ok(0, "No data yet") }),
        ];
        expect(names(draw(rs))).toEqual(["R name", "W name", "G name", "N name", "D name", "P name"]);
        // the picker keeps objective order
        const sel = draw(rs).querySelector<HTMLSelectElement>("select[data-objective-picker]")!;
        expect([...sel.options].map(o => o.value)).toEqual(["", "O0", "O1", "O2"]);
    });
    it("within a state orders rows by objective, primary first, then display order", () => {
        const rs = [
            row("A", "Financial", 1, 0.3, { objectiveCode: "O2", objectiveOrder: 2, displayOrder: 1, kpiType: "Supporting", payload: ok(90) }),
            row("B", "Financial", 1, 0.3, { objectiveCode: "O2", objectiveOrder: 2, displayOrder: 5, payload: ok(90) }),
            row("C", "Financial", 1, 0.3, { objectiveCode: "O1", objectiveOrder: 1, displayOrder: 9, kpiType: "Supporting", payload: ok(90) }),
            row("D", "Financial", 1, 0.3, { objectiveCode: "O1", objectiveOrder: 1, displayOrder: 3, kpiType: "Supporting", payload: ok(90) }),
        ];
        expect(names(draw(rs))).toEqual(["D name", "C name", "B name", "A name"]);
    });
    it("has seven header cells outside the scrolling body", () => {
        const t = draw().querySelector(".bd-table")!;
        expect([...t.querySelectorAll(".bd-thead > span")].map(s => s.textContent))
            .toEqual(["Status", "KPI · objective", "Actual", "Target", "Variance", "Score", "Trend"]);
        expect(t.querySelector(".bd-tbody .bd-thead")).toBeNull();
    });
    it("a row carries its key, series and tab stop, and seven cells", () => {
        const b = draw();
        const r = b.querySelector<HTMLElement>(".bd-tbody > .bd-row")!;
        expect(r.tagName).toBe("DIV");
        expect(r.getAttribute("data-key")).toBe("1");
        expect(r.hasAttribute("data-series")).toBe(false);
        expect(r.getAttribute("tabindex")).toBe("0");
        expect(r.children.length).toBe(7);
        expect(r.querySelector(".chip.bad")!.textContent).toBe("At risk");
        expect(r.querySelector(".bd-obj")!.textContent).toBe("Obj");
        expect(r.querySelector(".c-actual")!.textContent).toBe("50.0%");
        expect(r.querySelector(".c-target")!.textContent).toBe("≥ 50.0%");
        expect(r.querySelector(".c-score")!.textContent).toBe("60");
        const spark = r.querySelector(".c-trend svg.spark")!;
        expect(spark.getAttribute("width")).toBe("132");
        expect(spark.getAttribute("height")).toBe("42");
    });
    it("with a branch series the rows are the first hospital's, carrying their series index", () => {
        const vm = parseDataView(makeDataView([row("F1", "Financial", 1, 0.3, { payload: [ok(90), ok(60, "At risk")] })], { branches: ["Abha", "Jazan"] }));
        const rs = [...board(vm, null, null, null).querySelectorAll(".bd-row")];
        expect(rs.length).toBe(1);
        expect(rs[0].getAttribute("data-series")).toBe("0");
        expect(rs[0].querySelector(".c-score")!.textContent).toBe("90");
    });
    it("shows ≤ for a lower-is-better target and the variance coloured by state", () => {
        const rs = [row("L1", "Financial", 1, 0.3, { direction: "lower", payload: payload({ actual: 0.3, target: 0.4, variance: 0.25, score: 100, state: "On track", weight: 1, trend: [0.35, 0.3], targetTrend: [0.4, 0.4] }) }),
            row("L2", "Financial", 1, 0.3, { direction: "on_target", displayOrder: 2, payload: payload({ actual: 0.3, target: 0.4, variance: -0.25, score: 70, state: "Watch", weight: 1 }) })];
        const b = draw(rs);
        // the Watch row (L2) goes above the On track one (L1)
        const [r2, r1] = [...b.querySelectorAll(".bd-row")];
        expect(r1.querySelector(".c-target")!.textContent).toBe("≤ 40.0%");
        expect(r1.querySelector(".c-var")!.textContent).toBe("+25.0%");
        expect(r1.querySelector(".c-var")!.classList.contains("good")).toBe(true);
        expect(r2.querySelector(".c-target")!.textContent).toBe("≈ 40.0%");
        expect(r2.querySelector(".c-var")!.textContent).toBe("−25.0%");
        expect(r2.querySelector(".c-var")!.classList.contains("warn")).toBe(true);
    });
    it("a parked row shows its chip, the reason in place of the objective, – for actual and no sparkline", () => {
        const rs = [row("P1", "Financial", 1, 0.3, { kpiStatus: "parked", payload: payload({ state: "Parked" }) })];
        const r = draw(rs).querySelector(".bd-row")!;
        expect(r.querySelector(".chip.nodata")!.textContent).toBe("Parked");
        expect(r.querySelector(".bd-obj")!.textContent).toBe("Definition to be agreed");
        expect(r.querySelector(".c-actual")!.textContent).toBe("–");
        expect(r.querySelector(".c-var")!.textContent).toBe("–");
        expect(r.querySelector(".c-score")!.textContent).toBe("–");
        expect(r.querySelector("svg")).toBeNull();
        expect(r.textContent).not.toContain("NaN");
    });
    it("prints a score above 100 in full", () => {
        const rs = [row("X1", "Financial", 1, 0.3, { payload: payload({ actual: 0.9, target: 0.5, variance: 0.8, score: 130, state: "On track", weight: 1 }) })];
        const b = draw(rs);
        expect(b.querySelector(".bd-row .c-score")!.textContent).toBe("130");
        expect(b.querySelector(".bd-pscore")!.textContent).toBe("130");
    });
    it("tags manual KPIs after the name", () => {
        const rs = [row("M1", "Financial", 1, 0.3, { valueSource: "manual", payload: ok(90) }), row("M2", "Financial", 1, 0.3, { displayOrder: 2, payload: ok(90) })];
        const [m1, m2] = [...draw(rs).querySelectorAll(".bd-row")];
        expect(m1.querySelector(".bd-name .bd-tag")!.textContent).toBe("Manual");
        expect(m2.querySelector(".bd-tag")).toBeNull();
    });
    it("without a selected KPI the panel asks for one", () => {
        const b = draw();
        expect(b.querySelector(".bd-panel-main")!.textContent).toBe("Select a KPI in the table to see its monthly trend and hospitals");
        expect(b.querySelectorAll(".bd-row.selected").length).toBe(0);
    });
    it("the selected row is highlighted and described in the panel, with monthly bars", () => {
        const rs = [...rows, row("T1", "Financial", 1, 0.3, { direction: "lower", displayOrder: 4, objectiveCode: "O2", objectiveTitle: "Second",
            payload: payload({ actual: 0.45, target: 0.5, variance: 0.1, score: 91, state: "On track", weight: 1, trend: [0.6, 0.4, 0.55], targetTrend: [0.5, 0.5, 0.5] }) })];
        const vm = vmOf(rs);
        const t1 = fin(vm).find(k => k.code === "T1")!;
        const b = board(vm, null, null, keyOf(t1));
        const sel = [...b.querySelectorAll<HTMLElement>(".bd-row.selected")];
        expect(sel.length).toBe(1);
        expect(sel[0].getAttribute("data-key")).toBe(String(t1.rowIndex));
        const main = b.querySelector(".bd-panel-main")!;
        expect(main.textContent).toContain("Selected KPI");
        expect(main.querySelector("h2")!.textContent).toBe("T1 name");
        expect(main.querySelector(".bd-sub")!.textContent).toBe("Second · Lower is better");
        expect(main.textContent).toContain("45.0%");
        expect(main.textContent).toContain("91");
        expect(main.textContent).toContain("On track");
        expect(main.textContent).toContain("Monthly trend vs target");
        const bars = [...main.querySelectorAll("svg.bd-bars rect.bd-bar")];
        expect(bars.length).toBe(3);
        expect(bars.map(r => r.getAttribute("fill") === "#F5B865")).toEqual([true, false, true]);
        expect(main.querySelector("svg.bd-bars path.bd-tline")!.getAttribute("stroke-dasharray")).not.toBeNull();
        expect([...main.querySelectorAll(".bd-months > span")].map(m => m.textContent)).toEqual(["J", "A", "S"]);
    });
    it("the panel describes a KPI without a score by its chip and reason, with – values and no bars", () => {
        const rs = [row("N1", "Financial", 1, 0.3, { valueSource: "manual", payload: payload({ state: "" }) })];
        const vm = vmOf(rs);
        const main = board(vm, null, null, keyOf(fin(vm)[0])).querySelector(".bd-panel-main")!;
        expect(main.querySelector("h2")!.textContent).toBe("N1 name");
        expect(main.querySelector(".bd-sub")!.textContent).toBe("Obj · Higher is better");
        expect(main.querySelector(".chip.nodata")!.textContent).toBe("No data yet");
        expect(main.textContent).toContain("Waiting for this month's entry");
        expect([...main.querySelectorAll(".bd-fact-v")].map(v => v.textContent)).toEqual(["–", "–", "–"]);
        expect(main.querySelector("svg")).toBeNull();
    });
    it("a key that is not in the pillar leaves the panel empty", () => {
        const vm = vmOf();
        const c1 = vm.pillars[1].kpis[0];
        expect(board(vm, null, null, keyOf(c1)).querySelector(".bd-panel-main")!.textContent).toContain("Select a KPI");
    });
    it("monthlyBars draws one bar per month: met in the pillar colour, missed in the Watch tint, the target as a dashed step", () => {
        const vm = vmOf([row("B1", "Financial", 1, 0.3, { payload: payload({ actual: 0.5, target: 0.5, variance: 0, score: 85, state: "On track", weight: 1,
            trend: [0.5, null, 0.3, 0.6], targetTrend: [0.5, 0.5, 0.5, 0.55] }) })]);
        const s = monthlyBars(fin(vm)[0], 600, 120, "var(--p2)");
        const bars = [...s.querySelectorAll("rect.bd-bar")];
        expect(bars.length).toBe(3);
        expect(bars[0].getAttribute("style")).toContain("var(--p2)");
        expect(bars[1].getAttribute("fill")).toBe("#F5B865");
        expect(bars[1].classList.contains("missed")).toBe(true);
        expect(s.getAttribute("width")).toBe("600");
        const d = s.querySelector("path.bd-tline")!.getAttribute("d")!;
        expect(d.startsWith("M")).toBe(true);
        expect(s.outerHTML).not.toContain("NaN");
        for (const r of bars) {
            const y = Number(r.getAttribute("y")), h = Number(r.getAttribute("height"));
            expect(y).toBeGreaterThanOrEqual(0);
            expect(y + h).toBeLessThanOrEqual(120);
        }
    });
    it("renders through renderView in board mode, following ui.pillar", () => {
        const root = mount();
        renderView(root, vmOf(), "board", ui({ pillar: "Customer", showHeader: false }));
        expect(root.querySelector(".bd-strip h1")!.textContent).toBe("Customer");
        expect(root.querySelectorAll(".bd-row").length).toBe(1);
        expect(root.querySelector(".tabs")).toBeNull();
    });
    it("keeps the header title rule: the pillar name by default, a custom title when set", () => {
        const a = mount();
        renderView(a, vmOf(), "board", ui());
        expect(a.querySelector(".band h1")!.textContent).toBe("Financial");
        expect(a.querySelector(".band .sub")!.textContent).toBe("Financial question?");
        const b = mount();
        renderView(b, vmOf(), "board", ui({ title: "Group view" }));
        expect(b.querySelector(".band h1")!.textContent).toBe("Group view");
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
    it("each card says its achievement state with a chip: 100% and over On track, 85-99% Watch, under 85% At risk", () => {
        const root = draw();
        const chip = (c: HTMLElement) => c.querySelector(".chip")!;
        expect(chip(cards(root)[2]).textContent).toBe("On track");
        expect(chip(cards(root)[2]).querySelector(".mark.good")).not.toBeNull();
        expect(chip(cards(root)[0]).textContent).toBe("Watch");
        expect(chip(cards(draw({ score: "hitrate" }))[2]).textContent).toBe("At risk");
        expect(cards(root)[2].getAttribute("aria-label")).toBe("CFO: achievement 105%, On track, 2 of 2 KPIs scored");
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
