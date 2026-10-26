import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";

const css = readFileSync("style/visual.less", "utf8");

describe("layout rules found in the screenshot review", () => {
    it("owner figures stay on one line", () => {
        expect(css).toMatch(/\.owner td\.num\{[^}]*white-space:nowrap/);
    });
    it("the comparison table is fixed-layout with a sticky header, a narrow rank and a capped hospital column", () => {
        expect(css).toMatch(/\.cmp table\{[^}]*table-layout:fixed/);
        expect(css).toMatch(/\.cmp thead th\{[^}]*position:sticky;top:0;background:var\(--card\)/);
        expect(css).toMatch(/\.cmp \.rank\{[^}]*width:44px/);
        expect(css).toMatch(/\.cmp \.hosp\{[^}]*width:min\(22%,240px\)/);
    });
    it("KPI cells put actual / target on their own smaller line", () => {
        expect(css).toMatch(/\.cmp td \.at\{[^}]*display:block/);
    });
    it("the overview grid has the report's geometry: 450 px overall panel, four cards, a 348 px top row, 24 px gaps", () => {
        expect(css).toMatch(/\.ov\{[^}]*grid-template-columns:450px repeat\(4,minmax\(0,1fr\)\)/);
        expect(css).toMatch(/\.ov\{[^}]*grid-template-rows:348px minmax\(0,1fr\)/);
        expect(css).toMatch(/\.ov\{[^}]*gap:24px/);
        expect(css).toMatch(/\.ov-row2\{[^}]*grid-column:1\/-1/);
        expect(css).toMatch(/\.ov-row2\{[^}]*grid-template-columns:minmax\(0,1fr\) 630px/);
        expect(css).toMatch(/\.ov-row2\.no-trend\{[^}]*grid-template-columns:minmax\(0,1fr\)/);
    });
    it("the board grid keeps its rows to their content", () => {
        expect(css).toMatch(/\.grid\{[^}]*grid-auto-rows:max-content/);
    });
    it("the comparison table fills the visual", () => {
        expect(css).toMatch(/\.cmp table\{[^}]*width:100%/);
        expect(css).not.toMatch(/\.cmp table\{[^}]*width:auto/);
    });
});
