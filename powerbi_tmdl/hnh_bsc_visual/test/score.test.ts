import { describe, it, expect } from "vitest";
import { pillarScore, overallScore, pillarTrend, objectiveScore, overallTrend } from "../src/model/score";
import type { KpiRow, PillarSummary } from "../src/model/types";

const r = (score: number | null, weight: number | null, scoreTrend: (number | null)[] = []) =>
    ({ score, weight, scoreTrend }) as unknown as KpiRow;

describe("score", () => {
    it("pillarScore is the weighted mean over scored rows with weight > 0", () => {
        expect(pillarScore([r(80, 1), r(90, 3), r(null, 5), r(10, 0), r(20, null)])).toBeCloseTo(87.5);
    });
    it("pillarScore is null when nothing is scored", () => {
        expect(pillarScore([r(null, 1), r(50, 0)])).toBeNull();
        expect(pillarScore([])).toBeNull();
    });
    it("objectiveScore is the weighted mean of the objective's KPI scores, same rule as the pillar", () => {
        expect(objectiveScore([r(80, 2), r(50, 1), r(null, 4), r(100, 0)])).toBeCloseTo(70);
        expect(objectiveScore([r(null, 1)])).toBeNull();
    });
    it("overallScore weights the pillars that have a score", () => {
        const p = (score: number | null, weight: number) => ({ score, weight }) as PillarSummary;
        expect(overallScore([p(80, 0.3), p(60, 0.2), p(null, 0.5)])).toBeCloseTo(72);
        expect(overallScore([p(null, 1)])).toBeNull();
    });
    it("pillarTrend works month by month", () => {
        const t = pillarTrend([r(0, 1, [10, null, 30]), r(0, 1, [20, null, null])]);
        expect(t).toEqual([15, null, 30]);
        expect(pillarTrend([])).toEqual([]);
    });
    it("overallTrend is the pillar-weighted mean month by month", () => {
        const p = (weight: number, trend: (number | null)[]) => ({ weight, trend }) as unknown as PillarSummary;
        expect(overallTrend([p(0.3, [80, 90]), p(0.7, [60, null])])).toEqual([66, 90]);
        expect(overallTrend([])).toEqual([]);
    });
});
