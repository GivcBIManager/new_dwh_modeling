"use strict";

import powerbi from "powerbi-visuals-api";
import IVisual = powerbi.extensibility.visual.IVisual;
import VisualConstructorOptions = powerbi.extensibility.visual.VisualConstructorOptions;
import VisualUpdateOptions = powerbi.extensibility.visual.VisualUpdateOptions;
import "./../style/visual.less";

/** Stub: the rendering arrives with the later tasks. */
export class Visual implements IVisual {
    constructor(_options: VisualConstructorOptions) {
        // nothing yet
    }

    public update(_options: VisualUpdateOptions): void {
        // nothing yet
    }
}
