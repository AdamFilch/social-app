# [6]: Drawing-pad stickers

**Depends on:** [5]: Face stickers merged.

This ticket adds a fourth tab to the sticker tray: **Draw**. It opens a still drawing pad: a PencilKit canvas with Apple's tool picker (pens, marker, eraser, colours and undo), on a checkerboard so it's clear the background is transparent. When you tap **Done**, only your strokes are cropped and turned into an image, and that image becomes a sticker in drag mode, exactly like an emoji from [5]. From there it pins, moves, resizes, rotates and is removed the same way. Drawing directly on your moving face was dropped in the spec, because it is hard to aim and hard to make sit right.

## Summary
Adds the Draw tab and a pad sheet that outputs a cropped, transparent image to [5]'s sticker pipeline as a new `Sticker.kind` `.drawing(CIImage)`. Nothing in tracking, compositing or publishing changes.

## Users
- **Primary**: Adam and his partner during a call.
- **Not for**: outside calls (the pad is not saved).

## Scope
**MVP**
- Draw tab → full-height sheet with `PKCanvasView` + `PKToolPicker` (D22)
- Done: `drawing.image(from: drawing.bounds, scale: 2)` → `CIImage` → `.drawing` sticker in drag mode
- Done disabled while the canvas is empty; Cancel discards
- Counts toward the 10-sticker cap (D23)

**Out of scope**
- Saving drawings for later calls (D34)
- Drawing live on the face (spec)

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [End-to-End Flows](#end-to-end-flows)
3. [Blast Radius](#blast-radius)
4. [File Reference](#file-reference)
5. [Acceptance Criteria](#acceptance-criteria)
6. [Required Changes](#required-changes)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D7 | Visual design | Plain SwiftUI for all these tickets; designer agent spec → separate restyle ticket later | User will run the designer on the call screens | User |
| D22 | Drawing pad | PencilKit canvas + `PKToolPicker`, transparent background → PNG sticker | Least code | User |
| D23 | Sticker cap | Max 10 on the face at once; revisit after step 4 | Predictable load on iPhone 11 | User |
| D34 | Sticker lifetime | Kept in memory while camera is off; cleared at call end (spec) | Spec | Claude — straightforward |
| D36 | Device-only verification | Tickets needing camera/push ([4], [5], [6], [8] frontend) build + simulator-check what's possible; on-device ACs are a manual checklist, filed `partial` until the user runs it | Agent can't hold two iPhones | Claude — straightforward |

## End-to-End Flows
### Happy path
```
Tray ─ Draw ─► pad sheet (tool picker visible)
Draw a heart ─ Done ─► crop to stroke bounds ─► .drawing sticker in drag mode
Drag onto forehead ─► pinned (same as [5]) ─► partner sees it baked in
```
### Edge case: empty pad
```
Done stays disabled ─ Cancel ─► back to tray, nothing added
```

## Blast Radius
| Change | What breaks |
|---|---|
| `Sticker.kind` enum | [5] tray and compositor switch statements |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Effects/DrawingPad.swift` | **new** PencilKit sheet |
| `Buttercup/Effects/Sticker.swift` | `.drawing` case (from [5]) |
| `Buttercup/Effects/StickerTray.swift` | Draw tab (from [5]) |

---

## Acceptance Criteria
- [x] AC1: Simulator: Draw opens the pad with the tool picker; Done is disabled until a stroke exists.
- [ ] AC2: Simulator: after Done, the sticker in drag mode is cropped to the strokes with a transparent background (no white box).
- [ ] AC3 (device): The drawing pins to the face and follows head movement on the partner's phone.
- [ ] AC4: With 10 stickers placed, Draw is disabled like the other tabs.
- [x] AC5: `xcodebuild` builds for the simulator and a generic iOS device.

## Required Changes
- **Pad**: `DrawingPad` sheet (D22).
- **Sticker**: `.drawing` kind rendered once to `CIImage`.

## Features Catalog
- **Extends**: #1 Calls
- **Closes known gaps**: none

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Tool picker hidden behind the sheet on iPhone | Med | No tools | Show the picker as the canvas becomes first responder; full-height detent |

---
**Update:** the pad now opens inside the effects panel as in the in-call mockup (spec R3 and §4.9 layout), keeping Apple's `PKToolPicker` for the tools instead of the spec's custom toolbar (R2), at Adam's request. Simulator-checked: header ✕ · Draw · ✓, canvas sits above the picker, ✓ dimmed until a stroke, ✓ produced a cropped `.drawing` CIImage and returned to the previous tab.

*Status: PARTIAL — PR #24*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ✅ done | Simulator (iPhone 17 Pro): Draw tab opens a full-height "Draw" sheet on the checkerboard with the PencilKit tool picker visible (Pen, Monoline, Marker, Eraser, Lasso, Ruler, Pencil, Crayon, colour picker); Done is greyed and not tappable until a stroke, then enabled. The call screen can't be reached on this Mac, so the panel was mounted temporarily on the Calling tab and the Draw button forced on (no face in the simulator); both hacks were reverted before commit. |
| AC2 | ⚠️ unverified | The output is verified: two strokes gave a 232×216 px image (stroke bounds at scale 2), 95% of pixels fully transparent, 0 opaque white pixels, corner alpha 0, and `onAdd` received `.drawing(CIImage extent [0 0 232 216])`. Seeing it as a selected sticker in drag mode needs a tracked face, which the simulator's test clip doesn't give. |
| AC3 | ⚠️ unverified | Device only (D36). |
| AC4 | ⚠️ unverified | The Draw button uses the same `stickers.blocked` flag as the other tabs (cap, heat, no face). Seen disabled with "Show your face to add stickers" in the simulator; reaching 10 placed stickers needs a tracked face. |
| AC5 | ✅ done | `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 17' build` and `-destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`: both BUILD SUCCEEDED. |

### Needs attention
Manual on-device checklist (iPhone, in a call with the partner):
- [ ] Open Stickers → Draw. The pad opens inside the panel with ✕ · Draw · ✓, the tool picker shows at the bottom without covering the canvas, and ✓ is dimmed.
- [ ] Draw a heart and tap ✓. The panel closes and the heart sits on your nose, selected, with no white box around it.
- [ ] Drag the heart to your forehead. It pins there, and on the partner's phone it follows your head as you turn and tilt.
- [ ] Pinch, twist and trash work on the drawing as they do for an emoji.
- [ ] Open the pad, draw, tap ✕ (or swipe the header down). Nothing is added and the tray is back on the tab you came from.
- [ ] With the system in dark mode, draw in black. The sticker stays black, not inverted.
- [ ] Place 10 stickers. Draw's button is disabled with "That's 10. Remove one to add more."

