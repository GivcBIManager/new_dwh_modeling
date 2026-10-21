// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { gauge } from "../src/render/gauge";
import { sparkline } from "../src/render/sparkline";
import { header } from "../src/render/header";
import { statusStrip } from "../src/render/chips";
import type { ViewModel } from "../src/model/types";
import { readFileSync } from "node:fs";

const css = readFileSync("style/visual.less", "utf8");
const vm = { label: "A · B" } as ViewModel;

describe("colours stay out of the SVG so high contrast can replace them", () => {
    it("gauge track, sparkline and header shapes carry classes and no hard-coded colour", () => {
        const track = gauge(80, 220, 85, "x").querySelector(".gauge-track")!;
        expect(track.hasAttribute("stroke")).toBe(false);
        const sp = sparkline([1, 2, 3], [2, 2, 2], 100, 40);
        for (const c of ["spark-target", "spark-line", "spark-dot"]) {
            const n = sp.querySelector("." + c)!;
            expect(n).not.toBeNull();
            expect(n.hasAttribute("stroke") || n.hasAttribute("fill") && n.getAttribute("fill") !== "none").toBe(false);
        }
        const h = header(vm, "t", "s");
        const shapes = [...h.querySelectorAll(".mark-shape, .ribbon-shape")];
        expect(shapes.length).toBeGreaterThan(4);
        for (const n of shapes) expect(n.hasAttribute("fill")).toBe(false);
        expect(h.querySelector("stop")!.hasAttribute("stop-color")).toBe(false);
    });
    it("has a high-contrast rule for each", () => {
        for (const c of [".gauge-track", ".spark-target", ".spark-line", ".spark-dot", ".mark-shape", ".ribbon-shape"]) {
            expect(css).toContain(`.hnh-bsc.hc ${c}`);
        }
    });
    it("strip squares differ by state class for the warn pattern", () => {
        const s = statusStrip([{ state: "warn", stateWord: "Watch", name: "a", rowIndex: 0, seriesIndex: null } as never]);
        expect(s.querySelector("i")!.classList.contains("warn")).toBe(true);
        expect(css).toContain(".hnh-bsc.hc .strip i.warn");
    });
});
