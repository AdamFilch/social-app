# [5]: Face stickers — emoji, text and images

**Depends on:** [4]: ARKit camera merged.

This ticket adds the first face effect. During a call with your front camera on, the mid-size self tile gets an **Add sticker** button. Tapping it switches to the big self view (D41) and opens a tray with three tabs: **Emoji**, **Text** and **Images**. You drag a sticker from the tray onto your face. Where you let go, it pins to that spot (forehead, cheek, nose) and moves, tilts and scales with your head. Once it's placed you can drag it to a new spot, pinch to resize and twist to rotate. Tapping a sticker selects it and shows a trash button at the bottom middle of the screen. Stickers are drawn into your outgoing video, so your partner sees them with no extra code on their side. If your face leaves the frame, stickers freeze where it was last seen (D20). There can be at most 10 at once. Turning the camera off keeps them for when it comes back on, and they are cleared when the call ends.

## Summary
Adds a sticker model, an anchor that maps a point on the face to the screen every frame, a Core Image compositor that sits between the ARKit tracker ([4]) and the LiveKit publish step, the tray, and sticker gestures on the big self view. Bundles PNGs from `assets/stickers`. No backend changes.

## Users
- **Primary**: Adam and his partner during calls on their iPhone 11s.
- **Not for**: the back camera (no face tracking, D33) or the simulator (no face, though the tray and compositor still run on the clip).

## Scope
**MVP**
- Tray (sheet with detents): Emoji grid (system emoji keyboard input), Text (D21: type + ~6 colours), Images (every PNG in `assets/stickers`, D18)
- Add sticker on the mid tile → big self view + tray (D41)
- Drop-to-pin on the face; drag / pinch / twist (D19); tap → trash at bottom middle
- Baked into outgoing frames; preview shows the composited buffer ([4] Overview §1)
- Freeze when the face is lost (D20); cap 10 (D23); thermal `.critical` hides stickers (D35)
- `.impact(weight: .light)` haptic on drop (technical-spec Haptics)

