import { svg } from "./dom";

const R = 50;
const CIRC = 2 * Math.PI * R;

/** Full-circle score ring: a navy arc on the track fills by score / 100 (stopping at 0 and 100), the rounded score
 * in full and "of 100" in the middle. Colours come from CSS classes so high contrast can replace them. */
export function ring(score: number | null, size: number, label: string): SVGSVGElement {
    const has = score !== null && Number.isFinite(score);
    const shown = has ? Math.round(score as number) : null;
    const pct = has ? Math.min(Math.max(score as number, 0), 100) / 100 : 0;
    const s = svg("svg", {
        width: size, height: size, viewBox: "0 0 120 120", role: "img", class: "ring",
        "aria-label": shown === null ? `${label}: no data` : `${label} ${shown} of 100`,
    });
    s.appendChild(svg("circle", { cx: 60, cy: 60, r: R, fill: "none", "stroke-width": 12, class: "ring-track" }));
    s.appendChild(svg("circle", {
        cx: 60, cy: 60, r: R, fill: "none", "stroke-width": 12, "stroke-linecap": pct > 0 ? "round" : "butt", class: "ring-arc",
        "stroke-dasharray": `${(CIRC * pct).toFixed(2)} ${CIRC.toFixed(2)}`, transform: "rotate(-90 60 60)",
    }));
    s.appendChild(svg("text", { x: 60, y: 62, "text-anchor": "middle", "font-size": 34, class: "ring-score" }, [shown === null ? "–" : String(shown)]));
    s.appendChild(svg("text", { x: 60, y: 82, "text-anchor": "middle", "font-size": 12, class: "ring-of" }, ["of 100"]));
    return s;
}
