import type { KpiRow } from "./types";

/**
 * Owner achievement, as the old report's ownership overview (handover Hayat_BSC_Full_RS: _v9KpiUnitScore,
 * _varianceUnit, _ceilingUnit, _kpiCanJudge, _kpiOnTarget, _computeOwnerStats).
 * Weighted = weight-weighted mean of KPI unit scores (no cap); On-target = share of judgeable KPIs on or past target.
 * An owner's card blends 70% their own KPIs with 30% KPI 1, Net Revenue Achievement (the user's rule, 2026-11-12).
 */
export type ScoreMode = "weighted" | "hitrate";
export type OwnerTier = "csuite" | "all";
/** "owned": the owner's KPIs; "co": the owner's KPIs plus those they co-own. */
export type OwnerScope = "owned" | "co";

/** The C-suite roles, in strip order (the KPI owners of 2026-11-12, then roles of earlier ownership maps). */
export const CSUITE = ["CEO", "CMOO", "CMO", "COO", "CFO", "CCO", "CPEO", "CHRO", "CIO", "CSO"] as const;

/** KPI 1, Net Revenue Achievement: SHARED_SHARE of every owner's score. */
export const SHARED_KPI = "FIN_NET_REVENUE";
export const SHARED_SHARE = 0.3;

const norm = (name: string) => String(name ?? "").replace(/\s+/g, " ").trim().toUpperCase();
const csuiteIndex = (name: string) => (CSUITE as readonly string[]).indexOf(norm(name));
const num = (v: number | null | undefined): v is number => typeof v === "number" && Number.isFinite(v);

export function isCsuite(name: string): boolean {
    return csuiteIndex(name) >= 0;
}

/** Budget variance unit: 1 - (actual - target); values above 1.5 are read as percentages; at or below 0 becomes 0.01. */
export function varianceUnit(a: number, t: number): number | null {
    let av = a, tv = t;
    if (Math.abs(av) > 1.5 || Math.abs(tv) > 1.5) { av /= 100; tv /= 100; }
    let unit = 1 - (av - tv);
    if (!Number.isFinite(unit)) return null;
    if (unit <= 0) unit = 0.01;
    return unit;
}

/** Ceiling unit: 1 at or under the target, target / actual above it; no score without a positive target. */
export function ceilingUnit(a: number, t: number): number | null {
    let av = a, tv = t;
    if (Math.abs(av) > 1.5 || Math.abs(tv) > 1.5) { av /= 100; tv /= 100; }
    if (!(tv > 0)) return null;
    if (av <= tv) return 1;
    const unit = tv / av;
    return Number.isFinite(unit) && unit > 0 ? unit : null;
}

/** The handover scores a KPI as a budget variance when its name says so or it is lower-is-better with target 0
 * (our configuration has no "variance" direction). */
export function isBudgetVariance(r: Pick<KpiRow, "name" | "direction" | "target">): boolean {
    return /budget variance/i.test(r.name ?? "") || (r.direction === "lower" && r.target === 0);
}

/** A row the list shows a value for: actual and target present, not parked, not "no data". */
function hasData(r: KpiRow): boolean {
    return num(r.actual) && num(r.target) && r.state !== "parked" && r.state !== "nodata";
}

/** The KPI's unit score (1 = on target, no cap), or null when it cannot be scored. */
export function unitScore(r: KpiRow): number | null {
    if (!hasData(r)) return null;
    const a = r.actual as number, t = r.target as number;
    const ok = (u: number | null) => (u !== null && Number.isFinite(u) && u > 0 ? u : null);
    if (isBudgetVariance(r)) return ok(varianceUnit(a, t));
    if (r.direction === "ceiling") return ok(ceilingUnit(a, t));
    if (r.direction === "lower") return a > 0 && t > 0 ? ok(t / a) : null;
    if (r.direction === "on_target") return t === 0 ? null : ok(Math.max(0, 1 - Math.abs(a - t) / Math.abs(t)));
    return t > 0 ? ok(a / t) : null;
}

/** Weight-weighted mean of unit scores in percent; KPIs without a unit score or a positive weight are left out. */
export function weightedAchievement(rows: KpiRow[]): number | null {
    let num_ = 0, den = 0;
    for (const r of rows) {
        const u = unitScore(r);
        if (u === null || !num(r.weight) || !(r.weight > 0)) continue;
        num_ += u * r.weight;
        den += r.weight;
    }
    return den > 0 ? (num_ / den) * 100 : null;
}

export function canJudge(r: KpiRow): boolean {
    return hasData(r);
}

