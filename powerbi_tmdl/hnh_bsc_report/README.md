# HNH Balanced Scorecard report (Report Server)

A Python generator writes the Balanced Scorecard report as a Power BI project (PBIP): `HNH Balanced Scorecard.pbip`, with the folders `HNH Balanced Scorecard.Report/` (pages, visuals, theme, HNH visual) and `HNH Balanced Scorecard.SemanticModel/` (only the live connection to the SSAS perspective, no model). The generator needs no template. The project is committed in this folder; you open it from the repository.

Code: `model.py` defines the pages (`Page`, `Visual`, `Filter`, `col`, `meas`), and `pages.py` holds the report's pages (`PAGES`). `fields.py` (`unknown_fields`) checks every field against the `Balanced Scorecard` perspective. `pbir.py` (`write_pbip`) writes the project. `pbir_check.py` checks it against Power BI Desktop on this machine without opening Desktop. It checks the report JSON against the schemas Desktop embeds, and opens the project with Desktop's own project reader (scripts in `tools/`). `pbix.py` reads and checks pbix files (`check_upload_rules`). `layout.py` and the template route are the fallback (appendix). `build.py` is the CLI. Test with `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q`.

## Build the project

Run from the repository root:

`python powerbi_tmdl/hnh_bsc_report/build.py`

The defaults are `--format pbip`, `--database HNH_Analytics_Test` and `--server HNHANALYTICSSRV\REPORTSERVERDB`. `--out` is the folder for the project and defaults to this folder. `--pbiviz` is the HNH visual package and defaults to `powerbi_tmdl/hnh_bsc_visual/dist/hnhBscVisual*.pbiviz`; build it there with `npm run package` first. The command stops if a field is not in the perspective. It then prints `report schemas: passed` and `Desktop project reader: opened`, and exits 1 on any problem. Commit the regenerated project.

## Open the PBIP in Power BI Desktop

Use the normal Power BI Desktop (2.158, installed on this server). Desktop for Report Server comes in at step 4.

1. Open `powerbi_tmdl/hnh_bsc_report/HNH Balanced Scorecard.pbip`. If Desktop refuses the file or asks for a preview feature, go to File > Options and settings > Options > Preview features. Turn on both **Power BI Project (.pbip) save option** and **Store reports using enhanced metadata format (PBIR)**, restart Desktop, and open the file again. Sign in to `HNHANALYTICSSRV\REPORTSERVERDB` with your Windows account if asked. The report connects live to the `Balanced Scorecard` perspective of `HNH_Analytics_Test`.
2. Check the pages:
   1. Every page opens without a field error. A red "can't display" visual means a field is missing from the `Balanced Scorecard` perspective.
   2. The scorecard pages show the HNH Balanced Scorecard visual in the right mode (overview, board, owner, comparison). The header slicers (hospital, BSC category, date "this year") keep their selection from page to page; there is no time calculation slicer. The page buttons show their labels and switch pages.
   3. Drill through from a KPI to the hidden KPI detail page. The page opens with the same filters, Back returns, and a parked or manual KPI shows its state or note without an error. A manual KPI shows its notes in the "Manual entry note" table; for a measure KPI the table is empty, with no "(Blank)". "About this KPI" shows the full definition, wrapped. The Open detail button reads "Open detail" in pale blue until a matrix cell is selected.
   4. On KPI detail, select a hospital and month in the matrix and press Open detail. The family page of that KPI opens for that hospital and month only. "Keep all filters" is off on the family pages, so KPI detail's KPI filter does not follow; with it, the domain measures would show "... can't be analysed by "BSC KPI"" instead of numbers. The cards show numbers or blanks, the tables list the largest first, and the Back button returns.
3. File > Save As > Power BI file (`.pbix`), for example `C:\HNH\report\HNH Balanced Scorecard.pbix`. Close Desktop. Run `check_upload_rules` on this file as in step 5. It tells which format Desktop wrote: "has a Report/definition/ entry" means the file holds the PBIR report (expected from Desktop 2.158), which step 4 must turn into `Report/Layout`. An empty list means Desktop already wrote the legacy format.
4. Open that `.pbix` in **Power BI Desktop for Report Server** (May 2026). Check one scorecard page and KPI detail, then File > Save. Desktop for Report Server rewrites the file in its own format (`Report/Layout`, no `Report/definition`), which the server needs (Notes/05 of the handover).
5. Check the saved file from this folder:
   `python -c "from pbix import check_upload_rules; print(check_upload_rules(r'C:\HNH\report\HNH Balanced Scorecard.pbix'))"`
   Expected: `[]`. Any entry names a rule the server would refuse.
