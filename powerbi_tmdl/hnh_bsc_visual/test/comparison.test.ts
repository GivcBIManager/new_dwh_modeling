// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { renderView, type UiState } from "../src/render/index";
import { levelOf } from "../src/render/comparison";
import { parseDataView } from "../src/model/parse";
import { makeDataView, payload, FixtureRow } from "./fixtures";

const base = { kpiType: "Primary", direction: "higher", valueFormat: "pct", kpiStatus: "active", valueSource: "measure",
    scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70, owner: "Someone" };
const ui = (pillar: string | null = null, objective: string | null = null): UiState =>
    ({ pillar: null, compareLevel: { pillar, objective }, title: "t", subtitle: "s", showHeader: false });
const s = (score: number, weight = 1, actual = 0.42, target = 0.4) =>
    payload({ actual, target, variance: actual / target - 1, score, state: score >= 85 ? "On track" : score >= 70 ? "Watch" : "At risk", weight });
const none = payload({ state: "No data yet" });

function kpi(code: string, pillar: string, pOrder: number, obj: string, objTitle: string, oOrder: number, display: number, pay: string[], extra: FixtureRow = {}): FixtureRow {
    return { ...base, kpi: code, kpiName: code + " name", shortLabel: code, pillar, pillarOrder: pOrder, pillarWeight: 0.5, pillarQuestion: "q?",
        objectiveCode: obj, objectiveTitle: objTitle, objectiveOrder: oOrder, displayOrder: display, payload: pay, ...extra };
}

// Hospitals: Abha, Jazan, Khamis, and Head Office (no scores at all, left out).
//   Financial F1 Revenue: FA (weight 2) 90/60/75, FB (weight 1) 60/90/75     -> F1 80 / 70 / 75
//   Financial F2 Cost:    FC (weight 1) 40/100/none                          -> F2 40 / 100 / none
//   Financial pillar: 70 / 77.5 / 75; Customer C1 Care: CA 70/95/80 -> 70 / 95 / 80
//   Overall (0.5 each): 70 / 86.25 / 77.5
const BR = ["Abha", "Jazan", "Khamis", "Head Office"];
const rows: FixtureRow[] = [
    kpi("FA", "Financial", 1, "F1", "Revenue", 1, 1, [s(90, 2), s(60, 2, 0.3, 0.4), s(75, 2), none], { valueFormat: "pct" }),
    kpi("FB", "Financial", 1, "F1", "Revenue", 1, 2, [s(60), s(90), s(75), none], { valueFormat: "sar" }),
    kpi("FC", "Financial", 1, "F2", "Cost", 2, 3, [s(40), s(100), none, none]),
    kpi("CA", "Customer", 2, "C1", "Care", 1, 1, [s(70), s(95), s(80), none]),
];
const vm = () => parseDataView(makeDataView(rows, { branches: BR }));
const draw = (u: UiState) => { const root = document.createElement("div"); renderView(root, vm(), "comparison", u); return root; };
const heads = (root: HTMLElement) => [...root.querySelectorAll("thead th")].map(h => h.textContent);
const bodyRows = (root: HTMLElement) => [...root.querySelectorAll("tbody tr")].map(tr => [...tr.querySelectorAll("th,td")]);
const texts = (root: HTMLElement) => bodyRows(root).map(r => r.map(c => c.textContent));

describe("comparison league table, level 1 (all pillars)", () => {
    it("ranks hospitals by the overall score, with a column per pillar and the peer median", () => {
        const root = draw(ui());
        expect(heads(root)).toEqual(["#", "Hospital", "Overall", "Financial ▸", "Customer ▸", "Peer median"]);
        // Peer median: the other hospitals' overall score.
        expect(texts(root)).toEqual([
            ["1", "Jazan", "86", "78", "95", "74"],
            ["2", "Khamis", "78", "75", "80", "78"],
            ["3", "Abha", "70", "70", "70", "82"],
        ]);
    });
    it("colours score cells by the rounded score with the visual's thresholds and labels them", () => {
        const root = draw(ui());
        const [jazan] = bodyRows(root);
        expect(jazan[2].className).toContain("good");
        expect(jazan[3].className).toContain("warn");
        expect(jazan[2].getAttribute("aria-label")).toBe("Jazan: Overall 86 · On track");
        expect(jazan[3].getAttribute("title")).toBe("Jazan: Financial 78 · Watch");
        expect(bodyRows(root)[2][2].className).toContain("warn");
    });
    it("pillar and overall cells are not drill sources", () => {
        const root = draw(ui());
        expect(root.querySelector("[data-key]")).toBeNull();
        expect(root.querySelectorAll("tbody [tabindex]").length).toBe(0);
    });
    it("pillar headers are buttons that name the pillar level", () => {
        const root = draw(ui());
        const b = [...root.querySelectorAll<HTMLButtonElement>("thead button[data-cmp-pillar]")];
        expect(b.map(x => [x.dataset.cmpPillar, x.dataset.cmpObjective])).toEqual([["Financial", ""], ["Customer", ""]]);
        expect(b[0].getAttribute("type")).toBe("button");
    });
    it("the breadcrumb reads All pillars, with nothing to click", () => {
        const root = draw(ui());
        expect(root.querySelector(".crumbs")!.textContent).toBe("All pillars");
        expect(root.querySelectorAll(".crumbs button").length).toBe(0);
        expect(root.querySelector('.crumbs [aria-current="location"]')!.textContent).toBe("All pillars");
    });
    it("keeps the colour legend and says how to drill", () => {
        const root = draw(ui());
        const legend = root.querySelector(".cmp-legend")!.textContent!;
        expect(legend).toContain("85 and over on track");
        expect(legend).toContain("no data yet");
        expect(legend).toContain("Click a pillar");
    });
    it("leaves out Head Office (no KPI score)", () => {
        expect(texts(draw(ui())).map(r => r[1])).not.toContain("Head Office");
    });
});

