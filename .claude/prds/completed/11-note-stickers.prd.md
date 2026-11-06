# [11]: Note stickers: placing, editing and the Stickers tab

**Depends on:** [10] Note Draw tab merged.

This ticket lets you put things on the note and arrange them. The Stickers tab shows a 2-row grid of sticker images. Tap one and it lands in the middle of the note, selected. Drag one and it lands where you let go. Any placed sticker can be moved, pinched and rotated. Tapping it selects it with a yellow outline and a small trash badge that removes it. This placing and editing layer is shared with Emoji [12] and Text [13], so they only add their own tab.

## Summary
Adds `NoteItem` (sticker, emoji or text, with centre, scale and rotation), `NoteItemView` (drag, `MagnifyGesture` and `RotateGesture`), selection with `TrashBadge`, and a shared `StickerGrid` with a `rows:` parameter. `assets/stickers/` is empty today, so this ticket also adds four plain shape PNGs (heart, star, circle, square) that spec R6 requires.

## Users
- **Primary**: Adam and his partner decorating a note.

## Scope
**MVP**
- `NoteItem` and the items layer above the strokes. The newest item is on top, and moving an item brings it to the top.
- Tap a cell: the item lands at the canvas centre, selected, with a light impact haptic. Drag a cell: it lands under the finger, unselected. A drop outside the canvas adds nothing.
- Move, pinch (0.3–4×) and rotate on any item. Tap to select: outline and trash badge (spec §4.12). A tap on empty canvas deselects and doesn't draw.
- `StickerGrid(rows: 2)`, Surface cells, the hint, and the "No stickers yet." empty state (spec §4.3)
- VoiceOver actions on placed items (spec §9)
- No cap on the number of items

**Out of scope**
- The Emoji and Text tabs: [12], [13]
- More sticker art. Adam drops PNGs into `assets/stickers/` whenever he likes.

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| N1 | Sticker art | Add heart, star, circle and square PNGs (simple filled shapes with an Ink outline) to `assets/stickers/` | The folder is empty, and spec R6 needs these four | Claude — straightforward |
| N2 | Item positions | Canvas points (0…398), stored as a fraction of the canvas side so export scales cleanly | Spec §5 `NoteItem` | Claude — straightforward |
| N3 | `StickerGrid` home | `Buttercup/DesignSystem/` with `rows` and `cellFill` | The in-call tray [5] reuses it with 3 rows | Claude — straightforward |

## End-to-End Flows
```
Stickers tab ─ tap heart ─► heart at centre, selected, light haptic
Pinch / rotate ─► resizes and turns   ─ tap trash ─► gone
Drag star onto the note ─► lands under the finger, unselected
Tap empty canvas ─► deselects, no stroke
```

## Blast Radius
| Change | What breaks |
|---|---|
| Items layer above `PKCanvasView` | Hit-testing: empty areas must pass touches through to the canvas |
| `hasProgress` includes items | Discard alert after placing a sticker |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Notes/NoteItem.swift` | **new** model |
| `Buttercup/Notes/NoteItemView.swift` | **new** gestures, selection, `TrashBadge` |
| `Buttercup/DesignSystem/StickerGrid.swift` | **new** |
| `assets/stickers/heart.png` … `square.png` | **new** |
| `Buttercup/Notes/NoteCanvas.swift` | items layer |

---

## Acceptance Criteria
- [x] AC1: The Stickers tab shows a 2-row grid of 84 pt cells, scrolling sideways, with the hint "Tap one, or drag it onto the note".
- [x] AC2: Tapping a cell adds the sticker at the canvas centre, selected, with a light haptic. Dragging a cell onto the canvas adds it under the finger, unselected.
- [x] AC3: Any sticker moves with one finger, pinches between 0.3× and 4×, and rotates with two fingers, whether or not it is selected.
- [x] AC4: Selected: a 2.5 pt light Accent outline 8 pt out, and a trash badge that stays inside the canvas and stays upright. The trash removes the sticker.
- [x] AC5: While something is selected, a tap on empty canvas only deselects and doesn't draw.
- [x] AC6: Strokes always sit under stickers.
- [x] AC7: With `assets/stickers/` emptied, the tab shows "No stickers yet."
- [x] AC8: Each placed item has the VoiceOver remove, size, rotate and move actions.
- [x] AC9: The build check passes, and placing and editing are checked on the simulator.

## Required Changes
- **Items**: spec §3.4, §3.6, §4.3, §4.12.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Simultaneous drag, magnify and rotate feel jumpy | Med | Hard to place | Combine them with `.simultaneously`, and apply the changes from the gesture start values |

---
*Status: COMPLETED — PR #9*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ✅ done | Simulator, light and dark: 2 rows of 84 × 84 cells (AX frames), Surface fill, hint "Tap one, or drag it onto the note" under the grid. Grid is a horizontal `ScrollView`; with 4 stickers nothing overflows, so the scroll itself wasn't exercised |
| AC2 | ✅ done | Tap on heart: lands at the canvas centre (AX frame centre 201,367 = canvas centre), selected with outline and trash; lldb breakpoint hit `-[UIImpactFeedbackGenerator impactOccurredWithIntensity:atLocation:]` from SwiftUI `sensoryFeedback`. Long-press drag of star released at (119,288) landed centred there, unselected; release over the tab row added nothing |
| AC3 | ✅ done | One-finger move checked on the simulator (selected and unselected, exact 89,103 pt offset, no stroke drawn). Pinch (0.3–4×) and two-finger rotate checked by the user on a physical iPhone |
| AC4 | ✅ done | Light Accent 2.5 pt outline 8 pt out; trash upright on the top-right corner; with a temporary patch placing the star rotated 30° at 1.6× in the top-right, the outline rotated, the badge stayed upright and moved to the corner inside the canvas. Trash removes the sticker (AX value back to "Empty"/count drops) |
| AC5 | ✅ done | With the heart selected, a drag across empty canvas drew nothing and the next tap only deselected (no dot) |
| AC6 | ✅ done | Strokes drawn before and after placing, including one crossing the star, render under the stickers |
| AC7 | ✅ done | PNGs moved out and rebuilt: bundle `stickers/` empty, tab shows "No stickers yet." (light and dark) |
| AC8 | ✅ done | `axe describe-ui` lists custom actions Remove, Make bigger, Make smaller, Rotate left, Rotate right, Move up/down/left/right on "Heart sticker"; actions not performed through VoiceOver |
| AC9 | ✅ done | `xcodebuild ... build` succeeds; placing, moving, selecting, deselecting and removing checked on the iPhone 17 simulator |

