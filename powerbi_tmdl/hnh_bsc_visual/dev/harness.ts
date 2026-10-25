// Dev harness: renders the real Visual class with a fake host and a synthetic 70-KPI catalogue (comparison: 8 hospitals,
// 14 objectives, 31 KPIs). No real hospital figures.
import { Visual } from "../src/visual";
import { makeDataView, payload, FixtureRow } from "../test/fixtures";

let seed = 20261021;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };

const PILLARS = [
    { name: "Financial", order: 1, weight: 0.3, count: 14, q: "Are we financially sound and sustainable?", objectives: ["Grow revenue", "Control cost", "Protect cash"] },
    { name: "Customer", order: 2, weight: 0.25, count: 14, q: "Do patients and payers choose and trust us?", objectives: ["Patient experience", "Payer relationships"] },
    { name: "Internal Process", order: 3, weight: 0.3, count: 26, q: "Are our clinical and operational processes efficient and safe?", objectives: ["Clinical quality", "Throughput", "Supply chain", "Revenue cycle"] },
    { name: "Learning & Growth", order: 4, weight: 0.15, count: 16, q: "Are our people and systems ready for tomorrow?", objectives: ["Workforce", "Technology"] },
];
const OWNERS = ["Finance Department", "Patient Experience", "Medical Director", "Nursing Affairs", "Operations", "Human Resources", "Supply Chain", "Revenue Cycle", "Quality Department", "Information Technology"];
const MONTHS = 12;
const BASE = 85, SLOPE = 0.6, GOOD = 85, WATCH = 70;

interface Spec { name: string; fmt: string; dir: string; target: number }
const SPECS: Spec[] = [
    { name: "Net patient revenue", fmt: "sar", dir: "higher", target: 5_200_000 },
    { name: "Operating cost per bed day", fmt: "sar", dir: "ceiling", target: 1_800 },
    { name: "Pharmacy cost", fmt: "sar", dir: "ceiling", target: 2_400_000 },
    { name: "Outstanding insurance receivables", fmt: "sar", dir: "lower", target: 7_900_000 },
    { name: "Claim rejection rate", fmt: "pct", dir: "lower", target: 0.06 },
    { name: "Collection rate", fmt: "pct", dir: "higher", target: 0.92 },
    { name: "Bed occupancy rate", fmt: "pct", dir: "on_target", target: 0.78 },
    { name: "Staff turnover rate", fmt: "pct", dir: "lower", target: 0.11 },
    { name: "Readmission within 30 days", fmt: "pct", dir: "lower", target: 0.045 },
    { name: "Theatre utilisation rate", fmt: "pct", dir: "higher", target: 0.82 },
    { name: "Average length of stay", fmt: "days", dir: "on_target", target: 3.8 },
    { name: "Days in accounts receivable", fmt: "days", dir: "lower", target: 62 },
    { name: "Inventory days on hand", fmt: "days", dir: "on_target", target: 24 },
    { name: "ER door-to-doctor time", fmt: "mins", dir: "lower", target: 18 },
    { name: "Lab turnaround time", fmt: "mins", dir: "lower", target: 45 },
    { name: "Discharge process time", fmt: "mins", dir: "lower", target: 120 },
    { name: "Patient satisfaction (NPS)", fmt: "num", dir: "higher", target: 72 },
    { name: "Cost-to-revenue ratio", fmt: "num", dir: "ceiling", target: 0.88 },
    { name: "Nurse-to-patient ratio", fmt: "num", dir: "on_target", target: 5.5 },
];
const LONG: Spec[] = [
    { name: "Share of elective surgeries starting within 15 minutes of schedule", fmt: "pct", dir: "higher", target: 0.85 },
    { name: "Outpatient prescriptions dispensed within 20 minutes of arrival", fmt: "pct", dir: "higher", target: 0.9 },
];
const QUALIFIER = ["", " (YTD)", " (month)"];

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));
/** Score from the target variance: base 85 at target, 0.6 points per 1%, direction-aware, clamped and rounded. */
function scoreOf(variance: number, dir: string): number {
    const signed = dir === "lower" || dir === "ceiling" ? -variance : dir === "on_target" ? -Math.abs(variance) : variance;
    return Math.round(clamp(BASE + SLOPE * 100 * signed, 0, 100));
}
const stateOf = (score: number) => (score >= GOOD ? "On track" : score >= WATCH ? "Watch" : "At risk");

