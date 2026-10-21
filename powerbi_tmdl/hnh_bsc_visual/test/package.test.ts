import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const read = (file: string) => readFileSync(resolve(__dirname, "..", file), "utf-8");

describe("package contents", () => {
    it("declares no tooltips data role: a report-page tooltip is set in the Format pane", () => {
        const caps = JSON.parse(read("capabilities.json"));
        const roles = caps.dataRoles.map((r: { name: string }) => r.name);
        expect(roles).not.toContain("tooltips");
        expect(JSON.stringify(caps.dataViewMappings)).not.toContain("tooltips");
        expect(caps.tooltips.supportedTypes).toEqual({ default: true, canvas: true });
    });
    it("binds only declared roles", () => {
        const caps = JSON.parse(read("capabilities.json"));
        const roles = new Set(caps.dataRoles.map((r: { name: string }) => r.name));
        const bound = [...JSON.stringify(caps.dataViewMappings).matchAll(/"(?:to|in|by)":"(\w+)"/g)].map(m => m[1]);
        expect(bound.filter(r => !roles.has(r))).toEqual([]);
    });
    it("has no d3 dependency", () => {
        const pkg = JSON.parse(read("package.json"));
        expect(Object.keys({ ...pkg.dependencies, ...pkg.devDependencies }).filter(n => n === "d3" || n === "@types/d3")).toEqual([]);
    });
    it("has no prototype tooltip or menu styles (the host draws both)", () => {
        expect(read("style/visual.less")).not.toMatch(/(^|[\s,}])\.(tip|menu|sep)\b/m);
    });
});
