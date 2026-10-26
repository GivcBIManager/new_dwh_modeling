// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { lineChart } from "../src/render/linechart";

const months = ["Jul", "Aug", "Sep"];
const opts = (o: Partial<{ months: string[]; target: number }> = {}) => ({ months, target: 85, width: 900, height: 300, ...o });
const ys = (s: SVGSVGElement) => [...s.querySelectorAll(".lc-y")].map(t => Number(t.textContent));

describe("lineChart", () => {
    it("runs y from the lower ten (or ten under the target) to 100, a gridline every 10", () => {
        const s = lineChart([{ name: "Financial", colourVar: "var(--p1)", values: [62, 70, 95] }], opts());
        expect(ys(s)).toEqual([60, 70, 80, 90, 100]);
        expect(s.querySelectorAll(".lc-grid").length).toBe(5);
        const t = lineChart([{ name: "A", colourVar: "var(--p1)", values: [88, 90, 92] }], opts());
        expect(ys(t)[0]).toBe(70);
    });
    it("extends above 100 to the upper ten and never below 0", () => {
        expect(ys(lineChart([{ name: "A", colourVar: "var(--p1)", values: [40, 131, 90] }], opts())).at(-1)).toBe(140);
        expect(ys(lineChart([{ name: "A", colourVar: "var(--p1)", values: [3, 5, 4] }], opts({ target: 5 })))[0]).toBe(0);
    });
    it("draws a dashed target line, one path per series, a dot and the name at each line's last point", () => {
        const s = lineChart([
            { name: "Financial", colourVar: "var(--p1)", values: [70, 72, null] },
            { name: "Customer", colourVar: "var(--p2)", values: [80, 82, 84] },
        ], opts());
        expect(s.querySelector(".lc-target")!.getAttribute("stroke-dasharray")).not.toBeNull();
        const lines = [...s.querySelectorAll(".lc-line")];
        expect(lines.length).toBe(2);
        expect(lines[0].getAttribute("style")).toContain("var(--p1)");
        expect([...s.querySelectorAll(".lc-name")].map(n => n.textContent)).toEqual(["Financial", "Customer"]);
        const dots = [...s.querySelectorAll(".lc-dot")];
        expect(dots.length).toBe(2);
        expect(Number(dots[0].getAttribute("cx"))).toBeLessThan(Number(dots[1].getAttribute("cx")));
        expect([...s.querySelectorAll(".lc-month")].map(m => m.textContent)).toEqual(months);
        expect(s.outerHTML).not.toContain("NaN");
    });
    it("draws without month names and with an empty series", () => {
        const s = lineChart([{ name: "A", colourVar: "var(--p1)", values: [null, null, null] }], opts({ months: [] }));
        expect(s.querySelectorAll(".lc-month").length).toBe(0);
        expect(s.querySelectorAll(".lc-dot").length).toBe(0);
        expect(ys(s)).toEqual([70, 80, 90, 100]);
        expect(s.outerHTML).not.toContain("NaN");
    });
});
