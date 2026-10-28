# [13]: Note Text tab

**Depends on:** [11] Note stickers merged.

This ticket lets you type words onto the note. Tap Text and the keyboard rises. Above it sit the text field and Add, one row of the 10 colours that scrolls sideways, and four font chips: Rounded, Serif, Handwritten and Mono. Each chip is written in its own font. While you type, the words preview live on the visible part of the note. Add places them exactly there, selected, and from then on they move, pinch, rotate and delete like a sticker. Placed text can't be edited again in v1.

## Summary
Adds `NoteFont` (an enum with `font(size:)`) and a `TextStickerComposer` with `colours`, `fonts`, `addHasShadow` and a `preview` switch, so the in-call tray can reuse it later. Text becomes `NoteItem.kind = .text(String, NoteFont, Color)`.

## Scope
**MVP**
- Keyboard up: a 164 pt Surface panel riding the keyboard (keyboard layout guide), leaving the canvas visible from 160 to 432 on iPhone 11
- Keyboard down: the same three rows under the tab row at 630, 682 and 734
- Field (30 characters, `.done`), Add (no sticker shadow, disabled while the text is empty), `ColourDots(.row)` from [10], and the font chips (spec §4.5 table)
- Live preview on the canvas at 52 pt with the 7 pt Ink outline, centred in the visible part
- Add or Return places the text selected, with a light haptic, and clears the field. Font and colour reset to Rounded and Ink each time the screen opens.

**Out of scope**
- Re-editing placed text (Adam confirmed for v1)
- Changing the in-call text tab, which stays as it is (D18)

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| N1 | Fonts | SF Pro Rounded heavy, New York bold, `Noteworthy-Bold`, SF Mono bold | Spec R4, A2 | User |
| N2 | Text outline | The 7 pt Ink outline for every font | Spec §4.5 | Claude — straightforward |

## End-to-End Flows
```
Text tab ─► keyboard up, tools on keyboard ─ type "hi sam" ─► preview on canvas
Tap Handwritten, Pink ─► preview updates ─ Add ─► placed, selected, keyboard down
Dismiss keyboard without Add ─► tools drop under tabs, typed text kept until tab change
```

## File Reference
| File | Role |
|---|---|
| `Buttercup/Notes/NoteFont.swift` | **new** |
| `Buttercup/DesignSystem/TextStickerComposer.swift` | **new** |
| `Buttercup/Notes/NewNoteView.swift` | keyboard-riding layout for the Text tab |

---

## Acceptance Criteria
- [ ] AC1: Text tab with the keyboard up: field + Add, one sideways-scrolling row of the 10 dots, and four font chips, each drawn in its own font. At least 272 pt of the canvas stays visible on an iPhone 11 simulator.
- [x] AC2: Typing previews the text live on the canvas in the chosen font and colour with the Ink outline. An empty field previews nothing.
- [x] AC3: Add is disabled for empty or whitespace-only text. Input stops at 30 characters.
- [ ] AC4: Add or Return places the text where it previewed, selected, with a light haptic. Then the keyboard closes and the field clears.
- [ ] AC5: Placed text moves, pinches, rotates and deletes as in [11], and counts as progress. Typed text that wasn't added doesn't count.
- [x] AC6: With the keyboard down, the three rows sit under the tab row and nothing overlaps the home indicator.
- [x] AC7: The build check passes, and the tab is checked on the simulator in light and dark.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `Noteworthy-Bold` name differs | Low | Falls back to system | Check `UIFont(name:)` at launch in DEBUG |

---
*Status: PARTIAL — PR #PRNUM*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ❌ not done | Field + Add, one sideways-scrolling row of the 10 dots and the four chips each in its own font are built and checked on iPhone 17 and iPhone 11 simulators. The 272 pt is not met: on an iPhone 11 simulator (iOS 26.1) the panel top is 387 with the predictive bar (227 pt of canvas visible) and 414 without it (254 pt). The iOS 26 keyboard is 345 / 318 pt tall, not the 300 the spec assumed |
| AC2 | ✅ done | "hi sam" previews live, centred in the visible canvas (y 269 of 174–365 on iPhone 17), in Rounded / Handwritten / Serif / Mono and Ink / Pink / Red / Orange with the Ink outline; empty field shows nothing and the hint stays |
| AC3 | ✅ done | AX: Add `enabled=False` for "" and " "; typing 36 characters leaves "Abcdefghijklmnopqrstuvwxyz0123" (30) |
| AC4 | ⚠️ unverified | Add and Return both place the text at the previewed centre (badge at the previewed spot), selected, then the field reads "Type something" and the field drops to y 632. The light haptic is the shared `sensoryFeedback` on item count from [11]; a simulator can't play it |
| AC5 | ⚠️ unverified | One-finger drag moved the text (no stroke drawn); trash removes it (canvas "Empty"); a placed text makes ✕ show "Discard this note?"; typed-but-unadded text closes without the alert. A temporary patch placed text at 1.6× and 30°: outline rotates with it and the badge moved to a corner inside the canvas. Two-finger pinch and rotate weren't exercised (the simulator can't send them without Accessibility access) |
| AC6 | ✅ done | iPhone 11 simulator: field 630, dots 682, chips 734 (bottom 778), well above the home indicator; light and dark |
| AC7 | ✅ done | `xcodebuild … build` succeeds with no warnings; Text tab checked in light and dark on iPhone 17 and iPhone 11 simulators |

### Needs attention
- Decide AC1: shrink the panel or accept the smaller visible canvas on iOS 26 (the spec's 596 keyboard top doesn't hold on iOS 26.1).
- On a physical iPhone: feel the light haptic on Add and Return, and pinch and rotate a placed text.
- Optional: a way to close the keyboard and keep typed text (the flow's "Dismiss keyboard without Add"); today Return always adds.
