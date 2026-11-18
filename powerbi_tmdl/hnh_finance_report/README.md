# HNH Finance report

Power BI report "HNH Finance" on the `Finance Report` perspective, generated with the BSC generator's modules
(`../hnh_bsc_report`), like `../hnh_hr_report`. Eight pages (a monthly and a hospitals view of the Trial Balance,
Income Statement, Balance Sheet and KPIs & Ratios), each with the frame (`fin_frame.py`): four tabs, the view buttons,
the Hospital / Year / Month tile slicers and the period text. Every page carries the locked page filter
`Branch[Branch Key]` in 1..8 (hospitals only).

    python powerbi_tmdl/hnh_finance_report/build.py [--database HNH_Analytics_Test]
    python -m pytest powerbi_tmdl/hnh_finance_report

`build.py` writes `HNH Finance.pbip` here and checks it against Power BI Desktop's schemas and project reader (offline).
The Report Server package is written from the project by `../hnh_bsc_report/pbir_to_pbix.py` (`../README.md`).
