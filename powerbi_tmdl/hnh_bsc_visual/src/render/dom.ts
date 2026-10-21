const SVG_NS = "http://www.w3.org/2000/svg";

export type Attrs = Record<string, string | number | null | undefined>;
export type Child = Node | string | null | undefined;

function fill<T extends Element>(node: T, attrs: Attrs, children: Child[]): T {
    for (const [k, v] of Object.entries(attrs)) {
        if (v !== null && v !== undefined) node.setAttribute(k, String(v));
    }
    for (const c of children) {
        if (c === null || c === undefined) continue;
        node.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    }
    return node;
}

/** Create an HTML element. Text children become text nodes, so data is never parsed as markup. */
export function el<K extends keyof HTMLElementTagNameMap>(tag: K, attrs: Attrs = {}, children: Child[] = []): HTMLElementTagNameMap[K] {
    return fill(document.createElement(tag), attrs, children);
}

/** Create an SVG element. */
export function svg<K extends keyof SVGElementTagNameMap>(tag: K, attrs: Attrs = {}, children: Child[] = []): SVGElementTagNameMap[K] {
    return fill(document.createElementNS(SVG_NS, tag), attrs, children);
}
