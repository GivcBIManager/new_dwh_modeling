"""Load the Umm al-Qura calendar and Saudi public holidays into ClickHouse.

Creates default.map_hijri_calendar and default.map_public_holiday. Both are
rebuilt from scratch on every run: they are derived, never hand-edited.

Requires: pip install hijridate
"""
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from hijridate import Gregorian  # noqa: E402

from ch_env import client  # noqa: E402

START = date(2008, 1, 1)
END = date(date.today().year + 2, 12, 31)

HIJRI_MONTHS = [
    "Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani", "Jumada al-Awwal", "Jumada al-Thani",
    "Rajab", "Shaban", "Ramadan", "Shawwal", "Dhu al-Qadah", "Dhu al-Hijjah",
]


def build():
    calendar, holidays = [], []
    day = START
    while day <= END:
        h = Gregorian(day.year, day.month, day.day).to_hijri()
        calendar.append([day, h.year, h.month, h.day, HIJRI_MONTHS[h.month - 1]])
        if h.month == 10 and 1 <= h.day <= 4:
            holidays.append([day, "Eid al-Fitr"])
        elif h.month == 12 and 9 <= h.day <= 12:
            holidays.append([day, "Eid al-Adha"])
        elif day.month == 9 and day.day == 23:
            holidays.append([day, "National Day"])
        elif day.month == 2 and day.day == 22 and day.year >= 2022:
            holidays.append([day, "Founding Day"])
        day += timedelta(days=1)
    return calendar, holidays


def main():
    ch = client()
    calendar, holidays = build()
    ch.command(
        "CREATE OR REPLACE TABLE default.map_hijri_calendar (gregorian_date Date, hijri_year UInt16, "
        "hijri_month UInt8, hijri_day UInt8, hijri_month_name String) ENGINE = MergeTree ORDER BY gregorian_date"
    )
    ch.insert("default.map_hijri_calendar", calendar,
              column_names=["gregorian_date", "hijri_year", "hijri_month", "hijri_day", "hijri_month_name"])
    ch.command(
        "CREATE OR REPLACE TABLE default.map_public_holiday (holiday_date Date, holiday_name String) "
        "ENGINE = MergeTree ORDER BY holiday_date"
    )
    ch.insert("default.map_public_holiday", holidays, column_names=["holiday_date", "holiday_name"])
    print(f"map_hijri_calendar: {len(calendar):,} rows; map_public_holiday: {len(holidays):,} rows")


if __name__ == "__main__":
    main()
