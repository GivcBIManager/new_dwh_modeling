# HNH Balanced Scorecard report (Report Server)

A Python generator writes the pages of the Balanced Scorecard report into a legacy `.pbix`. The generator starts from a template that you save once in Power BI Desktop for Report Server (May 2026). Generated files go to `dist/` (git-ignored).

Code: `pbix.py` reads and writes the pbix (`read_pbix`, `write_pbix`, `check_upload_rules`, `set_database`, `samples`). `model.py` defines the pages (`Page`, `Visual`, `Filter`, `col`, `meas`). `layout.py` clones and rebinds the sample visuals. `fields.py` (`unknown_fields`) checks every field against the `Balanced Scorecard` perspective. `build.py` is the CLI: `python powerbi_tmdl/hnh_bsc_report/build.py --database HNH_Analytics_Test --out "powerbi_tmdl/hnh_bsc_report/dist/HNH Balanced Scorecard.pbix"`. It sets the connection's Data Source to `--server` (default `HNHANALYTICSSRV\REPORTSERVERDB`; Desktop keeps `localhost\reportserverdb` as typed). It prints the upload-rule check and exits 1 on any problem. Test with `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q`.

## Make the template

Use Power BI Desktop for Report Server (May 2026), not the normal Desktop.

1. New report. Get data > Analysis Services. Server `HNHANALYTICSSRV\REPORTSERVERDB`, database `HNH_Analytics_Test`, choose **Connect live**. In the cube / perspective list choose the perspective **Balanced Scorecard**.
2. Import the visual: Visualizations pane > ... > Import a visual from a file > `C:\HNH\visual\hnh_bsc_visual_1.0.0.0.pbiviz`.
3. Apply the brand theme: View > Themes > Browse for themes > `theme/hnh_bsc_theme.json` (in this folder).
4. Rename the first page to `Samples`. Build the 12 visuals below on it, each with any fields. Set each one's **title text** to the key shown (for example `sample:card`) and make the title visible (Format > General > Title > On) - or, for a visual without a title option, set the **Alt text** (Format > General > Alt text) to the key. The generator finds the visuals by this title. Samples carry no field-based formatting (no conditional formatting or fx rules). The generator removes any rule on a field the new visual does not bind, so it would be lost anyway. The one exception is `sample:buttonDrill`'s destination measure, which the generator removes and the page code sets again.

   | Title text | Visual |
   |---|---|
   | `sample:card` | Card |
   | `sample:multiRowCard` | Multi-row card |
   | `sample:table` | Table |
   | `sample:matrix` | Matrix |
   | `sample:barChart` | Clustered bar chart |
   | `sample:lineChart` | Line chart |
   | `sample:slicerDropdown` | Slicer, style Dropdown |
   | `sample:slicerRelativeDate` | Slicer on `'Date'[Date]`, style Relative date, set to "In this 1 calendar year" |
   | `sample:textbox` | Text box |
   | `sample:buttonNavigate` | Button, Action type Page navigation (any destination) |
   | `sample:buttonDrill` | Button, Action type Drill through. Destination: conditional formatting (fx) > Format style Field value > the measure `[BSC Detail Page]`. The measure arrives in Task 3; until then use any text measure, Task 5 rebinds it. |
   | `sample:hnhVisual` | The HNH Balanced Scorecard visual (any fields) |

5. Add a second page named `Drill sample`. Put the field `'BSC KPI'[KPI Code]` in Drill through > Drill through fields, and turn **Keep all filters** on.
6. Save as `powerbi_tmdl/hnh_bsc_report/template/hnh_bsc_template.pbix`. It holds no data (live connection), so it can be committed.
7. Check it from this folder:
   `python -c "from pbix import *; print(sorted(samples(read_pbix('template/hnh_bsc_template.pbix'))))"`
   Expected: all 12 keys. A missing key is named in the error.

## Verify against the real template (Step 5)

`set_database` and the synthetic test fixture are modelled on how Desktop writes an Analysis Services live connection: a `Connections` JSON part whose `ConnectionString` holds `Data Source=...;Initial Catalog=...;Cube=...`, plus `PbiModelDatabaseName`. No real live-connection file was available when this was written, so the field names and the part encoding are assumptions. After the template exists, open it (`read_pbix(...).connection`), confirm which fields hold the database name, and fix `set_database` and `tests/conftest.py` if they differ. `set_database` changes only the catalog / database fields it finds, leaves Data Source and unknown fields untouched, and raises if it finds none. `Connections` is rewritten only when it was changed; otherwise its bytes are kept.

## Build

Run from the repository root. For testing, point the report at the test database:

`python powerbi_tmdl/hnh_bsc_report/build.py --database HNH_Analytics_Test --out "powerbi_tmdl/hnh_bsc_report/dist/HNH Balanced Scorecard.pbix"`

Options: `--template` (default `template/hnh_bsc_template.pbix`), `--database`, `--server` (default `HNHANALYTICSSRV\REPORTSERVERDB`), `--out`. The output goes to `dist/` (git-ignored). The command prints the upload-rule check and exits 1 on any problem; an empty check is the expected result. Copy the file to `C:\HNHeport\` so it survives a clean checkout.

## Open and check in Desktop for Report Server

Open the built file in Power BI Desktop for Report Server (May 2026), not the normal Desktop. Check:

1. Every page opens without a field error (a red "can't display" visual means a field is missing from the `Balanced Scorecard` perspective).
2. Sign in as a one-hospital user (a non-admin member of `HNH_BI_Users` restricted to one hospital; an SSAS administrator bypasses row filters). The scorecard, the comparison and a KPI detail page show only that hospital.
3. Drill through from a parked KPI (a KPI whose status is not live) to the KPI detail page: the page opens, the cards show the parked state without an error, and the Back button returns.
4. Open the detail of a manual KPI: the manual note card shows the note, and Numerator / Denominator stay blank without an error.
5. Select a hospital and month in the matrix on the KPI detail page, press Open detail, and check each of the seven family pages for a KPI of that family: filters carry over (keep all filters). A family page with no data for the selection shows empty visuals, not errors.
6. Export a scorecard page and a KPI detail page to PDF (File > Export) and check the custom visual and the text render.

## Save and upload

1. Save the report from Desktop for Report Server (File > Save), so Desktop rewrites the file in its own format.
2. Check the saved file against the upload rules in `powerbi_tmdl/Hayat BSC Deliverable/Notes/05 Report Server.md` (the zip checks).
3. Upload to the Report Server folder the user chooses (Upload in the web portal).
4. A live connection to SSAS needs no stored credentials: the viewer's Windows identity flows to SSAS, which applies the row filters. Custom visuals must be allowed on the server so the HNH Balanced Scorecard visual loads.

## Switch to production

After the production SSAS deploy of `HNH_Analytics`: rebuild with `--database HNH_Analytics`, open the result, run the checks above, save, and upload over the earlier report.

## Re-run after a change

After a change to `pages.py`, the measures or the visual: run `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q`, rebuild, reopen, save and upload again. After a change to the template, redo the template check above.

## Layout format notes

See [LAYOUT_FORMAT.md](LAYOUT_FORMAT.md).
