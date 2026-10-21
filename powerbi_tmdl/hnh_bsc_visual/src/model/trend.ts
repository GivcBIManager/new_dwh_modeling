/** Parse a number from the payload ("100." and "-0.0523" are valid; blank is null). */
export function parseNumber(text: string | null | undefined): number | null {
    if (text === null || text === undefined) return null;
    const t = text.trim();
    if (t === "") return null;
    const n = Number(t);
    return Number.isFinite(n) ? n : null;
}

/** "1;;3" gives [1, null, 3]. Empty or missing text, or a guard text, gives []. */
export function parseTrend(text: string | null): (number | null)[] {
    if (text === null || text === undefined || text.trim() === "" || text.startsWith("\"")) return [];
    return text.split(";").map(parseNumber);
}
