// Dev harness: renders the real Visual class with a fake host and a synthetic 70-KPI catalogue. No real hospital figures.
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
const DIRECTIONS = ["higher", "higher", "lower", "ceiling", "on_target"];
const FORMATS = ["sar", "pct", "days", "mins", "num"];
const NAMES = ["Net revenue", "Operating margin", "Collection rate", "Claim rejection", "Bed occupancy", "Average length of stay", "ER wait time", "Patient satisfaction", "Staff turnover", "Training hours", "Readmission rate", "Theatre utilisation", "Stock days", "Denial recovery"];
const MONTHS = 12;

function scaleFor(fmt: string): number {
    return fmt === "sar" ? 5_000_000 : fmt === "pct" ? 0.8 : fmt === "days" ? 6 : fmt === "mins" ? 40 : 1200;
}

function series(base: number, spread: number): number[] {
    return Array.from({ length: MONTHS }, () => base * (1 + (rnd() - 0.5) * spread));
}

function branchPayload(kind: string, fmt: string, dir: string, tilt: number): string {
    if (kind === "empty") return payload({ state: "" });
    if (kind === "parked") return payload({ state: "Parked" });
    const t = scaleFor(fmt) * (0.8 + rnd() * 0.4);
    const score = Math.max(20, Math.min(100, 78 + tilt + (rnd() - 0.5) * 50));
    const delta = (score - 85) / 100 * (dir === "lower" || dir === "ceiling" ? -1 : 1);
    const actual = t * (1 + delta);
    const state = score >= 85 ? "On track" : score >= 70 ? "Watch" : "At risk";
    const ts = series(actual, 0.1);
    ts[MONTHS - 1] = actual;
    return payload({
        actual, target: t, variance: actual / t - 1, score: Math.round(score * 10) / 10, state, weight: 1 + Math.floor(rnd() * 3),
        trend: ts, targetTrend: Array(MONTHS).fill(t), scoreTrend: ts.map(() => Math.round((score + (rnd() - 0.5) * 20) * 10) / 10),
    });
}

export function buildRows(branches: number): FixtureRow[] {
    const rows: FixtureRow[] = [];
    let n = 0;
    for (const p of PILLARS) {
        for (let i = 0; i < p.count; i++, n++) {
            const fmt = FORMATS[n % FORMATS.length];
            const dir = DIRECTIONS[n % DIRECTIONS.length];
            const manual = n % 9 === 4;
            const parkedCatalogue = n % 17 === 6;
            const noData = !parkedCatalogue && n % 11 === 3;
            const kind = parkedCatalogue ? "parked" : noData ? "empty" : "value";
            const objective = p.objectives[i % p.objectives.length];
            const tilt = (p.order - 2.5) * 4;
            rows.push({
                kpi: `${p.name.slice(0, 1)}${p.order}-${String(i + 1).padStart(2, "0")}`,
                kpiName: `${NAMES[n % NAMES.length]} (${p.name} ${i + 1})`,
                shortLabel: NAMES[n % NAMES.length],
                pillar: p.name, pillarOrder: p.order, pillarWeight: p.weight, pillarQuestion: p.q,
                objectiveCode: `${p.name.slice(0, 1)}${p.order}.${(i % p.objectives.length) + 1}`, objectiveTitle: objective, objectiveOrder: (i % p.objectives.length) + 1,
                kpiType: i < 4 ? "Primary" : "Supporting", direction: dir, valueFormat: fmt, displayOrder: i + 1,
                kpiStatus: parkedCatalogue ? "parked" : "active", valueSource: manual ? "manual" : "measure",
                owner: OWNERS[n % OWNERS.length], scoreBase: 85, scoreSlope: 0.6, goodFrom: 85, watchFrom: 70,
                payload: branches > 0 ? Array.from({ length: branches }, (_, b) => branchPayload(kind, fmt, dir, tilt + (b - 1) * 8)) : branchPayload(kind, fmt, dir, tilt),
                selectionLabel: "Corporate · Jan 2026 – Sep 2026",
            });
        }
    }
    return rows;
}

const params = new URLSearchParams(location.search);
const mode = params.get("mode") ?? "overview";
const branches = mode === "comparison" ? ["Hospital A", "Hospital B", "Hospital C"] : undefined;
const dv = makeDataView(buildRows(branches ? branches.length : 0), branches ? { branches } : {});
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
document.body.setAttribute("data-font", getComputedStyle(root).fontFamily + "|" + getComputedStyle(root.querySelector("h1") ?? root).fontFamily);