function branchPayload(kind: string, spec: Spec, tilt: number): string {
    if (kind === "empty") return payload({ state: "" });
    if (kind === "parked") return payload({ state: "Parked" });
    const target = spec.target * (1 + (rnd() - 0.5) * 0.04);
    const variance = (rnd() - 0.5) * 0.55 + tilt;
    const actual = target * (1 + variance);
    const score = scoreOf(variance, spec.dir);
    const trend = Array.from({ length: MONTHS }, () => actual * (1 + (rnd() - 0.5) * 0.1));
    trend[MONTHS - 1] = actual;
    return payload({
        actual, target, variance, score, state: stateOf(score), weight: 1 + Math.floor(rnd() * 3),
        trend, targetTrend: Array(MONTHS).fill(target), scoreTrend: trend.map(v => scoreOf(v / target - 1, spec.dir)),
    });
}

/** The comparison page binds [BSC Visual Payload Scores]: the first six fields, empty trends. */
const scoresOnly = (p: string) => p.split("|").slice(0, 6).join("|") + "|||";
const PERIOD = "Jan 2026 – Sep 2026";

/** Rows for the given branch series (none: one corporate column). A branch named "Head Office" has no KPI values. */
export function buildRows(branches: string[] | null): FixtureRow[] {
    const rows: FixtureRow[] = [];
    let n = 0;
    for (const p of PILLARS) {
        for (let i = 0; i < p.count; i++, n++) {
            const longIdx = p.order === 1 && i === 5 ? 0 : p.order === 3 && i === 9 ? 1 : -1;
            const spec = longIdx >= 0 ? LONG[longIdx] : SPECS[(n * 7) % SPECS.length];
            const qual = longIdx >= 0 ? "" : QUALIFIER[Math.floor(n / SPECS.length) % QUALIFIER.length];
            const objIdx = i % p.objectives.length;
            const allParked = p.order === 4 && objIdx === 1;
            const parkedCatalogue = allParked || n % 17 === 6;
            const manual = n % 9 === 4;
            const noData = !parkedCatalogue && n % 11 === 3;
            const kind = parkedCatalogue ? "parked" : noData ? "empty" : "value";
            const tilt = (2.5 - p.order) * 0.03;
            rows.push({
                kpi: `${p.name.slice(0, 1)}${p.order}-${String(i + 1).padStart(2, "0")}`,
                kpiName: spec.name + qual, shortLabel: spec.name,
                pillar: p.name, pillarOrder: p.order, pillarWeight: p.weight, pillarQuestion: p.q,
                objectiveCode: `${p.name.slice(0, 1)}${p.order}.${objIdx + 1}`, objectiveTitle: p.objectives[objIdx], objectiveOrder: objIdx + 1,
                kpiType: i < 4 ? "Primary" : "Supporting", direction: spec.dir, valueFormat: spec.fmt, displayOrder: i + 1,
                kpiStatus: parkedCatalogue ? "parked" : "active", valueSource: manual ? "manual" : "measure",
                owner: OWNERS[n % OWNERS.length], scoreBase: BASE, scoreSlope: SLOPE, goodFrom: GOOD, watchFrom: WATCH,
                payload: branches
                    ? branches.map((b, bi) => scoresOnly(b === "Head Office" ? payload({ state: "No data yet" }) : branchPayload(kind, spec, tilt + (bi - 1) * 0.06)))
                    : branchPayload(kind, spec, tilt),
                selectionLabel: branches ? branches.map(b => `${b} · ${PERIOD}`) : `Corporate · ${PERIOD}`,
            });
        }
    }
    return rows;
}

