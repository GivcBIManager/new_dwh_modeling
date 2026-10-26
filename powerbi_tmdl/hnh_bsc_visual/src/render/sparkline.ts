import { isNum } from "../model/format";
import { svg } from "./dom";

export interface SparkPath {
    line: string;
    targetLine: string;
    last: { x: number; y: number } | null;
}


/** Path data for a trend and its target trend. Nulls leave gaps in the series but keep their x position. */
export function sparkPath(values: (number | null)[], target: (number | null)[], w: number, h: number): SparkPath {
    const n = Math.max(values.length, target.length);
    const have = [...values, ...target].filter(isNum);
    if (n < 2 || have.length === 0) return { line: "", targetLine: "", last: null };
    let lo = Math.min(...have), hi = Math.max(...have);
    if (hi === lo) { lo -= 0.5; hi += 0.5; }
    else { const pad = (hi - lo) * 0.05; lo -= pad; hi += pad; }
    const X = (i: number) => 2 + (i * (w - 4)) / (n - 1);
    const Y = (v: number) => h - 3 - ((v - lo) / (hi - lo)) * (h - 6);
    const draw = (a: (number | null)[]) => {
        const pts = a.map((v, i) => (isNum(v) ? { x: X(i), y: Y(v) } : null)).filter((p): p is { x: number; y: number } => p !== null);
        return { pts, d: pts.length < 2 ? "" : pts.map((p, i) => `${i ? "L" : "M"}${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join("") };
    };
    const main = draw(values), tgt = draw(target);
    return { line: main.d, targetLine: tgt.d, last: main.d ? main.pts[main.pts.length - 1] : null };
}

/** Sparkline SVG: dashed target, trend line and a dot on the latest point. Empty when there is nothing to draw. */
export function sparkline(values: (number | null)[], target: (number | null)[], w: number, h: number): SVGSVGElement {
    const s = svg("svg", { width: w, height: h, viewBox: `0 0 ${w} ${h}`, "aria-hidden": "true", class: "spark" });
    const p = sparkPath(values, target, w, h);
    if (p.targetLine) s.appendChild(svg("path", { d: p.targetLine, fill: "none", "stroke-dasharray": "3 3", "stroke-width": 1, class: "spark-target" }));
    if (p.line) s.appendChild(svg("path", { d: p.line, fill: "none", "stroke-width": 2, class: "spark-line" }));
    if (p.last) s.appendChild(svg("circle", { cx: p.last.x.toFixed(1), cy: p.last.y.toFixed(1), r: 3.5, class: "spark-dot" }));
    return s;
}
