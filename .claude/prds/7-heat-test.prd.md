# [7]: 30-minute heat test (build step 4)

**Depends on:** [5]: Face stickers merged (and [6] if built first).

This ticket has no code (D3). It is a test Adam and his partner run on their two iPhone 11s before hats and filters are built. They hold a 30-minute video call with face tracking and stickers on, write down how hot and how smooth it gets every 5 minutes, and use the result to decide whether the sticker cap, frame rate or resolution need to come down before more effects are added. The iPhone 11 is the oldest phone that runs iOS 26 and the one most likely to heat up (video-calls-spec Phones).

## Summary
A checklist and a results table. The outcome is either "go: build hats and filters as planned" or a list of settings to change, which becomes a small follow-up ticket.

## Users
- **Primary**: Adam and his partner, holding both phones.
- **Not for**: the developer agent (it can't run this).

## Scope
**MVP**
- Two runs: Wi-Fi on both; and one phone on cellular
- Results table filled in below; decision recorded

**Out of scope**
- An on-screen thermal or fps overlay — not wanted (D3). [4] already logs `thermalState` changes to the Xcode console, which can be read afterwards if a phone is plugged in.

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Test procedure](#test-procedure)
3. [Results](#results)
4. [Acceptance Criteria](#acceptance-criteria)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D1 | Missing sign-in/pairing/client | A foundation ticket [2] before any call ticket | Calls need real paired users; nothing gets thrown away | User |
| D2 | Ticket granularity | One PRD per build step, big steps split (step 1 → backend/frontend, step 3 → stickers / pad, step 5 → backend/frontend) | Each ticket verifiable in one go | User |
| D3 | Heat test (step 4) | Checklist-only PRD, no code | It's a manual test | User |
| D4 | Ringing before CallKit | In-app incoming sheet driven by Realtime on `calls` while the callee's app is open | Matches technical-spec §5 two-simulator testing | User |
| D5 | Invite delivery | Share sheet with `buttercup://invite/CODE` (custom URL scheme) plus a paste-code field | No domain needed | User |
| D6 | Onboarding | Name only (prefilled if available); `time_zone` from the phone; `avatar_tint` auto at pairing | Shortest path | User |
| D7 | Visual design | Plain SwiftUI for all these tickets; designer agent spec → separate restyle ticket later | User will run the designer on the call screens | User |
| D8 | Foundation screens | Plain SwiftUI, designer later | Used once by two people | User |
| D9 | Accounts | None yet (no paid Apple account, LiveKit Cloud or APNs key). Each ticket opens with a manual setup checklist | Stated by user | User |
| D10 | Sign-in method | Supabase email one-time code now; Sign in with Apple is a later ticket | Works without a paid account and on simulators (Mailpit locally) | User |
| D11 | LiveKit environment | Local `livekit-server --dev` for development and agent verification; LiveKit Cloud keys only as hosted Edge Function secrets for the phones | Verifiable without an account | User |
| D12 | Call history | In step 1: "Recent calls" on the Calling tab, read from `calls`; missed shown as missed | Plain RLS read; helps verify statuses | User |
| D13 | In-call controls | Mute, camera on/off, flip front/back, audio route picker (`AVRoutePickerView`); flip lives on the self tile (revised by D40) | User picked all four | User |
| D14 | Call writers | `start-call`, `answer-call`, `end-call` are all Edge Functions, as in technical-spec §3 | Matches spec | User |
| D15 | Busy / glare | One active (`ringing` or `answered`) call per pair; `start-call` returns the existing ringing call so the second tapper sees it as incoming | No double rings | User |
| D16 | Network drop | Show "Reconnecting…" while LiveKit retries; end as `ended` if the partner isn't back after ~30 s | Survives Wi-Fi → cellular | User |
| D17 | Missed calls | Ring timeout in step 1 (caller calls `end-call` `missed` at 45 s; `pg_cron` sweeps `ringing` > 60 s); missed-call notification in step 5 (made local, revised by D43) | Notification arrives with the ringing work | User |
| D18 | Image stickers | Bundle every PNG in `assets/stickers` at build time; developer adds 2–3 placeholders | Assets folder is empty today | User |
| D19 | Sticker gestures | Drag to move (re-pins), pinch to resize, twist to rotate; tap → trash (spec) | User picked all | User |
| D20 | Face lost | Stickers freeze at the last face position until tracking returns | User choice | User |
| D21 | Text stickers | Type text + pick one of ~6 colours; rounded bold with ink outline | Small sheet | User |
| D22 | Drawing pad | PencilKit canvas + `PKToolPicker`, transparent background → PNG sticker | Least code | User |
| D23 | Sticker cap | Max 10 on the face at once; revisit after step 4 | Predictable load on iPhone 11 | User |
| D24 | Foreground ringing after step 5 | CallKit everywhere; the step-1 in-app sheet is removed | One code path | User |
| D25 | CallKit extras | Outgoing calls via `CXStartCallAction` (Recents, Bluetooth/CarPlay), call back from Recents (`INStartCallIntent`), answer on lock screen/Bluetooth | User picked all | User |
| D26 | Ticket list | [2] Foundation; [3] Backend/Frontend Calls; [4] ARKit camera; [5] Stickers; [6] Drawing pad; [7] Heat test; [8] Backend/Frontend Ringing | Confirmed | User |
| D27 | Live call updates | Realtime `postgres_changes` on `calls` (already in the publication) rather than a broadcast channel | Already set up in PRD [1] | Claude — straightforward |
| D28 | Callee token delivery | `answer-call` returns the callee's LiveKit token; tokens never stored in `calls` or sent in pushes (step 5 push carries `call_id` + caller name only) | Partner can read `calls`; tokens are credentials | Claude — security |
| D29 | Room name | `room_name = calls.id::text` | Unique by construction | Claude — straightforward |
| D30 | Outbox / SwiftData | Not built in [2]; calls skip the outbox (technical-spec §1); arrives with the Notes tickets | YAGNI | Claude — straightforward |
| D31 | `avatar_tint` assignment | After pairing, each app sets its own tint to the first NotePaper colour the partner isn't using (direct `profiles` update, already allowed) | No migration needed | Claude — straightforward |
| D32 | Simulator video | `#if targetEnvironment(simulator)` feeds a bundled test clip through LiveKit `BufferCapturer` (technical-spec §5) | Simulator has no camera | Claude — straightforward |
| D33 | Back camera | Front = ARKit (`ARFaceTrackingConfiguration`, 30 fps, 720p, light estimation off); back = LiveKit's camera capturer with no stickers | ARKit face tracking is front-only | Claude — straightforward |
| D34 | Sticker lifetime | Kept in memory while camera is off; cleared at call end (spec) | Spec | Claude — straightforward |
| D35 | Heat fallback | `ProcessInfo.thermalState == .critical` hides stickers, restored below it (spec) | Spec | Claude — straightforward |
| D36 | Device-only verification | Tickets needing camera/push ([4], [5], [6], [8] frontend) build + simulator-check what's possible; on-device ACs are a manual checklist, filed `partial` until the user runs it | Agent can't hold two iPhones | Claude — straightforward |
| D37 | Secrets | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` (later `APNS_*`) via `supabase secrets set`; local values in gitignored `supabase/functions/.env` | CLAUDE.md: no secrets committed | Claude — straightforward |
| D38 | Stale `answered` call (both apps died mid-call) | When `start-call` finds an `answered` call for the pair, it asks LiveKit's RoomService whether the room has participants; if empty, it marks the call `ended` and continues | Otherwise the one-active-call index (D15) blocks every future call | Claude — straightforward |
| D39 | Self tile sizes (FaceTime-style) | Small corner tile → tap → mid tile with buttons → expand (↗) button → big self view with the partner as the small tile; tap the partner's small tile to swap back; tapping elsewhere while mid returns to small | User described FaceTime's behaviour | User |
| D40 | Mid tile buttons | Flip camera (moved off the main bar) and Add sticker ([5]); main bar keeps mute, camera on/off, audio route, hang up | User picked | User |
| D41 | Add sticker from the mid tile | Switches to the big self view and opens the tray; stickers are only placed and edited in the big self view | Inferred from "edit my stickers here" (big view) — veto at review | Claude — inferred |
| D42 | Cancel push | `end-call` sends a VoIP push `{call_id, status}` for `cancelled` / `missed`; the app ends the matching CallKit call, or reports and immediately ends it if it never showed | PushKit requires every VoIP push to be reported to CallKit (ios-limits §3) | Claude — iOS rule |
| D43 | Missed-call notification | A local notification from the callee's app ("Missed call from {name}") when its ringing call ends as `missed` or `cancelled`; the callee's app also stops ringing after 60 s on its own; no server alert push | The ringing phone is already awake; covers the `pg_cron` sweep path with no extra server code — veto at review | Claude — straightforward |
| D44 | Simulator incoming calls after [8] | On simulator builds, the Realtime insert reports the call to CallKit locally, since simulators get no VoIP push | Keeps the two-simulator test from technical-spec §5 working | Claude — straightforward |
| D45 | Session readable while locked | Supabase session stored in the Keychain with `kSecAttrAccessibleAfterFirstUnlock` | Answering from the lock screen must call `answer-call` before unlock | Claude — iOS rule |

## Test procedure
**Setup (both phones)**
1. Charge to at least 80%, unplug, and close other apps. Brightness at about 70%, Low Power Mode off.
2. Room temperature, phones held or on a stand (not on a sofa cushion).
3. Start a **Video** call. Each person places **5 stickers** (mix of emoji, text and an image or drawing).

**Every 5 minutes (0, 5, 10 … 30), each person notes**
- Battery %
- Feel: cool / warm / hot / too hot to hold
- Smoothness: does the partner's video or your stickers stutter? (none / some / a lot)
- Did stickers disappear on their own? That means `.critical` thermal fallback (D35)

**Run 2:** repeat with one phone on cellular (Wi-Fi off).

## Results
| Run | Phone | Min | Battery % | Feel | Stutter | Stickers off? |
|---|---|---|---|---|---|---|
| 1 Wi-Fi | Adam | 0 | | | | |
| … | | | | | | |

**Decision rule**
- Stickers switched off before 30 min, or a lot of stutter by 20 min → follow-up ticket: lower the cap (D23) to 5 and/or ARKit to 24 fps, then re-run.
- Hot but smooth to 30 min → go, but build hats as flat images only (already planned).
- Warm and smooth → go.

---

## Acceptance Criteria
- [ ] AC1: Both runs are completed and the Results table is filled in for both phones.
- [ ] AC2: A decision is written under Results (go / follow-up with named changes).
- [ ] AC3: If follow-up, a new PRD exists for the changes before build step 6 starts.

---
*Status: READY — ticket [7]*
