insert into auth.users (instance_id, id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change) values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'adam@example.com', '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'partner@example.com', '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'stranger@example.com', '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');

update public.profiles set display_name = 'Adam', time_zone = 'Europe/London', avatar_tint = 'NotePaperBlue'
where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set display_name = 'Partner', time_zone = 'Europe/London', avatar_tint = 'NotePaperPink'
where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set display_name = 'Stranger'
where id = '33333333-3333-3333-3333-333333333333';

insert into public.pairs (user_a, user_b) values
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');

insert into public.catalog_entries (id, hobby, source, external_id, title, details) values
  ('c0000000-0000-0000-0000-000000000001', 'reading', 'openlibrary', 'OL1W', 'Sample Book', '{"chapter_count": 12}'),
  ('c0000000-0000-0000-0000-000000000002', 'tv', 'tmdb', '1001', 'Sample Show', '{"seasons": [{"season": 1, "episode_count": 3}, {"season": 2, "episode_count": 3}]}'),
  ('c0000000-0000-0000-0000-000000000003', 'games', 'igdb', '2001', 'Sample Game', '{}');

insert into public.items (id, user_id, catalog_entry_id, chapter, season, episode, percent, hours) values
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'c0000000-0000-0000-0000-000000000001', 3, null, null, null, null),
  ('a0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'c0000000-0000-0000-0000-000000000002', null, 1, 2, null, null),
  ('a0000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'c0000000-0000-0000-0000-000000000003', null, null, null, 40, 10);

insert into public.logs (id, user_id, item_id, chapter, season, episode) values
  ('d0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000001', 3, null, null),
  ('d0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'a0000000-0000-0000-0000-000000000002', null, 1, 2);

insert into public.checkins (user_id, hobby, day) values
  ('11111111-1111-1111-1111-111111111111', 'reading', current_date),
  ('22222222-2222-2222-2222-222222222222', 'tv', current_date);

insert into public.notes (id, sender_id, image_path) values
  ('b0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111/b0000000-0000-0000-0000-000000000001.heic'),
  ('b0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222/b0000000-0000-0000-0000-000000000002.heic');

insert into public.favourites (user_id, note_id) values
  ('22222222-2222-2222-2222-222222222222', 'b0000000-0000-0000-0000-000000000001');

insert into public.calls (room_name, caller_id, callee_id, kind, status, answered_at, ended_at) values
  ('seed-room-1', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'video', 'ended', now(), now());

insert into public.devices (id, user_id, apns_token, voip_token, apns_env) values
  ('e0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'adam-apns', 'adam-voip', 'sandbox'),
  ('e0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'partner-apns', 'partner-voip', 'sandbox');

insert into public.widget_push_tokens (device_id, widget_kind, token) values
  ('e0000000-0000-0000-0000-000000000001', 'notes', 'adam-widget-notes');
