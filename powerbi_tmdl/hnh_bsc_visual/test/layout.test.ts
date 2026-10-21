import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";

const css = readFileSync("style/visual.less", "utf8");

describe("layout rules found in the screenshot review", () => {
    it("owner figures stay on one line", () => {
        expect(css).toMatch(/\.owner td\.num\{[^}]*white-space:nowrap/);
    });
    it("the comparison table fills the visual", () => {
        expect(css).toMatch(/\.cmp table\{[^}]*width:100%/);
        expect(css).not.toMatch(/\.cmp table\{[^}]*width:auto/);
    });
});
