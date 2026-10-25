import { describe, it, expect } from "vitest";
import {
    CSUITE, isCsuite, varianceUnit, ceilingUnit, isBudgetVariance, unitScore, canJudge, onTarget,
    weightedAchievement, hitRate, achievement, kpisOf, ownersOf, ownerCards,
} from "../src/model/achievement";
import type { KpiRow } from "../src/model/types";

let n = 0;
/** A KPI row with data: state "good", weight 1, direction higher. */
function k(o: Partial<KpiRow> = {}): KpiRow {
    n++;
    return {
        code: `K${n}`, name: `KPI ${n}`, shortLabel: "", pillar: "Financial", pillarOrder: 1, pillarWeight: 0.3, pillarQuestion: "",
        objectiveCode: "O1", objectiveTitle: "", objectiveOrder: 1, primary: true, direction: "higher", valueFormat: "pct",
        displayOrder: n, manual: false, parkedInCatalogue: false, owner: "CEO", coOwners: [],
        actual: 1, target: 1, variance: 0, score: 85, weight: 1, state: "good", stateWord: "On track", reason: null,
        trend: [], targetTrend: [], scoreTrend: [], branch: null, rowIndex: n, seriesIndex: null, ...o,
    };
}

describe("unit score (handover _v9KpiUnitScore)", () => {
    it("higher is better: actual / target, no cap", () => {
        expect(unitScore(k({ actual: 0.9, target: 1 }))).toBeCloseTo(0.9);
        expect(unitScore(k({ actual: 126, target: 100 }))).toBeCloseTo(1.26);
    });
    it("higher: no score without a positive target", () => {
        expect(unitScore(k({ actual: 5, target: 0 }))).toBeNull();
        expect(unitScore(k({ actual: 5, target: -2 }))).toBeNull();
    });
    it("an unknown or empty direction counts as higher", () => {
        expect(unitScore(k({ direction: "", actual: 3, target: 4 }))).toBeCloseTo(0.75);
    });
    it("lower is better: target / actual, both positive", () => {
        expect(unitScore(k({ direction: "lower", actual: 20, target: 18 }))).toBeCloseTo(0.9);
        expect(unitScore(k({ direction: "lower", actual: 9, target: 18 }))).toBeCloseTo(2);
        expect(unitScore(k({ direction: "lower", actual: 0, target: 0.094 }))).toBeNull();
        expect(unitScore(k({ direction: "lower", actual: -1, target: 5 }))).toBeNull();
    });
    it("ceiling: 1 at or under the target, target / actual above it", () => {
        expect(unitScore(k({ direction: "ceiling", actual: 0.02, target: 0.03 }))).toBe(1);
        expect(unitScore(k({ direction: "ceiling", actual: 0.03, target: 0.03 }))).toBe(1);
        expect(unitScore(k({ direction: "ceiling", actual: 0.04, target: 0.02 }))).toBeCloseTo(0.5);
        expect(unitScore(k({ direction: "ceiling", actual: 0.01, target: 0 }))).toBeNull();
    });
    it("on target: 1 - |a - t| / |t|, floored at 0 (then unscoreable), no score at target 0", () => {
        expect(unitScore(k({ direction: "on_target", actual: 0.7, target: 0.8 }))).toBeCloseTo(0.875);
        expect(unitScore(k({ direction: "on_target", actual: 0.9, target: 0.8 }))).toBeCloseTo(0.875);
        expect(unitScore(k({ direction: "on_target", actual: 2, target: 0.8 }))).toBeNull();
        expect(unitScore(k({ direction: "on_target", actual: 1, target: 0 }))).toBeNull();
    });
    it("budget variance by name: 1 - (actual - target), whatever the direction", () => {
        const r = k({ name: "Budget Variance (Cost Budget)", direction: "lower", actual: 0.03, target: 0.05 });
        expect(isBudgetVariance(r)).toBe(true);
        expect(unitScore(r)).toBeCloseTo(1.02);
        expect(unitScore(k({ name: "budget variance %", direction: "higher", actual: 0.1, target: 0 }))).toBeCloseTo(0.9);
    });
    it("budget variance by direction lower with target 0", () => {
        const r = k({ name: "Cost overrun", direction: "lower", actual: 0.04, target: 0 });
        expect(isBudgetVariance(r)).toBe(true);
        expect(unitScore(r)).toBeCloseTo(0.96);
        expect(unitScore(k({ direction: "lower", actual: -0.05, target: 0 }))).toBeCloseTo(1.05);
        expect(isBudgetVariance(k({ direction: "lower", target: 0.1 }))).toBe(false);
        expect(isBudgetVariance(k({ direction: "higher", target: 0 }))).toBe(false);
    });
    it("variance: values above 1.5 are read as percentages; a unit at or below 0 becomes 0.01", () => {
        expect(varianceUnit(3, 0)).toBeCloseTo(0.97);
        expect(varianceUnit(0.03, 0)).toBeCloseTo(0.97);
        expect(varianceUnit(1.4, 0)).toBeCloseTo(0.01);
        expect(varianceUnit(250, 0)).toBeCloseTo(0.01);
    });
    it("ceiling helper: percentage scaling does not change the ratio", () => {
        expect(ceilingUnit(4, 2)).toBeCloseTo(0.5);
        expect(ceilingUnit(0.04, 0.02)).toBeCloseTo(0.5);
        expect(ceilingUnit(1, 2)).toBe(1);
        expect(ceilingUnit(1, 0)).toBeNull();
    });
    it("a readmission KPI follows its configured direction, not its name", () => {
        expect(unitScore(k({ name: "30-Day Readmission Rate", direction: "lower", actual: 0.04, target: 0.02 }))).toBeCloseTo(0.5);
        expect(unitScore(k({ name: "30-Day Readmission Rate", direction: "lower", actual: 0.01, target: 0.02 }))).toBeCloseTo(2);
        expect(unitScore(k({ name: "30-Day Readmission Rate", direction: "ceiling", actual: 0.01, target: 0.02 }))).toBe(1);
    });
    it("no score without actual or target, or for a parked or no-data row", () => {
        expect(unitScore(k({ actual: null }))).toBeNull();
        expect(unitScore(k({ target: null }))).toBeNull();
        expect(unitScore(k({ actual: Number.NaN }))).toBeNull();
        expect(unitScore(k({ state: "parked" }))).toBeNull();
        expect(unitScore(k({ state: "nodata" }))).toBeNull();
    });
});

