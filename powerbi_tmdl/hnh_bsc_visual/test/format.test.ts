import { describe, it, expect } from "vitest";
import { deltaDirection, formatDelta, formatValue, formatVariance } from "../src/model/format";

describe("formatValue", () => {
    it("formats each value format", () => {
        expect(formatValue(0.1234, "pct")).toBe("12.3%");
        expect(formatValue(12345678, "sar")).toBe("SAR 12.3M");
        expect(formatValue(12345, "sar")).toBe("SAR 12,345");
        // billions in B with two decimals, so a group revenue fits its column (not "SAR 1,148.6M")
        expect(formatValue(1148600000, "sar")).toBe("SAR 1.15B");
        expect(formatValue(-2500000000, "sar")).toBe("SAR -2.50B");
        expect(formatValue(999000000, "sar")).toBe("SAR 999.0M");
        expect(formatValue(4, "days")).toBe("4.0 days");
        expect(formatValue(12.4, "mins")).toBe("12 min");
        expect(formatValue(73.354, "num")).toBe("73.35");
        expect(formatValue(1234.5, "num")).toBe("1,235");
    });
    it("shows a dash for a missing value", () => {
        expect(formatValue(null, "pct")).toBe("–");
    });
});

describe("formatVariance", () => {
    it("signs the percentage", () => {
        expect(formatVariance(0.052)).toBe("+5.2%");
        expect(formatVariance(-0.1)).toBe("−10.0%");
        expect(formatVariance(null)).toBe("–");
    });
});

describe("formatDelta", () => {
    it("rounds to one decimal, with an arrow up or down", () => {
        expect(formatDelta(1)).toBe("▲ 1.0");
        expect(formatDelta(-2.36)).toBe("▼ 2.4");
        expect(deltaDirection(1)).toBe("up");
        expect(deltaDirection(-2.36)).toBe("down");
    });
    it("prints a delta that rounds to zero without an arrow", () => {
        for (const d of [0, 0.04, -0.04, -0]) {
            expect(formatDelta(d)).toBe("0.0");
            expect(deltaDirection(d)).toBe("flat");
        }
    });
    it("shows a dash for no delta", () => {
        expect(formatDelta(null)).toBe("–");
        expect(deltaDirection(null)).toBe("flat");
    });
});
