create type public.hobby_kind as enum ('reading', 'tv', 'games');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  time_zone text not null default 'UTC',
  avatar_tint text,
  avatar_path text,
  created_at timestamptz not null default now()
);

create table public.pairs (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null unique references public.profiles (id) on delete cascade,
  user_b uuid not null unique references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);

create table public.pair_invites (
  code text primary key default translate(encode(extensions.gen_random_bytes(12), 'base64'), '+/', '-_'),
  created_by uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  used_by uuid references public.profiles (id) on delete cascade,
  used_at timestamptz
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  apns_token text not null,
  voip_token text,
  apns_env text not null check (apns_env in ('sandbox', 'production')),
  updated_at timestamptz not null default now(),
  unique (user_id, apns_token)
);

create table public.widget_push_tokens (
  device_id uuid not null references public.devices (id) on delete cascade,
  widget_kind text not null check (widget_kind in ('notes', 'hobby')),
  token text not null,
  updated_at timestamptz not null default now(),
  primary key (device_id, widget_kind)
);

create table public.calls (
  id uuid primary key default gen_random_uuid(),
  room_name text not null unique,
  caller_id uuid not null references public.profiles (id) on delete cascade,
  callee_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('audio', 'video')),
  status text not null check (status in ('ringing', 'answered', 'declined', 'missed', 'cancelled', 'ended')),
  created_at timestamptz not null default now(),
  answered_at timestamptz,
  ended_at timestamptz
);

create index calls_caller_created_idx on public.calls (caller_id, created_at);
create index calls_callee_created_idx on public.calls (callee_id, created_at);

create table public.notes (
  id uuid primary key,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  image_path text not null,
  created_at timestamptz not null default now(),
  unsent_at timestamptz
);

create index notes_sender_created_idx on public.notes (sender_id, created_at desc);

create table public.favourites (
  user_id uuid not null references public.profiles (id) on delete cascade,
  note_id uuid not null references public.notes (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, note_id)
);

create index favourites_note_idx on public.favourites (note_id);

create table public.catalog_entries (
  id uuid primary key default gen_random_uuid(),
  hobby public.hobby_kind not null,
  source text not null check (source in ('openlibrary', 'tmdb', 'igdb')),
  external_id text not null,
  title text not null,
  cover_url text,
  details jsonb not null default '{}',
  fetched_at timestamptz not null default now(),
  unique (source, external_id)
);

create table public.items (
  id uuid primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  catalog_entry_id uuid not null references public.catalog_entries (id),
  status text not null default 'current' check (status in ('current', 'finished')),
  chapter int,
  season int,
  episode int,
  percent smallint check (percent between 0 and 100),
  hours numeric(6, 1),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  last_logged_at timestamptz not null default now()
);

create index items_user_status_idx on public.items (user_id, status);
create index items_catalog_entry_idx on public.items (catalog_entry_id);

create table public.logs (
  id uuid primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_id uuid not null references public.items (id) on delete cascade,
  created_at timestamptz not null default now(),
  chapter int,
  season int,
  episode int,
  percent smallint check (percent between 0 and 100),
  hours numeric(6, 1)
);

create index logs_user_idx on public.logs (user_id);
create index logs_item_idx on public.logs (item_id);

create table public.checkins (
  user_id uuid not null references public.profiles (id) on delete cascade,
  hobby public.hobby_kind not null,
  day date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, hobby, day)
);

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create function public.is_paired_with(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.pairs p
    where (p.user_a = (select auth.uid()) and p.user_b = other)
       or (p.user_b = (select auth.uid()) and p.user_a = other)
  );
$$;

alter table public.profiles enable row level security;
alter table public.pairs enable row level security;
alter table public.pair_invites enable row level security;
alter table public.devices enable row level security;
alter table public.widget_push_tokens enable row level security;
alter table public.calls enable row level security;
alter table public.notes enable row level security;
alter table public.favourites enable row level security;
alter table public.catalog_entries enable row level security;
alter table public.items enable row level security;
alter table public.logs enable row level security;
alter table public.checkins enable row level security;

create policy "profiles select own or partner" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.is_paired_with(id));
create policy "profiles update own" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "pairs select own" on public.pairs for select to authenticated
  using ((select auth.uid()) in (user_a, user_b));

create policy "pair_invites select own" on public.pair_invites for select to authenticated
  using (created_by = (select auth.uid()));
create policy "pair_invites insert own" on public.pair_invites for insert to authenticated
  with check (created_by = (select auth.uid()));
