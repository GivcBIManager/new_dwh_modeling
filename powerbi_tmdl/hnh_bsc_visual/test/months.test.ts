import { describe, it, expect } from "vitest";
import { monthLabels, lastDelta } from "../src/model/months";

describe("months", () => {
    it("monthLabels ends at the last month in the label", () => {
        const m = monthLabels("Corporate · Jan 2026 – Sep 2026", 12);
        expect(m).toHaveLength(12);
        expect(m[0]).toBe("Oct");
        expect(m[11]).toBe("Sep");
        expect(monthLabels("Hospital A · Mar 2026", 3)).toEqual(["Jan", "Feb", "Mar"]);
    });
    it("monthLabels is empty without a month", () => {
        expect(monthLabels("No hospital", 12)).toEqual([]);
        expect(monthLabels("", 3)).toEqual([]);
    });
    it("lastDelta compares the last two months", () => {
        expect(lastDelta([80, null, 82, 84.5])).toBe(2.5);
        expect(lastDelta([80, null])).toBeNull();
        expect(lastDelta([])).toBeNull();
    });
});
