const NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** The n month names ending at the last "MMM yyyy" in the selection label; [] when the label has no month. */
export function monthLabels(label: string, n: number): string[] {
    const all = [...String(label ?? "").matchAll(/\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{4}\b/g)];
    if (all.length === 0 || n <= 0) return [];
    const end = NAMES.indexOf(all[all.length - 1][1]);
    const out: string[] = [];
    for (let i = n - 1; i >= 0; i--) out.push(NAMES[(((end - i) % 12) + 12) % 12]);
    return out;
}

/** Last month minus the one before; null unless both are numbers. */
export function lastDelta(trend: (number | null)[]): number | null {
    const n = trend.length;
    if (n < 2) return null;
    const a = trend[n - 1], b = trend[n - 2];
    return typeof a === "number" && Number.isFinite(a) && typeof b === "number" && Number.isFinite(b) ? a - b : null;
}