/** On or past target: the direction-adjusted variance is 0 or more; without one, actual against target by direction.
 * An on_target KPI's variance is -|actual - target| (never above 0), so it is on target when its state is On track. */
export function onTarget(r: KpiRow): boolean {
    if (r.direction === "on_target") return r.state === "good";
    if (num(r.variance)) return r.variance >= 0;
    if (!num(r.actual) || !num(r.target)) return false;
    return r.direction === "lower" || r.direction === "ceiling" ? r.actual <= r.target : r.actual >= r.target;
}

/** Share of judgeable KPIs on target, in percent; null when none can be judged. */
export function hitRate(rows: KpiRow[]): number | null {
    const judged = rows.filter(canJudge);
    return judged.length ? (100 * judged.filter(onTarget).length) / judged.length : null;
}

export function achievement(rows: KpiRow[], mode: ScoreMode): number | null {
    return mode === "hitrate" ? hitRate(rows) : weightedAchievement(rows);
}

/** The KPIs that count for an owner in the scope. */
export function kpisOf(rows: KpiRow[], owner: string, scope: OwnerScope): KpiRow[] {
    return rows.filter(r => r.owner === owner || (scope === "co" && r.coOwners.includes(owner)));
}

/** Everyone with a KPI in the scope: the C-suite first in its fixed order, then the others by name. */
export function ownersOf(rows: KpiRow[], scope: OwnerScope): string[] {
    const names = new Set<string>();
    for (const r of rows) {
        if (r.owner) names.add(r.owner);
        if (scope === "co") for (const c of r.coOwners) names.add(c);
    }
    const rank = (n: string) => { const i = csuiteIndex(n); return i < 0 ? CSUITE.length : i; };
    return [...names].sort((a, b) => (rank(a) - rank(b)) || a.localeCompare(b));
}

/** An owner's score: (1 - SHARED_SHARE) their own KPIs + SHARED_SHARE Net Revenue Achievement. Without a Net Revenue
 * result the owner's own result alone; without an own result, null (Net Revenue alone says nothing about the owner). */
export function blend(own: number | null, shared: number | null): number | null {
    if (own === null) return null;
    return shared === null ? own : (1 - SHARED_SHARE) * own + SHARED_SHARE * shared;
}

/** Net Revenue Achievement's part of every card, in percent: its unit score (Weighted) or 100 / 0 for on or off target
 * (On-target); null when it cannot be scored or judged, or is neither in the rows nor given as `fallback` (the row
 * from [BSC Net Revenue Payload], for when an Owner filter leaves it out of the rows). */
export function sharedPart(rows: KpiRow[], mode: ScoreMode, fallback: KpiRow | null = null): number | null {
    const r = rows.find(x => x.code === SHARED_KPI) ?? fallback;
    if (!r) return null;
    if (mode === "hitrate") return canJudge(r) ? (onTarget(r) ? 100 : 0) : null;
    const u = unitScore(r);
    return u === null ? null : u * 100;
}

export interface OwnerCard {
    owner: string;
    /** The owner's score in percent (70% own KPIs + 30% Net Revenue), or null when none of their KPIs can be scored or judged. */
    value: number | null;
    /** The owner's own KPIs alone, in percent. */
    own: number | null;
    /** Net Revenue Achievement's part, in percent; null when it has no result. */
    shared: number | null;
    /** KPIs scored (weighted) or on target (hit rate). */
    counted: number;
    /** KPIs in scope (weighted) or judged (hit rate). */
    total: number;
}

/** One card per owner or co-owner in the tier, in strip order. A card always counts the owned and co-owned KPIs
 * (as the old report's _computeOwnerStats); the Owned / Owned + co-owned toggle changes only the KPI list. The value
 * blends the owner's own result with Net Revenue Achievement (blend). */
export function ownerCards(rows: KpiRow[], o: { score: ScoreMode; tier: OwnerTier },
                           sharedRow: KpiRow | null = null): OwnerCard[] {
    const shared = sharedPart(rows, o.score, sharedRow);
    return ownersOf(rows, "co")
        .filter(n => o.tier === "all" || isCsuite(n))
        .map(owner => {
            const list = kpisOf(rows, owner, "co");
            if (o.score === "hitrate") {
                const judged = list.filter(canJudge);
                const own = hitRate(list);
                return { owner, value: blend(own, shared), own, shared, counted: judged.filter(onTarget).length, total: judged.length };
            }
            const scored = list.filter(r => unitScore(r) !== null && num(r.weight) && r.weight > 0);
            const own = weightedAchievement(list);
            return { owner, value: blend(own, shared), own, shared, counted: scored.length, total: list.length };
        });
}
