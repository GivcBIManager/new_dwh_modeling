import { el } from "./dom";

/** A single message block, used for guard text and empty selections. */
export function empty(message: string): HTMLElement {
    return el("div", { class: "empty", role: "status" }, [message]);
}
