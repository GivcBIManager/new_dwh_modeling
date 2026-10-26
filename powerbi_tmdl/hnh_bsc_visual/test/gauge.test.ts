// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { achievementGauge } from "../src/render/gauge";

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
});
