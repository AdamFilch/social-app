begin;
create extension if not exists pgtap with schema extensions;
select plan(50);

create function pg_temp.login(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

select is(
  (select count(*)::int from pg_tables where schemaname = 'public' and rowsecurity),
  12, 'AC2: 12 public tables with RLS enabled'
);

insert into auth.users (instance_id, id, aud, role, email)
values ('00000000-0000-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'new@example.com');
select ok(
  exists (select 1 from public.profiles where id = '44444444-4444-4444-4444-444444444444'),
  'AC3: new auth user gets a profile'
);

select set_eq(
  $$select tablename::text from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public'$$,
  array['notes', 'items', 'checkins', 'calls'],
  'AC13: realtime publication holds notes, items, checkins, calls'
);

select pg_temp.login('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is((select count(*)::int from public.profiles where id <> auth.uid()), 0, 'AC4: stranger sees no other profiles');
select is((select count(*)::int from public.notes), 0, 'AC4: stranger sees no notes');
select is((select count(*)::int from public.items), 0, 'AC4: stranger sees no items');
select is((select count(*)::int from public.logs), 0, 'AC4: stranger sees no logs');
select is((select count(*)::int from public.checkins), 0, 'AC4: stranger sees no checkins');
select is((select count(*)::int from public.favourites), 0, 'AC4: stranger sees no favourites');
select is((select count(*)::int from public.calls), 0, 'AC4: stranger sees no calls');
select is((select count(*)::int from public.pairs), 0, 'AC4: stranger sees no pairs');
reset role;

select pg_temp.login('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select is((select count(*)::int from public.notes where sender_id = '11111111-1111-1111-1111-111111111111'), 1, 'AC5: partner reads notes');
select is((select count(*)::int from public.items where user_id = '11111111-1111-1111-1111-111111111111'), 2, 'AC5: partner reads items');
select is((select count(*)::int from public.checkins where user_id = '11111111-1111-1111-1111-111111111111'), 1, 'AC5: partner reads checkins');
select throws_ok(
  $$insert into public.notes (id, sender_id, image_path) values (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'x')$$,
  '42501', null, 'AC5: partner cannot insert notes as the other'
);
select throws_ok(
  $$insert into public.items (id, user_id, catalog_entry_id) values (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'c0000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'AC5: partner cannot insert items as the other'
);
select throws_ok(
  $$insert into public.checkins (user_id, hobby, day) values ('11111111-1111-1111-1111-111111111111', 'games', current_date)$$,
  '42501', null, 'AC5: partner cannot insert checkins as the other'
);
update public.notes set unsent_at = now() where sender_id = '11111111-1111-1111-1111-111111111111';
update public.items set chapter = 99 where id = 'a0000000-0000-0000-0000-000000000001';
update public.checkins set day = current_date - 1 where user_id = '11111111-1111-1111-1111-111111111111';
delete from public.notes where sender_id = '11111111-1111-1111-1111-111111111111';
delete from public.items where user_id = '11111111-1111-1111-1111-111111111111';
delete from public.checkins where user_id = '11111111-1111-1111-1111-111111111111';
select ok((select unsent_at is null from public.notes where id = 'b0000000-0000-0000-0000-000000000001'), 'AC5: partner cannot update or delete notes');
select is((select chapter from public.items where id = 'a0000000-0000-0000-0000-000000000001'), 3, 'AC5: partner cannot update or delete items');
select is((select count(*)::int from public.items where user_id = '11111111-1111-1111-1111-111111111111'), 2, 'AC5: partner cannot delete items');
select is((select count(*)::int from public.checkins where user_id = '11111111-1111-1111-1111-111111111111' and day = current_date), 1, 'AC5: partner cannot update or delete checkins');

select is((select count(*)::int from public.devices where user_id = '11111111-1111-1111-1111-111111111111'), 0, 'AC6: partner cannot read devices');
select is((select count(*)::int from public.widget_push_tokens), 0, 'AC6: partner cannot read widget tokens');
reset role;

select pg_temp.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select is((select count(*)::int from public.devices), 1, 'AC6: owner reads own devices');
select throws_ok(
  $$insert into public.calls (room_name, caller_id, callee_id, kind, status) values ('r', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'audio', 'ringing')$$,
  '42501', null, 'AC7: authenticated cannot insert calls'
);
select throws_ok(
  $$insert into public.catalog_entries (hobby, source, external_id, title) values ('games', 'igdb', 'x', 'x')$$,
  '42501', null, 'AC7: authenticated cannot insert catalog entries'
);

select is((public.log_increment('d1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001')).chapter, 4, 'AC9: reading +1 chapter');
select is((public.log_increment('d1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001')).chapter, 4, 'AC9: repeated log_id changes nothing');
select is((select count(*)::int from public.logs where id = 'd1000000-0000-0000-0000-000000000001'), 1, 'AC9: repeated log_id writes one log');
select is((public.log_increment('d1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003')).hours, 11.0, 'AC9: games +1 hour');
reset role;

insert into public.items (id, user_id, catalog_entry_id, season, episode) values
  ('a1000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'c0000000-0000-0000-0000-000000000002', 1, 3),
  ('a1000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'c0000000-0000-0000-0000-000000000002', 2, 3);

set local role authenticated;
select is(
  (select array[i.season, i.episode] from public.log_increment('d1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000001') i),
  array[2, 1], 'AC9: TV rolls S1E3 to S2E1'
);
select is(
  (select array[i.season, i.episode] from public.log_increment('d1000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000002') i),
  array[2, 3], 'AC9: TV S2E3 stays unchanged'
);
select is((select count(*)::int from public.logs where id = 'd1000000-0000-0000-0000-000000000004'), 0, 'AC9: no log for TV past the final episode');

select public.check_in('games', '2026-01-01');
select public.check_in('games', '2026-01-01');
select is((select count(*)::int from public.checkins where user_id = auth.uid() and hobby = 'games' and day = '2026-01-01'), 1, 'AC10: check_in twice leaves one row');
select is(
  (select array[i.status, (i.finished_at is not null)::text] from public.finish_item('a0000000-0000-0000-0000-000000000003') i),
  array['finished', 'true'], 'AC10: finish_item sets finished and finished_at'
);

insert into public.notes (id, sender_id, image_path)
values ('b1000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111/b1000000-0000-0000-0000-000000000001.heic');
reset role;
insert into public.favourites (user_id, note_id) values ('22222222-2222-2222-2222-222222222222', 'b1000000-0000-0000-0000-000000000001');
insert into public.notes (id, sender_id, image_path, created_at)
values ('b1000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'old', now() - interval '5 hours');

set local role authenticated;
select ok((public.unsend_note('b1000000-0000-0000-0000-000000000001')).unsent_at is not null, 'AC11: unsend sets unsent_at');
reset role;
select is((select count(*)::int from public.favourites where note_id = 'b1000000-0000-0000-0000-000000000001'), 0, 'AC11: unsend deletes favourites');
set local role authenticated;
select throws_ok($$select public.unsend_note('b1000000-0000-0000-0000-000000000002')$$, 'P0001', 'unsend_window_passed', 'AC11: unsend fails after 4 h');

select lives_ok(
  $$insert into storage.objects (bucket_id, name) values ('notes', '11111111-1111-1111-1111-111111111111/s1.heic')$$,
  'AC12: sender uploads to own folder'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('notes', '22222222-2222-2222-2222-222222222222/s2.heic')$$,
  '42501', null, 'AC12: sender cannot upload to partner folder'
);
reset role;

select pg_temp.login('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select throws_ok($$select public.unsend_note('b0000000-0000-0000-0000-000000000001')$$, 'P0001', 'note_not_found', 'AC11: non-sender cannot unsend');
select is((select count(*)::int from storage.objects where bucket_id = 'notes' and name = '11111111-1111-1111-1111-111111111111/s1.heic'), 1, 'AC12: partner can select the object');
reset role;

select pg_temp.login('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id = 'notes'), 0, 'AC12: stranger cannot select the object');
reset role;

insert into public.pair_invites (code, created_by, expires_at) values ('expired', '33333333-3333-3333-3333-333333333333', now() - interval '1 minute');
insert into public.pair_invites (code, created_by, used_by, used_at) values ('used', '33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', now());
insert into public.pair_invites (code, created_by) values ('stranger', '33333333-3333-3333-3333-333333333333');
insert into public.pair_invites (code, created_by) values ('newuser', '44444444-4444-4444-4444-444444444444');

select pg_temp.login('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok($$select public.accept_invite('missing')$$, 'P0001', 'invite_not_found', 'AC8: unknown code rejected');
select throws_ok($$select public.accept_invite('expired')$$, 'P0001', 'invite_expired', 'AC8: expired invite rejected');
select throws_ok($$select public.accept_invite('used')$$, 'P0001', 'invite_used', 'AC8: used invite rejected');
select throws_ok($$select public.accept_invite('stranger')$$, 'P0001', 'cannot_pair_self', 'AC8: self invite rejected');
reset role;

select pg_temp.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select throws_ok($$select public.accept_invite('stranger')$$, 'P0001', 'already_paired', 'AC8: already-paired user rejected');
reset role;

select pg_temp.login('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is(
  (select array[p.user_a, p.user_b] from public.accept_invite('newuser') p),
  array['33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444']::uuid[],
  'AC8: success creates pair with user_a < user_b'
);
reset role;
select is((select used_by from public.pair_invites where code = 'newuser'), '33333333-3333-3333-3333-333333333333'::uuid, 'AC8: invite marked used');

select * from finish();
rollback;
