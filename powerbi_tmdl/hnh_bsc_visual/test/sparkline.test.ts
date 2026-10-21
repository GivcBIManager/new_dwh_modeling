// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { sparkPath } from "../src/render/sparkline";

const pts = (d: string) => (d.match(/[ML]/g) ?? []).length;

describe("sparkPath", () => {
    it("draws a line through all points", () => {
        const r = sparkPath([1, 2, 3], [], 100, 40);
        expect(r.line.startsWith("M")).toBe(true);
        expect(pts(r.line)).toBe(3);
        expect(r.targetLine).toBe("");
    });
    it("skips nulls but keeps x positions, and draws the target", () => {
        const r = sparkPath([null, null, 5, 7], [6, 6, 6, 6], 100, 40);
        expect(pts(r.line)).toBe(2);
        expect(r.targetLine).not.toBe("");
        expect(r.last?.x).toBe(98);
    });
    it("draws nothing for a single point", () => {
        const r = sparkPath([5], [], 100, 40);
        expect(r.line).toBe("");
        expect(r.last).toBeNull();
    });
    it("never prints NaN", () => {
        const cases: [(number | null)[], (number | null)[]][] = [
            [[], []], [[null], []], [[4, 4, 4], []], [[4, 4, 4], [4, 4, 4]], [[1, 2], [null, null]], [[0, 0], [0, 0]],
        ];
        for (const [v, t] of cases) {
            const r = sparkPath(v, t, 100, 40);
            expect(JSON.stringify(r)).not.toContain("NaN");
        }
    });
});