describe("comparison level 2 (a pillar's objectives)", () => {
    it("shows the pillar score, one column per objective, ranked by the pillar score", () => {
        const root = draw(ui("Financial"));
        expect(heads(root)).toEqual(["#", "Hospital", "Financial", "F1 · Revenue ▸", "F2 · Cost ▸", "Peer median"]);
        expect(texts(root)).toEqual([
            ["1", "Jazan", "78", "70", "100", "73"],
            ["2", "Khamis", "75", "75", "–", "74"],
            ["3", "Abha", "70", "80", "40", "76"],
        ]);
        expect(bodyRows(root)[1][4].className).toContain("nodata");
        expect(bodyRows(root)[1][4].getAttribute("aria-label")).toBe("Khamis: F2 · Cost No data yet");
    });
    it("objective headers carry the pillar and the objective code", () => {
        const root = draw(ui("Financial"));
        const b = [...root.querySelectorAll<HTMLButtonElement>("thead button[data-cmp-pillar]")];
        expect(b.map(x => [x.dataset.cmpPillar, x.dataset.cmpObjective])).toEqual([["Financial", "F1"], ["Financial", "F2"]]);
    });
    it("the breadcrumb goes back to all pillars", () => {
        const root = draw(ui("Financial"));
        expect(root.querySelector(".crumbs")!.textContent).toBe("All pillars › Financial");
        const b = [...root.querySelectorAll<HTMLButtonElement>(".crumbs button")];
        expect(b.map(x => [x.textContent, x.dataset.cmpPillar, x.dataset.cmpObjective])).toEqual([["All pillars", "", ""]]);
        expect(root.querySelector('.crumbs [aria-current="location"]')!.textContent).toBe("Financial");
    });
    it("says how to drill further", () => {
        expect(draw(ui("Financial")).querySelector(".cmp-legend")!.textContent).toContain("Click an objective");
    });
});

describe("comparison level 3 (an objective's KPIs)", () => {
    it("shows the objective score and one column per KPI, ranked by the objective score", () => {
        const root = draw(ui("Financial", "F1"));
        expect(heads(root)).toEqual(["#", "Hospital", "F1 · Revenue", "FA name", "FB name", "Peer median"]);
        expect(bodyRows(root).map(r => [r[0], r[1], r[2], r[5]].map(c => c.textContent))).toEqual([
            ["1", "Abha", "80", "73"],
            ["2", "Khamis", "75", "75"],
            ["3", "Jazan", "70", "78"],
        ]);
    });
    it("score cells carry their state's shape (aria-hidden), never only a tint; no-data cells keep the dash", () => {
        const [abha, khamis, jazan] = bodyRows(draw(ui("Financial", "F1")));
        expect(abha[3].querySelector(".sc .mark.good")!.getAttribute("aria-hidden")).toBe("true");
        expect(jazan[3].querySelector(".mark.bad")).not.toBeNull();
        expect(abha[2].querySelector(".mark")).not.toBeNull();
        expect(khamis[2].querySelector(".mark.warn")).not.toBeNull();
        const level2 = bodyRows(draw(ui("Financial")));
        expect(level2[1][4].querySelector(".mark")).toBeNull();
        expect(level2[1][4].textContent).toBe("–");
    });
    it("a KPI cell shows the score and actual / target in the KPI's value format, coloured by state", () => {
        const root = draw(ui("Financial", "F1"));
        const [abha, , jazan] = bodyRows(root);
        expect(abha[3].querySelector(".sc")!.textContent).toBe("90");
        expect(abha[3].querySelector(".at")!.textContent).toBe("42.0% / 40.0%");
        expect(abha[3].className).toContain("good");
        expect(abha[4].querySelector(".at")!.textContent).toBe("SAR 0 / 0");
        expect(jazan[3].querySelector(".at")!.textContent).toBe("30.0% / 40.0%");
        expect(jazan[3].className).toContain("bad");
        expect(abha[3].getAttribute("aria-label")).toBe("Abha: FA name 90 · On track · 42.0% / 40.0%");
    });
    it("KPI cells carry the KPI x hospital key for drill-through, tooltip and selection; dash cells stay inert", () => {
        const v = vm();
        const root = document.createElement("div");
        renderView(root, v, "comparison", ui("Financial", "F2"));
        const fc = v.pillars[0].kpis.filter(k => k.code === "FC");
        const jazan = fc.find(k => k.branch === "Jazan")!;
        const [first, , last] = bodyRows(root);
        expect(first[1].textContent).toBe("Jazan");
        expect([first[3].getAttribute("data-key"), first[3].getAttribute("data-series"), first[3].getAttribute("tabindex")])
            .toEqual([String(jazan.rowIndex), String(jazan.seriesIndex), "0"]);
        expect(last[1].textContent).toBe("Khamis");
        expect(last[0].textContent).toBe("–");
        expect(last[3].textContent).toBe("–");
        expect(last[3].hasAttribute("data-key") || last[3].hasAttribute("tabindex")).toBe(false);
        expect(root.querySelectorAll("[data-key]").length).toBe(2);
        expect(root.querySelector("td.peer[data-key], td.lead[data-key]")).toBeNull();
    });
    it("the breadcrumb goes back to all pillars and to the pillar", () => {
        const root = draw(ui("Financial", "F1"));
        expect(root.querySelector(".crumbs")!.textContent).toBe("All pillars › Financial › F1 · Revenue");
        const b = [...root.querySelectorAll<HTMLButtonElement>(".crumbs button")];
        expect(b.map(x => [x.textContent, x.dataset.cmpPillar, x.dataset.cmpObjective])).toEqual([["All pillars", "", ""], ["Financial", "Financial", ""]]);
        expect(root.querySelectorAll("thead button").length).toBe(0);
    });
    it("tells the user about the drill-through", () => {
        expect(draw(ui("Financial", "F1")).querySelector(".cmp-legend")!.textContent).toContain("Right-click a KPI");
    });
});

