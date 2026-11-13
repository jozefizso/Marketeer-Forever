#!/usr/bin/env python3
"""Enforce retention for the existing history and raw AHledger snapshots."""
import argparse
from contextlib import closing
import json
import sqlite3
import time
from pathlib import Path
import trends


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--snapshot-dir', required=True)
    parser.add_argument('--legacy-db', required=True)
    args = parser.parse_args()
    cutoff = int(time.time()) - trends.RETENTION
    removed = 0
    for file in Path(args.snapshot_dir).glob('*.json'):
        # Only the existing collector's timestamped snapshot filenames qualify.
        if not __import__('re').fullmatch(r'\d{8}T\d{6}Z-[0-9a-f]{24}\.json', file.name):
            continue
        try:
            if file.stat().st_mtime < cutoff:
                file.unlink()
                removed += 1
        except FileNotFoundError:
            continue
    dbpath = Path(args.legacy_db)
    if not dbpath.is_file():
        raise SystemExit('Legacy history database not found; cannot enforce its retention.')
    with closing(sqlite3.connect(str(dbpath), timeout=30)) as db, db:
        deleted = db.execute('DELETE FROM points WHERE observed < ?', (cutoff,)).rowcount
    print(json.dumps({'expired_snapshots': removed, 'expired_legacy_points': deleted}))


if __name__ == '__main__':
    main()
