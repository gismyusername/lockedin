-- Leaderboard over an arbitrary date range (week, month, year, all time).
--
-- Totals come from the range; presence deliberately does not. "Grinding now"
-- must mean now regardless of which range you are looking at, so it is read
-- from each member's most recent heartbeat, whatever day that landed on.
--
-- Dates are the per-user local day the client recorded, so members in
-- different timezones can disagree about a boundary day by one. Acceptable
-- for a friend group; the alternative is storing UTC instants and rebuilding
-- days per viewer.

create or replace function get_group_board_range(p_group uuid, p_from date, p_to date)
returns table (
  user_id uuid,
  display_name text,
  seconds bigint,
  is_active boolean,
  last_active_at timestamptz,
  heartbeat_at timestamptz
)
language sql
stable
as $$
  with agg as (
    select s.user_id, sum(s.seconds) as seconds
    from daily_scores s
    where s.date between p_from and p_to
    group by s.user_id
  ), latest as (
    select distinct on (s.user_id)
           s.user_id, s.is_active, s.last_active_at, s.heartbeat_at
    from daily_scores s
    order by s.user_id, s.heartbeat_at desc
  )
  select
    u.id,
    u.display_name,
    coalesce(a.seconds, 0)::bigint,
    coalesce(l.is_active, false),
    l.last_active_at,
    l.heartbeat_at
  from memberships m
  join users u on u.id = m.user_id
  left join agg a on a.user_id = u.id
  left join latest l on l.user_id = u.id
  where m.group_id = p_group
  order by coalesce(a.seconds, 0) desc, u.display_name;
$$;