/** Comparison catalogue: the four pillars with lettered objectives (F1 Revenue, ...) and two or three KPIs each. */
const CMP: { pillar: string; order: number; weight: number; q: string; objectives: [string, string, Spec[]][] }[] = [
    { pillar: "Financial", order: 1, weight: 0.3, q: PILLARS[0].q, objectives: [
        ["F1", "Revenue", [{ name: "Net revenue achievement", fmt: "sar", dir: "higher", target: 48_000_000 }, { name: "Net revenue growth vs last year", fmt: "pct", dir: "higher", target: 0.06 }]],
        ["F2", "Profitability", [{ name: "EBITDA margin", fmt: "pct", dir: "higher", target: 0.18 }, { name: "Cost-to-revenue ratio", fmt: "num", dir: "ceiling", target: 0.88 }]],
        ["F3", "Cash & Collections", [{ name: "Collection rate", fmt: "pct", dir: "higher", target: 0.92 }, { name: "Days in accounts receivable", fmt: "days", dir: "lower", target: 62 }, { name: "Claim rejection rate", fmt: "pct", dir: "lower", target: 0.06 }]],
        ["F4", "Asset Productivity", [{ name: "Bed occupancy rate", fmt: "pct", dir: "on_target", target: 0.78 }, { name: "Theatre utilisation rate", fmt: "pct", dir: "higher", target: 0.82 }]],
        ["F5", "Cost", [{ name: "Operating cost per bed day", fmt: "sar", dir: "ceiling", target: 1_800 }, { name: "Pharmacy cost", fmt: "sar", dir: "ceiling", target: 2_400_000 }]],
    ] },
    { pillar: "Customer", order: 2, weight: 0.25, q: PILLARS[1].q, objectives: [
        ["C1", "Patient Experience", [{ name: "Patient satisfaction (NPS)", fmt: "num", dir: "higher", target: 72 }, { name: "Complaints per 1,000 visits", fmt: "num", dir: "lower", target: 2.5 }]],
        ["C2", "Access", [{ name: "ER door-to-doctor time", fmt: "mins", dir: "lower", target: 18 }, { name: "Outpatient waiting time", fmt: "mins", dir: "lower", target: 25 }]],
        ["C3", "Payer Relationships", [{ name: "Approval turnaround", fmt: "days", dir: "lower", target: 2 }, { name: "Payer contracts renewed on time", fmt: "pct", dir: "higher", target: 0.9 }]],
    ] },
    { pillar: "Internal Process", order: 3, weight: 0.3, q: PILLARS[2].q, objectives: [
        ["P1", "Clinical Quality", [{ name: "Readmission within 30 days", fmt: "pct", dir: "lower", target: 0.045 }, { name: "Hospital-acquired infection rate", fmt: "pct", dir: "lower", target: 0.012 }]],
        ["P2", "Throughput", [{ name: "Average length of stay", fmt: "days", dir: "on_target", target: 3.8 }, { name: "Discharge process time", fmt: "mins", dir: "lower", target: 120 }, { name: "Lab turnaround time", fmt: "mins", dir: "lower", target: 45 }]],
        ["P3", "Supply Chain", [{ name: "Inventory days on hand", fmt: "days", dir: "on_target", target: 24 }, { name: "Stock-out rate", fmt: "pct", dir: "lower", target: 0.02 }]],
        ["P4", "Revenue Cycle", [{ name: "Clean claim rate", fmt: "pct", dir: "higher", target: 0.95 }, { name: "Coding accuracy", fmt: "pct", dir: "higher", target: 0.97 }]],
    ] },
    { pillar: "Learning & Growth", order: 4, weight: 0.15, q: PILLARS[3].q, objectives: [
        ["L1", "Workforce", [{ name: "Staff turnover rate", fmt: "pct", dir: "lower", target: 0.11 }, { name: "Saudization rate", fmt: "pct", dir: "higher", target: 0.35 }, { name: "Training hours per employee", fmt: "num", dir: "higher", target: 24 }]],
        ["L2", "Technology", [{ name: "Core system uptime", fmt: "pct", dir: "higher", target: 0.995 }, { name: "Digital adoption rate", fmt: "pct", dir: "higher", target: 0.6 }]],
    ] },
];

