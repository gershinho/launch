-- Block inappropriate / disposable emails before they reach the waitlist table.
-- Run in Supabase Dashboard → SQL Editor if this migration has not been applied yet.

create or replace function public.is_waitlist_email_allowed(raw_email text)
returns boolean
language plpgsql
immutable
as $$
declare
  email text;
  local_part text;
  domain_part text;
  local_clean text;
  banned text[] := array[
    'fuck', 'fuk', 'shit', 'bitch', 'cunt', 'dick', 'cock', 'pussy',
    'whore', 'slut', 'nigger', 'nigga', 'rape', 'porn', 'hentai'
  ];
  blocked_domains text[] := array[
    'mailinator.com', 'guerrillamail.com', 'guerrillamail.info',
    'guerrillamail.net', 'guerrillamail.org', '10minutemail.com',
    '10minutemail.net', 'tempmail.com', 'temp-mail.org', 'yopmail.com',
    'getnada.com', 'trashmail.com', 'sharklasers.com'
  ];
  frag text;
begin
  email := lower(trim(raw_email));

  if email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return false;
  end if;

  local_part := split_part(email, '@', 1);
  domain_part := regexp_replace(split_part(email, '@', 2), '\.$', '');

  if local_part ~ '[^[:ascii:]]' then
    return false;
  end if;

  if domain_part = any (blocked_domains) then
    return false;
  end if;

  local_clean := regexp_replace(local_part, '[^a-z0-9]', '', 'g');
  foreach frag in array banned loop
    if local_clean = frag then
      return false;
    end if;
    if local_part ~ ('(^|[^a-z0-9])' || frag || '([^a-z0-9]|$)') then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

create or replace function public.waitlist_email_guard()
returns trigger
language plpgsql
as $$
begin
  if not public.is_waitlist_email_allowed(new.email) then
    raise exception 'Please enter a valid email address.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists waitlist_email_policy on public.waitlist;

create trigger waitlist_email_policy
  before insert on public.waitlist
  for each row
  execute function public.waitlist_email_guard();
