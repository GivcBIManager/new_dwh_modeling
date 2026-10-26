export type StateKey = "good" | "warn" | "bad" | "nodata" | "parked" | "notarget";

export interface KpiRow {
    code: string;
    name: string;
    shortLabel: string;
    pillar: string;
    pillarOrder: number;
    pillarWeight: number | null;
    pillarQuestion: string;
    objectiveCode: string;
    objectiveTitle: string;
    objectiveOrder: number;
    primary: boolean;
    direction: string;
    valueFormat: string;
    displayOrder: number;
    manual: boolean;
    parkedInCatalogue: boolean;
    owner: string;
    definition: string;
    targetBasis: string;
    manualNote: string;
    /** The KPI's own scoring rule (blank in the model falls back to 85 / 0.6 / 85 / 70). */
    scoreBase: number;
    scoreSlope: number;
    goodFrom: number;
    watchFrom: number;
    /** Other people accountable for the KPI, from 'BSC KPI'[Co Owners] ("|" separated); never the owner. */
    coOwners: string[];
    actual: number | null;
    target: number | null;
    variance: number | null;
    score: number | null;
    weight: number | null;
    state: StateKey;
    stateWord: string;
    reason: string | null;
    trend: (number | null)[];
    targetTrend: (number | null)[];
    scoreTrend: (number | null)[];
    branch: string | null;
    rowIndex: number;
    seriesIndex: number | null;
}

export interface PillarSummary {
    name: string;
    order: number;
    weight: number | null;
    question: string;
    score: number | null;
    trend: (number | null)[];
    kpis: KpiRow[];
    /** Counts, score and trend describe the first branch (or all rows without a branch series). */
    counts: Record<StateKey, number>;
    /** One entry per branch series, in data order; empty without a branch series. */
    byBranch: { branch: string; score: number | null; counts: Record<StateKey, number> }[];
}

export interface ViewModel {
    pillars: PillarSummary[];
    overallScore: number | null;
    /** Overall score per branch series; empty without a branch series. */
    overallByBranch: { branch: string; score: number | null }[];
    label: string;
    thresholds: { base: number; slope: number; good: number; watch: number };
    branches: string[];
    guardMessage: string | null;
}

/** The nine fields of [BSC Visual Payload]. */
export interface Payload {
    actual: number | null;
    target: number | null;
    variance: number | null;
    score: number | null;
    stateText: string | null;
    weight: number | null;
    trend: (number | null)[];
    targetTrend: (number | null)[];
    scoreTrend: (number | null)[];
}
