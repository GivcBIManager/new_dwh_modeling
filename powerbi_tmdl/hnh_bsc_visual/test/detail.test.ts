// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { renderView, type UiState } from "../src/render/index";
import { detail, bandChart } from "../src/render/detail";
import { parseDataView } from "../src/model/parse";
import { makeDataView, payload, FixtureRow } from "./fixtures";

const base = { kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure",
    scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70 };
const ui = (o: Partial<UiState> = {}): UiState => ({ pillar: null, compareLevel: { pillar: null, objective: null }, objective: null, title: "Balanced scorecard", subtitle: "", showHeader: false, ...o });
const LABEL = "Corporate · Jan 2026 – Sep 2026";
const months12 = (v: number) => Array.from({ length: 12 }, (_, i) => v + i * 0.01);

function row(code: string, extra: FixtureRow = {}): FixtureRow {
    return { ...base, kpi: code, kpiName: code + " name", shortLabel: code, pillar: "Financial", pillarOrder: 1, pillarWeight: 0.3, pillarQuestion: "Q?",
        objectiveCode: "O1", objectiveTitle: "Protect the revenue cycle", objectiveOrder: 1, displayOrder: 1, owner: "CFO", coOwners: "COO|CMO",
        definition: "Share of claims paid at first submission", targetBasis: "Budget 2026", selectionLabel: LABEL,
        payload: payload({ actual: 0.45, target: 0.5, variance: -0.1, score: 79, state: "Watch", weight: 0.25,
            trend: months12(0.4), targetTrend: Array(12).fill(0.5), scoreTrend: Array(12).fill(79) }), ...extra };
}
const vmOf = (rs: FixtureRow[]) => parseDataView(makeDataView(rs));
const draw = (rs: FixtureRow[] = [row("F1")]) => detail(vmOf(rs));
const dd = (root: HTMLElement, term: string) => {
    const dt = [...root.querySelectorAll(".dt-profile dt")].find(d => d.textContent === term);
    return dt ? (dt.nextElementSibling as HTMLElement).textContent : null;
};
const bands = (root: HTMLElement) => [...root.querySelectorAll(".dt-bands li")].map(li => li.textContent);

