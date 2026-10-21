import type { ViewModel } from "../model/types";
import { el, svg } from "./dom";

export const DEFAULT_TITLE = "Balanced scorecard";

/** Header band: logo mark, title, subtitle and the selection label on the right. */
export function header(vm: ViewModel, title: string, subtitle: string): HTMLElement {
    const mark = svg("svg", { class: "mark", viewBox: "0 0 100 100", role: "img", "aria-label": "Hayat Healthcare" }, [
        svg("defs", {}, [svg("linearGradient", { id: "hnh-mk", x1: 0, y1: 0, x2: 0, y2: 1 }, [
            svg("stop", { offset: 0, class: "mk-a" }), svg("stop", { offset: 1, class: "mk-b" }),
        ])]),
        svg("path", { class: "mark-shape", d: "M66 4h16a14 14 0 0 1 14 14v64a14 14 0 0 1-14 14H66z" }),
        svg("path", { class: "mark-shape", d: "M18 4h22c-7 10-7 22 0 32H18A16 16 0 0 1 18 4z" }),
        svg("path", { class: "mark-shape", d: "M34 36h16a16 16 0 0 1 0 32H34c7-10 7-22 0-32z", opacity: 0.85 }),
        svg("path", { class: "mark-shape", d: "M18 64h22c-7 10-7 22 0 32H18a16 16 0 0 1 0-32z" }),
    ]);
    const ribbon = svg("svg", { class: "ribbon", viewBox: "0 0 600 112", preserveAspectRatio: "none", "aria-hidden": "true" }, [
        svg("path", { class: "ribbon-shape", d: "M600 0H430c-40 30-40 82 0 112h170z" }),
        svg("path", { class: "ribbon-shape", d: "M410 0H300c-28 30-28 82 0 112h110c-40-30-40-82 0-112z", opacity: 0.6 }),
    ]);
    const sep = vm.label.indexOf(" · ");
    const who = sep < 0 ? vm.label : vm.label.slice(0, sep);
    const period = sep < 0 ? "" : vm.label.slice(sep + 3);
    const ctx = el("div", { class: "ctx" }, [el("b", {}, [who]), period ? el("span", { class: "period" }, [period]) : null]);
    return el("div", { class: "band" }, [
        mark,
        el("div", {}, [el("h1", {}, [title]), el("div", { class: "sub" }, [subtitle])]),
        ribbon,
        ctx,
    ]);
}
