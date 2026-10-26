import powerbi from "powerbi-visuals-api";
import DataView = powerbi.DataView;

/** Row of attribute values keyed by role name, plus the payload text (one per branch when branches are used) and the label. */
export interface FixtureRow {
    [role: string]: unknown;
    payload?: string | (string | null)[] | null;
    selectionLabel?: string | (string | null)[] | null;
    targetBasis?: string | (string | null)[] | null;
    manualNote?: string | (string | null)[] | null;
}

export interface FixtureOpts {
    branches?: string[];
}

export const CATEGORY_ROLES = [
    "kpi", "kpiName", "shortLabel", "pillar", "pillarOrder", "pillarWeight", "pillarQuestion",
    "objectiveCode", "objectiveTitle", "objectiveOrder", "kpiType", "direction", "valueFormat",
    "displayOrder", "kpiStatus", "valueSource", "owner", "definition", "coOwners", "scoreBase", "scoreSlope", "goodFrom", "watchFrom",
];

/** Build the payload text: fields 1-9 in the measure's order. */
export function payload(f: {
    actual?: number | null; target?: number | null; variance?: number | null; score?: number | null;
    state?: string; weight?: number | null; trend?: (number | null)[]; targetTrend?: (number | null)[]; scoreTrend?: (number | null)[];
}): string {
    const n = (v: number | null | undefined) => (v === null || v === undefined ? "" : String(v));
    const t = (a?: (number | null)[]) => (a ? a.map(n).join(";") : "");
    return [n(f.actual), n(f.target), n(f.variance), n(f.score), f.state ?? "", n(f.weight), t(f.trend), t(f.targetTrend), t(f.scoreTrend)].join("|");
}

export function makeDataView(rows: FixtureRow[], opts: FixtureOpts = {}): DataView {
    const categories = CATEGORY_ROLES.map(role => ({
        source: { displayName: role, roles: { [role]: true }, queryName: `BSC KPI.${role}` },
        values: rows.map(r => (r[role] === undefined ? null : r[role])),
    }));
    const branches: (string | null)[] = opts.branches ?? [null];
    const groups = branches.map((b, gi) => {
        const col = (role: string, pick: (r: FixtureRow) => unknown) => ({
            source: { displayName: role, roles: { [role]: true }, queryName: `m.${role}` },
            values: rows.map(r => pick(r)),
        });
        const pay = (r: FixtureRow) => (Array.isArray(r.payload) ? r.payload[gi] ?? null : (r.payload ?? null));
        const lab = (r: FixtureRow) => (Array.isArray(r.selectionLabel) ? r.selectionLabel[gi] ?? null : (r.selectionLabel ?? null));
        const pick = (role: "targetBasis" | "manualNote") => (r: FixtureRow) => {
            const v = r[role];
            return Array.isArray(v) ? v[gi] ?? null : (v ?? null);
        };
        const vals = [col("payload", pay), col("selectionLabel", lab)];
        for (const role of ["targetBasis", "manualNote"] as const) {
            if (rows.some(r => r[role] !== undefined)) vals.push(col(role, pick(role)));
        }
        return { name: b, values: vals };
    });
    const flat = groups.flatMap(g => g.values);
    const values: Record<string, unknown> = Object.assign([...flat], { grouped: () => groups });
    if (opts.branches) {
        values.source = { displayName: "Branch", roles: { branch: true }, queryName: "Branch.Branch" };
    }
    return { metadata: { columns: [] }, categorical: { categories, values } } as unknown as DataView;
}
