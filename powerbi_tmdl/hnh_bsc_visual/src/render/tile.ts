import type { KpiRow } from "../model/types";
import { formatValue, formatVariance } from "../model/format";
import { directionNote } from "../model/parse";
import { el } from "./dom";
import { ICON, stateChip, stateClass } from "./chips";
import { sparkline } from "./sparkline";

const finite = (v: number | null): v is number => v !== null && Number.isFinite(v);

/** KPI tile. Carries data-key (row index) and data-series for interactions, and is focusable. */
export function tile(row: KpiRow): HTMLElement {
    const cls = stateClass(row.state);
    const hasValue = finite(row.actual) && row.state !== "nodata" && row.state !== "parked";
    const note = directionNote(row.direction);
    const root = el("div", {
        class: ["tile", row.primary ? "primary" : "", !hasValue || cls === "nodata" ? "nodata" : ""].filter(Boolean).join(" "),
        tabindex: 0, "data-key": row.rowIndex, "data-series": row.seriesIndex,
    });

    const top = el("div", { class: "top" }, [el("h4", {}, [row.name])]);
    if (hasValue && finite(row.variance) && cls !== "nodata") {
        const v = formatVariance(row.variance);
        top.appendChild(el("span", { class: `var ${cls}` }, [`${ICON[row.state]} ${row.stateWord} · ${v}`]));
    } else {
        top.appendChild(stateChip(row.state, row.stateWord));
    }
    root.appendChild(top);

    const targetText = finite(row.target) ? `Target ${formatValue(row.target, row.valueFormat)}` : "No target set";
    if (hasValue) {
        const left = el("div", {}, [
            el("div", { class: "val" }, [formatValue(row.actual, row.valueFormat)]),
            el("div", { class: "tgt" }, [note ? `${targetText} · ${note}` : targetText]),
        ]);
        const body = el("div", { class: "body" }, [left]);
        if (row.trend.filter(finite).length >= 2) {
            body.appendChild(el("div", { class: "sparkbox" }, [sparkline(row.trend, row.targetTrend, row.primary ? 340 : 150, row.primary ? 64 : 44)]));
        }
        root.appendChild(body);
    } else {
        root.appendChild(el("div", { class: "val" }, [row.reason ?? row.stateWord]));
        root.appendChild(el("div", { class: "tgt" }, [targetText]));
    }

    const meta = el("div", { class: "meta" }, [el("span", {}, [row.owner ? `Owner ${row.owner}` : null])]);
    if (row.manual) meta.appendChild(el("span", { class: "badge manual" }, ["Manual entry"]));
    if (hasValue && finite(row.score)) {
        meta.appendChild(el("span", { class: "score" }, [`Score ${Math.round(row.score)}`]));
    }
    root.appendChild(meta);
    return root;
}
