// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { achievementGauge } from "../src/render/gauge";
import { ring } from "../src/render/ring";
import { lineChart } from "../src/render/linechart";
import { sparkline } from "../src/render/sparkline";
import { header } from "../src/render/header";
import { monthlyBars } from "../src/render/bars";
import type { ViewModel } from "../src/model/types";
import { readFileSync } from "node:fs";

const css = readFileSync("style/visual.less", "utf8");
const vm = { label: "A · B" } as ViewModel;

describe("colours stay out of the SVG so high contrast can replace them", () => {
    it("gauge track, sparkline and header shapes carry classes and no hard-coded colour", () => {
        const track = achievementGauge(80, 220, "x").querySelector(".gauge-track")!;
        expect(track.hasAttribute("stroke")).toBe(false);
        const r = ring(80, 168, "x");
        for (const c of ["ring-track", "ring-arc"]) expect(r.querySelector("." + c)!.hasAttribute("stroke")).toBe(false);
        const lc = lineChart([{ name: "a", colourVar: "var(--p1)", values: [1, 2] }], { months: [], target: 85, width: 400, height: 200 });
        for (const c of ["lc-grid", "lc-target"]) expect(lc.querySelector("." + c)!.hasAttribute("stroke")).toBe(false);
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
        for (const c of [".gauge-track", ".spark-target", ".spark-line", ".spark-dot", ".mark-shape", ".ribbon-shape", ".ring-track", ".ring-arc", ".lc-grid", ".lc-target"]) {
            expect(css).toContain(`.hnh-bsc.hc ${c}`);
        }
    });
    it("monthly bars tell met from missed by class, and high contrast draws the missed ones hollow", () => {
        const row = { trend: [1, 0.5], targetTrend: [1, 1], direction: "higher", scoreBase: 85, scoreSlope: 0.6, goodFrom: 85 } as never;
        const s = monthlyBars(row, 200, 100, "var(--p1)");
        expect([...s.querySelectorAll("rect.bd-bar")].map(r => r.getAttribute("class"))).toEqual(["bd-bar met", "bd-bar missed"]);
        expect(s.querySelector(".bd-tline")!.hasAttribute("stroke")).toBe(false);
        expect(css).toContain(".hnh-bsc.hc .bd-bar.missed");
        expect(css).toContain(".hnh-bsc.hc .bd-tline");
    });
    it("state text colours (variance, panel state, deltas) follow the host foreground", () => {
        for (const t of ["--good-tx", "--warn-tx", "--bad-tx", "--nodata-tx"]) expect(css).toMatch(new RegExp(`\\.hnh-bsc\\.hc\\{[^}]*${t}:var\\(--hc-fg\\)`));
    });
});
