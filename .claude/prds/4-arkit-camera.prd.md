# [4]: ARKit camera into the call (build step 2)

**Depends on:** [3]: Frontend — Calls merged.

This ticket swaps the front camera in a call from LiveKit's standard capturer to ARKit face tracking. The video still looks plain: nothing is drawn on it yet. What changes is that every outgoing frame now arrives with a face anchor attached, which the stickers in [5] need. When your camera is on and facing front, an `ARSession` with `ARFaceTrackingConfiguration` runs at 30 fps and 720p with light estimation off. Each `ARFrame.capturedImage` is pushed into LiveKit through `BufferCapturer`, and your own preview shows the same buffer. Turning the camera off pauses the AR session. Flipping to the back camera stops ARKit and uses LiveKit's normal camera capturer, because ARKit face tracking only works with the front TrueDepth camera (D33). The simulator keeps using the test clip from [3].

## Summary
Adds a small `FaceTracker` protocol with an ARKit implementation (face-tracking-options.md §5) and a `CameraSource` switch in `CallStore` (front ARKit / back LiveKit / simulator clip). There are no backend, schema or screen-layout changes.

## Users
- **Primary**: Adam and his partner on their iPhone 11s; [5], which reads the face anchor.
- **Not for**: simulator users (they get the clip).

## Scope
**MVP**
- `FaceTracker` protocol: `start()`, `stop()`, `onFrame: (CVPixelBuffer, ARFaceAnchor?, timestamp) -> Void`
- `ARKitFaceTracker`: 30 fps, 720p video format, `isLightEstimationEnabled = false`, `maximumNumberOfTrackedFaces = 1`
- Frames → `BufferCapturer.capture(_:timeStampNs:rotation:)`; own preview renders the same buffer
- Camera off → session paused; on → resumed; flip → swap source
- `ProcessInfo.thermalState` logged once per change (helps [7])

**Out of scope**
- Drawing anything on frames — [5]
- Vision fallback / PiP — build step 9
- Mac — build step 10

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [State Machine](#state-machine)
4. [End-to-End Flows](#end-to-end-flows)
5. [Blast Radius](#blast-radius)
6. [File Reference](#file-reference)
7. [Acceptance Criteria](#acceptance-criteria)
8. [Required Changes](#required-changes)

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
`CallStore` owns one active camera source at a time. The ARKit source hands each frame, with its optional `ARFaceAnchor`, to a single `onFrame` sink. In this ticket the sink publishes the frame unchanged. In [5] a compositor sits between the tracker and the publish step, without touching the tracker.

Non-obvious design decisions:
1. **The preview shows the buffer, not an `ARSCNView`.** What you see is exactly what your partner sees. [5] relies on this: stickers are baked into the buffer, so the preview needs no separate overlay.
2. **Only one thing owns the camera at a time** (ios-limits §7). LiveKit's capturer is stopped before `ARSession.run`, and the session is paused before the back capturer starts.
3. **Rotation is passed explicitly.** `capturedImage` is landscape-sensor-oriented, so the publish step passes `.rotation90` for a portrait UI, and the preview mirrors the front camera.

## State Machine
```
camera off ─on (front)─► [arkit] ─flip─► [back] ─flip─► [arkit]
                            │ off            │ off
                            └──► [paused] ◄──┘
```
| Condition | Source |
|---|---|
| Simulator build | test clip (always) |
| Camera on, front | ARKit |
| Camera on, back | LiveKit camera capturer |
| Camera off | none, session paused |

## End-to-End Flows
### Happy path
```
Video call answered
  └─► camera on, front ─► ARKitFaceTracker.start (30 fps, 720p)
        └─► ARFrame ─► BufferCapturer.capture ─► partner sees plain video
Flip ─► ARSession.pause ─► LiveKit back capturer ─► partner sees back camera
Flip ─► back capturer stop ─► ARSession.run ─► front again
```

## Blast Radius
| Change | What breaks |
|---|---|
| `FaceTracker.onFrame` signature | [5] compositor |
| Video format choice | Heat ([7]) and LiveKit bandwidth (tech-stack §3 free-plan math) |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Calling/FaceTracker.swift` | **new** protocol + `ARKitFaceTracker` |
| `ButtercupKit/Sources/ButtercupKit/CallStore.swift` | camera source switch (from [3]) |
| `Buttercup/Calling/InCallView.swift` | preview renders the published buffer |

---

## Acceptance Criteria
<!-- On-device ACs are a manual checklist (D36). The PRD is filed partial until Adam runs them. -->
- [ ] AC1: Simulator build still shows and sends the test clip in a call (regression of [3] AC2).
- [ ] AC2 (device): Partner sees plain, upright, correctly mirrored front video during a Video call.
- [ ] AC3 (device): The debug log shows the AR video format at 1280×720 @ 30 fps and light estimation off.
- [ ] AC4 (device): Flip → partner sees the back camera; flip back → front again, with no freeze longer than about 1 s.
- [ ] AC5 (device): Camera off → AR session paused (log) and partner sees your initial; camera on → resumes.
- [ ] AC6: `xcodebuild` builds for both simulator and a generic iOS device.

## Required Changes
- **Tracker**: `FaceTracker` + `ARKitFaceTracker` (see [Overview](#overview)).
- **Store**: source switch per the [State Machine](#state-machine).
- **Preview**: draw the published buffer, mirrored for the front camera.
- **Device run**: needs Xcode signing on your phones. A free Personal Team works for ARKit, so the paid account isn't needed yet.

## Features Catalog
- **Extends**: #1 Calls
- **Closes known gaps**: none

## Open Questions
- [ ] Does ARKit's 720p format on the iPhone 11 crop the field of view noticeably? Check on device; if it does, try the next format up and downscale.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Wrong rotation/mirroring on first try | High | Sideways video | AC2 catches it; rotation is one constant |
| AR session restart lag on flip | Med | Brief freeze | Accept up to 1 s (AC4) |

---
*Status: READY — ticket [4]*
