-- Least privilege for the anon key.
--
-- The repo is public, so the release zip (and the anon key inside it) is
-- downloadable by anyone. Identity here is still an unauthenticated UUID, so
-- rows can't be tied to a real owner — but we can at least make the worst case
-- "someone adds junk rows" instead of "someone wipes the leaderboard".
--
-- Grants exactly what the app calls and nothing more:
--   users        insert + update (upsert of display name), select
--   groups       insert (create), select (find by code)
--   memberships  insert (join), select (board RPC)
--   daily_scores insert + update (heartbeat upsert), select
-- No DELETE anywhere.

drop policy if exists anon_all_users on users;
drop policy if exists anon_all_groups on groups;
drop policy if exists anon_all_memberships on memberships;
drop policy if exists anon_all_daily_scores on daily_scores;

create policy users_select on users for select using (true);
create policy users_insert on users for insert with check (true);
create policy users_update on users for update using (true) with check (true);

create policy groups_select on groups for select using (true);
create policy groups_insert on groups for insert with check (true);

create policy memberships_select on memberships for select using (true);
create policy memberships_insert on memberships for insert with check (true);

create policy scores_select on daily_scores for select using (true);
create policy scores_insert on daily_scores for insert with check (true);
create policy scores_update on daily_scores for update using (true) with check (true);

-- Belt and braces: drop the table privilege too, not just the row policy.
revoke delete on all tables in schema public from anon;
revoke delete on all tables in schema public from authenticated;
