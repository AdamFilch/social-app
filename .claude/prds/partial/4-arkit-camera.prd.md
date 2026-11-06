# [4]: ARKit camera into the call

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
| D7 | Visual design | Plain SwiftUI for all these tickets; designer agent spec → separate restyle ticket later | User will run the designer on the call screens | User |
| D13 | In-call controls | Mute, camera on/off, flip front/back, audio route picker (`AVRoutePickerView`); flip lives on the self tile (revised by D40) | User picked all four | User |
| D32 | Simulator video | `#if targetEnvironment(simulator)` feeds a bundled test clip through LiveKit `BufferCapturer` (technical-spec §5) | Simulator has no camera | Claude — straightforward |
| D33 | Back camera | Front = ARKit (`ARFaceTrackingConfiguration`, 30 fps, 720p, light estimation off); back = LiveKit's camera capturer with no stickers | ARKit face tracking is front-only | Claude — straightforward |
| D36 | Device-only verification | Tickets needing camera/push ([4], [5], [6], [8] frontend) build + simulator-check what's possible; on-device ACs are a manual checklist, filed `partial` until the user runs it | Agent can't hold two iPhones | Claude — straightforward |

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
- [x] AC6: `xcodebuild` builds for both simulator and a generic iOS device.

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
*Status: PARTIAL — PR #6*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ⚠️ unverified | Simulator build succeeds and the clip path is unchanged (`TestClipCapturer` still feeds a `BufferCapturer` while `front` stays true on the simulator), but no call was run: the agent could not tap in the Simulator (macOS denied osascript assistive access, and no simulator-control tool was connected). |
| AC2 | ⚠️ unverified | Device only (D36). |
| AC3 | ⚠️ unverified | Device only (D36). `FaceTracker` logs `AR session running WxH @ N fps, light estimation off`. |
| AC4 | ⚠️ unverified | Device only (D36). |
| AC5 | ⚠️ unverified | Device only (D36). `FaceTracker` logs `AR session paused`. |
| AC6 | ✅ done | `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 17' build` and `… -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` both succeed. |

### Needs attention
- AC1: sign in as `adam@example.com` on a simulator, start a Video call, and check the self tile shows the clip and the partner side (an `lk` client or meet.livekit.io) receives it.
- AC2–AC5: run the manual device checklist in the PR on two iPhones. Set a signing team first (a Personal Team works).
