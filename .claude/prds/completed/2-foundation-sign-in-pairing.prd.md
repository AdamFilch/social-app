# [2]: Foundation — sign-in, pairing and Supabase client

This ticket connects the iOS app to the Supabase backend from PRD [1] so that two real people exist in the app before any call is built. On first launch you type your email, receive a six-digit code, and type it in. Then you enter your name, and the app either shows your partner or asks you to pair. To pair, one of you taps **Invite**, which opens the share sheet with a `buttercup://invite/CODE` link. The other taps the link (or pastes the code into a field), and the app calls `accept_invite`. Both phones then land on the existing Calling / Notes / Hobbies tab shell, with the partner's name shown on the Calling tab.

Sign in with Apple is deferred because there is no paid Apple Developer account yet (D9, D10). Email codes work on simulators and, locally, every code is caught by Mailpit, so the developer agent can sign in two simulators without a real inbox.

## Summary
Adds the `ButtercupKit` local Swift package (Supabase client, `Profile` and `Pair` models, `SessionStore`), enables email OTP in `supabase/config.toml`, and adds four plain SwiftUI screens (email, code, name, pair). The tab shell in `Buttercup/ContentView.swift` stays as it is and is shown only once you are signed in and paired. No database changes.

## Users
- **Primary**: Adam and his partner, once each, on first launch; and the developer agent, which needs two signed-in, paired simulators for every call ticket after this.
- **Not for**: anyone outside the pair; App Store users.

## Scope
**MVP**
- `ButtercupKit` package with `supabase-swift`, `SupabaseClient` configured from `Info.plist` keys (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) with a DEBUG-local / Release-hosted switch
- Email OTP sign-in, session persisted by `supabase-swift` (Keychain)
- Name screen; sets `display_name` and `time_zone`
- Invite (share link) and accept (URL or paste); `avatar_tint` set after pairing (D31)
- Sign out (a plain button on the Calling tab, DEBUG and Release)

