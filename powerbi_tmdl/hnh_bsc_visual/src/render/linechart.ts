import { isNum } from "../model/format";
import { svg } from "./dom";

export interface LineSeries {
    name: string;
    /** CSS colour of the line and its end dot, such as "var(--p1)". */
    colourVar: string;
    values: (number | null)[];
}

export interface LineChartOpts {
    /** Month names for the x axis, ending at the last point; [] draws none. */
    months: string[];
    /** Value of the dashed target line. */
    target: number;
    width: number;
    height: number;
}

const floor10 = (v: number) => Math.floor(v / 10) * 10;
const ceil10 = (v: number) => Math.ceil(v / 10) * 10;
const FONT = 16.5;
const LABEL_GAP = 21;

/** The y range: from the lower ten under the lowest value (or ten under the target), not below 0 unless a score is,
 * to 100 or the upper ten above the highest value. Scores are not capped, so either end can pass 0 or 100. */
function yRange(values: number[], target: number): { lo: number; hi: number } {
    const t = isNum(target) ? [target - 10] : [];
    const low = [...values, ...t];
    const floor = values.length ? Math.min(0, ...values) : 0;
    const lo = low.length ? Math.max(floor10(floor), floor10(Math.min(...low))) : 0;
    let hi = Math.max(100, ...(values.length ? [ceil10(Math.max(...values))] : []), ...(isNum(target) ? [ceil10(target)] : []));
    if (hi <= lo) hi = lo + 10;
    return { lo, hi };
}

/** Multi-line chart: gridlines and labels every 10, a dashed target line, one line per series (gaps at nulls) with a
 * dot and the series name at its last point, and the month names under the points. Colours of the grid and target
 * come from CSS classes so high contrast can replace them. */
export function lineChart(series: LineSeries[], opts: LineChartOpts): SVGSVGElement {
    const { width: W, height: H, target, months } = opts;
    const n = series.reduce((m, s) => Math.max(m, s.values.length), 0);
    const all = series.flatMap(s => s.values.filter(isNum));
    const { lo, hi } = yRange(all, target);
    const longest = series.reduce((m, s) => Math.max(m, s.name.length), 0);
    const left = 45, right = longest ? Math.min(260, 18 + longest * 9.5) : 12;
    const top = 12, bottom = months.length ? 36 : 12;
    const plotW = Math.max(1, W - left - right), plotH = Math.max(1, H - top - bottom);
    const X = (i: number) => (n <= 1 ? left + plotW / 2 : left + 9 + (i * (plotW - 18)) / (n - 1));
    // Values outside the axis (below 0) are drawn at its edge, so nothing leaves the plot.
    const Y = (v: number) => top + ((hi - Math.min(Math.max(v, lo), hi)) / (hi - lo)) * plotH;
    const f = (v: number) => v.toFixed(1);

    const s = svg("svg", {
        width: W, height: H, viewBox: `0 0 ${W} ${H}`, role: "img", class: "lc",
        "aria-label": `Line chart: ${series.map(x => x.name).join(", ")}${isNum(target) ? `; target ${target}` : ""}`,
    });
    for (let v = lo; v <= hi; v += 10) {
        s.appendChild(svg("line", { x1: left, x2: left + plotW, y1: f(Y(v)), y2: f(Y(v)), "stroke-width": 1, class: "lc-grid" }));
        s.appendChild(svg("text", { x: left - 9, y: f(Y(v) + 5.5), "text-anchor": "end", "font-size": FONT, class: "lc-y" }, [String(v)]));
    }
    if (isNum(target)) {
        s.appendChild(svg("line", {
            x1: left, x2: left + plotW, y1: f(Y(target)), y2: f(Y(target)), "stroke-width": 2.25, "stroke-dasharray": "7.5 6", class: "lc-target",
        }));
    }

    const ends: { y: number; x: number; name: string }[] = [];
    for (const ser of series) {
        let d = "";
        let pen = false;
        let last: { x: number; y: number } | null = null;
        for (let i = 0; i < ser.values.length; i++) {
            const v = ser.values[i];
            if (!isNum(v)) { pen = false; continue; }
            last = { x: X(i), y: Y(v) };
            d += `${pen ? "L" : "M"}${f(last.x)} ${f(last.y)}`;
            pen = true;
        }
        if (d) {
            s.appendChild(svg("path", {
                d, fill: "none", "stroke-width": 3.4, "stroke-linejoin": "round", "stroke-linecap": "round", class: "lc-line", style: `stroke:${ser.colourVar}`,
            }));
        }
        if (last) {
            s.appendChild(svg("circle", { cx: f(last.x), cy: f(last.y), r: 6, class: "lc-dot", style: `fill:${ser.colourVar}` }));
            ends.push({ x: last.x, y: last.y, name: ser.name });
        }
    }
    // Names at the line ends, pushed apart so they never overlap.
    const order = ends.map((e, i) => ({ ...e, i, ly: e.y })).sort((a, b) => a.y - b.y);
    for (let k = 1; k < order.length; k++) order[k].ly = Math.max(order[k].ly, order[k - 1].ly + LABEL_GAP);
    const maxY = top + plotH;
    if (order.length && order[order.length - 1].ly > maxY) {
        order[order.length - 1].ly = maxY;
        for (let k = order.length - 2; k >= 0; k--) order[k].ly = Math.min(order[k].ly, order[k + 1].ly - LABEL_GAP);
    }
    for (const e of order.sort((a, b) => a.i - b.i)) {
        s.appendChild(svg("text", { x: f(e.x + 13.5), y: f(e.ly + 5.5), "font-size": FONT, class: "lc-name" }, [e.name]));
    }

    for (let i = 0; i < n; i++) {
        const m = months[months.length - n + i];
        if (m) s.appendChild(svg("text", { x: f(X(i)), y: H - 9, "text-anchor": "middle", "font-size": FONT, class: "lc-month" }, [m]));
    }
    return s;
}
