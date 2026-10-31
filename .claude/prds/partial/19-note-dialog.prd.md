# [19]: Note dialog

**Depends on:** [18] Notes tab week view merged. Independent of [20]; the two can be built in parallel.

Tapping a note tile opens the note big, in a centred dialog over the dimmed Notes tab (spec [notes-tab.md](../design/specs/notes-tab.md) §3.4, §4.6, §5, §7). The dialog shows:
- the sender's avatar and name ("You" for your own notes);
- the date and time;
- a ✕ button;
- the note at full card width, with a pager.

Swiping left goes to the day's next (older) note and right to the newer one, stopping at both ends. ✕ or a tap on the dim area closes it. This ticket adds the reusable `DialogCard` to the design system as well.

## Summary
Adds `DialogCard`, a scrim and a card that cover the app tab bar, and `NoteDialog`, the paged note view with its header and pager. It also wires tile taps in [18]'s `DayGrid` to open the dialog.

## Scope
**MVP**
- **`DialogCard` (§5, R7):**
  - Props: `isPresented: Binding<Bool>` and `content`.
  - The scrim is black at 42% (light) or 60% (dark), covering the whole tab including the tab bar.
  - The card is Surface, 20 pt from each screen edge, with radius 28, a 2.5 pt Outline and 16 pt padding.
  - It closes on a tap on the scrim. Swipe down does nothing.
- **Motion (§7):**
  - Open: the scrim fades 0 → 1, and the card fades and scales 0.96 → 1, over 0.2 s ease-out.
  - Close: a 0.15 s fade.
  - Reduce Motion: fades only.
  - No haptics.
- **`NoteDialog` (§4.6):**
  - **Header:** a 40 pt avatar; the name ("You" or the partner's name) over the date and time, e.g. "Thursday 29 Oct · 9:20 am"; and a ✕ `IconCircleButton(.plain)` on the right.
  - **Note:** a full-card-width square with radius 20 and a 2.5 pt Outline, paging horizontally through the day's notes newest first.
  - **Pager:** 8 pt dots; the current one is filled with Outline, the others with Divider. It's hidden when the day has one note.
- **Opening:** from any tile in `DayGrid`, the dialog opens on that note.
- **Live changes (§8):** if the open note is unsent, a refetch drops it and the dialog closes.
- **Image failed:** the same Divider fill and warning glyph as the tile.
- **Accessibility (§9):**
  - The card is modal (`.isModal`), and focus starts on the sender name.
  - The note is labelled "Note from Sam, Thursday 29 October, 9:20 am, note 1 of 3", with adjustable actions to move to the next or previous note.
  - The ✕ is labelled "Close", and the escape gesture closes the dialog.

**Out of scope**
- Favourite, Save to Photos and Unsend. Leave the space under the pager empty (§4.8).
- Opening the dialog from the widget or the month view

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| G1 | How it covers the tab bar | A root overlay in `ContentView`, the same pattern the call screen uses | Spec §5 allows either. The overlay needs no fight with `.fullScreenCover`'s system transition | Claude — straightforward |
| G2 | Paging | `TabView(selection:)` with `.page(indexDisplayMode: .never)` and a custom pager | Native, and stops at the ends without wrapping | Claude — straightforward |

All spec decisions (D4–D5, F1, N7, Q2) apply as written in spec §13.

## End-to-End Flows
```
tap tile 2 of 3 ─► scrim + card fade/scale 0.2 s ─► note 2, pager ○●○
swipe left ─► note 3 (older), header updates ─► swipe left ─► stays on 3
tap scrim or ✕ ─► 0.15 s fade ─► grid unchanged
sender unsends the open note ─► refetch ─► dialog closes
```

## Blast Radius
| Change | What breaks |
|---|---|
| Root overlay in `ContentView` | The call screen overlay and [16]'s toast share the root. Check that their z-order is call > dialog > toast |

## File Reference
| File | Role |
|---|---|
| `Buttercup/DesignSystem/DialogCard.swift` | **new** |
| `Buttercup/Notes/NoteDialog.swift` | **new** |
| `Buttercup/Notes/DayGrid.swift` | tile tap opens the dialog |
| `Buttercup/ContentView.swift` | overlay host |

---

## Acceptance Criteria
- [x] AC1: As `adam@example.com`, tapping today's middle tile opens the dialog on that note. The scrim covers the tab bar, and the card is 20 pt from the edges.
- [x] AC2: The header shows Sam's avatar, "Sam" and "Thursday 29 Oct · 9:20 am" (or "You" for Adam's notes), plus ✕.
- [x] AC3: Swiping goes newest → oldest, stops at both ends, and updates the header and pager. A one-note day has no pager.
- [x] AC4: ✕ and a scrim tap close it with a 0.15 s fade. Swipe down does nothing.
- [x] AC5: Open and close timings match §7, with no scale under Reduce Motion and no haptics.
- [x] AC6: Setting `unsent_at` on the open note with SQL closes the dialog.
- [ ] AC7: VoiceOver traps focus in the dialog, starts on the name, reads "note 1 of 3", and the escape gesture closes it.
- [x] AC8: Checked in light and dark against mockup states 6–7, and the build check passes.