describe("weighted achievement", () => {
    it("is the weight-weighted mean of unit scores, in percent", () => {
        const rows = [k({ actual: 1.2, target: 1, weight: 3 }), k({ actual: 0.6, target: 1, weight: 1 })];
        expect(weightedAchievement(rows)).toBeCloseTo(105);
    });
    it("leaves out unscoreable KPIs and KPIs without a positive weight", () => {
        const rows = [k({ actual: 0.9, target: 1, weight: 2 }), k({ actual: null, weight: 5 }), k({ actual: 0.1, target: 1, weight: null }),
            k({ actual: 0.1, target: 1, weight: 0 })];
        expect(weightedAchievement(rows)).toBeCloseTo(90);
    });
    it("is null when nothing is scoreable", () => {
        expect(weightedAchievement([k({ actual: null })])).toBeNull();
        expect(weightedAchievement([])).toBeNull();
    });
});

describe("hit rate (handover _kpiCanJudge / _kpiOnTarget)", () => {
    it("is the share of judgeable KPIs with a direction-adjusted variance of 0 or more", () => {
        const rows = [k({ variance: 0.05 }), k({ variance: 0 }), k({ variance: -0.01 }), k({ variance: -0.3 })];
        expect(hitRate(rows)).toBe(50);
    });
    it("judges only KPIs with an actual and a target", () => {
        expect(canJudge(k({ actual: null, variance: 0.1 }))).toBe(false);
        expect(canJudge(k({ target: null, variance: 0.1 }))).toBe(false);
        expect(canJudge(k({ state: "parked" }))).toBe(false);
        expect(hitRate([k({ variance: 0.1 }), k({ actual: null, variance: -0.5 })])).toBe(100);
        expect(hitRate([k({ actual: null })])).toBeNull();
    });
    it("without a variance compares actual with target in the KPI's direction", () => {
        expect(onTarget(k({ variance: null, actual: 5, target: 4 }))).toBe(true);
        expect(onTarget(k({ variance: null, direction: "lower", actual: 5, target: 4 }))).toBe(false);
        expect(onTarget(k({ variance: null, direction: "ceiling", actual: 4, target: 4 }))).toBe(true);
    });
    it("achievement() switches between the two", () => {
        const rows = [k({ actual: 1.2, target: 1, variance: 0.2 }), k({ actual: 0.6, target: 1, variance: -0.4 })];
        expect(achievement(rows, "weighted")).toBeCloseTo(90);
        expect(achievement(rows, "hitrate")).toBe(50);
    });
});

