begin;
create extension if not exists pgtap with schema extensions;
select plan(45);

create function pg_temp.login(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

create function pg_temp.pair_order() returns uuid[] language sql as $$
  select array_agg(id order by position) from public.sounds
  where sender_id in ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
$$;

select is((select count(*)::int from public.sounds), 6, 'AC1: 6 seed sounds');
select is(
  (select count(*)::int from public.sounds s join storage.objects o on o.bucket_id = 'sounds' and o.name = s.audio_path),
  6, 'AC1: every seed sound has its object in the sounds bucket'
);
select ok(
  'sounds' in (select tablename::text from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public'),
  'AC7: sounds is in supabase_realtime'
);

select throws_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000f1', '11111111-1111-1111-1111-111111111111', '   ', '11111111-1111-1111-1111-111111111111/c1000000-0000-0000-0000-0000000000f1.m4a', 1000, 1000)$$,
  '23514', null, 'AC6: empty title rejected'
);
select throws_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000f2', '11111111-1111-1111-1111-111111111111', repeat('a', 31), '11111111-1111-1111-1111-111111111111/c1000000-0000-0000-0000-0000000000f2.m4a', 1000, 1000)$$,
  '23514', null, 'AC6: 31-character title rejected'
);
select lives_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000f3', '11111111-1111-1111-1111-111111111111', repeat('a', 30), '11111111-1111-1111-1111-111111111111/c1000000-0000-0000-0000-0000000000f3.m4a', 1000, 1000)$$,
  'AC6: 30-character title accepted'
);
select throws_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000f4', '11111111-1111-1111-1111-111111111111', 'Long', '11111111-1111-1111-1111-111111111111/c1000000-0000-0000-0000-0000000000f4.m4a', 10001, 10001)$$,
  '23514', null, 'AC6: duration over 10000 rejected'
);
select throws_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_start_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000f5', '11111111-1111-1111-1111-111111111111', 'Short', '11111111-1111-1111-1111-111111111111/c1000000-0000-0000-0000-0000000000f5.m4a', 1000, 200, 699)$$,
  '23514', null, 'AC6: trim under 0.5 s rejected'
);
select throws_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000f6', '11111111-1111-1111-1111-111111111111', 'Path', '22222222-2222-2222-2222-222222222222/c1000000-0000-0000-0000-0000000000f6.m4a', 1000, 1000)$$,
  '23514', null, 'AC6: audio_path outside the sender folder rejected'
);
delete from public.sounds where id = 'c1000000-0000-0000-0000-0000000000f3';

insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values
  ('c1000000-0000-0000-0000-0000000000a3', '33333333-3333-3333-3333-333333333333', 'Mine', '33333333-3333-3333-3333-333333333333/c1000000-0000-0000-0000-0000000000a3.m4a', 1000, 1000);
select is((select position from public.sounds where id = 'c1000000-0000-0000-0000-0000000000a3'), 0, 'AC3: an unpaired user''s first sound gets position 0');

