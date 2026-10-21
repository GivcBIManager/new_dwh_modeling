import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";

const css = readFileSync("style/visual.less", "utf8");

describe("layout rules found in the screenshot review", () => {
    it("owner figures stay on one line", () => {
        expect(css).toMatch(/\.owner td\.num\{[^}]*white-space:nowrap/);
    });
    it("the comparison table is fixed-layout with a sticky header and a capped KPI column", () => {
        expect(css).toMatch(/\.cmp table\{[^}]*table-layout:fixed/);
        expect(css).toMatch(/\.cmp thead th\{[^}]*position:sticky;top:0;background:var\(--card\)/);
        expect(css).toMatch(/\.cmp thead th:first-child\{width:min\(32%,420px\)\}/);
    });
    it("gauges and the overview grid shrink instead of overflowing narrow pages", () => {
        expect(css).toMatch(/\.overall \.gauge,[^{]*\{max-width:100%;height:auto\}/);
        expect(css).toMatch(/\.pillars\{[^}]*repeat\(2,minmax\(0,1fr\)\)/);
        expect(css).toMatch(/\.grid\{[^}]*grid-auto-rows:max-content/);
    });
    it("the pillar gauge column is fluid", () => {
        expect(css).toMatch(/\.pillar \.body\{[^}]*minmax\(150px,230px\)/);
    });
    it("the comparison table fills the visual", () => {
        expect(css).toMatch(/\.cmp table\{[^}]*width:100%/);
        expect(css).not.toMatch(/\.cmp table\{[^}]*width:auto/);
    });
});