describe("KPI detail", () => {
    it("renders in mode detail instead of the overview", () => {
        const root = document.createElement("div");
        renderView(root, vmOf([row("F1")]), "detail", ui());
        expect(root.querySelector(".dt")).not.toBeNull();
        expect(root.querySelector(".ov")).toBeNull();
        expect(root.classList.contains("detail")).toBe(true);
        renderView(root, vmOf([row("F1")]), "overview", ui());
        expect(root.classList.contains("detail")).toBe(false);
    });
    it("draws the sub-bar, then the profile and the trend panel", () => {
        const d = draw();
        expect(d.querySelector(":scope > .dt-sub")).not.toBeNull();
        const body = d.querySelector(":scope > .dt-body")!;
        expect(body.querySelector(":scope > section.dt-profile")).not.toBeNull();
        expect(body.querySelector(":scope > section.dt-trend")).not.toBeNull();
        expect(body.children.length).toBe(2);
    });
    it("the sub-bar shows the breadcrumb and the KPI, period and hospital chips", () => {
        const sub = draw().querySelector(".dt-sub")!;
        expect(sub.querySelector(".dt-crumb")!.textContent).toBe("Overview › Financial › F1 name");
        const chips = [...sub.querySelectorAll(".dt-chip")].map(c => c.textContent);
        expect(chips).toEqual(["F1 name", "Jan 2026 – Sep 2026", "Corporate"]);
    });
    it("a label without a period gives one chip for it; an empty label none", () => {
        const one = [...draw([row("F1", { selectionLabel: "No hospital" })]).querySelectorAll(".dt-chip")].map(c => c.textContent);
        expect(one).toEqual(["F1 name", "No hospital"]);
        const none = [...draw([row("F1", { selectionLabel: null })]).querySelectorAll(".dt-chip")].map(c => c.textContent);
        expect(none).toEqual(["F1 name"]);
    });
    it("the profile names the pillar, objective and KPI, the actual in the state colour, the chip and the target line", () => {
        const p = draw().querySelector(".dt-profile")!;
        expect(p.querySelector(".dt-eyebrow")!.textContent).toBe("Financial · Protect the revenue cycle");
        expect(p.querySelector(".dt-eyebrow .dt-sq")!.getAttribute("style")).toContain("var(--p1)");
        expect(p.querySelector("h1")!.textContent).toBe("F1 name");
        const actual = p.querySelector(".dt-actual")!;
        expect(actual.textContent).toBe("45.0%");
        expect(actual.classList.contains("warn")).toBe(true);
        expect(p.querySelector(".chip.warn")!.textContent).toBe("Watch");
        expect(p.querySelector(".dt-tline-text")!.textContent).toBe("Target ≥ 50.0% · −10.0% · score 79");
    });
    it("a score above 100 prints in full", () => {
        const d = draw([row("F1", { payload: payload({ actual: 0.7, target: 0.5, variance: 0.4, score: 124, state: "On track", weight: 1 }) })]);
        expect(d.querySelector(".dt-tline-text")!.textContent).toContain("score 124");
    });
    it("the definition list carries the definition, polarity, target basis, weight, owners and source", () => {
        const d = draw();
        expect(dd(d, "Definition")).toBe("Share of claims paid at first submission");
        expect(dd(d, "Better when")).toBe("Higher is better");
        expect(dd(d, "Target basis")).toBe("Budget 2026");
        expect(dd(d, "Weight")).toBe("25.0%");
        expect(dd(d, "Owner")).toBe("CFO");
        expect(dd(d, "Co-owners")).toBe("COO, CMO");
        expect(dd(d, "Source")).toBe("Calculated");
    });
    it("blank facts read as a dash", () => {
        const d = draw([row("F1", { definition: null, targetBasis: null, coOwners: null, owner: null })]);
        for (const t of ["Definition", "Target basis", "Owner", "Co-owners"]) expect(dd(d, t)).toBe("–");
    });
    it("performance bands for a higher-is-better KPI are in its units", () => {
        const d = draw();
        expect(d.querySelector(".dt-profile h2")!.textContent).toBe("Performance bands");
        expect(bands(d)).toEqual(["On track ≥ 50.0%", "Watch 37.5% – 50.0%", "At risk < 37.5%"]);
        expect(d.querySelectorAll(".dt-bands li .mark").length).toBe(3);
    });
    it("a lower-is-better KPI mirrors them", () => {
        const d = draw([row("F1", { direction: "lower" })]);
        expect(bands(d)).toEqual(["On track ≤ 50.0%", "Watch 50.0% – 62.5%", "At risk > 62.5%"]);
    });
    it("an on-target KPI shows its bands within ± of the target", () => {
        const d = draw([row("F1", { direction: "on_target", scoreBase: 100 })]);
        expect(bands(d)).toEqual(["On track within ± 12.5%", "Watch within ± 25.0%", "At risk beyond ± 25.0%"]);
    });
    it("a KPI without a target has no performance bands, no band rects, its chip and reason and dashes", () => {
        const d = draw([row("F1", { payload: payload({ actual: 0.45, state: "No target", weight: 1, trend: months12(0.4), targetTrend: Array(12).fill(null) }) })]);
        expect([...d.querySelectorAll(".dt-profile h2")].map(h => h.textContent)).not.toContain("Performance bands");
        expect(d.querySelector(".dt-bands")).toBeNull();
        expect(d.querySelectorAll(".dt-band").length).toBe(0);
        expect(d.querySelector(".dt-profile .chip.nodata")!.textContent).toBe("No target");
        expect(d.querySelector(".dt-tline-text")!.textContent).toBe("Target – · – · score –");
    });
    it("a KPI with no data yet shows its reason and no actual", () => {
        const d = draw([row("F1", { payload: payload({ target: 0.5, state: "", weight: 1 }) })]);
        expect(d.querySelector(".dt-actual")!.textContent).toBe("–");
        expect(d.querySelector(".dt-why")!.textContent).toBe("Not yet calculated for this selection");
        expect(d.querySelector(".dt-bands")).toBeNull();
    });
    it("a manual KPI shows Manual entry and its note", () => {
        const d = draw([row("F1", { valueSource: "manual", manualNote: "Entered by the finance team" })]);
        expect(dd(d, "Source")).toBe("Manual entry");
        const note = d.querySelector(".dt-note")!;
        expect(note.textContent).toContain("Manual entry note");
        expect(note.textContent).toContain("Entered by the finance team");
        expect(draw().querySelector(".dt-note")).toBeNull();
    });
    it("with more than one KPI it shows the first and says so", () => {
        const d = draw([row("F2", { kpiType: "Supporting" }), row("F1")]);
        expect(d.querySelector(".dt-profile h1")!.textContent).toBe("F1 name");
        expect(d.querySelector(".dt-sub [role=note]")!.textContent).toBe("Showing F1 name; open KPI detail from one KPI");
        expect(draw().querySelector("[role=note]")).toBeNull();
    });
    it("the trend panel has its heading, keys and the band chart with month labels", () => {
        const t = draw().querySelector(".dt-trend")!;
        expect(t.querySelector("h2")!.textContent).toBe("Monthly trend with performance bands");
        expect(t.textContent).toContain("Actual");
        expect(t.textContent).toContain("Target");
        expect(t.querySelector("svg.dt-chart-svg")).not.toBeNull();
        const m = [...t.querySelectorAll("svg .dt-month")].map(x => x.textContent);
        expect(m).toEqual(["Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep"]);
    });
});

