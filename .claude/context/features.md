# buttercup features catalog

What the app does today, one entry per feature. Status words: **Built**, **Built (partial)**, **Planned**. Never renumber or rename entries; other documents link to their anchors. New features are appended after the last entry with a matching index row.

## Index

| # | Feature | Status |
|---|---|---|
| 1 | [Accounts and pairing](#1-accounts-and-pairing) | Built |
| 2 | [Calls](#2-calls) | Built (partial) |

---

## 1. Accounts and pairing

**Status:** Built

**What it does:** Signs a person in with a six-digit email code, asks for their name, and pairs them with their partner. Once paired, the app opens on the Calling / Notes / Hobbies tab shell with the partner's name on the Calling tab.

**Flow:**
1. Email screen: type an email, "Send code". Supabase emails a six-digit code (locally caught by Mailpit at `http://127.0.0.1:54324`).
2. Code screen: type the code, "Sign in". A wrong or expired code shows "That code didn't work." and stays on the screen.
3. Name screen: type a name, "Continue". Saves `profiles.display_name` and `profiles.time_zone` (from the phone).
4. Pair screen: an invite is created on arrival; "Invite" opens the share sheet with `buttercup://invite/CODE` and "Pair with me on buttercup", and the code is shown as selectable text. The partner opens the link or pastes the code and taps "Pair", which calls `accept_invite`. The inviter's screen refreshes every 5 s and on becoming active, so it moves on once the partner accepts.
5. Ready: each phone sets its own `avatar_tint` to the first NotePaper colour (Blue, Pink, Green, Lilac, Yellow) the partner isn't using; on a collision the later-created profile moves on next launch.
6. Sign out: a button on the Calling tab (and on the Pair screen) returns to the email screen.

**Rules:**
- State: no session → email; empty `display_name` → name; no partner profile visible → pair; otherwise the tab shell. The partner's `profiles` row is only readable once paired (RLS), so its presence decides paired vs unpaired.
- A `buttercup://invite/CODE` link opened while signed out or before the name is set is kept in memory and accepted once the app reaches the Pair screen. Links opened while already paired are ignored.
- Invite errors: `invite_not_found` "That code isn't right.", `invite_expired` "That invite has expired. Ask for a new one.", `invite_used` "That invite was already used.", `cannot_pair_self` "That's your own invite.", `already_paired` "You're already paired."
- Session is stored by `supabase-swift` in the Keychain (`kSecAttrAccessibleAfterFirstUnlock`) and survives relaunch.
- Debug builds talk to local Supabase (`http://127.0.0.1:54321`); Release builds to the hosted project. Set by the `SUPABASE_URL` / `SUPABASE_ANON_KEY` build settings, read from `Info.plist`.
- Failed actions play the `.error` haptic; nothing else has a haptic.

**Code:** `ButtercupKit/Sources/ButtercupKit/SessionStore.swift` (client, `Profile`, `SessionStore`), `Buttercup/Onboarding.swift` (email/code, name, pair screens), `Buttercup/ButtercupApp.swift` (root switch, `onOpenURL`), `Buttercup/ContentView.swift` (`CallingTab`), `Buttercup/Info.plist` (URL scheme, Supabase keys), `supabase/config.toml` + `supabase/templates/code.html` (email code template). Spec: [prds/completed/2-foundation-sign-in-pairing.prd.md](../prds/completed/2-foundation-sign-in-pairing.prd.md).

**Known gaps:**
- Sign in with Apple is not built (needs a paid Apple Developer account).
- No unpairing.
- Screens are plain SwiftUI, not yet restyled to the design system.

---

## 2. Calls

**Status:** Built (partial): backend and app screens are built; simulator-to-browser media (AC1), two-device calls (AC2) and the partner-side view of a camera toggle (AC6) are not yet verified; the ARKit camera ([4]), face stickers ([5]) and 3D sticker tracking ([28]) are built but not yet run on a device.

**What it does:** Creates, answers and ends 1:1 audio and video calls between paired partners. A call is one `calls` row plus a LiveKit room named after its id; the functions return LiveKit tokens, and the apps follow status changes over Realtime.

**Flow:**
1. `start-call {kind}` finds the partner, inserts a `ringing` row with `room_name = id`, and returns `{call, token, livekit_url}`.
2. The callee's app sees the insert over Realtime `postgres_changes` on `calls`.
3. `answer-call {call_id}` (callee) sets `answered` + `answered_at` and returns the callee's token. Repeating it on an answered call returns a fresh token (reconnect).
4. `end-call {call_id, reason}` sets `declined` (callee, from ringing), `cancelled` / `missed` (caller, from ringing) or `ended` (either, from answered), with `ended_at`.
5. A `pg_cron` job (`sweep-ringing-calls`, every minute) marks calls still ringing after 60 s as `missed`.
6. App: the Calling tab shows the partner, Audio and Video buttons and Recent calls ("No calls yet. Give {name} a ring?" when empty). Tapping a button shows "Calling {name}…" with Cancel; the callee gets a "{name} is calling" sheet with Answer and Decline.
7. App in-call screen: partner feed full size, a self tile (tap for the mid tile with Flip, Add sticker and ↗, ↗ swaps the views), Mute, Camera, audio route and Hang up, a call timer, and "Connecting…" / "Reconnecting…" banners.

**Rules:**
- One active (`ringing` or `answered`) call per pair, enforced by the `calls_one_active_per_pair` index. If the partner's call is already ringing, `start-call` returns `{call, incoming: true}` and no token; repeating my own ringing call returns it again.
- An `answered` call whose LiveKit room is empty (both apps died) is ended by the next `start-call`; if someone is in the room, `start-call` returns 409 `busy`.
- Errors are `{error}`: 400 `bad_request`, 401 `unauthorized`, 403 `not_paired`, 404 `call_not_found`, 409 `busy` / `call_not_ringing` (with `status`) / `invalid_transition`. `end-call` on a finished call returns it unchanged.
- Tokens: identity = user id, 2 h TTL, join/publish/subscribe for that room only. Never stored in `calls`.
- The app only reads `calls` (RLS: caller or callee); all writes go through the functions with the service role.
- App: `end()` sends `cancelled` from outgoing, `declined` from incoming, otherwise `ended`. An unanswered outgoing call sends `missed` after 45 s. "Reconnecting…" shows when the partner leaves the room or the app's LiveKit connection drops (including quick reconnects), and the call sends `ended` if it hasn't recovered after 30 s.
- App: if both partners tap Call at once, the second `start-call` returns `incoming: true` and that phone shows the incoming sheet.
- App: on the simulator the camera is a looping test clip (`TestClipCapturer` into a `BufferCapturer`); Flip does nothing there.
- App: on a device the front camera is ARKit face tracking (`ARKitFaceTracker`: 1280×720 @ 30 fps, light estimation off, one face), with each `ARFrame.capturedImage` pushed into a `BufferCapturer` rotated 90°. The back camera is LiveKit's camera capturer. Camera off and Flip unpublish the video track and pause ARKit, and Camera on or Flip publishes a new track from the chosen source. The self preview is mirrored for the front camera: with ARKit or the clip it is its own composite from `StickerCompositor` (mirrored video, shown through an `AVSampleBufferDisplayLayer`); with LiveKit's capturer it is LiveKit's mirrored view. Thermal state is logged on each change.
- App: face stickers ([5]). Add sticker (mid tile, front camera on only) switches to the big self view and opens a tray sheet (small and medium detents) with Emoji (a grid plus "Or type any emoji"), Text (text plus Ink, Yellow, Pink, Blue, Green or Lilac, drawn rounded heavy with an ink outline) and Images (every PNG in `assets/stickers`, bundled as the `stickers` folder; "No image stickers yet." when empty). Tapping an item places it on the face centre; dragging it out of the tray drops it where the finger lets go. A drop inside a camera-facing `ARFaceGeometry` triangle pins to that spot on the skin (triangle plus barycentric weights) and turns with it; a drop anywhere else pins to a head-fixed plane through the nose tip, with no distance limit ([28]). Each sticker is a 6 cm quad (× its scale) in face space, upright to the head, projected each frame and drawn in perspective with `CIPerspectiveTransform`, so it tilts, turns, foreshortens and scales with distance; one facing away from the camera is not drawn. In the big self view: drag moves and re-pins, pinch resizes (0.3–5×), twist rotates, tap selects (dashed outline in the preview only) and shows a trash button at the bottom middle; selecting closes the tray. Placing plays `.impact(weight: .light)`. Max 10, after which tray items are disabled with "That's 10. Remove one to add more." While no face is tracked, tray cells, the emoji field and Add are disabled at 40% with "Show your face to add stickers" and nothing can be placed. `StickerCompositor` draws them with Core Image (one Metal `CIContext`, one BGRA `CVPixelBufferPool`, each sticker pre-rendered once) between the frame source and `BufferCapturer`, so the partner sees them unmirrored; with no stickers or at thermal `.critical` the raw frame is sent. It renders a second, mirrored buffer for your own tile with each sticker's corners swapped so text and images read the right way round. A frame without a tracked face draws no stickers (they return with the face). Frame time for both renders is logged every 30 frames. Stickers survive camera off/on and are cleared when the call goes idle. The back camera has no stickers.
- Local LiveKit is `livekit-server --dev` (`devkey` / `secret`). Functions reach it at `LIVEKIT_API_URL` (`http://host.docker.internal:7880`); apps use `LIVEKIT_URL` (`ws://127.0.0.1:7880`).

**Code:** `supabase/functions/start-call/index.ts`, `supabase/functions/answer-call/index.ts`, `supabase/functions/end-call/index.ts`, `supabase/functions/_shared/supabase.ts` (admin client, auth, `loadCall`, `transition`), `supabase/functions/_shared/livekit.ts` (tokens, room participant check), `supabase/functions/.env.example`, `supabase/migrations/20261020082738_calls_rules.sql` (index, sweep, cron), `supabase/functions/tests/calls.test.ts`, `supabase/tests/database/calls_rules.test.sql`, `ButtercupKit/Sources/ButtercupKit/CallStore.swift`, `ButtercupKit/Sources/ButtercupKit/Call.swift`, `Buttercup/Calling/` (Calling tab, outgoing, incoming sheet, in-call, test clip capturer, `FaceTracker.swift` ARKit face tracker), `Buttercup/ContentView.swift` (call overlay, sheet, alerts), `Buttercup/ButtercupApp.swift` (`CallStore`, `resync()` on becoming active, wires the clip or the ARKit tracker through `StickerCompositor` into `CallStore`, clears stickers on idle), `Buttercup/Effects/` (`Sticker.swift` types and `StickerLayer`, `StickerCompositor.swift`, `StickerTray.swift`, `StickerGestures.swift`), `assets/stickers/` (image stickers, folder reference in the project). Spec: [prds/completed/3-backend-calls.prd.md](../prds/completed/3-backend-calls.prd.md), [prds/partial/3-frontend-calls.prd.md](../prds/partial/3-frontend-calls.prd.md), [prds/partial/4-arkit-camera.prd.md](../prds/partial/4-arkit-camera.prd.md), [prds/partial/5-face-stickers.prd.md](../prds/partial/5-face-stickers.prd.md), [prds/partial/28-face-sticker-tracking.prd.md](../prds/partial/28-face-sticker-tracking.prd.md).

**Known gaps:**
- AC1 unverified: simulator ↔ meet.livekit.io media, including partner audio reaching the app.
- AC2 unverified: a Video call between two iPhones (two simulators on one Mac can't both publish).
- AC6 partner side unverified: the other side showing video when the camera turns on and the initial again when it turns off.
- [4] unverified: the simulator call with the clip after the camera-source change (AC1), plus on-device ARKit front video, format log, flip and camera off (AC2–AC5).
- [5] unverified on a device: stickers following the face (AC2), drag/pinch/twist/trash on a real face (AC3), text sticker colour and outline on the partner's phone (AC4), and the back camera hiding Add sticker (AC9). Dragging from the tray onto the view could not be driven in the simulator.
- Selecting a placed sticker closes the tray; reopening it goes through the mid tile again.
- [28] unverified on a device: hiding on a lost face and leaving the screen edge (AC1), readable stickers in the mirrored preview and on the partner's phone (AC2), tilt, turn and facing-away hiding (AC3), surface and head-plane anchors (AC4), the no-face tray state on a real camera (AC5), and frame time under 33 ms on an iPhone 11 with 10 stickers (AC6).
- No VoIP, cancel or missed-call pushes ([8]).
- Functions are not deployed to the hosted project; that needs a LiveKit Cloud project and `supabase secrets set`.
