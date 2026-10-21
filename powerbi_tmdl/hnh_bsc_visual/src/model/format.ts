const DASH = "–";

function fixed(v: number, decimals: number): string {
    return v.toLocaleString("en-US", { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
}

export function formatValue(v: number | null, fmt: string): string {
    if (v === null || v === undefined || !Number.isFinite(v)) return DASH;
    switch (fmt) {
        case "pct":
            return `${fixed(v * 100, 1)}%`;
        case "sar":
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