/** Eight hospitals and Head Office over the comparison catalogue; each hospital leans differently per pillar so the ranks move between levels. */
export function buildComparisonRows(branches: string[]): FixtureRow[] {
    const lean = branches.map(() => CMP.map(() => (rnd() - 0.5) * 0.3));
    const rows: FixtureRow[] = [];
    let n = 0;
    CMP.forEach((p, pi) => {
        let display = 0;
        p.objectives.forEach(([code, title, specs], oi) => {
            specs.forEach((spec, ki) => {
                display++;
                rows.push({
                    kpi: `${code}.${ki + 1}`, kpiName: spec.name, shortLabel: spec.name,
                    pillar: p.pillar, pillarOrder: p.order, pillarWeight: p.weight, pillarQuestion: p.q,
                    objectiveCode: code, objectiveTitle: title, objectiveOrder: oi + 1,
                    kpiType: ki === 0 ? "Primary" : "Supporting", direction: spec.dir, valueFormat: spec.fmt, displayOrder: display,
                    kpiStatus: "active", valueSource: n % 9 === 4 ? "manual" : "measure",
                    owner: OWNERS[n % OWNERS.length], scoreBase: BASE, scoreSlope: SLOPE, goodFrom: GOOD, watchFrom: WATCH,
                    payload: branches.map((b, bi) => scoresOnly(b === "Head Office" ? payload({ state: "No data yet" })
                        : (n * 3 + bi) % 23 === 5 ? payload({ state: "" }) : branchPayload("value", spec, (3.5 - bi) * 0.025 + lean[bi][pi]))),
                    selectionLabel: branches.map(b => `${b} · ${PERIOD}`),
                });
                n++;
            });
        });
    });
    return rows;
}

const params = new URLSearchParams(location.search);
const shot = params.get("mode") ?? "overview";
/** "overview-scores" is the landing page as bound in the report: [BSC Visual Payload Scores], no trends. */
/** "comparison" is the league table; "comparison-pillar" and "comparison-objective" drill into Financial and F1 Revenue. */
const mode = shot === "overview-scores" ? "overview" : shot.startsWith("comparison") ? "comparison" : shot;
const HOSPITALS = ["Hospital A", "Hospital B", "Hospital C", "Hospital D", "Head Office", "Hospital E", "Hospital F", "Hospital G", "Hospital H"];
const branches = mode === "comparison" ? HOSPITALS : null;
const built = branches ? buildComparisonRows(branches) : buildRows(null);
if (shot === "overview-scores") for (const r of built) r.payload = scoresOnly(r.payload as string);
const dv = makeDataView(built, branches ? { branches } : {});
(dv.metadata as unknown as { objects: unknown }).objects = { scorecard: { mode } };

const selection = { select: () => Promise.resolve([]), clear: () => Promise.resolve({}), showContextMenu: () => undefined, getSelectionIds: () => [], registerOnSelectCallback: () => undefined };
const host = {
    eventService: { renderingStarted: () => undefined, renderingFinished: () => document.body.setAttribute("data-rendered", "1"), renderingFailed: (_o: unknown, m?: string) => { document.body.setAttribute("data-failed", m ?? "1"); document.body.textContent = "render failed: " + (m ?? ""); } },
    createSelectionManager: () => selection,
    createSelectionIdBuilder: () => { const b = { withCategory: () => b, withSeries: () => b, createSelectionId: () => ({ equals: () => false }) }; return b; },
    tooltipService: { show: () => undefined, hide: () => undefined },
    hostCapabilities: { allowInteractions: true },
    colorPalette: { isHighContrast: false },
};
const root = document.getElementById("root") as HTMLElement;
const visual = new Visual({ element: root, host } as never);
visual.update({ dataViews: [dv], viewport: { width: window.innerWidth, height: window.innerHeight }, type: 2 } as never);
const pillar = params.get("pillar");
if (pillar) (root.querySelector(`[data-pillar="${pillar}"]`) as HTMLElement | null)?.click();
// Drill the league table the way a user does: click the pillar header, then the objective header.
if (shot === "comparison-pillar" || shot === "comparison-objective") (root.querySelector('thead button[data-cmp-pillar="Financial"]') as HTMLElement | null)?.click();
if (shot === "comparison-objective") (root.querySelector('thead button[data-cmp-objective="F1"]') as HTMLElement | null)?.click();
document.body.setAttribute("data-font", getComputedStyle(root).fontFamily + "|" + getComputedStyle(root.querySelector("h1") ?? root).fontFamily);
