insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change) values
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'adam@example.com', extensions.crypt('password', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'partner@example.com', extensions.crypt('password', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'stranger@example.com', extensions.crypt('password', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');

update public.profiles set display_name = 'Adam', time_zone = 'Europe/London', avatar_tint = 'NotePaperBlue'
where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set display_name = 'Partner', time_zone = 'Europe/London', avatar_tint = 'NotePaperPink'
where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set display_name = 'Stranger'
where id = '33333333-3333-3333-3333-333333333333';

insert into public.pairs (user_a, user_b, created_at) values
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', now() - interval '45 days');

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

insert into public.notes (id, sender_id, image_path, created_at) values
  ('b0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111/b0000000-0000-0000-0000-000000000001.heic', date_trunc('day', now()) + (now() - date_trunc('day', now())) * 0.9),
  ('b0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222/b0000000-0000-0000-0000-000000000002.heic', date_trunc('day', now()) + (now() - date_trunc('day', now())) * 0.6),
  ('b0000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222/b0000000-0000-0000-0000-000000000003.heic', date_trunc('day', now()) + (now() - date_trunc('day', now())) * 0.3),
  ('b0000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111/b0000000-0000-0000-0000-000000000004.heic', date_trunc('day', now()) - interval '1 day' + interval '9 hours 20 minutes'),
  ('b0000000-0000-0000-0000-000000000005', '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222/b0000000-0000-0000-0000-000000000005.heic', date_trunc('day', now()) - interval '1 day' + interval '18 hours 40 minutes'),
  ('b0000000-0000-0000-0000-000000000006', '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222/b0000000-0000-0000-0000-000000000006.heic', date_trunc('day', now()) - interval '3 days' + interval '8 hours 10 minutes'),
  ('b0000000-0000-0000-0000-000000000007', '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222/b0000000-0000-0000-0000-000000000007.heic', date_trunc('day', now()) - interval '3 days' + interval '20 hours 30 minutes'),
  ('b0000000-0000-0000-0000-000000000008', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111/b0000000-0000-0000-0000-000000000008.heic', date_trunc('day', now()) - interval '5 days' + interval '12 hours'),
  ('b0000000-0000-0000-0000-000000000009', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111/b0000000-0000-0000-0000-000000000009.heic', date_trunc('day', now()) - interval '8 days' + interval '7 hours 45 minutes'),
  ('b0000000-0000-0000-0000-000000000010', '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222/b0000000-0000-0000-0000-000000000010.heic', date_trunc('day', now()) - interval '11 days' + interval '13 hours 15 minutes'),
  ('b0000000-0000-0000-0000-000000000011', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111/b0000000-0000-0000-0000-000000000011.heic', date_trunc('day', now()) - interval '15 days' + interval '19 hours 5 minutes'),
  ('b0000000-0000-0000-0000-000000000012', '22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222/b0000000-0000-0000-0000-000000000012.heic', date_trunc('day', now()) - interval '20 days' + interval '10 hours 30 minutes');

update public.notes set unsent_at = created_at + interval '1 hour' where id = 'b0000000-0000-0000-0000-000000000008';

insert into public.favourites (user_id, note_id) values
  ('22222222-2222-2222-2222-222222222222', 'b0000000-0000-0000-0000-000000000001');

insert into public.calls (room_name, caller_id, callee_id, kind, status, answered_at, ended_at) values
  ('seed-room-1', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'video', 'ended', now(), now());

insert into public.devices (id, user_id, apns_token, voip_token, apns_env) values
  ('e0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'adam-apns', 'adam-voip', 'sandbox'),
  ('e0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'partner-apns', 'partner-voip', 'sandbox');

insert into public.widget_push_tokens (device_id, widget_kind, token) values
  ('e0000000-0000-0000-0000-000000000001', 'notes', 'adam-widget-notes');
