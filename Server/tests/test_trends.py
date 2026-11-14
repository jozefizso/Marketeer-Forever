import json
import sys
import unittest
import tempfile
import os
from contextlib import closing
from unittest import mock
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import trends
import retention
import bulk
import bulk_low
import history_export

NOW = 1_800_000_000
MARKET = 'forever/pvp/horde/us'


def snapshot(ts, values):
    return {'market': MARKET, 'body': 'AHL1|%s|%d|%d\n%s' % (MARKET, ts, len(values), '\n'.join('%d:%d:1:1:1:1:1:1:1' % row for row in values))}


class TrendTests(unittest.TestCase):
    def setUp(self):
        self.db = trends.connect(':memory:')

    def test_single_low_outlier_does_not_skew_median(self):
        for hour in range(24):
            trends.ingest(self.db, snapshot(NOW - hour * 3600 - 1, [(42, 1 if hour == 3 else 10000)]), NOW)
        result = trends.summarize(self.db, MARKET, 42, NOW)
        self.assertEqual(result['last_24h']['median'], 10000)
        self.assertTrue(result['last_24h']['sufficient'])
        self.assertIsNone(result['change_24h_vs_14d_pct'])

    def test_hourly_dedup_and_comparison(self):
        for hour in range(48):
            trends.ingest(self.db, snapshot(NOW - hour * 3600 - 1, [(42, 200 if hour < 24 else 100)]), NOW)
        trends.ingest(self.db, snapshot(NOW - 2, [(42, 300)]), NOW)
        trends.ingest(self.db, snapshot(NOW - 3, [(42, 400)]), NOW)
        result = trends.summarize(self.db, MARKET, 42, NOW)
        self.assertEqual(result['change_24h_vs_previous_24h_pct'], 100)
        self.assertEqual(result['last_24h']['samples'], 24)

    def test_reject_bad_or_partial_without_changes(self):
        for body in ['AHL1|%s|%d|2\n42:1:1:1:1:1:1:1:1' % (MARKET, NOW), 'AHL1|%s|%d|1\n42:1:bad' % (MARKET, NOW)]:
            with self.assertRaises(ValueError): trends.ingest(self.db, {'market': MARKET, 'body': body}, NOW)
        self.assertEqual(self.db.execute('select count(*) from prices').fetchone()[0], 0)

    def test_retention_and_no_missing_price_fallback(self):
        s = snapshot(NOW - 15 * 86400, [(42, 20)])
        self.assertEqual(trends.ingest(self.db, s, NOW), 0)
        s = {'market': MARKET, 'body': 'AHL1|%s|%d|1\n42::1:1:1:1:1:1:1' % (MARKET, NOW - 1)}
        self.assertEqual(trends.ingest(self.db, s, NOW), 1)
        self.assertEqual(self.db.execute('select count(*) from prices').fetchone()[0], 0)
        self.assertEqual(self.db.execute('select price from low_prices').fetchone()[0], 1)

    def test_market_isolation(self):
        trends.ingest(self.db, snapshot(NOW - 1, [(42, 123)]), NOW)
        self.assertIsNone(trends.summarize(self.db, 'forever/pvp/alliance/us', 42, NOW)['last_24h']['median'])

    def test_long_baseline_and_expiry(self):
        for hour in range(14 * 24):
            trends.ingest(self.db, snapshot(NOW - hour * 3600 - 1, [(42, 200 if hour < 24 else 100)]), NOW)
        result = trends.summarize(self.db, MARKET, 42, NOW)
        self.assertTrue(result['last_14d']['sufficient'])
        self.assertEqual(result['last_14d']['median'], 100)
        self.assertEqual(result['change_24h_vs_14d_pct'], 100)
        trends.prune(self.db, NOW + 15 * 86400)
        self.assertEqual(self.db.execute('select count(*) from prices').fetchone()[0], 0)

    def test_empty_market_table_is_valid(self):
        self.assertEqual(trends.parse_snapshot({'market': MARKET, 'body': 'AHL1|%s|%d|0\n' % (MARKET, NOW)}, NOW), [])

    def test_bulk_matches_summary_and_omits_incomplete_windows(self):
        for hour in range(48):
            trends.ingest(self.db, snapshot(NOW-hour*3600-1, [(42, 200 if hour < 24 else 100)]), NOW)
        output = bulk.export(self.db, MARKET, NOW).splitlines()
        self.assertEqual(output[0], 'TRD1|%s|%d|1' % (MARKET, NOW))
        self.assertEqual(output[1].split(':')[:5], ['42','400','300','','1000'])
        self.assertEqual(bulk.export(self.db, 'forever/pvp/alliance/us', NOW).splitlines()[0].split('|')[-1], '0')

    def test_low_price_trends_resist_brief_undercut(self):
        for hour in range(24):
            low=1 if hour==1 else 80
            body='AHL1|%s|%d|1\n42:1000:%d:1:1:1:1:1:1' % (MARKET,NOW-hour*3600-1,low)
            trends.ingest(self.db, {'market':MARKET,'body':body}, NOW)
        fields=bulk_low.export(self.db,MARKET,NOW).splitlines()[1].split(':')
        self.assertEqual(fields[1], '160')
        self.assertEqual(fields[4], '160')

    def test_history_export_preserves_recent_hours_and_aggregates_older_days(self):
        for hour in range(80):
            trends.ingest(self.db, snapshot(NOW-hour*3600-1, [(42, 100)]), NOW)
        lines=history_export.export(self.db, MARKET, NOW).splitlines()
        self.assertEqual(lines[0], 'HST1|%s|%d|1' % (MARKET,NOW))
        points=lines[1].split(':',1)[1].split(';')
        self.assertTrue(48 <= len(points) <= 51)
        self.assertTrue(all(p.endswith(',2') for p in points))  # fixture's low is one copper
        self.assertEqual(history_export.export(self.db,'forever/pvp/alliance/us',NOW).splitlines()[0].split('|')[-1],'0')

    def test_retention_only_removes_expired_managed_data(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1]) as tmp:
            folder = Path(tmp)
            old = folder / '20261101T000000Z-1234567890abcdef12345678.json'
            recent = folder / '20261113T000000Z-1234567890abcdef12345678.json'
            unrelated = folder / 'important.json'
            for path in (old, recent, unrelated): path.write_text('{}')
            os.utime(old, (NOW - trends.RETENTION - 100, NOW - trends.RETENTION - 100))
            os.utime(unrelated, (NOW - trends.RETENTION - 100, NOW - trends.RETENTION - 100))
            os.utime(recent, (NOW - 1, NOW - 1))
            import sqlite3
            db = folder / 'legacy.sqlite3'
            with closing(sqlite3.connect(db)) as conn, conn:
                conn.execute('create table points(observed integer)')
                conn.executemany('insert into points values (?)', [(NOW - trends.RETENTION - 1,), (NOW - 1,)])
            with mock.patch.object(sys, 'argv', ['retention', '--snapshot-dir', str(folder), '--legacy-db', str(db)]), mock.patch('time.time', return_value=NOW):
                retention.main()
            self.assertFalse(old.exists()); self.assertTrue(recent.exists()); self.assertTrue(unrelated.exists())
            with closing(sqlite3.connect(db)) as conn: self.assertEqual(conn.execute('select count(*) from points').fetchone()[0], 1)


if __name__ == '__main__': unittest.main()
