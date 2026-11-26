-- Lunar Goats online leaderboard: one-time Supabase setup
-- Run this once in your Supabase project: SQL Editor -> New query -> paste -> Run.
--
-- Security model: the game only ever uses the public "anon"/"publishable" key.
-- Row Level Security lets anyone READ scores and INSERT new ones, but nobody can
-- edit or delete rows through the API. The CHECK constraints reject junk
-- (impossible scores, empty or very long names, malformed board names).
-- Never put the service_role / secret key in the game.

create table if not exists public.scores (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  -- "herd-r1", "herd-r2", ..., "daily-2026-11-19" or "stampede"
  board      text not null,
  name       text not null check (char_length(name) between 1 and 16),
  -- herd round / Daily: 100-30000. Stampede is a whole endless run: up to 1,000,000
  score      integer not null,
  -- 1-3 for a herd round; 3-9 for a full Daily; rounds cleared (1-999) for Stampede
  stars      smallint not null,
  -- every round needs a 5-second orbit lock, so anything faster is impossible
  time_s     real not null,
  dv         integer not null
);

-- Table-level checks (they compare columns, so they can't be column checks).
-- Safe to re-run: this also upgrades a table created by the older version of
-- this script, which had per-column checks without Stampede.
alter table public.scores drop constraint if exists scores_board_check;
alter table public.scores drop constraint if exists scores_score_check;
alter table public.scores drop constraint if exists scores_stars_check;
alter table public.scores drop constraint if exists scores_time_s_check;
alter table public.scores drop constraint if exists scores_dv_check;

alter table public.scores add constraint scores_board_check
  check (board ~ '^(herd-r[1-9][0-9]?|daily-[0-9]{4}-[0-9]{2}-[0-9]{2}|stampede)$');
alter table public.scores add constraint scores_score_check
  check (score between 100 and 30000 or (board = 'stampede' and score between 100 and 1000000));
alter table public.scores add constraint scores_stars_check
  check (stars between 1 and 9 or (board = 'stampede' and stars between 1 and 999));
alter table public.scores add constraint scores_time_s_check
  check (time_s >= 5 and (time_s < 7200 or (board = 'stampede' and time_s < 86400)));
alter table public.scores add constraint scores_dv_check
  check (dv between 0 and 100000 or (board = 'stampede' and dv between 0 and 100000000));

create index if not exists scores_board_score_idx
  on public.scores (board, score desc, created_at);

alter table public.scores enable row level security;

drop policy if exists "Anyone can read scores" on public.scores;
create policy "Anyone can read scores"
  on public.scores for select
  to anon, authenticated
  using (true);

drop policy if exists "Anyone can submit a score" on public.scores;
create policy "Anyone can submit a score"
  on public.scores for insert
  to anon, authenticated
  with check (true);

-- Newer Supabase projects don't grant table access to the API roles by default.
-- Grant exactly read + insert (no update/delete) to visitors.
grant select, insert on public.scores to anon, authenticated;

-- No update or delete policies: submitted scores can't be changed via the API.
-- To remove a junk entry, delete it yourself in Table Editor -> scores.
