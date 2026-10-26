import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";

const css = readFileSync("style/visual.less", "utf8");

describe("layout rules found in the screenshot review", () => {
    it("table figures and panel figures clip with an ellipsis instead of running into the next column", () => {
        expect(css).toMatch(/\.c-actual,\.c-target,\.c-var,\.c-score\{[^}]*overflow:hidden;text-overflow:ellipsis/);
        expect(css).toMatch(/\.bd-fact-v\{[^}]*font-size:33px[^}]*overflow:hidden;text-overflow:ellipsis/);
    });
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
    it("the pillar board has the report's geometry: a 96 px strip, a 21 px gap, the table beside a 660 px panel", () => {
        expect(css).toMatch(/\.bd\{[^}]*grid-template-rows:96px minmax\(0,1fr\)/);
        expect(css).toMatch(/\.bd\{[^}]*gap:21px/);
        expect(css).toMatch(/\.bd-strip\{[^}]*height:96px/);
        expect(css).toMatch(/\.bd-body\{[^}]*grid-template-columns:minmax\(0,1fr\) 660px/);
        expect(css).toMatch(/\.bd-body\{[^}]*gap:24px/);
    });
    it("the panel keeps its drawn part to 432 px and leaves the chart and button slots at their report size", () => {
        expect(css).toMatch(/\.bd-panel-main\{[^}]*height:432px/);
        expect(css).toMatch(/\.bd-slot-chart\{[^}]*height:219px/);
        expect(css).toMatch(/\.bd-slot-chart\{[^}]*margin:0 24px/);
        expect(css).toMatch(/\.bd-slot-button\{[^}]*height:60px/);
        expect(css).toMatch(/\.bd-slot-button\{[^}]*margin:18px 24px 0/);
        // A border would move the slots by its width: the panel's edge is an inset shadow.
        expect(css).not.toMatch(/\.bd-panel\{[^}]*border:/);
    });
    it("the scorecard rows scroll inside the table under a fixed header row", () => {
        expect(css).toMatch(/\.bd-tbody\{[^}]*overflow-y:auto/);
        expect(css).toMatch(/\.bd-tbody\{[^}]*flex:1/);
        expect(css).toMatch(/\.bd-tbody\{[^}]*min-height:0/);
        expect(css).toMatch(/\.bd-thead\{[^}]*flex:none/);
        expect(css).toMatch(/\.bd-table\{[^}]*overflow:hidden/);
    });
    it("the comparison table fills the visual", () => {
        expect(css).toMatch(/\.cmp table\{[^}]*width:100%/);
        expect(css).not.toMatch(/\.cmp table\{[^}]*width:auto/);
    });
});