describe("comparison ranking", () => {
    it("ties (same shown score) share the rank and go by hospital name; unscored go last", () => {
        const r = [
            kpi("FA", "Financial", 1, "F1", "Revenue", 1, 1, [s(80.2), s(79.9), none, s(60)]),
            kpi("FB", "Financial", 1, "F1", "Revenue", 1, 2, [none, none, s(90), none]),
        ];
        const root = document.createElement("div");
        renderView(root, parseDataView(makeDataView(r, { branches: ["Zulfi", "Baha", "Dammam", "Abqaiq"] })), "comparison", ui("Financial", "F1"));
        // Objective F1: Zulfi 80.2, Baha 79.9 (both show 80), Dammam 90 via FB, Abqaiq 60.
        expect(texts(root).map(x => x.slice(0, 3))).toEqual([["1", "Dammam", "90"], ["2", "Baha", "80"], ["2", "Zulfi", "80"], ["4", "Abqaiq", "60"]]);
    });
});

describe("comparison level resolution", () => {
    it("falls back to the top when the pillar or the objective is not in the data", () => {
        const v = vm();
        expect(levelOf(v, { pillar: "Financial", objective: "F1" })).toEqual({ pillar: "Financial", objective: "F1" });
        expect(levelOf(v, { pillar: "Financial", objective: null })).toEqual({ pillar: "Financial", objective: null });
        expect(levelOf(v, { pillar: "Nope", objective: null })).toEqual({ pillar: null, objective: null });
        expect(levelOf(v, { pillar: "Financial", objective: "C1" })).toEqual({ pillar: null, objective: null });
        expect(levelOf(v, { pillar: null, objective: "F1" })).toEqual({ pillar: null, objective: null });
        expect(heads(draw(ui("Nope")))[2]).toBe("Overall");
    });
});

describe("comparison empty and small cases", () => {
    it("asks for a hospital field without a branch series", () => {
        const root = document.createElement("div");
        renderView(root, parseDataView(makeDataView(rows.map(r => ({ ...r, payload: (r.payload as string[])[0] })))), "comparison", ui());
        expect(root.querySelector(".empty")!.textContent).toBe("Add a hospital field to compare hospitals");
    });
    it("says so when no hospital has a score", () => {
        const root = document.createElement("div");
        renderView(root, parseDataView(makeDataView([kpi("FA", "Financial", 1, "F1", "Revenue", 1, 1, [none, none])], { branches: ["Abha", "Jazan"] })), "comparison", ui());
        expect(root.querySelector("table")).toBeNull();
        expect(root.querySelector(".empty")!.textContent).toBe("No hospital has a KPI score in this selection");
    });
    it("one hospital: rank 1 and a dash peer median", () => {
        const root = document.createElement("div");
        renderView(root, parseDataView(makeDataView([kpi("FA", "Financial", 1, "F1", "Revenue", 1, 1, [s(90)])], { branches: ["Abha"] })), "comparison", ui());
        expect(texts(root)).toEqual([["1", "Abha", "90", "90", "–"]]);
    });
});
