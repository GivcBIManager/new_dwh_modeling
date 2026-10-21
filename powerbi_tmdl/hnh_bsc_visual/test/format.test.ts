import { describe, it, expect } from "vitest";
import { formatValue, formatVariance } from "../src/model/format";

describe("formatValue", () => {
    it("formats each value format", () => {
        expect(formatValue(0.1234, "pct")).toBe("12.3%");
        expect(formatValue(12345678, "sar")).toBe("SAR 12.3M");
        expect(formatValue(12345, "sar")).toBe("SAR 12,345");
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
