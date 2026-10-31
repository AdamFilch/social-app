# buttercup technical spec

Oct 19, 2026 · @Adam

How buttercup is built: a native Swift app on iOS 18+, using Apple frameworks wherever possible, with Supabase as the only backend. Decisions T1–T17 in [decisions.md](decisions.md) were settled with Adam on 2026-10-19. Product behaviour lives in the feature specs; this doc covers the how.

## 1. App

### Project layout

| Part | What's in it |
| --- | --- |
| `Buttercup` (iOS app target) | Screens, ARKit / CallKit / PushKit code, App Intents |
| `ButtercupWidgets` (widget extension) | Notes widget and hobby widgets |
| `ButtercupKit` (local Swift package) | Models, Supabase client, outbox, SwiftData schema, design system |

App and widget share one **App Group**, which holds the SwiftData store and note thumbnails.

**Dependencies:** only `livekit/client-sdk-swift` and `supabase-swift`. Everything else is Apple's: SwiftUI, SwiftData, ARKit, Vision, Core Image / Metal, CallKit, PushKit, AVFoundation, PencilKit, WidgetKit, App Intents, AuthenticationServices (Sign in with Apple) and Network.

### State

- Plain SwiftUI with async/await. No architecture library.
- One `@Observable @MainActor` store per feature: `SessionStore`, `CallStore`, `NotesStore`, `HobbyStore`, injected with `.environment`.
- Stores read from SwiftData and write through the outbox (below), so screens show cached data instantly.

### Design system

