-- waitlistv2: mirror of public.waitlist (schema, RLS, and email guard trigger).
-- public.waitlist is left untouched and keeps its existing rows.

create table if not exists public.waitlistv2 (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  created_at timestamptz not null default now()
);

alter table public.waitlistv2 enable row level security;

drop policy if exists "Anyone can join waitlistv2" on public.waitlistv2;
create policy "Anyone can join waitlistv2"
  on public.waitlistv2
  for insert
  to anon, authenticated
  with check (true);

-- Reuse the same email policy guard as the original waitlist
-- (defined in 20260529120000_waitlist_email_policy.sql).
drop trigger if exists waitlistv2_email_policy on public.waitlistv2;
create trigger waitlistv2_email_policy
  before insert on public.waitlistv2
  for each row
  execute function public.waitlist_email_guard();

-- Seed with the most recent signup from the original waitlist.
insert into public.waitlistv2 (email, created_at)
select email, created_at
from public.waitlist
order by created_at desc
limit 1
on conflict (email) do nothing;
