import { svg } from "./dom";

interface Dial {
    value: number | null;
    size: number;
    /** Value at the arc's end (the arc is capped there). */
    max: number;
    /** Value at the target marker. */
    marker: number;
    good: number;
    watch: number;
    suffix: string;
    caption: string;
    aria: (shown: number | null) => string;
}

/** Half-circle dial: rounded value in the middle, a target marker, the arc coloured by the good/watch thresholds. */
function dial(d: Dial): SVGSVGElement {
    const { size } = d;
    const has = d.value !== null && Number.isFinite(d.value);
    const r = size / 2 - 14, c = Math.PI * r, mid = size / 2;
    const pct = has ? Math.max(0, Math.min(d.value as number, d.max)) / d.max : 0;
    const shown = has ? Math.round(d.value as number) : null;
    const col = shown === null ? "var(--nodata)" : shown >= d.good ? "var(--good)" : shown >= d.watch ? "var(--warn)" : "var(--bad)";
    const ang = Math.PI * (1 - Math.min(d.marker, d.max) / d.max);
    const arc = `M14 ${mid} A${r} ${r} 0 0 1 ${size - 14} ${mid}`;
    const s = svg("svg", {
        width: size, height: mid + 28, viewBox: `0 0 ${size} ${mid + 28}`, role: "img", class: "gauge", "aria-label": d.aria(shown),
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
    }, [shown === null ? "–" : `${shown}${d.suffix}`]));
    s.appendChild(svg("text", { x: mid, y: mid + 20, "text-anchor": "middle", "font-size": 13, fill: "var(--muted)" }, [d.caption]));
    return s;
}

/** Half-circle gauge. Score is 0-100, shown rounded; the marker sits at `good`; the arc colour follows the good/watch thresholds. */
export function gauge(score: number | null, size: number, good: number, label: string, watch = 70): SVGSVGElement {
    return dial({
        value: score, size, max: 100, marker: good, good, watch, suffix: "", caption: `target ${good}`,
        aria: shown => (shown === null ? `${label}: no data` : `${label}: ${shown} out of 100`),
    });
}

/** Owner achievement in percent (may pass 100; the arc stops at its end). Marker at 100%; 100+ on track, 85-99 watch, below 85 at risk. */
export function achievementGauge(value: number | null, size: number, label: string): SVGSVGElement {
    return dial({
        value, size, max: 100, marker: 100, good: 100, watch: 85, suffix: "%", caption: "Achievement",
        aria: shown => `${label} achievement: ${shown === null ? "no data" : `${shown}%`}`,
    });
}