**Out of scope**
- Sign in with Apple — needs a paid account (D10)
- SwiftData cache and outbox — not needed by calls (D30)
- Design-system styling — plain SwiftUI, restyled later (D8)
- Unpairing — no requirement yet

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [State Machine](#state-machine)
4. [Writers](#writers)
5. [Readers](#readers)
6. [End-to-End Flows](#end-to-end-flows)
7. [Blast Radius](#blast-radius)
8. [File Reference](#file-reference)
9. [Acceptance Criteria](#acceptance-criteria)
10. [Required Changes](#required-changes)

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

## Overview
`SessionStore` owns the Supabase session and the two `profiles` rows (yours and your partner's). It drives which screen shows. All reads and writes use the contract in [PRD 1 § Contract for frontend](completed/1-supabase-backend-foundation.prd.md#contract-for-frontend). Nothing new is added on the server.

Questions the data answers:
1. **Am I signed in?** → `supabase.auth.session` exists
2. **Have I set my name?** → my `profiles.display_name != ''`
3. **Am I paired, and with whom?** → a `pairs` row containing me; the partner is the other `profiles` row returned by `from('profiles').select()`

Non-obvious design decisions:
1. **Tint is chosen by each phone, not by `accept_invite`** ([D31](#decision-log)). Each app updates only its own row (allowed by RLS), so no migration is needed. The order of the five NotePaper colours is fixed: `NotePaperBlue`, `NotePaperPink`, `NotePaperGreen`, `NotePaperLilac`, `NotePaperYellow`. Each app takes the first one the partner isn't using. If both phones pick at the same moment and collide, the one that comes second (by `profiles.created_at`) moves to the next colour on its next launch.
2. **One Supabase client in `ButtercupKit`.** Every later store (`CallStore`, etc.) gets it from `SessionStore` rather than making its own, so one session and one Realtime socket are shared.

## State Machine
```
[signedOut] ─code ok─► [needsName] ─save─► [unpaired] ─accept / partner accepts─► [ready]
      ▲                                                                      │
      └──────────────────────────── sign out ────────────────────────────────┘
```
| Condition | State |
|---|---|
| no session | `signedOut` |
| session, `display_name == ''` | `needsName` |
| name set, no `pairs` row | `unpaired` |
| `pairs` row exists | `ready` (tab shell) |

While `unpaired`, the inviter's screen refreshes the pair status when the app becomes active and every 5 s while visible, so it moves to `ready` once the partner accepts.

## Writers
### 1. Request code → `supabase.auth.signInWithOTP(email:)`
**Trigger:** Email screen, "Send code". **Pre-conditions:** a valid-looking email, otherwise the button stays disabled. **Errors:** a rate limit or network failure shows "Couldn't send the code. Try again."

### 2. Verify code → `supabase.auth.verifyOTP(email:token:type: .email)`
**Trigger:** Code screen. A wrong or expired code shows "That code didn't work."

### 3. Save name → `from('profiles').update({display_name, time_zone: TimeZone.current.identifier})`
**Trigger:** Name screen, "Continue". Empty or whitespace-only names are blocked.

### 4. Create invite → `from('pair_invites').insert({}).select('code, expires_at')`
**Trigger:** Pair screen, "Invite". Opens `ShareLink` with `buttercup://invite/{code}` and the text "Pair with me on buttercup".

### 5. Accept invite → `rpc('accept_invite', {p_code})`
**Trigger:** `onOpenURL` for `buttercup://invite/{code}`, or the "Paste code" field.

| Error | Message shown |
|---|---|
| `invite_not_found` | "That code isn't right." |
| `invite_expired` | "That invite has expired. Ask for a new one." |
| `invite_used` | "That invite was already used." |
| `cannot_pair_self` | "That's your own invite." |
| `already_paired` | "You're already paired." |

**Edge cases:** if a link opens while the app is still `signedOut` or `needsName`, the code is kept in memory and used once the app reaches `unpaired`.

### 6. Set tint → `from('profiles').update({avatar_tint})`
Runs when the app enters `ready` and my `avatar_tint` is null (see Overview §1).

**Does not write:** `pairs` directly, `devices` (comes with ticket [8]), or any feature table.

## Readers
### `from('profiles').select()`
**Returns:** at most 2 rows (mine and my partner's). **Why:** your name, the partner's name and tint on the Calling tab.

### `from('pairs').select()`
**Returns:** 0 or 1 row. **Why:** decides `unpaired` vs `ready`.

| Consumer | File |
|---|---|
| Root view switch | `Buttercup/ButtercupApp.swift` |
| Partner name on Calling tab | `Buttercup/ContentView.swift` (Calling tab placeholder) |

## End-to-End Flows
### Happy path: pair two simulators
```
Sim A: email → code (Mailpit) → name "Adam" → Invite → share link copied
Sim B: email → code → name "Sam" → paste code
  └─► rpc accept_invite ─► pairs row
Sim B: ready, picks first free tint
Sim A: next 5 s refresh → ready, picks first tint Sam isn't using
Both: Calling tab shows the other's name
```
### Edge case: link tapped before signing in
```
Tap buttercup://invite/X while signedOut
  └─► code kept ─► sign in ─► name ─► unpaired ─► accept_invite(X) automatically
```

## Blast Radius
| Change | What breaks |
|---|---|
| `SessionStore` API | Every later store that takes the client from it ([3] frontend onward) |
| URL scheme `buttercup` | Existing invite links |
| `Info.plist` key names | Every build configuration |

## File Reference
| File | Role |
|---|---|
| `ButtercupKit/Package.swift` | **new** local package, depends on `supabase-swift` |
| `ButtercupKit/Sources/ButtercupKit/Supabase.swift` | **new** client setup |
| `ButtercupKit/Sources/ButtercupKit/Models.swift` | **new** `Profile`, `Pair` |
| `ButtercupKit/Sources/ButtercupKit/SessionStore.swift` | **new** state machine above |
| `Buttercup/Onboarding/*.swift` | **new** Email, Code, Name, Pair screens |
| [Buttercup/ButtercupApp.swift](../../Buttercup/ButtercupApp.swift) | Root switch on session state, `onOpenURL` |
| [Buttercup/ContentView.swift](../../Buttercup/ContentView.swift) | Partner name + Sign out on the Calling tab |
| [supabase/config.toml](../../supabase/config.toml) | Email OTP enabled (`[auth.email] enable_signup`, OTP length 6) |
| `Buttercup.xcodeproj` | URL type `buttercup`, package reference, Info.plist keys |

---

## Acceptance Criteria
- [x] AC1: On a fresh simulator, entering an email sends a code visible in Mailpit (`http://127.0.0.1:54324`), and entering it signs in.
- [x] AC2: A wrong code shows "That code didn't work." and stays on the code screen.
- [x] AC3: After saving a name, `profiles.display_name` and `time_zone` are set for that user (checked in Studio or `psql`).
- [x] AC4: Two simulators pair by opening `buttercup://invite/CODE` (`xcrun simctl openurl booted …`) and, in a second run, by pasting the code. Both end on the tab shell showing the other's name.
- [x] AC5: An expired invite and an already-used invite each show their message from [Writers §5](#writers).
- [x] AC6: After pairing, both `avatar_tint` values are set and differ.
- [x] AC7: Killing and relaunching the app keeps you signed in and paired; Sign out returns to the email screen.
- [x] AC8: `xcodebuild -scheme Buttercup -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeds, and `supabase db reset && supabase test db && supabase db lint` still pass.

## Required Changes
- **Package**: create `ButtercupKit` and add `supabase-swift` (see [File Reference](#file-reference)).
- **Config**: enable email OTP in `supabase/config.toml`; hosted project: enable the Email provider in the dashboard (manual, listed in Open Questions).
- **Session**: `SessionStore` with the [State Machine](#state-machine).
- **Screens**: four onboarding screens per [Writers](#writers); errors per the §5 table.
- **App**: root switch and `onOpenURL` in `ButtercupApp.swift`; URL type in the project.

## Features Catalog
- **Extends**: New feature (accounts and pairing). `.claude/context/features.md` doesn't exist yet; the developer agent creates it with this entry.
- **Closes known gaps**: none

## Open Questions
- [ ] The hosted Supabase default SMTP sends only a few emails an hour. Is that enough for two people, or should a custom SMTP be set up? Assumed enough.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Hosted email rate limit while testing on phones | Med | Can't sign in for a while | Sign in once; sessions persist |
| Simulator can't reach local Supabase from a second device type | Low | AC4 blocked | Both simulators use `127.0.0.1`, which they share with the Mac |

---
*Status: COMPLETED — PR #3*