select pg_temp.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select is((select count(*)::int from public.sounds), 6, 'AC2: Adam sees the pair''s 6 sounds and not the stranger''s');
select lives_ok(
  $$insert into public.sounds (id, sender_id, title, emoji, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000a1', '11111111-1111-1111-1111-111111111111', 'New', '🎉', '11111111-1111-1111-1111-111111111111/c1000000-0000-0000-0000-0000000000a1.m4a', 1000, 1000)$$,
  'AC2: Adam inserts as himself'
);
select ok(
  (select position from public.sounds where id = 'c1000000-0000-0000-0000-0000000000a1')
    < (select min(position) from public.sounds where id <> 'c1000000-0000-0000-0000-0000000000a1'),
  'AC3: Adam''s new sound is first'
);
select throws_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000b1', '22222222-2222-2222-2222-222222222222', 'Fake', '22222222-2222-2222-2222-222222222222/c1000000-0000-0000-0000-0000000000b1.m4a', 1000, 1000)$$,
  '42501', null, 'AC2: Adam cannot insert as Partner'
);
select throws_ok(
  $$update public.sounds set title = 'Boop boop', emoji = null, trim_start_ms = 10 where id = 'c0000000-0000-0000-0000-000000000002'$$,
  '23514', null, 'AC6: a trim that cuts a short clip is rejected on update'
);
update public.sounds set title = 'Boop boop', emoji = null where id = 'c0000000-0000-0000-0000-000000000002';
select is(
  (select array[title, coalesce(emoji, 'none')] from public.sounds where id = 'c0000000-0000-0000-0000-000000000002'),
  array['Boop boop', 'none'], 'AC2: Adam updates Partner''s sound'
);
select throws_ok(
  $$update public.sounds set position = 99 where id = 'c0000000-0000-0000-0000-000000000002'$$,
  '42501', null, 'AC2: position is not writable directly'
);
delete from public.sounds where id = 'c0000000-0000-0000-0000-000000000006';
select is((select count(*)::int from public.sounds where id = 'c0000000-0000-0000-0000-000000000006'), 0, 'AC2: Adam deletes Partner''s sound');
reset role;

select pg_temp.login('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select is((select count(*)::int from public.sounds where sender_id = '11111111-1111-1111-1111-111111111111'), 4, 'AC2: Partner sees Adam''s sounds');
update public.sounds set title = 'Dinner!', trim_end_ms = 1500 where id = 'c0000000-0000-0000-0000-000000000005';
select is(
  (select array[title, trim_end_ms::text] from public.sounds where id = 'c0000000-0000-0000-0000-000000000005'),
  array['Dinner!', '1500'], 'AC2: Partner updates Adam''s sound'
);
delete from public.sounds where id = 'c0000000-0000-0000-0000-000000000005';
select is((select count(*)::int from public.sounds where id = 'c0000000-0000-0000-0000-000000000005'), 0, 'AC2: Partner deletes Adam''s sound');
select throws_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000b2', '11111111-1111-1111-1111-111111111111', 'Fake', '11111111-1111-1111-1111-111111111111/c1000000-0000-0000-0000-0000000000b2.m4a', 1000, 1000)$$,
  '42501', null, 'AC2: Partner cannot insert as Adam'
);
select lives_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000a2', '22222222-2222-2222-2222-222222222222', 'Hey', '22222222-2222-2222-2222-222222222222/c1000000-0000-0000-0000-0000000000a2.m4a', 1000, 1000)$$,
  'AC2: Partner inserts as herself'
);
select ok(
  (select position from public.sounds where id = 'c1000000-0000-0000-0000-0000000000a2')
    < (select min(position) from public.sounds where id <> 'c1000000-0000-0000-0000-0000000000a2'),
  'AC3: Partner''s new sound lands before Adam''s newer one'
);
reset role;