## Required Changes
Paste spec §12 item 4 (the new Dialog card component) into `design.md` §6.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Paged `TabView` gestures fight the scrim tap | Low | Taps on the note close the dialog | Put the scrim tap only on the area outside the card |

---
*Status: PARTIAL — PR #PRNUM*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ✅ done | As adam, tapping today's second tile (Partner, 8.12) opened the dialog on that note (pager ○●○○). A scrim tap at the Calling tab's spot closed it without switching tabs, so the scrim covers the tab bar. The card measured 361.7 pt wide on a 402 pt screen (20 pt each side) |
| AC2 | ✅ done | Header showed the pink "P" avatar with ring, "Partner", "Saturday, 31 Oct · 8.12" and ✕. Adam's note shows "You" with the "A" avatar. Date and time follow the device locale, the same formatter as `NoteTile` (comma and "8.12" come from the locale) |
| AC3 | ✅ done | Paging went 8.57 → 8.18 → 7.39 → 1.40 and stopped at both ends, with the header and pager updating on each page. Thursday 29 (one note) shows no pager |
| AC4 | ✅ done | ✕ and a scrim tap both closed it. Vertical swipes on the note and card left it open. Frame timing of the close: about 0.12–0.15 s fade, no width change |
| AC5 | ✅ done | Screen recording: on open the scrim darkens and the card grows to full width over about 0.17–0.2 s. With Reduce Motion on, the card is at full width from the first frame (fade only). No `sensoryFeedback` or feedback generator in the new code |
| AC6 | ✅ done | `update notes set unsent_at = now()` on another note kept the dialog open with the page, header and pager in sync. On the open note it closed the dialog with no crash, including after notes before it were removed |
| AC7 | ⚠️ unverified | `.isModal`, focus on the name, the "note 1 of 3" label, adjustable actions and the escape action are in the code, but VoiceOver speech, the focus trap and the escape gesture need a person on a device |
| AC8 | ✅ done | Compared states 6 and 7 against the mockup in light and dark (scrim 42 / 60%, Outline card, ring avatar, pager). `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded |

### Needs attention
- AC7: with VoiceOver on, open a note and check that focus starts on the name, that swipes stay inside the card, that the note reads "Note from Partner, …, note 1 of N", that swipe up and down change notes, and that the two-finger scrub closes it.
- G2 deviation: the note pages in a paging `ScrollView` (spec §5's alternative), not `TabView(.page)`. With `TabView(.page)` in the root overlay, opening and closing the dialog quickly crashed the app twice (EXC_BAD_ACCESS in `-[UIView _wrappedProcessTraitChanges:withBehavior:]`). The paging `ScrollView` passed the same stress test. Please confirm, or reopen G2.
