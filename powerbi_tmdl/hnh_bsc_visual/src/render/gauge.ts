import { svg } from "./dom";

/** Half-circle gauge. Score is 0-100, shown rounded; the marker sits at `good`; the arc colour follows the good/watch thresholds. */
export function gauge(score: number | null, size: number, good: number, label: string, watch = 70): SVGSVGElement {
    const has = score !== null && Number.isFinite(score);
    const r = size / 2 - 14, c = Math.PI * r, mid = size / 2;
    const pct = has ? Math.max(0, Math.min(score as number, 100)) / 100 : 0;
    const shown = has ? Math.round(score as number) : null;
    const col = !has ? "var(--nodata)" : shown !== null && shown >= good ? "var(--good)" : shown !== null && shown >= watch ? "var(--warn)" : "var(--bad)";
    const ang = Math.PI * (1 - good / 100);
    const arc = `M14 ${mid} A${r} ${r} 0 0 1 ${size - 14} ${mid}`;
    const s = svg("svg", {
        width: size, height: mid + 28, viewBox: `0 0 ${size} ${mid + 28}`, role: "img", class: "gauge",
        "aria-label": has ? `${label}: ${shown} out of 100` : `${label}: no data`,
    });
    s.appendChild(svg("path", { d: arc, fill: "none", "stroke-width": 22, "stroke-linecap": "round", class: "gauge-track" }));
    s.appendChild(svg("path", {
        d: arc, fill: "none", stroke: col, "stroke-width": 22, "stroke-linecap": "round", class: "gauge-arc",
        "stroke-dasharray": c.toFixed(2), "stroke-dashoffset": (c * (1 - pct)).toFixed(2),
    }));
    s.appendChild(svg("line", {
        x1: (mid + r * Math.cos(ang)).toFixed(1), y1: (mid - r * Math.sin(ang)).toFixed(1),
        x2: (mid + (r - 26) * Math.cos(ang)).toFixed(1), y2: (mid - (r - 26) * Math.sin(ang)).toFixed(1),
        stroke: "var(--navy)", "stroke-width": 3, class: "gauge-target",
    }));
    s.appendChild(svg("text", {
        x: mid, y: mid - 6, "text-anchor": "middle", "font-size": (size / 5.2).toFixed(1), "font-weight": 800, fill: col,
    }, [has ? String(shown) : "–"]));
    s.appendChild(svg("text", { x: mid, y: mid + 20, "text-anchor": "middle", "font-size": 13, fill: "var(--muted)" }, [`target ${good}`]));
    return s;
}
