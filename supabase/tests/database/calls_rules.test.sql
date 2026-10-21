begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into public.calls (id, room_name, caller_id, callee_id, kind, status) values
  ('f0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'audio', 'ringing');

select throws_ok(
  $$insert into public.calls (room_name, caller_id, callee_id, kind, status) values ('dup-same', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'audio', 'ringing')$$,
  '23505', null, 'AC1: second ringing call, same direction, violates calls_one_active_per_pair'
);
select throws_ok(
  $$insert into public.calls (room_name, caller_id, callee_id, kind, status) values ('dup-reverse', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'video', 'ringing')$$,
  '23505', null, 'AC1: second ringing call, reverse direction, violates calls_one_active_per_pair'
);

update public.calls set status = 'ended', ended_at = now() where id = 'f0000000-0000-0000-0000-000000000001';
select lives_ok(
  $$insert into public.calls (id, room_name, caller_id, callee_id, kind, status, created_at) values ('f0000000-0000-0000-0000-000000000002', 'old', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'audio', 'ringing', now() - interval '61 seconds')$$,
  'AC1: an ended call does not block a new ringing one'
);

insert into public.calls (id, room_name, caller_id, callee_id, kind, status, created_at) values
  ('f0000000-0000-0000-0000-000000000003', 'fresh', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'audio', 'ringing', now() - interval '30 seconds');

select is(public.sweep_ringing_calls(), 1, 'AC2: sweep marks one call');
select results_eq(
  $$select status, ended_at is not null from public.calls where id = 'f0000000-0000-0000-0000-000000000002'$$,
  $$values ('missed'::text, true)$$,
  'AC2: 61-second-old ringing call is missed with ended_at'
);
select results_eq(
  $$select status, ended_at is null from public.calls where id = 'f0000000-0000-0000-0000-000000000003'$$,
  $$values ('ringing'::text, true)$$,
  'AC2: 30-second-old ringing call is left alone'
);
select ok(
  not has_function_privilege('authenticated', 'public.sweep_ringing_calls()', 'execute'),
  'AC2: authenticated cannot execute sweep_ringing_calls'
);
select ok(
  exists (select 1 from cron.job where jobname = 'sweep-ringing-calls'),
  'AC2: cron.job contains sweep-ringing-calls'
);

select * from finish();
rollback;
