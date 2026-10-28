# [12]: Note Emoji tab

**Depends on:** [11] Note stickers merged.

This ticket fills the Emoji tab with Apple's full emoji set in a 2-row strip that scrolls sideways. Each category has a small label at its start, and nine category chips at the bottom jump between them. Long-press an emoji to pick a skin tone. Tapping or dragging an emoji places it on the note exactly like a sticker from [11].

## Summary
Adds a shared `EmojiStrip` with a `rows:` parameter, and `SkinTonePicker`. Emoji become `NoteItem.kind = .emoji`. The data, tone picker and per-emoji tone memory follow the in-call spec §4.6, so the in-call tray [5] can reuse the same views with 3 rows.

## Scope
**MVP**
- `EmojiStrip(rows: 2)`, as in spec §4.4: 72 pt cells, inline category labels, nine jump chips at top 808
- Long-press → `SkinTonePicker`. The chosen tone is remembered per emoji.
- Tap → centre, selected. Drag → under the finger. Both use [11].

**Out of scope**
- Emoji search or the system keyboard (in-call spec R6)

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| N1 | Emoji data | A bundled emoji list grouped into the nine categories, as in-call spec §4.6 | Same set as calls (D16) | Claude — straightforward |
| N2 | Shared views | `EmojiStrip` and `SkinTonePicker` live in `Buttercup/DesignSystem/` | The in-call tray [5] reuses them | Claude — straightforward |

## End-to-End Flows
```
Emoji tab ─► Smileys first ─ tap Animals chip ─► strip scrolls (0.35 s ease-out)
Tap 😘 ─► at canvas centre, selected
Long-press 👋 ─► tone picker ─ pick ─► placed with that tone; remembered next time
```

## File Reference
| File | Role |
|---|---|
| `Buttercup/DesignSystem/EmojiStrip.swift` | **new** |
| `Buttercup/DesignSystem/SkinTonePicker.swift` | **new** |
| `Buttercup/Resources/emoji.json` (or similar) | **new** category data |

---

## Acceptance Criteria
- [ ] AC1: The Emoji tab shows a 2-row strip of 72 pt cells with category labels, and nine chips at the bottom. The current chip has a Divider disc.
- [ ] AC2: Tapping a chip scrolls to that category. Scrolling by hand updates the current chip.
- [ ] AC3: Tap and drag place emoji exactly as stickers do in [11].
- [ ] AC4: Long-pressing a toneable emoji opens the tone picker. The chosen tone is used and remembered.
- [ ] AC5: Emoji cells have their system names for VoiceOver, with the hint "Double-tap to add to the note".
- [ ] AC6: The build check passes and the tab is checked on the simulator.

## Features Catalog
- **Extends**: #2 Notes widget

---
*Status: READY — ticket [12]*
