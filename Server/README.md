# Marketeer price trend prototype

`trends.py` imports validated AHL1 snapshots into a separate SQLite database. It keeps at most one latest observation per market/item/hour and calculates the median of AHledger's market medians over the latest 24 hours, previous 24 hours, latest 48 hours, and latest 14 days. Prices are copper. A single one-copper low listing does not directly determine the result; thin markets or sustained manipulation can still affect medians.

Outputs include sample count, time span, last observation, and a sufficiency flag. Percentage changes are withheld until the relevant periods meet the minimum coverage thresholds. These thresholds are initial heuristics and should be reviewed with live data. Empty items and missing markets are never treated as zero. Summaries do not imply confirmed sales.

`collect.py` is a staged collector for all 24 region/ruleset/faction groups. It checks upstream cache headers, continues after individual market failures, can backfill existing valid snapshots, and expires its own hourly observations after two weeks. It does not delete existing server snapshots or the separate personal-scan database. Those existing stores must be addressed separately to enforce the requested total retention limit.

`retention.py` is the separately tested cleanup: it deletes timestamp-named raw AHledger snapshot files older than 14 days and deletes older rows from the existing personal/older-scan history database. It does not remove other files. On an hourly schedule, expiry can occur up to roughly an hour after the 14-day boundary. The owner approved this cleanup.

AHledger's published terms state that from 10 December 2026, storing responses beyond their cache lifetime or building an archive requires a licence that permits it. The collector stops at that date unless explicitly run with `--archive-licensed`; the owner confirmed archive permission and the live scheduled job uses that flag. The existing production snapshot collector is separate and does not have this guard. See https://ahledger.com/developers.

The collector and per-item endpoint are live on devvy.xyz. Collection runs at minute 17 of each hour and retention at minute 47. The first test backfilled existing snapshots and fetched all 24 markets successfully; five returned empty tables. Seven days of coverage are required before the 14-day comparison is considered sufficiently representative. The initial coverage thresholds should be reviewed with live data. For local tests run `python -m unittest discover -s tests -v`.
