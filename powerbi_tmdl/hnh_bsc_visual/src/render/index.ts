import type { ViewModel } from "../model/types";
import { el } from "./dom";
import { empty } from "./empty";
import { header, DEFAULT_TITLE } from "./header";
import { overview } from "./overview";
import { board, boardPillar } from "./board";
import { owner } from "./owner";
import { comparison } from "./comparison";

export type Mode = "overview" | "board" | "owner" | "comparison";

export interface UiState {
    pillar: string | null;
    focusBranch: string | null;
    title: string;
    subtitle: string;
    showHeader: boolean;
}

/** Clear and redraw the visual's root for the chosen mode. */
export function renderView(root: HTMLElement, vm: ViewModel, mode: Mode, ui: UiState): void {
    root.replaceChildren();
    root.classList.add("hnh-bsc");
    if (vm.guardMessage) { root.appendChild(empty(vm.guardMessage)); return; }
    if (vm.pillars.every(p => p.kpis.length === 0)) { root.appendChild(empty("No KPIs in this selection")); return; }

    let title = ui.title;
    if (mode === "board" && title === DEFAULT_TITLE) title = boardPillar(vm, ui.pillar).name;
    const subtitle = mode === "board" ? boardPillar(vm, ui.pillar).question || ui.subtitle : ui.subtitle;
    if (ui.showHeader) root.appendChild(header(vm, title, subtitle));
    // With a branch series bound, overview, board and owner describe the first hospital only.
    if (mode !== "comparison" && vm.branches.length > 0) {
        root.appendChild(el("div", { class: "hint", role: "note" }, [`Showing ${vm.branches[0]} — switch to Hospital comparison to compare hospitals`]));
    }

    const body = mode === "overview" ? overview(vm)
        : mode === "board" ? board(vm, ui.pillar, !ui.showHeader)
        : mode === "owner" ? owner(vm)
        : comparison(vm, ui.focusBranch);
    root.appendChild(el("div", { class: "view" }, [body]));
}
