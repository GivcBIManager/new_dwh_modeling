# Power BI reports on HNHANALYTICSSRV

How a report built in this repository reaches Power BI Report Server, and the rules learned on the way. Every report
here is a Power BI project (PBIP, PBIR format) written by a generator and connected live to the SSAS model
`HNH_Analytics` (or `HNH_Analytics_Test`): `hnh_bsc_report/` (the Balanced Scorecard) and
`pressGaneyDashboard/pressGaneyDashboard/` (the Press Ganey dashboard). Measures live in the model
(`ssas/HNH_Analytics/tables/_Measures.tmdl`), never in the report.

## The server reads only the legacy package

Power BI Report Server on this machine (May 2026, product version 1.26.9637, build 15.0.1121.109) reads a report
from the package part `Report/Layout` (the legacy layout, one UTF-16 LE JSON document). A `.pbix` that holds the PBIR
folder `Report/definition` instead is refused on upload with HTTP 400: the server's parser
`PbixParserV1.GetReportDocumentFromPowerBIPackage` finds no report document (RSPowerBI log, 2026-10-26 12:56).

Power BI Desktop 2.158 **and** Power BI Desktop for Report Server (May 2026, 2.154) save a PBIR project as a PBIR
package, and neither converts a PBIR report back to the legacy layout (Desktop for Report Server opens, renders and
even "Save as > Power BI Report Server" a PBIR report, but what it saves is PBIR and the server rejects it).

So the route for every report is:

1. Build the project: `python <report>/build.py` or `python tools/build_report.py`, then the report's checks
   (`pbir_check.py` / `validate_pbir.py`: Desktop's embedded schemas and project reader, `--desktop-rs` for Desktop
   for Report Server's; the smoke test on the deployed measures).
2. Write the legacy package with the shared converter:
   `python powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py "<report>.pbip" --out "<name>.pbix"`
   (`pressGaneyDashboard/.../tools/pbir_to_pbix.py` wraps it for that report). It passes
   `hnh_bsc_report/pbix.check_upload_rules`, which the converter's test runs on both reports.
3. Open the `.pbix` in Desktop for Report Server (`C:\Program Files\Microsoft Power BI Desktop RS`) and look at the
   pages; it reads the legacy package. Do not save from there.
4. Upload it in the web portal (`http://hnhanalyticssrv/reports`) into the report's folder, or File > Save as >
   Power BI Report Server from Desktop for Report Server. A live connection needs no stored credentials: the viewer's
   Windows identity flows to SSAS, which applies the row filters. Custom visuals must be allowed in the portal
   settings, and a private visual must be packaged in the report (`CustomVisuals/<guid>/`), not referenced from
   AppSource.
5. Sign in as a one-branch user (a non-admin member of `HNH_BI_Users`) and check that every page shows that branch
   only; an SSAS administrator bypasses the row filters.

## What the converter translates

`pbir_to_pbix.py` reads the generated `definition/` folder and writes `Report/Layout` plus the package parts the
server expects (shapes taken from `test isual.pbix`, written by Desktop for Report Server, the handover's legacy pbix
and `hnh_bsc_report/LAYOUT_FORMAT.md`):

| PBIR | Legacy |
| --- | --- |
| `pages.json` order, `page.json` (size, `displayOption`, `visibility`, `pageBinding`, `visualInteractions`, filters) | `sections[]` with `displayOption` 1 / 2 / 3, page `config` (`visibility` 1, `pageBinding`, `visualInteractions` with numeric types), `filters` as a JSON string |
| `visual.json` `query.queryState` projections and `sortDefinition` | `singleVisual.projections` (role → queryRef), `prototypeQuery` (From aliases: first letter in lower case, `_` for `_Measures`; Select named by queryRef; OrderBy), `columnProperties` for display names |
| `objects`, `visualContainerObjects`, `syncGroup`, `drillFilterOtherVisuals` | `objects`, `vcObjects`, `syncGroup`, `drillFilterOtherVisuals` (literal encodings are the same) |
| filters (`field`, `howCreated` User / Drillthrough) | `expression`, `howCreated` 1 / 5, same filter body |
| `report.json` resource packages | RegisteredResources (type 1; images 100, custom theme 201), each custom visual (type 0, item 5), one base theme as SharedResources (type 2, item 202): `theme/CY26SU05.json`, the theme Desktop for Report Server writes |
| `modelReference.json` | `Connections` as Desktop for Report Server writes it: `Data Source=…;Initial Catalog=…;Cube="…"` |

Not translated, and refused with a message: report-level measures (`reportExtensions.json`: put them in the model),
bookmarks, visual groups, AppSource visuals, hierarchy fields, a dataset reference that is not a `modelReference.json`.
Two codes are inferred rather than observed, so check them on the first open of a new report: the custom theme item
type (201) and the `visualInteractions` type values (Default 0, DataFilter 1, HighlightFilter 2, NoFilter 3).

## Other rules for a new report

- Build the report from a generator, commit the project, never hand-edit the JSON; Desktop's own save of a `.pbip`
  is overwritten by the next build.
- Connect to `HNH_Analytics_Test` while the model work is in flight and to `HNH_Analytics` after the production deploy
  (`--database` on the generators).
- Check field names against the perspective (`fields.py` / `model_fields.json` exported through DMVs) and let the
  report name a measure as soon as it is in the repository's TMDL (`model_measures.py`), so the project builds before
  the deploy.
- Guards (`ssas/tools/measure_guards.py`): a measure allowed to be filtered by a table must call the measures it wraps
  through their `_Unguarded` twins, or the inner guard answers with its message inside the visual. The dashboard's
  smoke test runs the deployed measures and flags any guard message.
- A button label needs a `selector: {"id": "default"}` entry; a report-level measure would need
  `"Schema": "extension"` (not used any more); PBIR files are UTF-8 without a byte-order mark.
