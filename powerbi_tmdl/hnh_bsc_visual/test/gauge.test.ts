// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { gauge } from "../src/render/gauge";

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
