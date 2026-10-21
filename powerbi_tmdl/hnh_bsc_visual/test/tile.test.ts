// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { tile } from "../src/render/tile";
import { stateChip, statusStrip } from "../src/render/chips";
import type { KpiRow } from "../src/model/types";

function row(o: Partial<KpiRow> = {}): KpiRow {
    return {
        code: "K1", name: "Net revenue", shortLabel: "Revenue", pillar: "Financial", pillarOrder: 1, pillarWeight: 0.3,
        pillarQuestion: "", objectiveCode: "F1", objectiveTitle: "Grow", objectiveOrder: 1, primary: true,
        direction: "lower", valueFormat: "pct", displayOrder: 1, manual: false, parkedInCatalogue: false, owner: "CFO",
        actual: 0.42, target: 0.4, variance: 0.05, score: 87.4, weight: 1, state: "good", stateWord: "On track", reason: null,
        trend: [0.3, 0.4, 0.42], targetTrend: [0.4, 0.4, 0.4], scoreTrend: [], branch: null, rowIndex: 7, seriesIndex: null, ...o,
    };
}

describe("tile", () => {
    it("renders an on-track primary KPI", () => {
        const t = tile(row());
        expect(t.classList.contains("primary")).toBe(true);
        expect(t.getAttribute("data-key")).toBe("7");
        expect(t.hasAttribute("data-series")).toBe(false);
        expect(t.getAttribute("tabindex")).toBe("0");
        const text = t.textContent ?? "";
        expect(text).toContain("42.0%");
        expect(text).toContain("Target 40.0%");
        expect(text).toContain("lower is better");
        expect(text).toContain("CFO");
        expect(text).toContain("Score 87");
        expect(text).not.toContain("Manual entry");
        const v = t.querySelector(".var")!;
        expect(v.classList.contains("good")).toBe(true);
        expect(v.textContent).toContain("✓");
        expect(v.textContent).toBe("✓ On track · +5.0%");
    });
    it("shows the manual badge and series index", () => {
        const t = tile(row({ manual: true, seriesIndex: 2 }));
        expect(t.textContent).toContain("Manual entry");
        expect(t.getAttribute("data-series")).toBe("2");
    });
    it("shows the reason, no number, for a nodata tile", () => {
        const t = tile(row({ state: "nodata", stateWord: "No data yet", actual: null, variance: null, score: null, trend: [], targetTrend: [], reason: "Waiting for this month's entry" }));
        expect(t.classList.contains("nodata")).toBe(true);
        const text = t.textContent ?? "";
        expect(text).toContain("Waiting for this month's entry");
        expect(text).not.toContain("NaN");
        expect(text).not.toMatch(/(^|[^\d.])0([^\d.%]|$)/);
        expect(text).not.toContain("Score");
    });
    it("handles parked and notarget without numbers", () => {
        const p = tile(row({ state: "parked", stateWord: "Parked", actual: null, target: null, variance: null, score: null, reason: "Definition to be agreed" }));
        expect(p.classList.contains("nodata")).toBe(true);
        expect(p.textContent).toContain("Definition to be agreed");
        const n = tile(row({ state: "notarget", stateWord: "No target", target: null, variance: null, score: null }));
        expect(n.classList.contains("nodata")).toBe(true);
        expect(n.textContent).not.toContain("NaN");
        expect(n.textContent).toContain("No target");
    });
});

describe("chips", () => {
    it("builds a state chip with icon, word and text", () => {
        const c = stateChip("bad", "At risk", "3");
        expect(c.className).toContain("chip");
        expect(c.classList.contains("bad")).toBe(true);
        expect(c.textContent).toBe("▼ 3 At risk");
        expect(stateChip("parked", "Parked").classList.contains("nodata")).toBe(true);
    });
    it("builds a status strip with one cell per row", () => {
        const s = statusStrip([row(), row({ state: "warn", stateWord: "Watch", rowIndex: 8 })]);
        expect(s.classList.contains("strip")).toBe(true);
        const cells = s.querySelectorAll("i");
        expect(cells.length).toBe(2);
        expect(cells[1].classList.contains("warn")).toBe(true);
        expect(cells[1].getAttribute("data-key")).toBe("8");
        expect(cells[0].getAttribute("role")).toBe("img");
        expect(cells[0].getAttribute("aria-label")).toBe("Net revenue: On track");
    });
});