6. Upload the `.pbix` to the Report Server folder the user chooses (Upload in the web portal). A live connection to SSAS needs no stored credentials: the viewer's Windows identity flows to SSAS, which applies the row filters. Custom visuals must be allowed on the server so the HNH Balanced Scorecard visual loads.
7. On the server, sign in as a one-hospital user: a non-admin member of `HNH_BI_Users` restricted to one hospital. An SSAS administrator bypasses row filters. The scorecard, the comparison and a KPI detail page show only that hospital. Export a scorecard page and a KPI detail page to PDF and check that the custom visual and the text render.

Leave the `.pbip` and its folders off the server. Desktop writes its local state to `.pbi/` folders, which are git-ignored (`.gitignore` here).

## Switch to production

After the production SSAS deploy of `HNH_Analytics`: run `python powerbi_tmdl/hnh_bsc_report/build.py --database HNH_Analytics`, then repeat the steps above and upload over the earlier report.

## Re-run after a change

The Date slicer on the scorecard pages and KPI detail is a From - To range that opens on 1 January - 31 December of the year of the build; rebuild in January to move it to the new year (the measures and the header label stop at today, so the page reads as year to date).

After a change to `pages.py`, the measures or the visual: run the tests, rebuild, commit the project, then open, save and upload again. A change made in Desktop and saved to the PBIP is overwritten by the next build. Carry the change into `pages.py` instead.

## Format notes

See [LAYOUT_FORMAT.md](LAYOUT_FORMAT.md) (legacy layout and PBIR).

## Appendix: Fallback (legacy template route)

Use this route if the PBIP route fails, for example when Desktop for Report Server will not open the `.pbix` saved by Desktop. This writer has been tested only on a synthetic template (`tests/conftest.py`), never on a template saved by Desktop for Report Server. Check the first real build's drill-through pages, in particular "keep all filters" (on for KPI detail, off for the family pages; `layout.keep_filters_off`). It writes a legacy `.pbix` directly from a template: `python powerbi_tmdl/hnh_bsc_report/build.py --format pbix --database HNH_Analytics_Test --out "powerbi_tmdl/hnh_bsc_report/dist/HNH Balanced Scorecard.pbix"`. Options: `--template` (default `template/hnh_bsc_template.pbix`), `--database`, `--server`, `--out`. The output goes to `dist/` (git-ignored). The build sets the connection's Data Source to `--server`, because Desktop keeps `localhost\reportserverdb` as typed. It prints the upload-rule check and exits 1 on any problem.

### Make the template

Use Power BI Desktop for Report Server (May 2026), not the normal Desktop.

1. New report. Get data > Analysis Services. Server `HNHANALYTICSSRV\REPORTSERVERDB`, database `HNH_Analytics_Test`, choose **Connect live**. In the cube / perspective list choose the perspective **Balanced Scorecard**.
2. Import the visual: Visualizations pane > ... > Import a visual from a file > `C:\HNH\visual\hnh_bsc_visual_1.0.0.0.pbiviz`.
3. Apply the brand theme: View > Themes > Browse for themes > `theme/hnh_bsc_theme.json` (in this folder).
4. Rename the first page to `Samples`. Build the 12 visuals below on it, each with any fields. Set each one's **title text** to the key shown (for example `sample:card`) and make the title visible (Format > General > Title > On). For a visual without a title option, set the **Alt text** (Format > General > Alt text) to the key instead. The generator finds the visuals by this title. Samples carry no field-based formatting (no conditional formatting or fx rules). The generator removes any rule on a field the new visual does not bind, so it would be lost anyway. The one exception is `sample:buttonDrill`'s destination measure, which the generator removes and the page code sets again.

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
   | `sample:buttonDrill` | Button, Action type Drill through. Destination: conditional formatting (fx) > Format style Field value > the measure `[BSC Detail Page]`. |
   | `sample:hnhVisual` | The HNH Balanced Scorecard visual (any fields) |

5. Add a second page named `Drill sample`. Put the field `'BSC KPI'[KPI Code]` in Drill through > Drill through fields, and turn **Keep all filters** on.
6. Save as `powerbi_tmdl/hnh_bsc_report/template/hnh_bsc_template.pbix`. It holds no data (live connection), so it can be committed.
7. Check it from this folder:
   `python -c "from pbix import *; print(sorted(samples(read_pbix('template/hnh_bsc_template.pbix'))))"`
   Expected: all 12 keys. A missing key is named in the error.

### Open, save and upload the fallback file

Open the built file in Power BI Desktop for Report Server and run the page checks in step 2 of "Open the PBIP" above. Then File > Save, run `check_upload_rules` on the saved file, and upload it as in steps 5 to 7.
