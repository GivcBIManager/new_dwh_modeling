"""Write a table that a Power BI model embeds in its partition (Table.FromRows over a
compressed JSON blob) to a CSV file.

Usage: python scripts/extract_pbi_table.py <table.tmdl> <out.csv> <COL1> <COL2> ...
"""
import base64
import csv
import json
import re
import sys
import zlib


def main():
    tmdl, out, columns = sys.argv[1], sys.argv[2], sys.argv[3:]
    text = open(tmdl, encoding="utf-8").read()
    match = re.search(r'Binary\.FromText\("([^"]+)"', text)
    if not match:
        raise SystemExit(f"No embedded table in {tmdl}")
    rows = json.loads(zlib.decompress(base64.b64decode(match.group(1)), -15))
    if any(len(r) != len(columns) for r in rows):
        raise SystemExit(f"Expected {len(columns)} columns per row")
    with open(out, "w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(columns)
        writer.writerows([[str(v).strip() for v in r] for r in rows])
    print(f"wrote {len(rows)} rows to {out}")


if __name__ == "__main__":
    main()
