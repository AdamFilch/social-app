# [8]: Frontend — Ringing

**Depends on:** [8]: Backend — Ringing merged, [5] merged (or at least [3] Frontend), and the manual setup in [8] Backend done.

This ticket makes buttercup ring like a real phone call. Whether the app is open, in the background, closed or the phone is locked, an incoming call shows the native iPhone call screen ("Adam — buttercup Video"). You answer it from the lock screen, from AirPods or other Bluetooth, or from CarPlay. Answering connects the call and opens the buttercup in-call screen once the phone is unlocked. Decline, or the caller cancelling, stops the ringing on both sides. If you miss a call, your phone shows "Missed call from Adam". Outgoing calls go through CallKit too, so both directions appear in the Phone app's Recents, and tapping a buttercup entry there calls back. The in-app incoming sheet from [3] is removed, because CallKit handles every incoming call (D24). Simulators still ring through Realtime, now shown through CallKit (D44).

## Summary
Adds a `CallKitController` (one `CXProvider` + `CXCallController`) and a `PushKitController` (`PKPushRegistry`), wires them to `CallStore` from [3], registers device tokens, handles `INStartCallIntent`, and posts local missed-call notifications. LiveKit's audio session is driven by CallKit's activation callbacks. No backend changes.

## Users
- **Primary**: Adam and his partner on their iPhones, mostly with the app closed.
- **Not for**: the Mac (later, build step 10).

## Scope
**MVP**
- PushKit registration → `devices` upsert (both `apns_token` and `voip_token`, `apns_env` from the build: Debug = `sandbox`, Release/TestFlight = `production`)
- Report every VoIP push to CallKit before the handler returns (ios-limits §3)
- Answer / decline / end / mute via CallKit actions ↔ [3] contract
- Outgoing calls via `CXStartCallAction` (D25)
- Recents call-back via `INStartCallIntent` (D25)
- Local missed-call notification and the callee's own 60 s ring limit (D43)
- Remove `IncomingSheet` (D24); simulator Realtime → CallKit (D44)
- Keychain accessibility after first unlock (D45)