create policy "pair_invites delete own" on public.pair_invites for delete to authenticated
  using (created_by = (select auth.uid()));

create policy "devices all own" on public.devices for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "widget_push_tokens all own device" on public.widget_push_tokens for all to authenticated
  using (exists (select 1 from public.devices d where d.id = device_id and d.user_id = (select auth.uid())))
  with check (exists (select 1 from public.devices d where d.id = device_id and d.user_id = (select auth.uid())));

create policy "calls select caller or callee" on public.calls for select to authenticated
  using ((select auth.uid()) in (caller_id, callee_id));

create policy "notes select own or partner" on public.notes for select to authenticated
  using (sender_id = (select auth.uid()) or public.is_paired_with(sender_id));
create policy "notes insert own" on public.notes for insert to authenticated
  with check (sender_id = (select auth.uid()));

create policy "favourites select own or partner" on public.favourites for select to authenticated
  using (user_id = (select auth.uid()) or public.is_paired_with(user_id));
create policy "favourites insert own" on public.favourites for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.notes n where n.id = note_id));
create policy "favourites delete own" on public.favourites for delete to authenticated
  using (user_id = (select auth.uid()));

create policy "catalog_entries select authenticated" on public.catalog_entries for select to authenticated
  using (true);

create policy "items select own or partner" on public.items for select to authenticated
  using (user_id = (select auth.uid()) or public.is_paired_with(user_id));
create policy "items insert own" on public.items for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "items update own" on public.items for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "items delete own" on public.items for delete to authenticated
  using (user_id = (select auth.uid()));

create policy "logs select own or partner" on public.logs for select to authenticated
  using (user_id = (select auth.uid()) or public.is_paired_with(user_id));

create policy "checkins select own or partner" on public.checkins for select to authenticated
  using (user_id = (select auth.uid()) or public.is_paired_with(user_id));

create function public.accept_invite(p_code text) returns public.pairs
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_invite public.pair_invites;
  v_pair public.pairs;
begin
  if v_uid is null then
    raise exception using errcode = 'P0001', message = 'not_authenticated';
  end if;
  select * into v_invite from public.pair_invites where code = p_code for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'invite_not_found';
  end if;
  if v_invite.expires_at < now() then
    raise exception using errcode = 'P0001', message = 'invite_expired';
  end if;
  if v_invite.used_by is not null then
    raise exception using errcode = 'P0001', message = 'invite_used';
  end if;
  if v_invite.created_by = v_uid then
    raise exception using errcode = 'P0001', message = 'cannot_pair_self';
  end if;
  if exists (
    select 1 from public.pairs p
    where p.user_a in (v_uid, v_invite.created_by) or p.user_b in (v_uid, v_invite.created_by)
  ) then
    raise exception using errcode = 'P0001', message = 'already_paired';
  end if;
  insert into public.pairs (user_a, user_b)
  values (least(v_uid, v_invite.created_by), greatest(v_uid, v_invite.created_by))
  returning * into v_pair;
  update public.pair_invites set used_by = v_uid, used_at = now() where code = p_code;
  return v_pair;
end;
$$;

create function public.set_progress(
  p_log_id uuid, p_item_id uuid, p_chapter int, p_season int, p_episode int, p_percent smallint, p_hours numeric
) returns public.items
language plpgsql security definer set search_path = '' as $$
declare
  v_item public.items;
begin
  select * into v_item from public.items where id = p_item_id and user_id = auth.uid() for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'item_not_found';
  end if;
  if exists (select 1 from public.logs where id = p_log_id) then
    return v_item;
  end if;
  if v_item.status <> 'current' then
    raise exception using errcode = 'P0001', message = 'item_not_found';
  end if;
  update public.items set
    chapter = coalesce(p_chapter, chapter),
    season = coalesce(p_season, season),
    episode = coalesce(p_episode, episode),
    percent = coalesce(p_percent, percent),
    hours = coalesce(p_hours, hours),
    last_logged_at = now()
  where id = p_item_id
  returning * into v_item;
  insert into public.logs (id, user_id, item_id, chapter, season, episode, percent, hours)
  values (p_log_id, v_item.user_id, v_item.id, v_item.chapter, v_item.season, v_item.episode, v_item.percent, v_item.hours);
  return v_item;
end;
$$;

create function public.log_increment(p_log_id uuid, p_item_id uuid) returns public.items
language plpgsql security definer set search_path = '' as $$
declare
  v_item public.items;
  v_hobby public.hobby_kind;
  v_seasons jsonb;
  v_count int;
