import { describe, it, expect } from "vitest";
import { varianceOf, kpiScoreOf, met, bandEdges } from "../src/model/bands";
import type { KpiRow } from "../src/model/types";

const row = (direction: string, o: Partial<KpiRow> = {}) =>
    ({ direction, scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70, ...o }) as KpiRow;

describe("bands", () => {
    it("varianceOf follows the model", () => {
        expect(varianceOf(120, 100, "higher")).toBeCloseTo(0.2);
        expect(varianceOf(4, 5, "lower")).toBeCloseTo(0.2);
        expect(varianceOf(3, 5, "on_target")).toBeCloseTo(-0.4);
        expect(varianceOf(3, 0, "higher")).toBe(3);
    });
    it("kpiScoreOf is not clamped", () => {
        expect(kpiScoreOf(row("higher"), 120, 100)).toBe(97);
        expect(kpiScoreOf(row("higher"), 300, 100)).toBe(205);
    });
    it("met compares with goodFrom", () => {
        expect(met(row("lower"), 4, 5)).toBe(true);
        expect(met(row("lower"), 6, 5)).toBe(false);
    });
    it("bandEdges per direction", () => {
        const h = bandEdges(row("higher"), 100)!;
        expect(h.kind).toBe("above");
        expect(h.good).toBeCloseTo(99.1667, 4);
        expect(h.watch).toBeCloseTo(74.1667, 4);
        const l = bandEdges(row("lower"), 0.05)!;
        expect(l.kind).toBe("below");
        expect(l.good).toBeCloseTo(0.050417, 6);
        expect(l.watch).toBeCloseTo(0.062917, 6);
        const o = bandEdges(row("on_target"), 4)!;
        expect(o.kind).toBe("around");
        expect(o.good).toBeCloseTo(0.0333, 4);
        expect(o.watch).toBeCloseTo(1.0333, 4);
    });
    it("bandEdges sit at the rounded-score boundary, so an actual the model calls On track is inside the On track band", () => {
        const h = row("higher");
        expect(kpiScoreOf(h, 81.6, 82.1)).toBe(85);
        expect(met(h, 81.6, 82.1)).toBe(true);
        expect(81.6).toBeGreaterThanOrEqual(bandEdges(h, 82.1)!.good);
        // Just past each edge the rounded score changes state, in every direction.
        const e = bandEdges(h, 100)!;
        expect(kpiScoreOf(h, e.good + 1e-6, 100)).toBe(85);
        expect(kpiScoreOf(h, e.good - 1e-6, 100)).toBe(84);
        expect(kpiScoreOf(h, e.watch + 1e-6, 100)).toBe(70);
        expect(kpiScoreOf(h, e.watch - 1e-6, 100)).toBe(69);
        const lo = row("lower"), le = bandEdges(lo, 0.05)!;
        expect(met(lo, le.good - 1e-9, 0.05)).toBe(true);
        expect(met(lo, le.good + 1e-9, 0.05)).toBe(false);
        const on = row("on_target", { scoreBase: 100 }), oe = bandEdges(on, 4)!;
        expect(met(on, 4 + oe.good - 1e-9, 4)).toBe(true);
        expect(met(on, 4 + oe.good + 1e-9, 4)).toBe(false);
    });
    it("bandEdges is null without a slope or a finite target", () => {
        expect(bandEdges(row("higher", { scoreSlope: 0 }), 100)).toBeNull();
        expect(bandEdges(row("higher"), NaN)).toBeNull();
    });
});
