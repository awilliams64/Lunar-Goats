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
  -- "herd-r1", "herd-r2", ... or "daily-2026-11-19"
  board      text not null
             check (board ~ '^(herd-r[1-9][0-9]?|daily-[0-9]{4}-[0-9]{2}-[0-9]{2})$'),
  name       text not null check (char_length(name) between 1 and 16),
  score      integer not null check (score between 100 and 30000),
  -- 1-3 for a herd round; 3-9 for a full Daily (sum of its three rounds)
  stars      smallint not null check (stars between 1 and 9),
  -- every round needs a 5-second orbit lock, so anything faster is impossible
  time_s     real not null check (time_s >= 5 and time_s < 7200),
  dv         integer not null check (dv between 0 and 100000)
);

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
