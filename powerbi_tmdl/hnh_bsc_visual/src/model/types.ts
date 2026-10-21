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
    counts: Record<StateKey, number>;
}

export interface ViewModel {
    pillars: PillarSummary[];
    overallScore: number | null;
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