select pg_temp.login('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is((select count(*)::int from public.sounds where sender_id <> '33333333-3333-3333-3333-333333333333'), 0, 'AC2: stranger sees no pair sounds');
update public.sounds set title = 'Hacked' where sender_id <> '33333333-3333-3333-3333-333333333333';
delete from public.sounds where sender_id <> '33333333-3333-3333-3333-333333333333';
select throws_ok(
  $$insert into public.sounds (id, sender_id, title, audio_path, duration_ms, trim_end_ms) values ('c1000000-0000-0000-0000-0000000000b3', '11111111-1111-1111-1111-111111111111', 'Fake', '11111111-1111-1111-1111-111111111111/c1000000-0000-0000-0000-0000000000b3.m4a', 1000, 1000)$$,
  '42501', null, 'AC2: stranger cannot insert as Adam'
);
reset role;
select is((select count(*)::int from public.sounds where sender_id <> '33333333-3333-3333-3333-333333333333'), 6, 'AC2: stranger deleted nothing');
select is((select count(*)::int from public.sounds where title = 'Hacked'), 0, 'AC2: stranger updated nothing');

select pg_temp.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select lives_ok(
  $$select public.reorder_sounds(array[
    'c0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-0000000000a2',
    'c0000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-0000000000a1', 'c0000000-0000-0000-0000-000000000002'
  ]::uuid[])$$,
  'AC4: reorder with the pair''s ids'
);
select is(
  pg_temp.pair_order(),
  array['c0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-0000000000a2',
        'c0000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-0000000000a1', 'c0000000-0000-0000-0000-000000000002']::uuid[],
  'AC4: new order applied'
);
select is(
  (select array_agg(position order by position) from public.sounds),
  array[1, 2, 3, 4, 5, 6], 'AC4: positions are 1..n'
);
select throws_ok(
  $$select public.reorder_sounds(array['c0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-0000000000a1']::uuid[])$$,
  'P0001', 'sounds_mismatch', 'AC4: missing id rejected'
);
select throws_ok(
  $$select public.reorder_sounds(array['c0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-0000000000a1', 'c1000000-0000-0000-0000-0000000000a2', 'c1000000-0000-0000-0000-0000000000ff']::uuid[])$$,
  'P0001', 'sounds_mismatch', 'AC4: extra id rejected'
);
select throws_ok(
  $$select public.reorder_sounds(array['c0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-0000000000a1', 'c1000000-0000-0000-0000-0000000000a3']::uuid[])$$,
  'P0001', 'sounds_mismatch', 'AC4: foreign id rejected'
);
select throws_ok(
  $$select public.reorder_sounds(array['c0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-0000000000a1', 'c1000000-0000-0000-0000-0000000000a2']::uuid[])$$,
  'P0001', 'sounds_mismatch', 'AC4: duplicate id rejected'
);
select is(
  pg_temp.pair_order(),
  array['c0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-0000000000a2',
        'c0000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-0000000000a1', 'c0000000-0000-0000-0000-000000000002']::uuid[],
  'AC4: rejected reorders change nothing'
);
reset role;

select pg_temp.login('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select throws_ok(
  $$select public.reorder_sounds(array['c0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-0000000000a2', 'c0000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-0000000000a1']::uuid[])$$,
  'P0001', 'sounds_mismatch', 'AC4: stranger cannot reorder the pair'
);
reset role;
select is(
  (select array_agg(position order by position) from public.sounds where sender_id <> '33333333-3333-3333-3333-333333333333'),
  array[1, 2, 3, 4, 5, 6], 'AC4: stranger reorder changed nothing'
);

select pg_temp.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select lives_ok(
  $$insert into storage.objects (bucket_id, name) values ('sounds', '11111111-1111-1111-1111-111111111111/t1.m4a')$$,
  'AC5: Adam uploads to his own folder'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('sounds', '22222222-2222-2222-2222-222222222222/t2.m4a')$$,
  '42501', null, 'AC5: Adam cannot upload to Partner''s folder'
);
reset role;

select set_config('storage.allow_delete_query', 'true', true);

select pg_temp.login('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id = 'sounds'), 0, 'AC5: stranger cannot read sound files');
delete from storage.objects where bucket_id = 'sounds';
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('sounds', '11111111-1111-1111-1111-111111111111/t3.m4a')$$,
  '42501', null, 'AC5: stranger cannot upload to Adam''s folder'
);
reset role;
select is((select count(*)::int from storage.objects where bucket_id = 'sounds'), 7, 'AC5: stranger deleted no sound files');

select pg_temp.login('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id = 'sounds' and name = '11111111-1111-1111-1111-111111111111/t1.m4a'), 1, 'AC5: Partner reads Adam''s file');
delete from storage.objects where bucket_id = 'sounds' and name = '11111111-1111-1111-1111-111111111111/t1.m4a';
reset role;
select is((select count(*)::int from storage.objects where bucket_id = 'sounds' and name = '11111111-1111-1111-1111-111111111111/t1.m4a'), 0, 'AC5: Partner deletes Adam''s file');

select * from finish();
rollback;
