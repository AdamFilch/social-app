# buttercup features catalog

What the app does today, one entry per feature. Status words: **Built**, **Built (partial)**, **Planned**. Never renumber or rename entries; other documents link to their anchors. New features are appended after the last entry with a matching index row.

## Index

| # | Feature | Status |
|---|---|---|
| 1 | [Accounts and pairing](#1-accounts-and-pairing) | Built |
| 2 | [Calls](#2-calls) | Built (partial) |
| 3 | [Notes](#3-notes) | Built |

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

**Status:** Built (partial): backend and app screens are built; simulator-to-browser media (AC1), two-device calls (AC2) and the partner-side view of a camera toggle (AC6) are not yet verified.

**What it does:** Creates, answers and ends 1:1 audio and video calls between paired partners. A call is one `calls` row plus a LiveKit room named after its id; the functions return LiveKit tokens, and the apps follow status changes over Realtime.

**Flow:**
1. `start-call {kind}` finds the partner, inserts a `ringing` row with `room_name = id`, and returns `{call, token, livekit_url}`.
2. The callee's app sees the insert over Realtime `postgres_changes` on `calls`.
3. `answer-call {call_id}` (callee) sets `answered` + `answered_at` and returns the callee's token. Repeating it on an answered call returns a fresh token (reconnect).
4. `end-call {call_id, reason}` sets `declined` (callee, from ringing), `cancelled` / `missed` (caller, from ringing) or `ended` (either, from answered), with `ended_at`.
5. A `pg_cron` job (`sweep-ringing-calls`, every minute) marks calls still ringing after 60 s as `missed`.
6. App: the Calling tab shows the partner, Audio and Video buttons and Recent calls ("No calls yet. Give {name} a ring?" when empty). Tapping a button shows "Calling {name}…" with Cancel; the callee gets a "{name} is calling" sheet with Answer and Decline.
7. App in-call screen: partner feed full size, a self tile (tap for the mid tile with Flip and ↗, ↗ swaps the views), Mute, Camera, audio route and Hang up, a call timer, and "Connecting…" / "Reconnecting…" banners.

**Rules:**
- One active (`ringing` or `answered`) call per pair, enforced by the `calls_one_active_per_pair` index. If the partner's call is already ringing, `start-call` returns `{call, incoming: true}` and no token; repeating my own ringing call returns it again.
- An `answered` call whose LiveKit room is empty (both apps died) is ended by the next `start-call`; if someone is in the room, `start-call` returns 409 `busy`.
- Errors are `{error}`: 400 `bad_request`, 401 `unauthorized`, 403 `not_paired`, 404 `call_not_found`, 409 `busy` / `call_not_ringing` (with `status`) / `invalid_transition`. `end-call` on a finished call returns it unchanged.
- Tokens: identity = user id, 2 h TTL, join/publish/subscribe for that room only. Never stored in `calls`.
- The app only reads `calls` (RLS: caller or callee); all writes go through the functions with the service role.
- App: `end()` sends `cancelled` from outgoing, `declined` from incoming, otherwise `ended`. An unanswered outgoing call sends `missed` after 45 s. "Reconnecting…" shows when the partner leaves the room or the app's LiveKit connection drops (including quick reconnects), and the call sends `ended` if it hasn't recovered after 30 s.
- App: if both partners tap Call at once, the second `start-call` returns `incoming: true` and that phone shows the incoming sheet.
- App: on the simulator the camera is a looping test clip (`TestClipCapturer` into a `BufferCapturer`); Flip does nothing there.
- Local LiveKit is `livekit-server --dev` (`devkey` / `secret`). Functions reach it at `LIVEKIT_API_URL` (`http://host.docker.internal:7880`); apps use `LIVEKIT_URL` (`ws://127.0.0.1:7880`).

**Code:** `supabase/functions/start-call/index.ts`, `supabase/functions/answer-call/index.ts`, `supabase/functions/end-call/index.ts`, `supabase/functions/_shared/supabase.ts` (admin client, auth, `loadCall`, `transition`), `supabase/functions/_shared/livekit.ts` (tokens, room participant check), `supabase/functions/.env.example`, `supabase/migrations/20261020082738_calls_rules.sql` (index, sweep, cron), `supabase/functions/tests/calls.test.ts`, `supabase/tests/database/calls_rules.test.sql`, `ButtercupKit/Sources/ButtercupKit/CallStore.swift`, `ButtercupKit/Sources/ButtercupKit/Call.swift`, `Buttercup/Calling/` (Calling tab, outgoing, incoming sheet, in-call, test clip capturer), `Buttercup/ContentView.swift` (call overlay, sheet, alerts), `Buttercup/ButtercupApp.swift` (`CallStore`, `resync()` on becoming active). Spec: [prds/completed/3-backend-calls.prd.md](../prds/completed/3-backend-calls.prd.md), [prds/partial/3-frontend-calls.prd.md](../prds/partial/3-frontend-calls.prd.md).

**Known gaps:**
- AC1 unverified: simulator ↔ meet.livekit.io media, including partner audio reaching the app.
- AC2 unverified: a Video call between two iPhones (two simulators on one Mac can't both publish).
- AC6 partner side unverified: the other side showing video when the camera turns on and the initial again when it turns off.
- No VoIP, cancel or missed-call pushes ([8]).
- Functions are not deployed to the hosted project; that needs a LiveKit Cloud project and `supabase secrets set`.

---

## 3. Notes

**Status:** Built: the new note screen's frame only; its tools come in [10]–[16].

**What it does:** "Make a note" on the Notes tab opens the New Note Screen as a full-screen cover. It has nothing to draw or add yet: it shows the frame that later tickets fill in.

**Flow:**
1. Notes tab: a temporary "Make a note" button (primary pill with the sticker shadow) presents `NewNoteView` with `.fullScreenCover`.
2. The cover opens blank, in Draw mode, on the Draw tab: ✕ on the left and a disabled Send (40%, no shadow) on the right of the top bar, the pen | camera toggle on the right of the mode row, a white square canvas (screen width − 16, radius 20, 2.5 pt Outline), and the tab row Draw · Stickers · Emoji · Text · Face.
3. Tabs switch the selected pill; their content is empty. Face is at 40% and can't be tapped ("Face stickers, coming later").
4. Photo mode shows a blank Surface square and hides the tab row; the camera comes in [14].
5. ✕, a swipe down that starts above the canvas, the VoiceOver escape gesture and the mode toggle act at once when there is no progress.

**Rules:**
- `NoteDraft` holds `mode`, `photo`, `drawing`, `items` and `selection`; `hasProgress` is a photo, any stroke or any item.
- With progress, those actions show "Discard this note?" / "You will lose your progress if you proceed" / Keep editing / Discard, and Discard does the action (a mode switch clears the draft and opens the other mode blank).
- Swipe down follows the finger and closes past 30% of the height or faster than 600 pt/s; otherwise it eases back over 0.2 s. With Reduce Motion it doesn't follow the finger. A drag that starts on the canvas never dismisses.
- Debug builds add a placeholder item with a triple tap on the canvas, to test the discard alert before the tab tickets land.
- Send stays disabled until [16].

**Code:** `Buttercup/ContentView.swift` (`NotesTab`), `Buttercup/Notes/NewNoteView.swift` (cover, layout, alert, swipe down, `NoteTab`), `Buttercup/Notes/NoteDraft.swift` (`NoteDraft`, `NoteMode`, `NoteItem`), `Buttercup/Notes/ModeToggle.swift`, `Buttercup/DesignSystem/PillTabRow.swift`, `Buttercup/DesignSystem/Buttons.swift` (`PressableButtonStyle`, `PillButtonStyle`, `IconCircleButton`). Spec: [design/specs/new-note-screen.md](../design/specs/new-note-screen.md), [prds/completed/9-new-note-shell.prd.md](../prds/completed/9-new-note-shell.prd.md).

**Known gaps:**
- No tab content: Draw [10], Stickers [11], Emoji [12], Text [13].
- No camera or Retake [14], no outbox [15], no sending [16].
- No Notes tab home, widget, calendar, favourites or unsend.
