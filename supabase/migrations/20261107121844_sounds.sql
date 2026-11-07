create table public.sounds (
  id uuid primary key,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 30),
  emoji text check (emoji is null or char_length(emoji) between 1 and 16),
  audio_path text not null,
  duration_ms int not null check (duration_ms between 1 and 10000),
  trim_start_ms int not null default 0 check (trim_start_ms >= 0),
  trim_end_ms int not null,
  position int not null default 0,
  created_at timestamptz not null default now(),
  check (audio_path = sender_id::text || '/' || id::text || '.m4a'),
  check (trim_end_ms <= duration_ms),
  check (
    trim_end_ms - trim_start_ms >= 500
    or (duration_ms < 500 and trim_start_ms = 0 and trim_end_ms = duration_ms)
  )
);

create index sounds_sender_position_idx on public.sounds (sender_id, position);

alter table public.sounds enable row level security;

create policy "sounds select own or partner" on public.sounds for select to authenticated
  using (sender_id = (select auth.uid()) or public.is_paired_with(sender_id));
create policy "sounds insert own" on public.sounds for insert to authenticated
  with check (sender_id = (select auth.uid()));
create policy "sounds update own or partner" on public.sounds for update to authenticated
  using (sender_id = (select auth.uid()) or public.is_paired_with(sender_id))
  with check (sender_id = (select auth.uid()) or public.is_paired_with(sender_id));
create policy "sounds delete own or partner" on public.sounds for delete to authenticated
  using (sender_id = (select auth.uid()) or public.is_paired_with(sender_id));

revoke update on public.sounds from anon, authenticated;
grant update (title, emoji, trim_start_ms, trim_end_ms) on public.sounds to authenticated;

create function public.set_sound_position() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  select coalesce(min(s.position) - 1, 0) into new.position
  from public.sounds s
  where s.sender_id = new.sender_id
     or s.sender_id in (
       select case when p.user_a = new.sender_id then p.user_b else p.user_a end
       from public.pairs p
       where new.sender_id in (p.user_a, p.user_b)
     );
  return new;
end;
$$;

create trigger sounds_set_position
before insert on public.sounds
for each row execute function public.set_sound_position();

create function public.reorder_sounds(ordered_ids uuid[]) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_ids uuid[];
begin
  select coalesce(array_agg(t.id), '{}') into v_ids
  from (
    select s.id from public.sounds s
    where s.sender_id = auth.uid() or public.is_paired_with(s.sender_id)
    for update
  ) t;
  if ordered_ids is null
     or cardinality(ordered_ids) <> cardinality(v_ids)
     or not (ordered_ids @> v_ids and v_ids @> ordered_ids) then
    raise exception using errcode = 'P0001', message = 'sounds_mismatch';
  end if;
  update public.sounds s set position = o.ord::int
  from unnest(ordered_ids) with ordinality o(id, ord)
  where s.id = o.id;
end;
$$;

revoke execute on function public.set_sound_position() from public, anon, authenticated;
revoke execute on function public.reorder_sounds(uuid[]) from public, anon;
grant execute on function public.reorder_sounds(uuid[]) to authenticated;

insert into storage.buckets (id, name, public) values ('sounds', 'sounds', false);

create policy "sounds bucket insert own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'sounds' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "sounds bucket select own or partner" on storage.objects for select to authenticated
  using (
    bucket_id = 'sounds' and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or case
        when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.is_paired_with(((storage.foldername(name))[1])::uuid)
        else false
      end
    )
  );
create policy "sounds bucket delete own or partner" on storage.objects for delete to authenticated
  using (
    bucket_id = 'sounds' and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or case
        when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.is_paired_with(((storage.foldername(name))[1])::uuid)
        else false
      end
    )
  );

alter publication supabase_realtime add table public.sounds;
