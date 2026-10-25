// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { gauge, achievementGauge } from "../src/render/gauge";

describe("gauge", () => {
    it("labels and shows a rounded score with a target marker", () => {
        const g = gauge(87.4, 220, 85, "Financial");
        expect(g.getAttribute("aria-label")).toBe("Financial: 87 out of 100");
        expect(g.querySelector("text")?.textContent).toBe("87");
        expect(g.querySelector(".gauge-target")).not.toBeNull();
        expect(g.querySelector(".gauge-arc")?.getAttribute("stroke")).toBe("var(--good)");
    });
    it("colours by threshold", () => {
        expect(gauge(75, 220, 85, "x").querySelector(".gauge-arc")?.getAttribute("stroke")).toBe("var(--warn)");
        expect(gauge(40, 220, 85, "x").querySelector(".gauge-arc")?.getAttribute("stroke")).toBe("var(--bad)");
    });
    it("classifies on the displayed, rounded score", () => {
        const g = gauge(84.6, 220, 85, "x");
        expect(g.querySelector("text")?.textContent).toBe("85");
        expect(g.querySelector(".gauge-arc")?.getAttribute("stroke")).toBe("var(--good)");
        expect(gauge(84.4, 220, 85, "x").querySelector(".gauge-arc")?.getAttribute("stroke")).toBe("var(--warn)");
        expect(gauge(69.5, 220, 85, "x", 70).querySelector(".gauge-arc")?.getAttribute("stroke")).toBe("var(--warn)");
    });
    it("shows a dash in the no-data colour", () => {
        const g = gauge(null, 220, 85, "Financial");
        expect(g.querySelector("text")?.textContent).toBe("–");
        expect(g.querySelector("text")?.getAttribute("fill")).toBe("var(--nodata)");
        expect(g.getAttribute("aria-label")).toBe("Financial: no data");
        expect(g.outerHTML).not.toContain("NaN");
    });
});

describe("achievement gauge", () => {
    const arc = (g: SVGSVGElement) => g.querySelector(".gauge-arc")!;
    it("shows a percent that can pass 100, with the arc capped at its end", () => {
        const g = achievementGauge(126.2, 160, "CEO");
        expect(g.querySelector("text")!.textContent).toBe("126%");
        expect(arc(g).getAttribute("stroke-dashoffset")).toBe("0.00");
        expect(g.getAttribute("aria-label")).toBe("CEO achievement: 126%");
    });
    it("is labelled Achievement and puts the target marker at 100%, the arc's end", () => {
        const g = achievementGauge(90, 160, "CEO");
        expect([...g.querySelectorAll("text")].map(t => t.textContent)).toContain("Achievement");
        const m = g.querySelector(".gauge-target")!;
        const r = 160 / 2 - 14;
        expect(Number(m.getAttribute("x1"))).toBeCloseTo(80 + r, 0);
        expect(Number(m.getAttribute("y1"))).toBeCloseTo(80, 0);
    });
    it("colours 100% and up on track, 85-99% watch, under 85% at risk, on the rounded value", () => {
        expect(arc(achievementGauge(100, 160, "x")).getAttribute("stroke")).toBe("var(--good)");
        expect(arc(achievementGauge(99.5, 160, "x")).getAttribute("stroke")).toBe("var(--good)");
        expect(arc(achievementGauge(99.4, 160, "x")).getAttribute("stroke")).toBe("var(--warn)");
        expect(arc(achievementGauge(85, 160, "x")).getAttribute("stroke")).toBe("var(--warn)");
        expect(arc(achievementGauge(84.4, 160, "x")).getAttribute("stroke")).toBe("var(--bad)");
    });
    it("shows a dash when there is nothing to score", () => {
        const g = achievementGauge(null, 160, "CIO");
        expect(g.querySelector("text")!.textContent).toBe("–");
        expect(g.getAttribute("aria-label")).toBe("CIO achievement: no data");
        expect(g.outerHTML).not.toContain("NaN");
    });
    it("leaves the score gauge as it was", () => {
        const g = gauge(126, 220, 85, "x");
        expect(g.querySelector("text")!.textContent).toBe("126");
        expect([...g.querySelectorAll("text")].map(t => t.textContent)).toContain("target 85");
    });
});
