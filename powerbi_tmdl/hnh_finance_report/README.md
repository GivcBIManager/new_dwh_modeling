# HNH Finance report

Power BI report "HNH Finance" on the `Finance Report` perspective, generated with the BSC generator's modules
(`../hnh_bsc_report`), like `../hnh_hr_report`. Eight pages (a monthly and a hospitals view of the Trial Balance,
Income Statement, Balance Sheet and KPIs & Ratios), each with the frame (`fin_frame.py`): four tabs, the view buttons,
the Hospital / Year / Month tile slicers and the period text. Every page carries the locked page filter
`Branch[Branch Key]` in 1..8 (hospitals only).

The trial balance, income statement and balance sheet pages (`pages_statements.py`) add four tiles, two charts
driven by the matrix row (by month on the monthly pages, by hospital on the hospitals pages), a header and the
statement matrix (`fin_blocks.py`); the income statement hides its grand total row (R9e) and bands its subtotal lines
([FR Row Band]); the balance sheet shows [FR BS Difference] in a card under the matrix.

    python powerbi_tmdl/hnh_finance_report/build.py [--database HNH_Analytics_Test]
    python -m pytest powerbi_tmdl/hnh_finance_report

`build.py` writes `HNH Finance.pbip` here and checks it against Power BI Desktop's schemas and project reader (offline).
The Report Server package is written from the project by `../hnh_bsc_report/pbir_to_pbix.py` (`../README.md`).