**Out of scope**
- Drawing pad — [6]
- Glasses, hats and face paint — build steps 6–7
- Partner's stickers on you — build step 8
- Saving stickers between calls — the spec clears them (D34)

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [Data Model](#data-model)
4. [Behaviour](#behaviour)
5. [End-to-End Flows](#end-to-end-flows)
6. [Blast Radius](#blast-radius)
7. [File Reference](#file-reference)
8. [Acceptance Criteria](#acceptance-criteria)
9. [Required Changes](#required-changes)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D7 | Visual design | Plain SwiftUI for all these tickets; designer agent spec → separate restyle ticket later | User will run the designer on the call screens | User |
| D18 | Image stickers | Bundle every PNG in `assets/stickers` at build time; developer adds 2–3 placeholders | Assets folder is empty today | User |
| D19 | Sticker gestures | Drag to move (re-pins), pinch to resize, twist to rotate; tap → trash (spec) | User picked all | User |
| D20 | Face lost | Stickers freeze at the last face position until tracking returns | User choice | User |
| D21 | Text stickers | Type text + pick one of ~6 colours; rounded bold with ink outline | Small sheet | User |
| D23 | Sticker cap | Max 10 on the face at once; revisit after step 4 | Predictable load on iPhone 11 | User |
| D33 | Back camera | Front = ARKit (`ARFaceTrackingConfiguration`, 30 fps, 720p, light estimation off); back = LiveKit's camera capturer with no stickers | ARKit face tracking is front-only | Claude — straightforward |
| D34 | Sticker lifetime | Kept in memory while camera is off; cleared at call end (spec) | Spec | Claude — straightforward |
| D35 | Heat fallback | `ProcessInfo.thermalState == .critical` hides stickers, restored below it (spec) | Spec | Claude — straightforward |
| D36 | Device-only verification | Tickets needing camera/push ([4], [5], [6], [8] frontend) build + simulator-check what's possible; on-device ACs are a manual checklist, filed `partial` until the user runs it | Agent can't hold two iPhones | Claude — straightforward |
| D39 | Self tile sizes (FaceTime-style) | Small corner tile → tap → mid tile with buttons → expand (↗) button → big self view with the partner as the small tile; tap the partner's small tile to swap back; tapping elsewhere while mid returns to small | User described FaceTime's behaviour | User |
| D40 | Mid tile buttons | Flip camera (moved off the main bar) and Add sticker ([5]); main bar keeps mute, camera on/off, audio route, hang up | User picked | User |
| D41 | Add sticker from the mid tile | Switches to the big self view and opens the tray; stickers are only placed and edited in the big self view | Inferred from "edit my stickers here" (big view) — veto at review | Claude — inferred |

## Overview
A `StickerLayer` holds up to 10 `PlacedSticker`s in memory on `CallStore`. On every ARKit frame the compositor projects each sticker's face anchor to pixel space, builds a `CIImage` transform (position, the head's roll plus the sticker's own rotation, and scale from face distance times the sticker's own scale), composites them over `capturedImage`, and renders into a BGRA `CVPixelBufferPool` buffer. That buffer goes to both `BufferCapturer` and the preview.

Non-obvious design decisions:
1. **Anchor = nearest face-mesh vertex plus an offset.** On drop, every `ARFaceGeometry` vertex is projected to the screen, and the nearest one's index is stored with the remaining offset in face-local units. Each frame re-projects that vertex. Stickers follow the face shape (a cheek sticker stays on the cheek when you turn) without any 3D rendering.
2. **The compositor is the single place stickers become pixels.** [6] drawings and later hats feed it a `CIImage`, so they never touch tracking or publishing.
3. **Gestures act on the big self view only** (D41). Touch points map to buffer pixels through the same mirrored transform the preview uses, so a drop lands where your finger is.
4. **Freezing reuses the last projection.** When `ARFaceAnchor.isTracked` is false, the compositor keeps drawing the last screen transforms rather than hiding them (D20).

## Data Model
In memory only; nothing is stored or synced.

| Type | Field | Meaning |
|---|---|---|
| `Sticker` | `id: UUID`, `kind: .emoji(String) / .text(String, colour) / .image(name)` | what was picked |
| `PlacedSticker` | `sticker`, `vertexIndex: Int`, `offset: SIMD2<Float>`, `scale: Float`, `rotation: Float`, `image: CIImage` (pre-rendered once) | its pin and transform |
| `StickerLayer` | `items: [PlacedSticker]` (≤ 10), `selected: UUID?`, `lastTransforms` | per call; cleared on `idle` |

## Behaviour
| Moment | What you see |
|---|---|
| Mid tile, camera on, front | Flip, ↗, **Add sticker** |
| Back camera or camera off | Add sticker hidden |
| Tray open | Big self view; tray sheet at medium detent; dragging out of the tray dismisses it to its small detent |
| Drop on face | Pins, light haptic |
| Drop off the face (no anchor) | Snaps to the nearest face point |
| 10 placed | Tray items disabled; caption "That's 10. Remove one to add more." |
| Tap a sticker | Selected (outline in preview only, not in the video), trash at bottom middle; tap elsewhere to deselect |
| Text tab | Text field + 6 colour swatches (Ink, Accent, NotePaper Pink/Blue/Green/Lilac), "Add" → sticker in drag mode |
| Images tab empty | "No image stickers yet." |
| Thermal `.critical` | Stickers stop drawing; returns below `.critical` |

## End-to-End Flows
### Happy path
```
Mid tile ─ Add sticker ─► big self view + tray
Drag 🌸 onto left cheek ─► nearest vertex stored ─► light haptic
Each ARFrame ─► project vertex ─► CI composite ─► BufferCapturer ─► partner sees 🌸 on cheek
Turn head ─► 🌸 follows; pinch ─► bigger; twist ─► rotated
Tap 🌸 ─► trash ─► removed
End call ─► layer cleared
```
### Edge case: face leaves frame
```
isTracked = false ─► last transforms reused ─► stickers frozen ─► face back ─► follow again
```

## Blast Radius
| Change | What breaks |
|---|---|
| Compositor input (`CIImage` + anchor) | [6] drawings, later hats and face paint |
| `PlacedSticker` anchor scheme | Every sticker kind; partner stickers (step 8) will send these fields |
| Mid tile buttons | [3] D39–D40 layout |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Effects/Sticker.swift` | **new** types above |
| `Buttercup/Effects/StickerCompositor.swift` | **new** projection + Core Image render |
| `Buttercup/Effects/StickerTray.swift` | **new** tray sheet |
| `Buttercup/Effects/StickerGestures.swift` | **new** drag / pinch / rotate / tap on big self view |
| `Buttercup/Calling/InCallView.swift` | Add sticker on mid tile, trash button |
| `Buttercup/Calling/FaceTracker.swift` | `onFrame` routed through the compositor (from [4]) |
| `assets/stickers/*.png` | 2–3 placeholder PNGs if empty (D18), added to the app bundle as a folder reference |

---

## Acceptance Criteria
<!-- Device ACs are a manual checklist (D36). -->
- [ ] AC1: Simulator: Add sticker opens the big self view and the tray; an emoji dropped on the clip shows in the browser participant's view (the compositor runs; placement is approximate with no face).
- [ ] AC2 (device): A dropped sticker stays on the same face spot while you turn and tilt your head, as seen on the partner's phone.
- [ ] AC3 (device): Drag moves it to a new spot; pinch resizes; twist rotates; tap → trash removes it.
- [ ] AC4 (device): Text sticker with a chosen colour appears with an ink outline.
- [ ] AC5: Image tab lists every PNG in `assets/stickers`.
- [ ] AC6: The 11th sticker can't be added and the caption shows.
- [ ] AC7 (device): Covering the camera freezes stickers; uncovering resumes tracking.
- [ ] AC8: Camera off then on keeps the stickers; ending the call and starting a new one starts with none.
- [ ] AC9: Back camera hides Add sticker and draws no stickers.
- [ ] AC10: `xcodebuild` builds for the simulator and a generic iOS device.

## Required Changes
- **Effects**: sticker types, compositor, tray, gestures (see [Overview](#overview)).
- **In-call**: Add sticker on the mid tile and the trash button.
- **Assets**: bundle `assets/stickers`; add placeholders if empty.

## Features Catalog
- **Extends**: #1 Calls
- **Closes known gaps**: none

## Open Questions
- [ ] Should a text sticker be editable after placing it? Not decided; for now remove it and add it again.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Projecting 1,220 vertices on every drop is slow | Low | Lag on drop only | It runs once per drop, not per frame |
| Core Image render > 33 ms on iPhone 11 | Med | Frame drops | Pre-render sticker images once; one `CIContext` (Metal); measured in [7] |

---
*Status: READY — ticket [5]*
