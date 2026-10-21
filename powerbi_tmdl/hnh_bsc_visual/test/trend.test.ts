import { describe, it, expect } from "vitest";
import { parseTrend } from "../src/model/trend";

describe("parseTrend", () => {
    it("splits values", () => expect(parseTrend("1;2;3")).toEqual([1, 2, 3]));
    it("keeps empty slots as null", () => expect(parseTrend(";;5;7")).toEqual([null, null, 5, 7]));
    it("returns [] for empty or missing", () => {
        expect(parseTrend("")).toEqual([]);
        expect(parseTrend(null)).toEqual([]);
    });
    it("returns [] for a guard text", () => {
        expect(parseTrend("\"This measure can't be analysed by Payer\"")).toEqual([]);
    });
    it("accepts a trailing dot", () => expect(parseTrend("100.;-0.5")).toEqual([100, -0.5]));
});
