# [9]: New note screen shell

**Depends on:** [2] Foundation merged (signed-in, paired tab shell).

This ticket builds the frame of the New Note Screen with nothing to draw yet. Tapping **Make a note** on the Notes tab opens a full-screen cover with ✕ and a disabled **Send** in the top bar, the pen | camera toggle above the canvas, an empty white square canvas, and the tab row Draw · Stickers · Emoji · Text · Face. The tabs switch but show empty content. Face is greyed out. The ticket also adds the editor's state object (`NoteDraft`) and its "has progress" rule, plus the discard alert on ✕, swipe down and mode switch, so every later tab ticket just adds content.

## Summary
New `Buttercup/Notes/` folder with `NewNoteView`, `NoteDraft`, `ModeToggle` and `PillTabRow`. Also adds the shared button styles from design.md §6 (`PressableButtonStyle`, `PillButtonStyle`, `IconCircleButton`), because none exist yet. Adds a temporary "Make a note" button to the Notes tab placeholder. No backend changes.

## Users
- **Primary**: Adam and his partner, opening the note editor.
- **Not for**: the in-call tray. That reuses `PillTabRow` later.

## Scope
**MVP**
- "Make a note" on the Notes tab presents `NewNoteView` with `.fullScreenCover`
- The top bar, mode row, canvas frame, tab row and positions from spec §4.1 and §4.6
- `NoteDraft` (`@Observable`): `mode`, `photo`, `drawing`, `items`, `selection`, `hasProgress`
- Discard alert (spec §3.9) on ✕, swipe down from the top band (spec §7) and mode switch, only when `hasProgress`
- Shared button styles: `PressableButtonStyle`, `PillButtonStyle` (small primary with `StickerShadow`, secondary), `IconCircleButton`

**Out of scope**
- Tab content: [10]–[13]
- Camera and Retake behaviour: [14]. Retake is not shown yet, because it only appears in Photo mode.
- Send behaviour: [16]. Send stays disabled.
- "Send one back": the Calling tab's latest-note card doesn't exist yet. Whoever builds that card presents the same `NewNoteView`.

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
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| N1 | Source of truth | [specs/new-note-screen.md](../design/specs/new-note-screen.md) and mockup v4 | Approved 2026-10-28 | User |
| N2 | Entry point | A plain "Make a note" button on the Notes tab placeholder for now | The Notes tab home isn't built; this ticket only needs a way in | Claude — straightforward |
| N3 | Shared styles | Built here in `Buttercup/DesignSystem/` | The first ticket to need them; spec §5 says "build them if this ticket lands first" | Claude — straightforward |
| N4 | Swipe down | A custom drag on the top band (y < 160) following spec §7, not `interactiveDismissDisabled` tricks | The canvas must never start a dismiss | Claude — straightforward |

## End-to-End Flows
### Happy path
```
Notes tab ─ Make a note ─► cover: Draw mode, Draw tab, Send 40%
Tap Stickers / Emoji / Text ─► pill selects, empty content
✕ (no progress) ─► cover closes, no alert
```
### Edge case: progress
```
(debug) add a fake item to draft ─ ✕ ─► "Discard this note?" ─ Keep editing ─► stays
                                    ─ Discard ─► closes
```

## Blast Radius
| Change | What breaks |
|---|---|
| Notes tab placeholder gets a button | Nothing; it is a placeholder |
| New button styles | Nothing; nothing used styles before |

## File Reference
| File | Role |
|---|---|
| `Buttercup/ContentView.swift` | Notes tab: "Make a note" button and cover |
| `Buttercup/Notes/NewNoteView.swift` | **new** cover, layout, alert, swipe down |
| `Buttercup/Notes/NoteDraft.swift` | **new** draft state and `hasProgress` |
| `Buttercup/Notes/ModeToggle.swift` | **new** two-segment pill, asks the parent before switching |
| `Buttercup/DesignSystem/PillTabRow.swift` | **new** scrolling pills with a `disabled` set |
| `Buttercup/DesignSystem/Buttons.swift` | **new** pressable, pill, icon-circle styles |

---

## Acceptance Criteria
- [ ] AC1: Signed in as `adam@example.com`, Notes → Make a note opens a full-screen cover: blank, Draw mode, Draw tab selected.
- [ ] AC2: The top bar holds only ✕ (left) and Send (right). Send is at 40% with no shadow and does nothing.
- [ ] AC3: The mode row has the toggle on the right. The canvas is screen width − 16, square, white in light and dark, radius 20, 2.5 pt Outline.
- [ ] AC4: The tab row shows Draw · Stickers · Emoji · Text · Face and scrolls. Face is at 40% and can't be tapped, and VoiceOver reads "Face stickers, coming later".
- [ ] AC5: With no progress, ✕, swipe down from above the canvas and the mode toggle act at once. A drag that starts on the canvas never dismisses.
- [ ] AC6: With `hasProgress` true, the same three actions show the alert "Discard this note?" / "You will lose your progress if you proceed" / Keep editing / Discard, and Discard does the action.
- [ ] AC7: The build check passes, and the screen is checked in light and dark on the simulator.

## Required Changes
- **Notes tab**: temporary entry button (N2).
- **Editor frame**: spec §3.1, §3.2, §3.9, §4.1, §4.6, §7 (open/close, swipe, mode switch).
- **Design system**: buttons from design.md §6 (N3).

## Features Catalog
- **Extends**: #2 Notes widget
- **Closes known gaps**: none

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Custom swipe-down fights the cover's own dismiss | Low | Double dismiss | A full-screen cover has no system swipe, so only the custom one exists |

---
*Status: PARTIAL — PR #PRNUM*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ⚠️ unverified | Built in `ContentView.swift` (`NotesTab`, `.fullScreenCover`) and `NewNoteView.swift` (starts `.draw` mode, `.draw` tab); no simulator-driving tool was available to open it |
| AC2 | ⚠️ unverified | Top bar holds only `IconCircleButton` ✕ and Send (`PillButtonStyle(height: 44, sticker: true)`, `.disabled(true)` gives 40% and drops the sticker shadow); not seen on a simulator |
| AC3 | ⚠️ unverified | Toggle right-aligned in the mode row; canvas `.padding(.horizontal, 8)` + `.aspectRatio(1)`, white fill, radius 20 continuous, 2.5 Outline `.strokeBorder`; not seen in light or dark |
| AC4 | ⚠️ unverified | `PillTabRow` in a horizontal `ScrollView`, Face in `disabled` (40%, `.disabled`), label "Face stickers, coming later"; VoiceOver not run |
| AC5 | ⚠️ unverified | `confirm` runs the action at once without progress; the drag is attached only to the top band, never the canvas; not exercised |
| AC6 | ⚠️ unverified | `.alert` with the spec's title, message, Keep editing (`.cancel`) and Discard (`.destructive`); Debug builds add a fake item with a triple tap on the canvas to test it; not exercised |
| AC7 | ⚠️ unverified | Build check passes (`** BUILD SUCCEEDED **`, iPhone 17 Simulator, Debug); light and dark simulator check not done |

### Needs attention
- Sign in as `adam@example.com` on the iPhone 17 Simulator, open Notes → Make a note, and check AC1–AC6 in light and dark (triple-tap the canvas in a Debug build to get `hasProgress` for AC6). Then tick the ACs and move this PRD to `completed/`.
