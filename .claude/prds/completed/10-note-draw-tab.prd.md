# [10]: Note Draw tab

**Depends on:** [9] New note screen shell merged.

This ticket makes the white canvas drawable. You draw with one finger, in one pen width, in one of 10 ink colours. The eraser removes whole strokes and undo steps back. The colour dots sit in a 2-row grid that scrolls sideways. A hint, "Draw something for Sam", sits on the empty canvas until the first stroke. Drawing counts as progress, so the discard alert from [9] now guards real work.

## Summary
Adds `NoteCanvas` (the white square plus a `PKCanvasView` with its tool picker hidden), `DrawTools` and a shared `ColourDots` with `.grid(rows:)` and `.row` layouts. Adds the `NoteInkRed` and `NoteInkOrange` colour sets. No backend changes.

## Users
- **Primary**: Adam and his partner drawing a note.

## Scope
**MVP**
- `PKCanvasView`, `drawingPolicy = .anyInput`, never showing `PKToolPicker`. `PKInkingTool(.pen, color:, width: 9)` and `PKEraserTool(.vector)`.
- Pen, eraser and undo as in spec §4.2. Undo is at 40% when there is nothing to undo. Picking a colour while the eraser is on switches back to the pen.
- `ColourDots` with the 10 colours in spec §6.3, in `.grid(rows: 2)` layout, default Ink
- The canvas hint (spec §4.2), which fades on the first content
- `NoteDraft.drawing` updates, so `hasProgress` is true after a stroke

**Out of scope**
- Stickers and text: [11]–[13]
- Pen width or size slider (spec, "one pen width")

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| N1 | Ink colours | The 10 in spec §6.3. Red #E5483B and Orange #FF8A3D added as colour sets that are the same in both modes | Spec R3 | User |
| N2 | `ColourDots` layouts | One component with `.row` and `.grid(rows:)` | [13] Text uses `.row` (spec R9) | Claude — straightforward |
| N3 | Ink and Accent values | Always the light values, because the canvas is always white | Spec §6.3 | Claude — straightforward |

## End-to-End Flows
```
Open editor ─► hint shown ─ draw ─► hint fades, Send stays 40% until [16], Undo live
Eraser ─ swipe over stroke ─► whole stroke gone
Pick Pink while eraser on ─► pen selected, ink Pink
✕ ─► discard alert (progress)
```

## Blast Radius
| Change | What breaks |
|---|---|
| New colour sets | Nothing |
| `NoteDraft.drawing` now written | [9]'s `hasProgress` now also becomes true from strokes |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Notes/NoteCanvas.swift` | **new** white square, `PKCanvasView` wrapper, hint |
| `Buttercup/Notes/DrawTools.swift` | **new** pen, eraser, undo |
| `Buttercup/DesignSystem/ColourDots.swift` | **new** row and grid layouts |
| `Buttercup/Assets.xcassets/NoteInkRed.colorset`, `NoteInkOrange.colorset` | **new** |

---

## Acceptance Criteria
- [x] AC1: Draw tab: pen, eraser and undo at top 634, and 10 dots in a 2 × 5 grid at top 690, in spec §6.3 order. Ink is selected.
- [x] AC2: Strokes are 9 pt wide in the chosen colour. No Apple tool picker ever appears.
- [x] AC3: The eraser removes whole strokes only. Undo steps back through strokes and erasures, and is at 40% when there is nothing left.
- [x] AC4: The hint shows on an empty canvas and fades over 0.15 s on the first stroke.
- [x] AC5: After one stroke, ✕ shows the discard alert.
- [x] AC6: Each dot has its VoiceOver name and `.isSelected` state. White's dot shows its outline on the white canvas.
- [x] AC7: The build check passes, and drawing is checked on the simulator in light and dark.

## Required Changes
- **Canvas**: spec §3.3, §4.2.
- **Tokens**: spec §6.3, §12 items 1–2.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `PKCanvasView` steals the top-band swipe | Low | Can't close | The canvas starts at y 160, and the swipe zone is above it |

---
*Status: COMPLETED — PR #8*
