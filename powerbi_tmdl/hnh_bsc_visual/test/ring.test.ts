// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { ring } from "../src/render/ring";

const arcOf = (s: SVGSVGElement) => s.querySelector(".ring-arc")!;
const dash = (s: SVGSVGElement) => arcOf(s).getAttribute("stroke-dasharray")!.split(" ").map(Number);
const circ = (s: SVGSVGElement) => 2 * Math.PI * Number(arcOf(s).getAttribute("r"));

describe("ring", () => {
    it("is a full circle that fills by score / 100, labelled with the rounded score", () => {
        const s = ring(74.8, 168, "Overall score");
        expect(s.getAttribute("width")).toBe("168");
        expect(s.getAttribute("aria-label")).toBe("Overall score 75 of 100");
        expect(dash(s)[0]).toBeCloseTo(circ(s) * 0.748, 1);
        expect(s.querySelector(".ring-track")).not.toBeNull();
        expect(s.querySelector(".ring-score")!.textContent).toBe("75");
        expect(s.textContent).toContain("of 100");
    });
    it("stops at 100 and at 0, and prints the number in full", () => {
        const hi = ring(112, 168, "x");
        expect(dash(hi)[0]).toBeCloseTo(circ(hi), 1);
        expect(hi.querySelector(".ring-score")!.textContent).toBe("112");
        const lo = ring(-5, 168, "x");
        expect(dash(lo)[0]).toBe(0);
        expect(lo.querySelector(".ring-score")!.textContent).toBe("-5");
    });
    it("shows a dash without a score", () => {
        const s = ring(null, 168, "Overall score");
        expect(s.querySelector(".ring-score")!.textContent).toBe("–");
        expect(s.getAttribute("aria-label")).toBe("Overall score: no data");
        expect(s.outerHTML).not.toContain("NaN");
    });
});
