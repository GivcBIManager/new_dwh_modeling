import { describe, it, expect } from "vitest";
import { parseDataView, parsePayload, directionNote } from "../src/model/parse";
import { makeDataView, payload, FixtureRow } from "./fixtures";

const base = { kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure",
    scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70 };

function row(code: string, pillar: string, order: number, w: number, extra: FixtureRow = {}): FixtureRow {
    return { ...base, kpi: code, kpiName: code + " name", shortLabel: code, pillar, pillarOrder: order, pillarWeight: w, pillarQuestion: "Q?",
        objectiveCode: "O1", objectiveTitle: "Obj", objectiveOrder: 1, displayOrder: 1, owner: "Someone", ...extra };
}

const ok = (score: number, weight: number, st = "On track", trend: (number | null)[] = [score]) =>
    payload({ actual: 1, target: 1, variance: 0, score, state: st, weight, trend, targetTrend: [1], scoreTrend: trend });

describe("parsePayload", () => {
    it("splits the nine fields, accepting a trailing dot", () => {
        const p = parsePayload("100.|90|0.11|88.5|On track|2|1;2;|3;4;|5;;6");
        expect(p).toEqual({ actual: 100, target: 90, variance: 0.11, score: 88.5, stateText: "On track", weight: 2,
            trend: [1, 2, null], targetTrend: [3, 4, null], scoreTrend: [5, null, 6] });
    });
    it("reads blank fields as null", () => {
        expect(parsePayload("||||No data yet|||||")).toMatchObject({ actual: null, score: null, weight: null, stateText: "No data yet", trend: [] });
    });
    it("recognises the guard text", () => {
        const g = "\"BSC Visual Payload can't be analysed by Payer\"";
        expect(parsePayload(g)).toEqual({ guard: g });
    });
    it("null gives an empty payload", () => {
        expect(parsePayload(null)).toMatchObject({ actual: null, stateText: null });
    });
});

