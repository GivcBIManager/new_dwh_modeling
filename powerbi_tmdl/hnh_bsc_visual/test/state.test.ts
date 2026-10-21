import { describe, it, expect } from "vitest";
import { stateOf } from "../src/model/state";

describe("stateOf", () => {
    it("maps the state words", () => {
        expect(stateOf("On track", "active", "measure").key).toBe("good");
        expect(stateOf("Watch", "active", "measure").key).toBe("warn");
        expect(stateOf("At risk", "active", "measure").key).toBe("bad");
        expect(stateOf("No target", "active", "measure").key).toBe("notarget");
        expect(stateOf("On track", "active", "measure").reason).toBeNull();
    });
    it("explains No data yet by source", () => {
        expect(stateOf("No data yet", "active", "manual")).toMatchObject({ key: "nodata", reason: "Waiting for this month's entry" });
        expect(stateOf("No data yet", "active", "measure")).toMatchObject({ key: "nodata", reason: "Not yet calculated for this selection" });
    });
    it("explains Parked", () => {
        expect(stateOf("Parked", "parked", "measure")).toMatchObject({ key: "parked", reason: "Definition to be agreed" });
        expect(stateOf("Parked", "active", "manual").reason).toBe("Waiting for the first entry");
        expect(stateOf("Parked", "active", "measure").reason).toBe("No data in any month");
    });
    it("treats a missing state as no data", () => {
        expect(stateOf(null, "active", "measure").key).toBe("nodata");
    });
});
