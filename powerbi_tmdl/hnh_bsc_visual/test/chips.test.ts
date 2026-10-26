// @vitest-environment jsdom
import { describe, it, expect } from "vitest";
import { stateChip, stateMark, pillarColourVar } from "../src/render/chips";

describe("status marks and chips", () => {
    it("draws a mark span per state class, hidden from assistive tech", () => {
        const m = stateMark("bad");
        expect(m.tagName).toBe("SPAN");
        expect(m.className).toBe("mark bad");
        expect(m.getAttribute("aria-hidden")).toBe("true");
        expect(stateMark("notarget").className).toBe("mark nodata");
    });
    it("builds a chip with a mark and the state word", () => {
        const c = stateChip("warn", "Watch");
        expect(c.className).toBe("chip warn");
        expect(c.querySelector(".mark.warn")).not.toBeNull();
        expect(c.textContent).toBe("Watch");
    });
    it("puts the optional text before the word and shares the no-data styling", () => {
        const c = stateChip("parked", "Parked", "3");
        expect(c.className).toBe("chip nodata");
        expect(c.textContent).toBe("3 Parked");
    });
    it("maps pillar order to a pillar colour variable with a fallback", () => {
        expect(pillarColourVar(1)).toBe("var(--p1)");
        expect(pillarColourVar(2)).toBe("var(--p2)");
        expect(pillarColourVar(4)).toBe("var(--p4)");
        expect(pillarColourVar(9)).toBe("var(--blue-dk)");
        expect(pillarColourVar(0)).toBe("var(--blue-dk)");
    });
});
