# [28]: Face sticker tracking

**Depends on:** [5]: Face stickers (PR #20, branch `prd-5-face-stickers`). Build on that branch; it is not merged yet. [29]: In-call restyle builds on this ticket.

This ticket changes how a placed sticker follows your face, after Adam tried [5] on two phones. A sticker now lives in 3D with your head. If you drop it on your face, it sticks to that spot on the skin and turns with it: a cheek sticker turns with the cheek. If you drop it off your face (above your head, beside your ear), it sits on an invisible plane fixed to your head, so it floats there and follows as you turn, tilt and nod. Stickers are drawn in perspective. Look left and they turn left and get narrower. Tilt your head and they tilt. Turn far enough that one faces away from the camera, and it is hidden as if behind your head. When the face is lost (out of frame, covered, or not found), every sticker disappears on that frame and comes back when the face does. Nothing freezes and nothing sticks at the screen edge. While no face is tracked you can't add stickers. Your own preview is a true mirror, but stickers in it still read the right way round. Your partner sees the normal, unmirrored video with readable stickers.

## Summary
Replaces [5]'s 2D anchor (nearest mesh vertex plus a screen offset, snapped back within 3 cm) with a 3D anchor: a point on the face surface, or a point on a head-fixed plane. Each sticker becomes a quad in face space, projected every frame and drawn with a perspective warp. Removes the freeze from D20, so a lost face hides the stickers instead. Mirrors the self-preview and renders it as a second composite so the stickers in it aren't flipped. Blocks adding stickers while no face is tracked. Unchanged: the tray, the gestures you use (drag, pinch, twist, tap → trash), the 10 cap, thermal hiding, camera-off keeping, and the clear-on-call-end rule. There are no backend changes.

## Users
- **Primary**: Adam and his partner on iPhone 11s during a video call with the front camera on.
- **Not for**: the back camera (D33) or the simulator. The simulator has no face, so stickers there never show (see AC7).

## Scope
**MVP**
- 3D anchor: surface (on the face) or head plane (off it); no snap window (D43, D49, D50)
- Perspective drawing that follows roll, yaw and pitch; hidden when facing away (D45, D51)
- Lost face: instant hide and show (D44)
- Mirrored self-preview with readable stickers (D46, D48, D52)
- No face tracked: adding is blocked (D47)

**Out of scope**
- Call screen and tray restyle — [29]
- Occlusion by the head for stickers that face the camera but sit "behind" the head in depth — needs depth rendering; facing-away hiding covers the common case
- Drawing pad, hats, partner stickers — [6] and later steps

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
| D19 | Sticker gestures (from [5]) | Drag to move (re-pins), pinch to resize, twist to rotate; tap → trash | Unchanged | User |
| D23 | Sticker cap (from [5]) | Max 10 | Unchanged | User |
| D33 | Back camera (from [5]) | No stickers on the back camera | ARKit face tracking is front-only | Claude — straightforward |
| D35 | Heat fallback (from [5]) | `.critical` hides stickers | Unchanged | Claude — straightforward |
| D36 | Device-only verification (from [5]) | Device ACs are a manual checklist; ticket filed `partial` until the user runs them | Agent can't hold two iPhones | Claude — straightforward |
| D42 | Ticket split | Two stacked tickets: [28] tracking fixes on the `prd-5-face-stickers` branch, then [29] the restyle on top of [28] | Small, reviewable PRs | User |
| D43 | 3D anchor | On the face: stick to that skin spot and turn with it. Off the face: a point on a plane fixed to the head, anywhere, with no distance limit | "Put the emoji anywhere on the plane and the plane still follows my face" | User |
| D44 | Face lost (replaces [5] D20 freeze) | Hide every sticker on the first frame without a tracked face; show them on the first frame with one. No grace period, no fade | User chose instant | User |
| D45 | Facing away | A sticker whose front faces away from the camera isn't drawn | As if hidden behind the head | User |
| D46 | Readable stickers in the mirror | The self-preview is a separate composite: mirrored video, with stickers drawn so they read the right way round. The outgoing video is unchanged | User wants text readable on their own screen; accepted the cost of a second render | User |
| D47 | Adding with no face | While no face is tracked, tray cells, Add and the type-an-emoji field are disabled with "Show your face to add stickers"; a drop adds nothing | User choice | User |
| D48 | Mirror direction | Only your own preview is mirrored; your partner sees the unmirrored video | FaceTime and camera-app convention | Claude — straightforward |
| D49 | Head plane | The plane through the nose tip, parallel to the face anchor's local XY plane (normal = face +Z) | Stickers above the head or at the side sit at face depth and turn with the head | Claude — straightforward |
| D50 | "On the face" | The drop point falls inside a projected `ARFaceGeometry` triangle that faces the camera. Anchor = triangle index + barycentric weights; orientation = that triangle's normal | More exact than nearest-vertex; a hit test also decides surface vs plane | Claude — straightforward |
| D51 | Perspective drawing | Project the sticker quad's four corners and warp the image with `CIPerspectiveTransform` inside the existing Core Image compositor. No SceneKit or RealityKit | Keeps the single compositor from [5] Overview §2 | Claude — straightforward |
| D52 | Which stickers are un-flipped | Your own preview shows every kind the way it looked in the tray. In the outgoing video, text stays readable and emoji and image stickers are mirrored, like a real object on your face | Revised on device: the partner saw emoji and images the wrong way round | User |

## Overview
`PlacedSticker` holds an `Anchor`: either `.surface(triangle, barycentric)` or `.plane(point)`, both in face-local coordinates. It also holds its scale (meters) and its own rotation about the sticker's normal. On every ARKit frame, `StickerCompositor` checks whether a face is tracked. If not, it draws nothing and reports `faceTracked = false`. If so, it builds each sticker's quad in face space, sends it to world space with `ARFaceAnchor.transform`, and projects the four corners with `ARCamera.projectPoint`. It skips quads that face away from the camera and warps each pre-rendered image onto its projected corners. It renders twice: the outgoing buffer (normal) for `BufferCapturer`, and the preview buffer (mirrored video, stickers un-flipped) for your own tile.

Questions the data answers:
1. **Draw this sticker now?** → face tracked ∧ thermal < `.critical` ∧ dot(quad normal in world, direction to camera) > 0
2. **Where are its corners on screen?** → anchor point + basis (normal, head up) × half-size → `anchor.transform` → `projectPoint` → display transform
3. **Can I add a sticker?** → `StickerLayer.faceTracked` ∧ !full

Non-obvious design decisions:
1. **Surface vs plane is decided per drop by a hit test** (D50). Dragging a placed sticker re-runs it, so a sticker can move from cheek to above the head and change anchor kind.
2. **The quad's up direction is the head's up** (face +Y, made orthogonal to the normal), then rotated by the sticker's own twist. A sticker on a slanted cheek still stands upright relative to the head.
3. **Size is in meters** (`0.06 m × scale` on the longest side), so closer and farther fall out of the projection. No separate distance scaling.
4. **Hiding replaces freezing** (D44). `projection` is no longer cached between frames. That cache is what kept stickers frozen and stuck at the screen edge when ARKit stopped tracking a face leaving the frame.
5. **Preview and outgoing come from one placement pass** (D46). The quads are computed once per frame. The preview pass mirrors the video and corners horizontally, and draws each image pre-flipped so it reads correctly. Gestures map touches to display space with the same mirror, so a drop still lands under the finger.

## Data Model
In memory only; nothing is stored or synced.

| Type | Field | Meaning |
|---|---|---|
| `Anchor` **new** | `.surface(triangle: Int, weights: SIMD3<Float>)` / `.plane(SIMD3<Float>)` | Face-local pin (D43, D49, D50) |
| `PlacedSticker` (changed) | `anchor: Anchor` replaces `vertexIndex` and `offset`; `scale: Float` (× 0.06 m), `rotation: Float` (about the normal), `image`, `mirroredImage` **new** | Its pin and transform |
| `StickerLayer` (changed) | `faceTracked: Bool` **new**, published on the main actor only when it changes | Gates adding (D47) |
| `StickerCompositor.Placement` (changed) | `corners: [CGPoint]` (4, display space) replaces center/size/angle; `nil` when hidden | Hit test, selection outline |

## Behaviour
| Moment | What you see |
|---|---|
| Drop on your face | Sticks to that skin spot, light haptic; turns with the cheek, nose or forehead |
| Drop off your face (above the head, beside it, anywhere on screen) | Floats there on the head plane and follows your head; no snapping |
| Tilt your head | Stickers tilt with it |
| Turn or nod | Stickers turn and foreshorten; past 90° from the camera they are hidden |
| Lean in / back | Stickers grow / shrink with distance |
| Face leaves the frame, is covered, or isn't found | All stickers vanish on that frame and return with the face. None stay at the screen edge |
| Face partly off-screen but tracked | Stickers move off-screen with it |
| No face tracked, tray open | Cells, emoji field and Add disabled at 40%; hint "Show your face to add stickers" in place of the cap caption. A drop adds nothing |
| Your own preview | Mirrored like a mirror; text and images read the right way round |
| Partner's view of you | Unmirrored; text and images read the right way round |
| Drag / pinch / twist / tap | As [5] D19; drag re-anchors (surface or plane) on each move; twist rotates about the sticker's normal |
| Gestures while no face is tracked | Nothing is hit (no sticker is drawn) |

## End-to-End Flows
### Happy path: sticker above the head
```
Drag 👑 from the tray to 3 cm above your hairline
  └─► StickerGestures drop → map touch to display space (mirror-aware)
        └─► StickerCompositor.pin(at:)
              ├─ hit-test projected front-facing triangles → miss
              ├─ ray from camera through touch ∩ head plane (D49) → face-local point
              └─► PlacedSticker(anchor: .plane(p)) → light haptic
Each ARFrame (face tracked)
  └─► quad = p ± right·w ± up·h → world → projectPoint → corners
        ├─ facing camera? yes → CIPerspectiveTransform → composite
        ├─► outgoing buffer → BufferCapturer → partner sees 👑 above your head
        └─► preview buffer (mirrored video, un-flipped 👑) → your tile
Turn head left → 👑 turns left and narrows, stays above the head
```

### Edge case: face leaves the screen
```
Face moves toward the left edge, still tracked → corners move off-screen with it
ARKit stops tracking → isTracked false (or no anchor)
  └─► draw nothing, faceTracked = false → tray (if open) disables adding
Face returns → stickers drawn on the first tracked frame at their anchors
```

## Blast Radius
| Change | What breaks |
|---|---|
| `PlacedSticker` anchor scheme | [29] selection outline and hit test; [6] drawings; partner stickers (step 8) will send these fields |
| `Placement` becomes 4 corners | `StickerGestures` selection outline and `hit(_:)`; [29] §4.10 outline must follow the projected quad |
| Preview is its own buffer | `InCallView` `Feed` for your own video; [4]'s preview path |
| Second render per frame | iPhone 11 heat budget ([7] heat test) |

## File Reference
| File | Role |
|---|---|
| [Buttercup/Effects/Sticker.swift](Buttercup/Effects/Sticker.swift) | `Anchor` **new**, `PlacedSticker` fields, `StickerLayer.faceTracked`, mirrored image |
| [Buttercup/Effects/StickerCompositor.swift](Buttercup/Effects/StickerCompositor.swift) | Hit test, plane intersection, quad projection, back-face cull, perspective warp, two outputs, no cached projection |
| [Buttercup/Effects/StickerGestures.swift](Buttercup/Effects/StickerGestures.swift) | Mirror-aware mapping, polygon hit and outline, drop rejected with no face |
| [Buttercup/Effects/StickerTray.swift](Buttercup/Effects/StickerTray.swift) | No-face disabled state and hint |
| [Buttercup/Calling/InCallView.swift](Buttercup/Calling/InCallView.swift) | Your own tile shows the preview buffer, mirrored |
| [Buttercup/Calling/FaceTracker.swift](Buttercup/Calling/FaceTracker.swift) | Passes `ARCamera` with each frame if the compositor needs it there |

---

## Acceptance Criteria
<!-- Device ACs are a manual checklist (D36). -->
- [ ] AC1 (device): Covering the camera or leaving the frame hides every sticker on that frame, and they reappear when the face is back. A face leaving past the screen edge takes its stickers off-screen; none stay stuck at the edge.
- [ ] AC2 (device): Your own preview is mirrored; the partner's view is not. Text and image stickers read the right way round on both screens.
- [ ] AC3 (device): Stickers tilt with head roll, and turn and foreshorten with yaw and pitch. A cheek sticker is hidden when you turn far enough that it faces away.
- [ ] AC4 (device): A sticker dropped above the head or beside it stays there relative to the head as you move; one dropped on the cheek stays on the cheek. No drop snaps back to the face.
- [ ] AC5 (device): With no face tracked, tray cells, Add and the emoji field are disabled with "Show your face to add stickers", and a drop adds nothing.
- [ ] AC6 (device): The compositor logs its per-frame time (both renders) with `Logger`; on an iPhone 11 it stays under 33 ms in a call with 10 stickers.
- [x] AC7: Simulator (no face): the tray shows the no-face disabled state, and the call still connects with your own preview showing the mirrored clip.
- [x] AC8: `xcodebuild` builds for the simulator and for `generic/platform=iOS`.

## Required Changes
- **Anchor and placement**: `Anchor` type, surface hit test and plane intersection in `pin(at:)`, and removal of the 3 cm snap (see [Overview](#overview), D43, D49, D50).
- **Drawing**: per-frame quad projection, back-face cull, `CIPerspectiveTransform`; no cached `projection`, so no face means nothing is drawn (D44, D45, D51).
- **Preview**: second composite with mirrored video and pre-flipped images; your own tile shows it unmirrored by the view (D46, D48, D52). First find out why the current `Feed(mirror: calls.front)` didn't mirror on device, and note it in the PR.
- **Gestures**: mapping matches the preview's mirror; hit test and selection outline use the 4 corners.
- **No face**: `faceTracked` drives the tray's disabled state and hint (D47).
- **Logging**: frame time for AC6.
- **Don't commit** the local `Buttercup.xcodeproj` edits on this machine (LAN `SUPABASE_URL`, `DEVELOPMENT_TEAM`).

## Features Catalog
- **Extends**: #2 Calls
- **Closes known gaps**: TBD — read the Calls entry in `.claude/context/features.md` on `main` when filing

## Open Questions
- [ ] Should a sticker at face depth but behind the head (for example far beside the ear while you turn) be hidden by the head? Not in this ticket; revisit if it looks wrong on device.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Two Core Image renders exceed 33 ms on iPhone 11 | Med | Frame drops, heat | One placement pass; reuse the CIContext and pools; AC6 measures; [7] heat test |
| Hit-testing ~2,300 triangles on each drag move lags | Low | Laggy drag | Run on drop and drag only, never per frame; early-out by bounding box |
| Raw ARKit frames are already mirrored or rotated differently than assumed | Med | Preview or partner flipped wrongly | Verify both screens on device (AC2) before tuning the rest |

---
*Status: PARTIAL — PR #21*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ⚠️ unverified | Device only (D36). In code: `render` sets `projection = nil` on any frame without a tracked `ARFaceAnchor`, so nothing is placed or drawn; no projection is kept between frames. |
| AC2 | ⚠️ unverified | Device only for stickers. On two simulators the self tile showed the test clip mirrored ("test clip" read backwards) and the partner saw it unmirrored. |
| AC3 | ⚠️ unverified | Device only (D36). |
| AC4 | ⚠️ unverified | Device only (D36). |
| AC5 | ⚠️ unverified | Device only (D36). The same disabled state was seen on the simulator (AC7). |
| AC6 | ⚠️ unverified | Logging is in: `StickerCompositor` logs "Frame time avg X ms, max Y ms, N stickers" every 30 frames (category `StickerCompositor`). The simulator showed avg 3.7–4.7 ms with the clip and 0 stickers; the iPhone 11 number with 10 stickers needs a device. |
| AC7 | ✅ done | iPhone 16e and iPhone Air simulators in a local Video call: the self tile showed the mirrored clip; Add sticker opened the tray with "Show your face to add stickers", emoji cells, the emoji field and Add (with "Hi" typed) at 40%; tapping the 🌸 and Add placed nothing. |
| AC8 | ✅ done | `xcodebuild … -destination 'platform=iOS Simulator,…' build` and `… -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` both succeed with no warnings in app code. |

### Needs attention
Run on two iPhones in a Video call, front camera on, then tick the ACs:
1. AC5 first: with the tray open, cover the camera. Cells, the emoji field and Add go dim with "Show your face to add stickers"; dragging a cell onto the view adds nothing. Uncover: they come back.
2. AC4: drag 👑 from the tray to about 3 cm above your hairline and 🌸 onto your left cheek. Move and turn your head: the crown stays above your head, the flower stays on the cheek, and neither snaps back.
3. AC3: tilt your head (stickers tilt), turn left and right and nod (they turn and narrow). Turn until the cheek faces away: the flower disappears and returns as you turn back.
4. AC2: add the text "hi". Your own screen is a mirror and "hi" reads left to right; the partner's screen is unmirrored and "hi" also reads left to right. Check an image sticker the same way.
5. AC1: cover the camera: all stickers vanish on that frame and return when you uncover it. Slowly move your face off the left edge: stickers slide off-screen with it and none stay stuck at the edge.
6. AC6: with 10 stickers placed, watch Console (subsystem `com.adamfilchoir.buttercup`, category `StickerCompositor`) for a minute. Avg and max should stay under 33 ms.
7. Also check: a twist turns the sticker the same way your fingers turn (in the mirrored view), and the dashed selection outline follows the tilted, foreshortened sticker.
