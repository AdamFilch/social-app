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
- [ ] AC1: Simulator: Draw opens the pad with the tool picker; Done is disabled until a stroke exists.
- [ ] AC2: Simulator: after Done, the sticker in drag mode is cropped to the strokes with a transparent background (no white box).
- [ ] AC3 (device): The drawing pins to the face and follows head movement on the partner's phone.
- [ ] AC4: With 10 stickers placed, Draw is disabled like the other tabs.
- [ ] AC5: `xcodebuild` builds for the simulator and a generic iOS device.

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
*Status: READY — ticket [6]*
