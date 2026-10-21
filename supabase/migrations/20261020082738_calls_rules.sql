create unique index calls_one_active_per_pair on public.calls (least(caller_id, callee_id), greatest(caller_id, callee_id))
where status in ('ringing', 'answered');

create extension if not exists pg_cron;

create function public.sweep_ringing_calls() returns int
language plpgsql security definer set search_path = '' as $$
declare
  n int;
begin
  update public.calls set status = 'missed', ended_at = now()
  where status = 'ringing' and created_at < now() - interval '60 seconds';
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke execute on function public.sweep_ringing_calls() from public, anon, authenticated;

select cron.schedule('sweep-ringing-calls', '* * * * *', 'select public.sweep_ringing_calls()');
