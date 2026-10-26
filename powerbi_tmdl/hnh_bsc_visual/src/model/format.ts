/** The placeholder for a missing value, everywhere in the visual. */
export const DASH = "–";

/** A finite number (not null, undefined or NaN). */
export const isNum = (v: number | null | undefined): v is number => typeof v === "number" && Number.isFinite(v);

function fixed(v: number, decimals: number): string {
    return v.toLocaleString("en-US", { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
}

export function formatValue(v: number | null, fmt: string): string {
    if (v === null || v === undefined || !Number.isFinite(v)) return DASH;
    switch (fmt) {
        case "pct":
            return `${fixed(v * 100, 1)}%`;
        case "sar":
            // Billions in B (two decimals), so a group figure fits its column: "SAR 1.15B", not "SAR 1,148.6M".
            if (Math.abs(v) >= 1e9) return `SAR ${fixed(v / 1e9, 2)}B`;
            return Math.abs(v) >= 1e6 ? `SAR ${fixed(v / 1e6, 1)}M` : `SAR ${fixed(v, 0)}`;
        case "days":
            return `${fixed(v, 1)} days`;
        case "mins":
            return `${fixed(v, 0)} min`;
        default:
            return Math.abs(v) >= 1000 ? fixed(v, 0) : fixed(v, 2);
    }
}

export function formatVariance(v: number | null): string {
    if (v === null || v === undefined || !Number.isFinite(v)) return DASH;
    const text = fixed(Math.abs(v) * 100, 1);
    return `${v < 0 ? "−" : "+"}${text}%`;
}

const roundDelta = (d: number) => Math.round(d * 10) / 10;

/** A month-on-month change in score points: "▲ 1.0" / "▼ 2.4"; "0.0" without an arrow when it rounds to zero. */
export function formatDelta(d: number | null): string {
    if (d === null || d === undefined || !Number.isFinite(d)) return DASH;
    const r = roundDelta(d);
    return r === 0 ? "0.0" : `${r < 0 ? "▼" : "▲"} ${Math.abs(r).toFixed(1)}`;
}

/** The delta's class: "up", "down", or "flat" when it rounds to zero or is missing. */
export function deltaDirection(d: number | null): "up" | "down" | "flat" {
    if (d === null || d === undefined || !Number.isFinite(d)) return "flat";
    const r = roundDelta(d);
    return r > 0 ? "up" : r < 0 ? "down" : "flat";
}