describe("parseDataView", () => {
    const rows: FixtureRow[] = [
        row("B2", "Customer", 2, 0.2, { kpiType: "Supporting", displayOrder: 1, payload: ok(60, 1, "At risk"), selectionLabel: "Hospital 6 | 2026-08" }),
        row("A2", "Financial", 1, 0.3, { displayOrder: 2, payload: ok(90, 1) }),
        row("A1", "Financial", 1, 0.3, { displayOrder: 1, payload: ok(80, 1, "Watch") }),
        row("A3", "Financial", 1, 0.3, { displayOrder: 3, kpiStatus: "parked", payload: ok(100, 0, "Parked") }),
        row("C1", "Learning & Growth", 4, 0.15, { payload: payload({ state: "No target" }) }),
        row("D1", "Internal Process", 3, 0.35, { payload: ok(75, 1) }),
    ];

    it("orders pillars and KPIs, computes pillar and overall scores", () => {
        const vm = parseDataView(makeDataView(rows));
        expect(vm.guardMessage).toBeNull();
        expect(vm.pillars.map(p => p.name)).toEqual(["Financial", "Customer", "Internal Process", "Learning & Growth"]);
        const fin = vm.pillars[0];
        expect(fin.kpis.map(k => k.code)).toEqual(["A1", "A2", "A3"]);
        expect(fin.score).toBeCloseTo(85); // (80+90)/2, A3 weight 0 ignored
        expect(fin.trend).toEqual([85]);
        expect(vm.pillars[3].score).toBeNull();
        expect(vm.overallScore).toBeCloseTo((85 * 0.3 + 60 * 0.2 + 75 * 0.35) / 0.85);
        expect(vm.label).toBe("Hospital 6 | 2026-08");
        expect(vm.thresholds).toEqual({ base: 85, slope: 0.6, good: 85, watch: 70 });
        expect(vm.branches).toEqual([]);
    });

    it("puts primary KPIs before supporting ones, then by display order", () => {
        const vm = parseDataView(makeDataView([
            row("S1", "Financial", 1, 0.3, { kpiType: "Supporting", displayOrder: 1, payload: ok(1, 1) }),
            row("P2", "Financial", 1, 0.3, { displayOrder: 5, payload: ok(1, 1) }),
            row("P1", "Financial", 1, 0.3, { displayOrder: 2, payload: ok(1, 1) }),
        ]));
        expect(vm.pillars[0].kpis.map(k => k.code)).toEqual(["P1", "P2", "S1"]);
        expect(vm.pillars[0].kpis[2].primary).toBe(false);
    });

    it("counts states and fills row fields", () => {
        const vm = parseDataView(makeDataView(rows));
        expect(vm.pillars[0].counts).toEqual({ good: 1, warn: 1, bad: 0, nodata: 0, parked: 1, notarget: 0 });
        const a3 = vm.pillars[0].kpis[2];
        expect(a3).toMatchObject({ parkedInCatalogue: true, reason: "Definition to be agreed", state: "parked", weight: 0, manual: false, branch: null, seriesIndex: null });
        const a1 = vm.pillars[0].kpis[0];
        expect(a1).toMatchObject({ name: "A1 name", actual: 1, target: 1, variance: 0, score: 80, stateWord: "Watch", rowIndex: 2, scoreTrend: [80] });
    });

    it("builds one row per KPI and branch", () => {
        const vm = parseDataView(makeDataView([
            row("A1", "Financial", 1, 0.3, { payload: [ok(80, 1), ok(70, 1, "Watch")] }),
        ], { branches: ["Hospital A", "Hospital B"] }));
        expect(vm.branches).toEqual(["Hospital A", "Hospital B"]);
        const ks = vm.pillars[0].kpis;
        expect(ks.map(k => [k.branch, k.seriesIndex, k.score])).toEqual([["Hospital A", 0, 80], ["Hospital B", 1, 70]]);
    });

    it("describes the first branch in counts, score and trend and gives per-branch values", () => {
        const vm = parseDataView(makeDataView([
            row("A1", "Financial", 1, 0.3, { displayOrder: 1, payload: [ok(80, 1, "On track", [70, 80]), ok(40, 1, "At risk", [30, 40])] }),
            row("A2", "Financial", 1, 0.3, { displayOrder: 2, payload: [ok(70, 1, "Watch", [60, 70]), ok(90, 1, "On track", [80, 90])] }),
        ], { branches: ["Hospital A", "Hospital B"] }));
        const fin = vm.pillars[0];
        expect(fin.kpis).toHaveLength(4);
        expect(fin.counts).toEqual({ good: 1, warn: 1, bad: 0, nodata: 0, parked: 0, notarget: 0 });
        expect(fin.score).toBeCloseTo(75);
        expect(fin.trend).toEqual([65, 75]);
        expect(fin.byBranch).toHaveLength(2);
        expect(fin.byBranch[0]).toMatchObject({ branch: "Hospital A", counts: { good: 1, warn: 1, bad: 0 } });
        expect(fin.byBranch[0].score).toBeCloseTo(75);
        expect(fin.byBranch[1]).toMatchObject({ branch: "Hospital B", counts: { good: 1, warn: 0, bad: 1 } });
        expect(fin.byBranch[1].score).toBeCloseTo(65);
        expect(vm.overallByBranch.map(b => b.branch)).toEqual(["Hospital A", "Hospital B"]);
        expect(vm.overallByBranch[0].score).toBeCloseTo(75);
        expect(vm.overallByBranch[1].score).toBeCloseTo(65);
        expect(vm.overallScore).toBeCloseTo(75);
    });

    it("has no per-branch values without a branch series", () => {
        const vm = parseDataView(makeDataView([row("A1", "Financial", 1, 0.3, { payload: ok(80, 1) })]));
        expect(vm.pillars[0].byBranch).toEqual([]);
        expect(vm.overallByBranch).toEqual([]);
    });

    it("names a blank branch (Blank)", () => {
        const vm = parseDataView(makeDataView([row("A1", "Financial", 1, 0.3, { payload: [ok(1, 1), ok(2, 1)] })], { branches: ["", "Hospital B"] }));
        expect(vm.branches).toEqual(["(Blank)", "Hospital B"]);
    });

    it("returns the guard message when only the second branch carries it", () => {
        const g = "\"BSC Visual Payload can't be analysed by Payer\"";
        const vm = parseDataView(makeDataView([row("A1", "Financial", 1, 0.3, { payload: [ok(1, 1), g] })], { branches: ["A", "B"] }));
        expect(vm.guardMessage).toBe(g);
        expect(vm.pillars).toEqual([]);
    });

    it("returns the guard message and no rows", () => {
        const g = "\"BSC Visual Payload can't be analysed by Payer\"";
        const vm = parseDataView(makeDataView([row("A1", "Financial", 1, 0.3, { payload: g })]));
        expect(vm.guardMessage).toBe(g);
        expect(vm.pillars).toEqual([]);
        expect(vm.overallScore).toBeNull();
    });

    it("returns the guard message when only the selection label carries it", () => {
        const g = "\"BSC Selection Label can't be analysed by Payer\"";
        const vm = parseDataView(makeDataView([row("A1", "Financial", 1, 0.3, { payload: ok(1, 1), selectionLabel: g })]));
        expect(vm.guardMessage).toBe(g);
        expect(vm.pillars).toEqual([]);
    });

    it("finds columns by role, not position", () => {
        const dv = makeDataView(rows);
        dv.categorical!.categories!.reverse();
        expect(parseDataView(dv).pillars.map(p => p.name)).toEqual(["Financial", "Customer", "Internal Process", "Learning & Growth"]);
    });

    it("handles a data view without data", () => {
        const vm = parseDataView({ metadata: { columns: [] } } as never);
        expect(vm.pillars).toEqual([]);
        expect(vm.guardMessage).toBeNull();
    });
});

describe("directionNote", () => {
    it("explains non-obvious directions", () => {
        expect(directionNote("lower")).toBe("lower is better");
        expect(directionNote("ceiling")).toBe("at most the target");
        expect(directionNote("on_target")).toBe("closest to the target is best");
        expect(directionNote("higher")).toBeNull();
    });
});