describe("owners", () => {
    it("C-suite is CEO, COO, CMO, CFO, CHRO, CIO, CSO, matched without regard to case or spacing", () => {
        expect([...CSUITE]).toEqual(["CEO", "COO", "CMO", "CFO", "CHRO", "CIO", "CSO"]);
        expect(isCsuite(" cfo ")).toBe(true);
        expect(isCsuite("Quality Manager")).toBe(false);
    });
    it("orders the C-suite first in its fixed order, then the others by name; no Unassigned", () => {
        const rows = [k({ owner: "Quality Manager" }), k({ owner: "CFO" }), k({ owner: "CEO" }), k({ owner: "Internal Audit" }),
            k({ owner: "CHRO" }), k({ owner: "" }), k({ owner: "COO" })];
        expect(ownersOf(rows, "owned")).toEqual(["CEO", "COO", "CFO", "CHRO", "Internal Audit", "Quality Manager"]);
    });
    it("Owned counts the owner's KPIs; Owned + co-owned adds the KPIs where they are a co-owner", () => {
        const a = k({ owner: "COO", coOwners: ["CFO"] }), b = k({ owner: "CFO" });
        expect(kpisOf([a, b], "CFO", "owned")).toEqual([b]);
        expect(kpisOf([a, b], "CFO", "co")).toEqual([a, b]);
        expect(ownersOf([a], "owned")).toEqual(["COO"]);
        expect(ownersOf([a], "co")).toEqual(["COO", "CFO"]);
    });
    it("ownerCards: C-suite tier keeps the C-suite only, All owners keeps everyone", () => {
        const rows = [k({ owner: "CFO", actual: 0.9, target: 1, variance: -0.1 }), k({ owner: "Quality Manager", actual: 1.1, target: 1, variance: 0.1 })];
        expect(ownerCards(rows, { score: "weighted", tier: "csuite", scope: "owned" }).map(c => c.owner)).toEqual(["CFO"]);
        const all = ownerCards(rows, { score: "weighted", tier: "all", scope: "owned" });
        expect(all.map(c => [c.owner, Math.round(c.value as number)])).toEqual([["CFO", 90], ["Quality Manager", 110]]);
        expect(ownerCards(rows, { score: "hitrate", tier: "all", scope: "owned" }).map(c => c.value)).toEqual([0, 100]);
    });
    it("ownerCards: the scope changes what counts for an owner, and counts are given", () => {
        const rows = [k({ owner: "COO", coOwners: ["CFO"], actual: 0.5, target: 1 }), k({ owner: "CFO", actual: 1, target: 1 }), k({ owner: "CFO", actual: null })];
        const owned = ownerCards(rows, { score: "weighted", tier: "csuite", scope: "owned" });
        expect(owned.find(c => c.owner === "CFO")).toMatchObject({ value: 100, counted: 1, total: 2 });
        const co = ownerCards(rows, { score: "weighted", tier: "csuite", scope: "co" });
        expect(co.find(c => c.owner === "CFO")).toMatchObject({ value: 75, counted: 2, total: 3 });
    });
    it("ownerCards: an owner with nothing scoreable has a null value", () => {
        const c = ownerCards([k({ owner: "CIO", actual: null })], { score: "weighted", tier: "csuite", scope: "owned" });
        expect(c).toEqual([{ owner: "CIO", value: null, counted: 0, total: 1 }]);
    });
});
