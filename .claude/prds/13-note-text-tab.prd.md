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
- [ ] AC2: Typing previews the text live on the canvas in the chosen font and colour with the Ink outline. An empty field previews nothing.
- [ ] AC3: Add is disabled for empty or whitespace-only text. Input stops at 30 characters.
- [ ] AC4: Add or Return places the text where it previewed, selected, with a light haptic. Then the keyboard closes and the field clears.
- [ ] AC5: Placed text moves, pinches, rotates and deletes as in [11], and counts as progress. Typed text that wasn't added doesn't count.
- [ ] AC6: With the keyboard down, the three rows sit under the tab row and nothing overlaps the home indicator.
- [ ] AC7: The build check passes, and the tab is checked on the simulator in light and dark.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `Noteworthy-Bold` name differs | Low | Falls back to system | Check `UIFont(name:)` at launch in DEBUG |

---
*Status: READY — ticket [13]*
