# [3]: Frontend — Calls

**Depends on:** [3]: Backend — Calls merged, and [2]: Foundation merged.

This ticket makes the first real buttercup call. The Calling tab shows your partner with two equal buttons, **Audio** and **Video**, and below them a list of recent calls. Tapping a button shows an outgoing screen ("Calling Sam…") with a Cancel button, and gives up after 45 s. If your partner's app is open, a sheet slides up saying "Adam is calling" with **Answer** and **Decline**. Once answered, both phones show the in-call screen: the partner's video full screen (or their initial when their camera is off), your own small tile in a corner, and a main bar with mute, camera on/off, audio route and hang up. The self tile works like FaceTime (D39). Tap it and it grows to a mid size showing a Flip button and an expand (↗) button; tap anywhere else and it shrinks back. Expand swaps the views so you are full screen and your partner is the small tile, and tapping your partner's tile swaps back. If the network drops, the screen says "Reconnecting…", and the call ends if the partner isn't back within about 30 s.

Ringing only works while the callee's app is open. Ringing a closed or locked phone arrives with CallKit in ticket [8], which also removes the in-app sheet (D24). The camera in this ticket is LiveKit's standard camera capturer. ARKit comes in [4]. On the simulator, a bundled test clip replaces the camera (D32).

Backend half: [[3]: Backend — Calls](3-backend-calls.prd.md). This ticket uses only its [Contract for frontend](3-backend-calls.prd.md#contract-for-frontend).

## Summary
Adds `livekit/client-sdk-swift`, a `CallStore`, and four plain SwiftUI views (Calling tab, outgoing, incoming sheet, in-call). No schema or function changes. The visual design comes later in a restyle ticket from the designer agent (D7).

## Users
- **Primary**: Adam and his partner calling each other from the open app; the developer agent testing simulator ↔ browser and simulator ↔ simulator.
- **Not for**: anyone outside the pair.

## Scope
**MVP**
- Calling tab: partner name + avatar initial on their tint, Audio / Video buttons, Recent calls list
- Outgoing screen with Cancel; 45 s timeout → `end-call missed`
- Incoming sheet from Realtime with Answer / Decline
- In-call: remote video or initial; main bar with mute, camera on/off, `AVRoutePickerView`, hang up; call timer
- Self tile with three sizes (small / mid with Flip + expand / big self view with partner small), D39–D40. [5] adds the Add sticker button to the mid tile.
- Reconnecting state, ending after ~30 s without the partner
- Simulator test clip through `BufferCapturer`
- `.success` haptic on connect, `.error` when an action fails (technical-spec Haptics)

**Out of scope**
- CallKit, PushKit, closed-app ringing, missed-call notification — [8]
- ARKit — [4]; stickers — [5]
- Brand styling — later restyle (D7)
- Picture-in-Picture — build step 9

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [State Machine](#state-machine)
4. [Behaviour](#behaviour)
5. [Writers](#writers)
6. [Readers](#readers)
7. [End-to-End Flows](#end-to-end-flows)
8. [Blast Radius](#blast-radius)
9. [File Reference](#file-reference)
10. [Acceptance Criteria](#acceptance-criteria)
11. [Required Changes](#required-changes)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D4 | Ringing before CallKit | In-app incoming sheet driven by Realtime on `calls` while the callee's app is open | Matches technical-spec §5 two-simulator testing | User |
| D7 | Visual design | Plain SwiftUI for all these tickets; designer agent spec → separate restyle ticket later | User will run the designer on the call screens | User |
| D9 | Accounts | None yet (no paid Apple account, LiveKit Cloud or APNs key). Each ticket opens with a manual setup checklist | Stated by user | User |
| D11 | LiveKit environment | Local `livekit-server --dev` for development and agent verification; LiveKit Cloud keys only as hosted Edge Function secrets for the phones | Verifiable without an account | User |
| D12 | Call history | In step 1: "Recent calls" on the Calling tab, read from `calls`; missed shown as missed | Plain RLS read; helps verify statuses | User |
| D13 | In-call controls | Mute, camera on/off, flip front/back, audio route picker (`AVRoutePickerView`); flip lives on the self tile (revised by D40) | User picked all four | User |
| D14 | Call writers | `start-call`, `answer-call`, `end-call` are all Edge Functions, as in technical-spec §3 | Matches spec | User |
| D15 | Busy / glare | One active (`ringing` or `answered`) call per pair; `start-call` returns the existing ringing call so the second tapper sees it as incoming | No double rings | User |
| D16 | Network drop | Show "Reconnecting…" while LiveKit retries; end as `ended` if the partner isn't back after ~30 s | Survives Wi-Fi → cellular | User |
| D17 | Missed calls | Ring timeout in step 1 (caller calls `end-call` `missed` at 45 s; `pg_cron` sweeps `ringing` > 60 s); missed-call notification in step 5 (made local, revised by D43) | Notification arrives with the ringing work | User |
| D24 | Foreground ringing after step 5 | CallKit everywhere; the step-1 in-app sheet is removed | One code path | User |
| D27 | Live call updates | Realtime `postgres_changes` on `calls` (already in the publication) rather than a broadcast channel | Already set up in PRD [1] | Claude — straightforward |
| D28 | Callee token delivery | `answer-call` returns the callee's LiveKit token; tokens never stored in `calls` or sent in pushes (step 5 push carries `call_id` + caller name only) | Partner can read `calls`; tokens are credentials | Claude — security |
| D29 | Room name | `room_name = calls.id::text` | Unique by construction | Claude — straightforward |
| D32 | Simulator video | `#if targetEnvironment(simulator)` feeds a bundled test clip through LiveKit `BufferCapturer` (technical-spec §5) | Simulator has no camera | Claude — straightforward |
| D37 | Secrets | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` (later `APNS_*`) via `supabase secrets set`; local values in gitignored `supabase/functions/.env` | CLAUDE.md: no secrets committed | Claude — straightforward |
| D38 | Stale `answered` call (both apps died mid-call) | When `start-call` finds an `answered` call for the pair, it asks LiveKit's RoomService whether the room has participants; if empty, it marks the call `ended` and continues | Otherwise the one-active-call index (D15) blocks every future call | Claude — straightforward |
| D39 | Self tile sizes (FaceTime-style) | Small corner tile → tap → mid tile with buttons → expand (↗) button → big self view with the partner as the small tile; tap the partner's small tile to swap back; tapping elsewhere while mid returns to small | User described FaceTime's behaviour | User |
| D40 | Mid tile buttons | Flip camera (moved off the main bar) and Add sticker ([5]); main bar keeps mute, camera on/off, audio route, hang up | User picked | User |

## Overview
`CallStore` (`@Observable @MainActor`, in `ButtercupKit`) holds the current call's `phase`, the LiveKit `Room`, and the recent-calls list. It subscribes once to Realtime `calls` changes using the Supabase client from `SessionStore` (ticket [2]). The server row decides what the call's status is. The app's own `phase` adds local states that the server doesn't track (connecting, reconnecting).

Questions the data answers:
1. **Is someone calling me right now?** → a Realtime insert with `callee_id = me`, `status = 'ringing'`
2. **Did my call get answered or rejected?** → a Realtime update on my active call's `status`
3. **What's in the history?** → the `calls` history read (Contract)

Non-obvious design decisions:
1. **Leave the room on any terminal status from Realtime.** Whoever hangs up calls `end-call`, and the other side reacts to the Realtime update. LiveKit's participant-disconnected event is used only for the 30 s reconnect window (D16), so a brief drop isn't mistaken for a hang-up.
2. **Camera toggling never touches `calls.kind`.** `kind` records how the call started. The camera is just `room.localParticipant.setCamera(enabled:)`.
3. **The simulator clip goes through `BufferCapturer`**, the same path ARKit uses in [4] and stickers use in [5]. Video on the simulator exercises that path from day one.

## State Machine
```
[idle] ─tap─► [outgoing] ─answered─► [connecting] ─room joined─► [active] ─end─► [idle]
   │              │ cancel / 45 s / declined ──────────────────────────────────► [idle]
   └─incoming─► [incoming] ─answer─► [connecting]      [active] ⇄ [reconnecting] ─30 s─► [idle]
                    │ decline / caller cancelled / missed ─────────────────────► [idle]
```
| Condition | Phase |
|---|---|
| No active call | `idle` |
| I started, row `ringing` | `outgoing` (caller joins the room immediately and waits) |
| Row `ringing`, I'm callee | `incoming` |
| Answered, joining room | `connecting` |
| Both in the room | `active` |
| Partner disconnected or my room reconnecting | `reconnecting` |

**Audio / Video buttons are disabled when** the phase isn't `idle`, or there is no partner.

## Behaviour
| Screen | Shows | Actions | Empty / error / loading |
|---|---|---|---|
| Calling tab | Partner initial on `avatar_tint`, name, Audio, Video; "Recent calls" rows: direction icon, Audio/Video, relative time, duration or status word ("Missed" in Danger, "Declined", "Cancelled") | Audio, Video | Empty history: "No calls yet. Give {name} a ring?"; history load failure: the list is hidden and a retry happens on the next appear |
| Outgoing (full screen) | "Calling {name}…", initial | Cancel | `busy`: "{name} is on another call", back to idle |
| Incoming (sheet) | "{name} is calling", Audio/Video | Answer, Decline | Caller cancels → sheet closes |
| In-call (full screen) | Big view: partner's video or initial; small tile (top-right): you; mm:ss timer | Main bar: Mute, Camera, Route, Hang up | "Reconnecting…" banner |

**Self tile** (D39, D40). It shows your camera, or your initial when the camera is off:

```
[small] ─tap tile─► [mid: Flip, ↗] ─tap ↗─► [self big, partner small]
   ▲                     │ tap elsewhere            │ tap partner tile
   └─────────────────────┘                          └──► [small]
```
Size changes use the default `.smooth` animation with no bounce (technical-spec Motion), and become a fade with Reduce Motion. The tile is the same component in both positions, so [5] only adds a button to it.

A video call starts with the camera on; an audio call starts with it off. Both people can turn their camera on or off at any time. Microphone and camera permission prompts appear the first time they're needed. If either is denied, the call continues without it and the button shows as off.

## Writers
All via the backend contract.

| User action | Call | Then |
|---|---|---|
| Audio / Video | `start-call {kind}` | `incoming: true` → phase `incoming` with that row; else join room, phase `outgoing` |
| Cancel / 45 s | `end-call {reason: cancelled \| missed}` | leave room, idle |
| Answer | `answer-call {call_id}` | join room, phase `connecting` |
| Decline | `end-call {declined}` | idle |
| Hang up | `end-call {ended}` | leave room, idle |
| Reconnect timeout (30 s) | `end-call {ended}` | idle |

**Errors:** any failed call fires the `.error` haptic and shows "Couldn't reach {name}. Try again" (design.md voice), and the phase returns to `idle`. `answer-call` 409 `call_not_ringing` closes the sheet without showing an error.

## Readers
| Data | Source | Consumer |
|---|---|---|
| Partner name, tint | `SessionStore` ([2]) | Calling tab, outgoing, incoming |
| Recent calls | history read; reloaded on Calling tab appear and on every Realtime terminal update | Calling tab |
| Live status | Realtime `calls` | `CallStore.phase` |
| Media | LiveKit `Room` tracks | In-call |

## End-to-End Flows
### Happy path: video call between two simulators
```
Sim A taps Video
  └─► start-call ─► join room (test clip publishing) ─► outgoing
Sim B Realtime insert ─► incoming sheet ─► Answer
  └─► answer-call ─► join room ─► active (.success)
Sim A Realtime update answered ─► active (.success)
Sim A Hang up ─► end-call ended ─► idle; Sim B Realtime ended ─► idle
Both histories show "Video · 0:42"
```
### Edge case: nobody answers
```
Sim A outgoing for 45 s ─► end-call missed ─► idle
Sim B sheet closes on Realtime update; both histories show "Missed"
```
### Edge case: Wi-Fi drop
```
active ─► LiveKit reconnecting ─► "Reconnecting…"
  ├─ back within 30 s ─► active
  └─ not back ─► end-call ended ─► idle
```

## Blast Radius
| Change | What breaks |
|---|---|
| `CallStore.phase` names | [8] maps CallKit actions onto them |
| The `BufferCapturer` publish path | [4] and [5] feed frames into it |
| Removing the incoming sheet | Only allowed in [8], when CallKit replaces it (D24) |

## File Reference
| File | Role |
|---|---|
| `ButtercupKit/Sources/ButtercupKit/Call.swift` | **new** `Call` model (Codable, snake_case) |
| `ButtercupKit/Sources/ButtercupKit/CallStore.swift` | **new** phase machine, functions, Realtime, LiveKit room |
| `Buttercup/Calling/CallingView.swift` | **new** Calling tab |
| `Buttercup/Calling/OutgoingView.swift`, `IncomingSheet.swift`, `InCallView.swift` | **new** |
| `Buttercup/Calling/TestClipCapturer.swift` | **new**, `#if targetEnvironment(simulator)` |
| `Buttercup/Resources/test-clip.mp4` | **new** short looping clip |
| [Buttercup/ContentView.swift](../../Buttercup/ContentView.swift) | Calling tab shows `CallingView`; full-screen covers for call phases |
| `Buttercup.xcodeproj` | LiveKit package, `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, background mode `audio` |

---

## Acceptance Criteria
- [ ] AC1: Simulator ↔ browser: the simulator joins a room from `start-call` while meet.livekit.io (custom URL `ws://127.0.0.1:7880`, token from `lk token create --api-key devkey --api-secret secret --join --room <id> --identity web`) is in the same room. Each side sees and hears the other (the simulator shows the test clip).
- [ ] AC2: Two simulators, Video: A rings B, B answers, and both reach the in-call screen with remote video. Hang up on either side returns both to idle, and history shows a Video row with a duration.
- [x] AC3: Decline on B → A returns to idle; both histories show "Declined".
- [x] AC4: Cancel on A → B's sheet closes; both show "Cancelled".
- [x] AC5: No answer for 45 s → both show "Missed" (red).
- [ ] AC6: Audio call: starts with the camera off; turning the camera on mid-call shows video on the other side, and off shows the initial again.
- [ ] AC7: Mute stops the other side hearing you (checked against the browser); Flip on the mid tile switches the capturer (no-op on the simulator, no crash).
- [x] AC8: Self tile: tap → mid with Flip and ↗; tap elsewhere → small; ↗ → you big, partner small; tap partner tile → back to partner big.
- [x] AC9: Both tap Call within a second → one call rings; the second tapper sees the incoming sheet.
- [x] AC10: Stopping `livekit-server` mid-call shows "Reconnecting…", and the call ends about 30 s later.
- [x] AC11: Empty history shows "No calls yet. Give {name} a ring?".
- [x] AC12: `xcodebuild … build` succeeds; backend `supabase test db` still passes.

## Required Changes
- **Package**: add `livekit/client-sdk-swift` to `ButtercupKit`.
- **Store**: `CallStore` per [State Machine](#state-machine) and [Writers](#writers).
- **Screens**: per [Behaviour](#behaviour).
- **Simulator**: `TestClipCapturer` reading the clip with `AVAssetReader` and pushing frames into `BufferCapturer` (D32).
- **Project**: usage strings, audio background mode.

## Features Catalog
- **Extends**: #1 Calls (created by [3] backend)
- **Closes known gaps**: none

## Open Questions
- [ ] Should the outgoing screen play a ringback tone? Not decided; silent for now.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Two simulators share one Mac mic/speaker | High | Audio echo confuses AC2 | Judge audio with simulator ↔ browser (AC1); use AC2 for flow |
| Realtime misses an event while the app is backgrounded | Med | Stale phase | Re-read the active call on `scenePhase == .active` |

---
*Status: PARTIAL — PR #5*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ⚠️ unverified | Claude in Chrome tools (`mcp__claude-in-chrome__*`) were not available to the agent, so the meet.livekit.io side could not be driven. The `lk` CLI stand-in was not used again by decision. |
| AC2 | ⚠️ unverified | Skipped by Adam's decision: needs two iPhones. Two simulators on one Mac can't both publish. |
| AC3 | ✅ done | Sheet "Partner is calling" → Decline closes it, 0 active calls, row `declined`, history shows "Declined". |
| AC4 | ✅ done | Caller cancel closes the sheet, history "Cancelled"; Adam's Cancel leaves 0 active calls, row `cancelled`. |
| AC5 | ✅ done | Outgoing screen closed after 45.1 s, row `missed` 46 s after creation, history "Missed". |
| AC6 | ⚠️ unverified | This side verified: audio call publishes only the mic; Camera on publishes a camera track the partner subscribes to; Camera off mutes it; self tile goes initial → video → initial. The partner's screen needs the browser (see AC1). |
| AC7 | ⚠️ unverified | The mic track goes `muted` / `unmuted` on the server at the Mute / Unmute taps (seen by the `lk` client); Flip tapped with no crash. Not checked by ear against the browser. |
| AC8 | ✅ done | Tap → mid tile with Flip and ↗; tap elsewhere → small; ↗ → self full size, partner tile; tap partner tile → back. Screenshots at each step. |
| AC9 | ✅ done | Scripted race (partner `start-call` fired with the tap, staggered 0–1000 ms, 6 rounds): always exactly 1 active call; both winners occurred, and the loser always got the incoming state (Adam's sheet, or `incoming: true` for the partner). |
| AC10 | ✅ done | `livekit-server` killed mid-call: "Reconnecting…" within ~1.3 s, call ended 30.1 s later, row `ended` (two runs). Needed the fix in `4a437d5`. |
| AC11 | ✅ done | "No calls yet. Give Partner a ring?" with no call rows. |
| AC12 | ✅ done | `xcodebuild … build` succeeds; `supabase test db` 58/58 pass after `supabase db reset`; `supabase db lint` no errors. |

### Needs attention
- AC1 and AC6 (partner side): connect the Claude in Chrome extension and re-run against meet.livekit.io, or check by hand: custom URL `ws://127.0.0.1:7880`, token from `lk token create --api-key devkey --api-secret secret --join --room <call id> --identity web`; confirm video both ways, partner audio on the simulator, and the browser showing the simulator's video only while its camera is on.
- AC7: confirm by ear in the browser that Mute silences the simulator.
- AC2: a Video call between two iPhones.
