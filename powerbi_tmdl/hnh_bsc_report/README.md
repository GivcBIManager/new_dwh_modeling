# HNH Balanced Scorecard report (Report Server)

A Python generator writes the pages of the Balanced Scorecard report into a legacy `.pbix`. The generator starts from a template that you save once in Power BI Desktop for Report Server (May 2026). Generated files go to `dist/` (git-ignored).

Code: `pbix.py` reads and writes the pbix (`read_pbix`, `write_pbix`, `check_upload_rules`, `set_database`, `samples`). Test with `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q`.

## Make the template

Use Power BI Desktop for Report Server (May 2026), not the normal Desktop.

1. New report. Get data > Analysis Services. Server `HNHANALYTICSSRV\REPORTSERVERDB`, database `HNH_Analytics_Test`, choose **Connect live**. In the cube / perspective list choose the perspective **Balanced Scorecard**.
2. Import the visual: Visualizations pane > ... > Import a visual from a file > `C:\HNH\visual\hnh_bsc_visual_1.0.0.0.pbiviz`.
3. Apply the brand theme: View > Themes > Browse for themes > `theme/hnh_bsc_theme.json` (in this folder).
4. Rename the first page to `Samples`. Build the 12 visuals below on it, each with any fields. Set each one's **title text** to the key shown (for example `sample:card`) and make the title visible (Format > General > Title > On). The generator finds the visuals by this title.

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

## Layout format notes

See `.superpowers/sdd/2026-10-22-bsc-report/task-1-report.md`.