Full brand guide: [design.md](design.md). Mockup: [design-directions](https://claude.ai/artifact/C3QVDouTjcQZEoruGFxDqi).

- **Look:** Buttercup Field in light mode, Sticky Note in dark (T17). The mode follows the system setting. It is a custom look, not standard Liquid Glass.
- **Colours:** named tokens in `Buttercup/Assets.xcassets`, each with light and dark values (hex values in design.md §3).
  - Core: `Accent`, `Background`, `Surface`, `TextPrimary`, `TextSecondary` and `Danger`.
  - Added: `OnAccent`, `Outline`, `Highlight`, `OnHighlight` and `Divider`.
  - Note paper (the same in both modes): `NotePaperYellow`, `NotePaperPink`, `NotePaperBlue`, `NotePaperGreen` and `NotePaperLilac`.
  - Accent is a fill only, never text. Highlight only means "new to you".
- **Font:** SF Pro Rounded, set once with `.fontDesign(.rounded)` at the root. Dynamic Type works for free.
- **Shared constants** in `ButtercupKit`:
  - Spacing: 4 / 8 / 12 / 16 / 20 / 24 / 32.
  - Radius: 8 / 12 / 20 / 22 / 28 / pill, all continuous corners.
  - Border: 1.5 / 2 / 2.5.
  - Highlight ring: 3 pt with a 3 pt gap.
  - Sticker-shadow offset: 3, 3.
- **Shared components** in `ButtercupKit`:
  - `Card`, `ListGroup` / `ListRow`.
  - `PillButtonStyle` (primary, call, secondary, small, text, destructive). Every button is a pill.
  - `StickerShadow` modifier, used at most once per screen and only on its single create action.
  - `HighlightRing` modifier.
  - `Chip`, `PlusOneButton`.
  - `Avatar`: an initial on the person's `avatar_tint` now, a photo later.
  - `NoteTile`, `ProgressBar`.
  - `Doodle`: `doodle-flower`, `doodle-sparkle`, `doodle-tape` and `doodle-squiggle`, at most one per screen.

### Haptics

Minimal. Tab changes get only `.selection`, the lightest haptic. Ordinary buttons have no haptic; they only get a visual press from the shared `PressableButtonStyle`: the fill darkens and the sticker offset goes from 3 to 0 over 0.1 s ease-out, with no scale and no spring. Haptics are kept for the few moments that matter:

| Moment | Feedback |
| --- | --- |
| Call connected, note sent | `.success` |
| An action fails | `.error` |
| Sticker dropped on face | `.impact(weight: .light)` |

### Motion

- Custom bottom tab bar (Calling / Notes / Hobbies) that replaces the system Liquid Glass bar, whose stretchy selection animation felt jarring. Each tab has its own pill. Changing tabs cross-fades the old and new pills over 0.15 s ease-out, and no indicator moves between them. The selected icon uses its `.fill` variant. The bar has a Surface background with a 2.5 pt `Outline` top edge.
- Highlight and selection rings fade in over 0.15 s ease-out. Nothing idles, loops or animates on appear.
- Cards (a note, a book, a call) open into their detail screen with a zoom transition (`.navigationTransition(.zoom)` + `.matchedTransitionSource`).
- Creating something (note, item, call options) opens a sheet with detents.
- Default animation is `.smooth` with no bounce; with Reduce Motion on, zooms and slides become fades.

### Sync and offline

- **On launch:** pull rows changed since the last sync into SwiftData.
- **Session offline:** `SessionStore` saves `me`, `partner` and `pairedAt` to the App Group `UserDefaults` after each refresh and restores them when a launch can't reach the server, so a stored session opens the tabs offline. Only a missing or rejected session shows sign-in.
- **While open:** Supabase Realtime subscriptions on `notes`, `items`, `checkins` and `calls` apply partner changes live.
- **While closed:** notifications and WidgetKit pushes (sent by `push-partner`) wake the widgets.
- **Outbox:** every write (send note, +1, set progress, check-in, finish item, favourite, unsend) is saved as an `OutboxAction` in SwiftData first, then sent. A flusher retries when `NWPathMonitor` reports a connection. Rows use ids made on the phone, so a retry never creates a duplicate. Calls need a connection and skip the outbox.
- **Widgets** read the shared SwiftData store and the note thumbnails in the App Group; they never call the network.

## 2. Database

Supabase Postgres. All timestamps are `timestamptz` defaulting to `now()`. `→` means a foreign key.

**Enum `hobby_kind`:** `reading`, `tv`, `games`. The presets are fixed, so an enum replaces a hobbies table.

### profiles

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | → `auth.users.id` |
| display_name | text | |
| time_zone | text | e.g. `Europe/London`, used for "today" |
| avatar_tint | text | Name of a NotePaper colour token, e.g. `NotePaperBlue`; set at pairing (Q23) |
| avatar_path | text null | Storage path for a photo avatar, added later; when null the avatar shows an initial |
| created_at | timestamptz | |

### pairs

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | |
| user_a | uuid | → profiles; check `user_a < user_b` |
| user_b | uuid | → profiles |
| created_at | timestamptz | |

Unique on (`user_a`, `user_b`). Becomes friendships when the app goes public.

### pair_invites

| Column | Type | Notes |
| --- | --- | --- |
| code | text pk | random, shared as a link |
| created_by | uuid | → profiles |
| created_at | timestamptz | |
| expires_at | timestamptz | |
| used_by | uuid null | → profiles |
| used_at | timestamptz null | |

### devices

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | |
| user_id | uuid | → profiles |
| apns_token | text | normal notifications |
| voip_token | text | PushKit, for ringing |
| apns_env | text | `sandbox` or `production` |
| updated_at | timestamptz | |

### widget_push_tokens

| Column | Type | Notes |
| --- | --- | --- |
| device_id | uuid | → devices |
| widget_kind | text | `notes` or `hobby` |
| token | text | from WidgetKit push |
| updated_at | timestamptz | |

Primary key (`device_id`, `widget_kind`).

### calls

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | |
| room_name | text unique | LiveKit room |
| caller_id | uuid | → profiles |
| callee_id | uuid | → profiles |
| kind | text | `audio` or `video` (how it started) |
| status | text | `ringing`, `answered`, `declined`, `missed`, `cancelled`, `ended` |
| created_at | timestamptz | |
| answered_at | timestamptz null | |
| ended_at | timestamptz null | |

Indexes on (`caller_id`, `created_at`) and (`callee_id`, `created_at`). This is the call history.

### notes

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | made on the phone |
| sender_id | uuid | → profiles |
| image_path | text | `{sender_id}/{id}.heic` in the `notes` bucket |
| created_at | timestamptz | |
| unsent_at | timestamptz null | set by `unsend_note` |

Index on (`sender_id`, `created_at desc`).

### favourites

| Column | Type | Notes |
| --- | --- | --- |
| user_id | uuid | → profiles |
| note_id | uuid | → notes, on delete cascade |
| created_at | timestamptz | |

Primary key (`user_id`, `note_id`).

### catalog_entries

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | |
| hobby | hobby_kind | |
| source | text | `openlibrary`, `tmdb` or `igdb` |
| external_id | text | id in that source |
| title | text | |
| cover_url | text | image stays on the source's servers |
| details | jsonb | reading `{chapter_count}`; tv `{seasons: [{season, episode_count}]}`; games `{}` |
| fetched_at | timestamptz | |

Unique on (`source`, `external_id`).

### items

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | made on the phone |
| user_id | uuid | → profiles |
| catalog_entry_id | uuid | → catalog_entries |
| status | text | `current` or `finished` |
| chapter | int null | reading |
| season | int null | tv |
| episode | int null | tv |
| percent | smallint null | games, 0–100 |
| hours | numeric(6,1) null | games |
| started_at | timestamptz | |
| finished_at | timestamptz null | |
| last_logged_at | timestamptz | drives the widget's "most recent item" |

Index on (`user_id`, `status`).

### logs

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | made on the phone |
| user_id | uuid | → profiles |
| item_id | uuid | → items |
| created_at | timestamptz | |
| chapter, season, episode, percent, hours | same as items | progress after this change |

### checkins

| Column | Type | Notes |
| --- | --- | --- |
| user_id | uuid | → profiles |
| hobby | hobby_kind | |
| day | date | in the phone's time zone |
| created_at | timestamptz | |

Primary key (`user_id`, `hobby`, `day`), so checking in twice is harmless.

## 3. Rules, functions and pushes

### Row-level security

- Helper `is_paired_with(other uuid) returns boolean`, `security definer`, checks `pairs`.
- Every user table: **read** your own rows or your partner's (`user_id = auth.uid() or is_paired_with(user_id)`); **write** only your own.
- `calls` and `catalog_entries` are read-only to the app; Edge Functions write them with the service role.

### Postgres functions (RPC)

Actions that touch several rows run as one function, so they fully succeed or fully fail and the rules live on the server.

| Function | Does |
| --- | --- |
| `accept_invite(code)` | Checks expiry, creates the `pairs` row, marks the invite used |
| `log_increment(log_id, item_id)` | Chapter +1, episode +1 rolling into the next season from `catalog_entries.details`, or hours +1; writes the `logs` row and `last_logged_at` |
| `set_progress(log_id, item_id, …)` | Sets progress by hand (e.g. game percent) and writes a log |
| `check_in(hobby, day)` | Upserts the `checkins` row |
| `finish_item(item_id)` | Sets `status = finished`, `finished_at` |
| `unsend_note(note_id)` | Checks sender and the 4-hour window, sets `unsent_at`, deletes the image and favourites |

### Edge Functions

| Function | Does |
| --- | --- |
| `start-call` | Creates the `calls` row and LiveKit tokens, sends the VoIP push |
| `answer-call` | Sets `answered`, `answered_at` |
| `end-call` | Sets `declined`, `cancelled`, `ended` or `missed`, sends a cancel push so ringing stops |
| `catalog-search` | Searches Open Library, TMDB or IGDB (keys and the IGDB Twitch secret stay on the server) and upserts `catalog_entries` |
| `push-partner` | Database-webhook target for inserts on `notes`, `logs`, `checkins` and the unsend update; sends the text-only notification and/or WidgetKit push to the partner |

**Ring timeout:** the caller's app calls `end-call` with `missed` after 45 seconds. A `pg_cron` job marks any call still `ringing` after 60 seconds as missed, in case the caller's app died.

**Realtime publication:** `notes`, `items`, `checkins`, `calls`.

## 4. Images

- **Notes, the only images stored:**
  1. The editor flattens the note into one 1000 × 1000 HEIC (about 150 KB). Offline, it waits in the App Group with its outbox entry.
  2. Uploaded to the private Storage bucket `notes` at `{sender_id}/{note_id}.heic`, then the `notes` row is inserted.
  3. `push-partner` sends "New note from Adam" (no image) and a WidgetKit push.
  4. The partner's app lists rows with `NotesStore.notes(in:)` (one date range, newest first, unsent ones left out), downloads each image with an authenticated `storage.from("notes").download(path:)` under the bucket's select policy, and caches it in memory (`NSCache`, keyed by note id). `NotesStore.changes()` signals any insert or update on `notes` over realtime, and the caller refetches its range. Writing a small thumbnail to the App Group for the widget comes later.
  5. Storage rules: the sender writes to their own folder; the sender and their partner can read.
  6. `unsend_note` deletes the file. Copies saved to Photos stay.
  7. The free 1 GB holds roughly 6,500 notes.
- **Covers:** only `catalog_entries.cover_url` is stored; the phone caches the image.
- **Face-effect assets:** bundled in the app from `assets/`.
- **Call video:** streamed through LiveKit, never stored.

## 5. Testing calls

A buttercup call is two participants in a LiveKit room, so most of the call flow can be tested on a Mac. Anything that needs the camera hardware or VoIP push needs the two iPhone 11s.

| Test | Where | How |
| --- | --- | --- |
| Call connects, audio and video both ways | Simulator ↔ browser | Join the same LiveKit room from the simulator and from LiveKit's web Meet app (meet.livekit.io, custom server URL plus a token from `lk token create`). The browser uses the Mac's webcam and mic. |
| Start, answer and end flow between two app instances | Two simulators side by side (different device types) | Each signs in as a different test user; the callee picks up through the Supabase Realtime ringing broadcast while its app is open. |
| Outgoing video on the simulator | Simulator | The simulator has no camera, so `#if targetEnvironment(simulator)` builds feed a bundled test clip into LiveKit's `BufferCapturer`, the same path the effects use. |
| Missed-call notification | Simulator | `xcrun simctl push` delivers normal notifications. |
| VoIP ringing from a closed app, CallKit lock screen, ARKit face effects, PiP camera, heat | Both iPhone 11s only | Install through Xcode or TestFlight. The simulator has no camera and is assumed not to get VoIP pushes *(inferred)*. |

Build step 1 (a call joined from a button, see video-calls-spec.md) is tested simulator ↔ browser; everything from the ARKit camera onward is tested on the phones.