describe("bandChart", () => {
    const kpi = (extra: FixtureRow = {}) => vmOf([row("F1", extra)]).pillars[0].kpis[0];
    const M = ["Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep"];
    it("draws three bands per month for a 12-month trend, in the state tints", () => {
        const s = bandChart(kpi(), M, 1278, 288);
        const rects = [...s.querySelectorAll("rect.dt-band")];
        expect(rects.length).toBe(36);
        expect(new Set(rects.map(r => r.getAttribute("fill")))).toEqual(new Set(["#E3F6F3", "#FFF2E0", "#FDE9E5"]));
        expect(rects.filter(r => r.classList.contains("good")).length).toBe(12);
    });
    it("draws the actual line in the dark blue with a dot per month, and the dashed monthly target", () => {
        const s = bandChart(kpi(), M, 1278, 288);
        const line = s.querySelector("path.dt-line")!;
        expect(line.getAttribute("style")).toContain("var(--blue-dk)");
        expect(s.querySelectorAll("circle.dt-dot").length).toBe(12);
        expect(s.querySelector("path.dt-tline")!.getAttribute("stroke-dasharray")).not.toBeNull();
        expect(s.querySelectorAll(".dt-y").length).toBeGreaterThan(1);
    });
    it("months without a target draw no bands", () => {
        const t = Array(12).fill(0.5); t[0] = null; t[5] = null;
        const s = bandChart(kpi({ payload: payload({ actual: 0.45, target: 0.5, score: 79, state: "Watch", weight: 1, trend: months12(0.4), targetTrend: t }) }), M, 1278, 288);
        expect(s.querySelectorAll("rect.dt-band").length).toBe(30);
    });
    it("an on-target KPI draws a centred band around each month's target", () => {
        const s = bandChart(kpi({ direction: "on_target", scoreBase: 100 }), M, 1278, 288);
        const good = s.querySelector("rect.dt-band.good")!, watch = s.querySelector("rect.dt-band.warn")!;
        const mid = (r: Element) => Number(r.getAttribute("y")) + Number(r.getAttribute("height")) / 2;
        expect(Math.abs(mid(good) - mid(watch))).toBeLessThan(0.2);
        expect(Number(watch.getAttribute("height"))).toBeGreaterThan(Number(good.getAttribute("height")));
    });
    it("leaves the month labels out without months, and never leaves the plot with extreme values", () => {
        const s = bandChart(kpi({ payload: payload({ actual: 5, target: 0.5, score: 300, state: "On track", weight: 1, trend: [-2, 0.5, 9], targetTrend: [0.5, 0.5, 0.5] }) }), [], 600, 200);
        expect(s.querySelectorAll(".dt-month").length).toBe(0);
        for (const c of s.querySelectorAll("circle.dt-dot")) {
            const y = Number(c.getAttribute("cy"));
            expect(y).toBeGreaterThanOrEqual(0);
            expect(y).toBeLessThanOrEqual(200);
        }
        for (const r of s.querySelectorAll("rect.dt-band")) expect(Number(r.getAttribute("height"))).toBeGreaterThanOrEqual(0);
    });
});

describe("KPI detail geometry", () => {
    const css = readFileSync("style/visual.less", "utf8");
    it("a 78 px sub-bar whose text keeps clear of the native buttons (x 150 to 1570)", () => {
        expect(css).toMatch(/\.dt-sub\{[^}]*height:78px/);
        expect(css).toMatch(/\.dt-sub\{[^}]*padding:0 350px 0 150px/);
    });
    it("the profile (510 wide, from y 102) beside the 390 px trend panel, the lower right left empty", () => {
        expect(css).toMatch(/\.dt-body\{[^}]*grid-template-columns:510px minmax\(0,1fr\)/);
        expect(css).toMatch(/\.dt-body\{[^}]*grid-template-rows:390px minmax\(0,1fr\)/);
        expect(css).toMatch(/\.dt-body\{[^}]*gap:24px/);
        expect(css).toMatch(/\.dt-body\{[^}]*padding:24px 30px/);
        expect(css).toMatch(/\.dt-profile\{[^}]*grid-row:1\/-1/);
        expect(css).toMatch(/\.hnh-bsc\.detail\{[^}]*background:transparent/);
    });
});