**Out of scope**
- Sign in with Apple — separate later ticket
- Picture-in-Picture — build step 9
- Default calling app entitlement (ios-limits §2) — not requested

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [State Machine](#state-machine)
4. [Writers](#writers)
5. [End-to-End Flows](#end-to-end-flows)
6. [Blast Radius](#blast-radius)
7. [File Reference](#file-reference)
8. [Acceptance Criteria](#acceptance-criteria)
9. [Required Changes](#required-changes)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D9 | Accounts | None yet (no paid Apple account, LiveKit Cloud or APNs key). Each ticket opens with a manual setup checklist | Stated by user | User |
| D17 | Missed calls | Ring timeout in step 1 (caller calls `end-call` `missed` at 45 s; `pg_cron` sweeps `ringing` > 60 s); missed-call notification in step 5 (made local, revised by D43) | Notification arrives with the ringing work | User |
| D24 | Foreground ringing after step 5 | CallKit everywhere; the step-1 in-app sheet is removed | One code path | User |
| D25 | CallKit extras | Outgoing calls via `CXStartCallAction` (Recents, Bluetooth/CarPlay), call back from Recents (`INStartCallIntent`), answer on lock screen/Bluetooth | User picked all | User |
| D28 | Callee token delivery | `answer-call` returns the callee's LiveKit token; tokens never stored in `calls` or sent in pushes (step 5 push carries `call_id` + caller name only) | Partner can read `calls`; tokens are credentials | Claude — security |
| D36 | Device-only verification | Tickets needing camera/push ([4], [5], [6], [8] frontend) build + simulator-check what's possible; on-device ACs are a manual checklist, filed `partial` until the user runs it | Agent can't hold two iPhones | Claude — straightforward |
| D37 | Secrets | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` (later `APNS_*`) via `supabase secrets set`; local values in gitignored `supabase/functions/.env` | CLAUDE.md: no secrets committed | Claude — straightforward |
| D42 | Cancel push | `end-call` sends a VoIP push `{call_id, status}` for `cancelled` / `missed`; the app ends the matching CallKit call, or reports and immediately ends it if it never showed | PushKit requires every VoIP push to be reported to CallKit (ios-limits §3) | Claude — iOS rule |
| D43 | Missed-call notification | A local notification from the callee's app ("Missed call from {name}") when its ringing call ends as `missed` or `cancelled`; the callee's app also stops ringing after 60 s on its own; no server alert push | The ringing phone is already awake; covers the `pg_cron` sweep path with no extra server code — veto at review | Claude — straightforward |
| D44 | Simulator incoming calls after [8] | On simulator builds, the Realtime insert reports the call to CallKit locally, since simulators get no VoIP push | Keeps the two-simulator test from technical-spec §5 working | Claude — straightforward |
| D45 | Session readable while locked | Supabase session stored in the Keychain with `kSecAttrAccessibleAfterFirstUnlock` | Answering from the lock screen must call `answer-call` before unlock | Claude — iOS rule |

## Overview
CallKit becomes the front door for call actions, and `CallStore` stays the owner of the call itself. Every user action, whether from the system UI, Bluetooth or the in-app buttons, becomes a `CXAction`. The provider delegate turns it into the [3] contract call and the matching `CallStore.phase` change. The CallKit call UUID is `calls.id`, so pushes, Realtime and CallKit all refer to the same id.

Non-obvious design decisions:
1. **In-app buttons go through `CXCallController` too.** Hang up in the app requests a `CXEndCallAction`, not a direct `end-call`, so the system UI, Recents and Bluetooth state never fall out of sync.
2. **LiveKit doesn't configure the audio session itself.** Automatic audio session configuration is turned off. The session is set to `.playAndRecord` / `.voiceChat` before reporting, and LiveKit audio starts only in `provider(_:didActivate:)`. Otherwise audio is silent when answering from the lock screen.
3. **The push handler does the minimum.** It reports the call with `caller_name` and `hasVideo` from the payload, then fulfils the push completion. Signing in, Realtime and LiveKit only start after you answer.
4. **Cancel pushes always report something** (D42). For a known UUID, the app calls `reportCall(with:endedAt:reason: .unanswered)`. For an unknown one, it reports a new incoming call and then ends it immediately.

## State Machine
`CallStore.phase` from [3] is unchanged; CallKit maps onto it:

| CallKit event | Phase change | Contract call |
|---|---|---|
| ring push / sim Realtime insert → `reportNewIncomingCall` | → `incoming` | — |
| `CXAnswerCallAction` | `incoming` → `connecting` | `answer-call` |
| `CXEndCallAction` while `incoming` | → `idle` | `end-call declined` |
| `CXStartCallAction` | `idle` → `outgoing` | `start-call` |
| `CXEndCallAction` while `outgoing` | → `idle` | `end-call cancelled` |
| `CXEndCallAction` while `active` | → `idle` | `end-call ended` |
| `CXSetMutedCallAction` | — | LiveKit mic |
| cancel push / Realtime terminal / 60 s local limit | → `idle`, `reportCall(endedAt:)` | — |

Outgoing: `reportOutgoingCall(startedConnectingAt:)` when the row is `ringing`, and `connectedAt` when the callee joins the room.

## Writers
### 1. Register device → `devices` upsert
On every launch after sign-in, and whenever PushKit or APNs gives a new token. If the user has denied notifications, only the VoIP token is used. `apns_token` is `not null` in PRD [1], so the app always requests remote notification registration as well.

### 2. Missed-call notification → `UNUserNotificationCenter.add`
When an `incoming` call ends because of `missed` or `cancelled`, or the local 60 s limit: title "Missed call from {name}", tapping opens the Calling tab. Permission is requested once, the first time the app becomes `ready` ([2]).

### 3. Recents call-back → `INStartCallIntent`
The handle is the partner's user id (`CXHandle(type: .generic, value:)`). The intent opens the app and starts a call of the same kind. If the handle isn't your current partner, the call is ignored.

## End-to-End Flows
### Happy path: locked phone
```
A taps Video ─► CXStartCallAction ─► start-call ─► ring push
B locked ─► PushKit ─► reportNewIncomingCall (native screen)
B slides to answer ─► CXAnswerCallAction ─► session from Keychain ─► answer-call ─► didActivate ─► LiveKit joins
A Realtime answered ─► reportOutgoingCall connectedAt ─► in-call
```
### Edge case: caller cancels
```
A Hang up while ringing ─► CXEndCallAction ─► end-call cancelled ─► cancel push
B ─► reportCall endedAt .unanswered ─► "Missed call from Adam"
```
### Edge case: B's phone offline
```
No push arrives ─► A times out at 45 s ─► missed ─► B gets nothing until the app opens; history shows Missed
```

## Blast Radius
| Change | What breaks |
|---|---|
| Removing `IncomingSheet` | Any code path that still shows it (search for it) |
| Push handler | Not reporting a push gets the app killed and, after repeats, VoIP pushes stop (ios-limits §3) |
| Keychain accessibility | Lock-screen answer can't authenticate |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Calling/CallKitController.swift` | **new** provider + controller + delegate |
| `Buttercup/Calling/PushKitController.swift` | **new** registry + payload parsing |
| `ButtercupKit/Sources/ButtercupKit/CallStore.swift` | actions routed via CallKit (from [3]) |
| `ButtercupKit/Sources/ButtercupKit/Supabase.swift` | Keychain accessibility (from [2]) |
| `Buttercup/Calling/IncomingSheet.swift` | **deleted** (D24) |
| `Buttercup/ButtercupApp.swift` | `INStartCallIntent` / `onContinueUserActivity` |
| `Buttercup.xcodeproj` | Push Notifications capability, background modes `voip` + `audio`, `NSUserActivityTypes` `INStartCallIntent` |

---

## Acceptance Criteria
<!-- Device ACs are a manual checklist on both iPhones (D36). -->
- [ ] AC1 (device): With B's app force-quit and the phone locked, A's Video call shows the native incoming screen on B with A's name.
- [ ] AC2 (device): Answering from the lock screen connects with audio both ways, and unlocking shows the buttercup in-call screen.
- [ ] AC3 (device): Answering and hanging up with AirPods works.
- [ ] AC4 (device): Decline on B → A returns to idle with "Declined"; A cancelling → B stops ringing within about 2 s and shows "Missed call from Adam".
- [ ] AC5 (device): No answer → both sides stop at about 45 s; B shows the missed notification.
- [ ] AC6 (device): With B's app open in the foreground, the CallKit UI shows and no in-app sheet appears.
- [ ] AC7 (device): Both directions appear in Phone → Recents as buttercup calls, and tapping one starts a buttercup call to the partner.
- [ ] AC8 (device): Mute from the CallKit UI and the in-app mute stay in sync.
- [ ] AC9: Two simulators still ring each other (through CallKit, via Realtime) and pass [3] Frontend AC2–AC5.
- [ ] AC10: `devices` has a row for each phone with `voip_token` and the right `apns_env`.
- [ ] AC11: `xcodebuild` builds for the simulator and a generic iOS device.

## Required Changes
- **CallKit / PushKit**: controllers per [Overview](#overview) and the [State Machine](#state-machine) table.
- **Audio**: LiveKit's manual audio session plus CallKit activation (Overview §2).
- **Notifications**: permission and a local missed-call notification ([Writers §2](#writers)).
- **Intents**: Recents call-back ([Writers §3](#writers)).
- **Cleanup**: delete `IncomingSheet`.
- **Project**: capabilities and background modes.

## Features Catalog
- **Extends**: #1 Calls
- **Closes known gaps**: none

## Open Questions
- [ ] Does `supabase-swift` let you set the Keychain accessibility, or does it need a custom `AuthLocalStorage`? Check during implementation (D45).

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Silent audio when answering locked | High (common CallKit bug) | No audio | Overview §2; AC2 |
| Tokens differ between Debug and TestFlight builds | Med | Pushes go to the wrong APNs host | `apns_env` from the build configuration; AC10 |

---
*Status: READY — ticket [8] frontend*
