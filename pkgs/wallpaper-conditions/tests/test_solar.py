from __future__ import annotations

import unittest
from datetime import date, datetime, timedelta, timezone

from astral import Observer
from astral.sun import dawn, dusk

from wallpaper_conditions.solar import phase, season

VIENNA = (48.2082, 16.3738)
TROMSO = (69.6492, 18.9553)


class PhaseTests(unittest.TestCase):
    def test_vienna_noon_is_day(self) -> None:
        now = datetime(2026, 6, 21, 11, 0, tzinfo=timezone.utc)
        self.assertEqual(phase(now, *VIENNA), "day")

    def test_vienna_winter_night(self) -> None:
        now = datetime(2026, 12, 21, 23, 0, tzinfo=timezone.utc)
        self.assertEqual(phase(now, *VIENNA), "night")

    def test_civil_twilight_is_dawn_and_dusk(self) -> None:
        observer = Observer(latitude=VIENNA[0], longitude=VIENNA[1])
        day = date(2026, 6, 21)
        dawn_time = dawn(observer, day, depression=6, tzinfo=timezone.utc)
        dusk_time = dusk(observer, day, depression=6, tzinfo=timezone.utc)
        self.assertEqual(phase(dawn_time + timedelta(minutes=10), *VIENNA), "dawn")
        self.assertEqual(phase(dusk_time - timedelta(minutes=10), *VIENNA), "dusk")

    def test_polar_day_and_night_do_not_raise(self) -> None:
        summer = datetime(2026, 6, 21, 23, 0, tzinfo=timezone.utc)
        winter = datetime(2026, 12, 21, 0, 0, tzinfo=timezone.utc)
        self.assertEqual(phase(summer, *TROMSO), "day")
        self.assertEqual(phase(winter, *TROMSO), "night")

    def test_naive_datetime_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            phase(datetime(2026, 6, 21, 11, 0), *VIENNA)


class SeasonTests(unittest.TestCase):
    def test_months(self) -> None:
        expected = {
            1: "winter",
            2: "winter",
            3: "spring",
            4: "spring",
            5: "spring",
            6: "summer",
            7: "summer",
            8: "summer",
            9: "autumn",
            10: "autumn",
            11: "autumn",
            12: "winter",
        }
        for month, value in expected.items():
            self.assertEqual(season(datetime(2026, month, 15, 12, 0, tzinfo=timezone.utc)), value)


if __name__ == "__main__":
    unittest.main()
