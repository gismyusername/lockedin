-- Per-hour breakdown of each day, so "when did I work" survives a new Mac the
-- same way the daily total already does.
--
-- 24 integers of seconds, indexed 0...23 in the user's local time. Nullable:
-- older clients don't send it, and the leaderboard never reads it.

alter table daily_scores add column if not exists hours integer[];

-- Keep the board query untouched — this column is for the owner's own history,
-- not for anything shared.