begin
  select * into v_item from public.items where id = p_item_id and user_id = auth.uid() for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'item_not_found';
  end if;
  if exists (select 1 from public.logs where id = p_log_id) then
    return v_item;
  end if;
  if v_item.status <> 'current' then
    raise exception using errcode = 'P0001', message = 'item_not_found';
  end if;
  select c.hobby, c.details -> 'seasons' into v_hobby, v_seasons
  from public.catalog_entries c where c.id = v_item.catalog_entry_id;
  if v_hobby = 'reading' then
    return public.set_progress(p_log_id, p_item_id, coalesce(v_item.chapter, 0) + 1, null, null, null, null);
  elsif v_hobby = 'games' then
    return public.set_progress(p_log_id, p_item_id, null, null, null, null, coalesce(v_item.hours, 0) + 1);
  end if;
  v_item.season := coalesce(v_item.season, 1);
  v_item.episode := coalesce(v_item.episode, 0) + 1;
  select (s ->> 'episode_count')::int into v_count
  from jsonb_array_elements(coalesce(v_seasons, '[]')) s where (s ->> 'season')::int = v_item.season;
  if v_item.episode > v_count then
    if not exists (
      select 1 from jsonb_array_elements(coalesce(v_seasons, '[]')) s where (s ->> 'season')::int = v_item.season + 1
    ) then
      select * into v_item from public.items where id = p_item_id;
      return v_item;
    end if;
    v_item.season := v_item.season + 1;
    v_item.episode := 1;
  end if;
  return public.set_progress(p_log_id, p_item_id, null, v_item.season, v_item.episode, null, null);
end;
$$;

create function public.check_in(p_hobby public.hobby_kind, p_day date) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception using errcode = 'P0001', message = 'not_authenticated';
  end if;
  insert into public.checkins (user_id, hobby, day) values (auth.uid(), p_hobby, p_day)
  on conflict do nothing;
end;
$$;

create function public.finish_item(p_item_id uuid) returns public.items
language plpgsql security definer set search_path = '' as $$
declare
  v_item public.items;
begin
  update public.items set status = 'finished', finished_at = coalesce(finished_at, now())
  where id = p_item_id and user_id = auth.uid()
  returning * into v_item;
  if not found then
    raise exception using errcode = 'P0001', message = 'item_not_found';
  end if;
  return v_item;
end;
$$;

create function public.unsend_note(p_note_id uuid) returns public.notes
language plpgsql security definer set search_path = '' as $$
declare
  v_note public.notes;
begin
  select * into v_note from public.notes where id = p_note_id and sender_id = auth.uid() for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'note_not_found';
  end if;
  if v_note.unsent_at is not null then
    return v_note;
  end if;
  if v_note.created_at < now() - interval '4 hours' then
    raise exception using errcode = 'P0001', message = 'unsend_window_passed';
  end if;
  update public.notes set unsent_at = now() where id = p_note_id returning * into v_note;
  delete from public.favourites where note_id = p_note_id;
  return v_note;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.is_paired_with(uuid) from public, anon;
revoke execute on function public.accept_invite(text) from public, anon;
revoke execute on function public.set_progress(uuid, uuid, int, int, int, smallint, numeric) from public, anon;
revoke execute on function public.log_increment(uuid, uuid) from public, anon;
revoke execute on function public.check_in(public.hobby_kind, date) from public, anon;
revoke execute on function public.finish_item(uuid) from public, anon;
revoke execute on function public.unsend_note(uuid) from public, anon;
grant execute on function public.is_paired_with(uuid) to authenticated;
grant execute on function public.accept_invite(text) to authenticated;
grant execute on function public.set_progress(uuid, uuid, int, int, int, smallint, numeric) to authenticated;
grant execute on function public.log_increment(uuid, uuid) to authenticated;
grant execute on function public.check_in(public.hobby_kind, date) to authenticated;
grant execute on function public.finish_item(uuid) to authenticated;
grant execute on function public.unsend_note(uuid) to authenticated;

insert into storage.buckets (id, name, public) values ('notes', 'notes', false);

create policy "notes bucket insert own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'notes' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "notes bucket delete own folder" on storage.objects for delete to authenticated
  using (bucket_id = 'notes' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "notes bucket select own or partner" on storage.objects for select to authenticated
  using (
    bucket_id = 'notes' and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or case
        when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.is_paired_with(((storage.foldername(name))[1])::uuid)
        else false
      end
    )
  );

alter publication supabase_realtime add table public.notes, public.items, public.checkins, public.calls;
