# [18]: Notes tab week view

**Depends on:** [17] Notes read path merged. Blocks [19] and [20].

This ticket replaces the lone "Make a note" button with the Notes tab's week view (spec [notes-tab.md](../design/specs/notes-tab.md) §3.1–§3.2, §3.5–§3.6, §4.1–§4.4). The screen shows:
- the "Notes" title row;
- "Make a note";
- a Monday-first week strip that pages by week between the pairing week and the current week;
- below it, the selected day's header and its notes in a newest-first 2-column grid.

Today opens selected. Tiles are only drawn here: [19] makes them open the dialog. The title row leaves room for the month toggle, which [20] adds.

## Summary
Rewrites `NotesTab` with `selectedDay` state and adds two views, `WeekStrip` and `DayGrid`. It reuses `NotesStore` from [17] and refetches when the tab appears, when the app returns to the foreground, after a send, and on realtime changes. It also removes [17]'s DEBUG readout.

## Scope
**MVP**
- **Shared frame (§4.1):**
  - "Notes" in `.largeTitle` heavy, with no doodle, then "Make a note" (the existing `PillButtonStyle(sticker: true)`, full width).
  - The title row, button and strip stay fixed; only the day content scrolls.
- **`WeekStrip` (§4.2):**
  - 7 cells, Monday first, each about 48 × 74 with radius 14 and a 2 pt Outline on Surface.
  - Each cell shows the day letter (`.weekday(.narrow)`), the date in monospaced digits, and up to 3 stacked 15 pt mini-cards cropped from the day's newest note images.
  - Today has an Accent fill. The selected day has a 2 pt Background gap and a 2.5 pt Outline ring outside the cell, so the layout doesn't shift.
- **Paging (§3.2, §3.5):** one page per week, which follows the finger and snaps.
  - The same weekday stays selected after a swipe.
  - The earliest page is the week containing `pairedAt`; the latest is the current week.
- **Day header and grid (§4.3):**
  - The header reads e.g. "Thursday 29", never "Today", with a trailing count: "1 note", "3 notes" or "No notes".
  - The grid has 2 columns with 16 pt gaps. Tiles have radius 20, a 2.5 pt Outline and a 24 pt sender avatar, newest first.
  - Tiles have no tape, ring, badge or time.
- **Empty day (§4.4):** "No notes yet", the same for past, today and future days.
- **States (§8):**
  - **Loading:** Divider placeholders, with a `ProgressView` only after 1 s.
  - **Load failed:** "Couldn't load notes. Try again" with a "Try again" button.
  - **Image failed:** the tile keeps the Divider fill with a warning glyph.
  - **Long day:** the grid scrolls.
- **Selection:** tapping any cell selects it, including empty and future days. The ring and the content cross-fade over 0.15 s. No haptics.
- **Position memory (§3.1):**
  - The tab keeps its place across tab switches.
  - On returning to the foreground on a new day, it resets to today only if you were on the old today.
- **Refresh (§5):** on appear, on foreground, after [16]'s `onSent`, and on `NotesStore.changes()`. New notes fade in over 0.15 s.
- **Accessibility (§9):**
  - The strip is one adjustable element, with custom actions "Previous week" and "Next week" that are present only within the limits. Cells are reachable too.
  - Tile labels read "Note from Sam, 9:20 am".
  - The day header has the header trait.
  - At accessibility sizes the strip text caps at `.accessibility1` with the Large Content Viewer, and the grid becomes one column.

**Out of scope**
- Opening the note dialog from a tile: [19]
- The month view, the toggle pill and the dot tokens: [20]
- Favourite, Save and Unsend; the outbox badge; the unseen ring (spec §11)

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| W1 | Strip paging container | Paging `ScrollView` (`.scrollTargetBehavior(.paging)`) over a bounded range of weeks | Native paging, available on iOS 17+. Bounds come from `pairedAt`, so there's no custom edge code (spec §7) | Claude — straightforward |
| W2 | Avatar | Reuse the Calling avatar view, moved to `DesignSystem/` if it's private | It already exists in `Buttercup/Calling/` | Claude — straightforward |
| W3 | Tile tap before [19] | No action | [19] wires it | Claude — straightforward |

All spec decisions (D1–D3, D8, D11–D17, N1–N3, N9–N10, Q1–Q2, Q4, F2, S1) apply as written in spec §13.

## End-to-End Flows
```
open tab ─► this week, today selected ─► notes(in: week) ─► grid newest first
tap Wed ─► ring + content cross-fade 0.15 s ─► Wed grid / "No notes yet"
swipe strip right ─► previous week, same weekday ─► fetch that week
swipe at pairing week ─► page does not advance
Sam sends ─► realtime ─► refetch ─► tile fades in first
```

## Blast Radius
| Change | What breaks |
|---|---|
| `NotesTab` rewrite | The new-note cover and [16]'s toast must still present from it. Recheck Send end to end |
| Avatar moved to DesignSystem | Calling screens that use it. Rebuild and look at the Calling tab |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Notes/NotesTab.swift` | **new**, moved out of `ContentView.swift`; mode-free for now |
| `Buttercup/Notes/WeekStrip.swift` | **new** |
| `Buttercup/Notes/DayGrid.swift` | **new** header, grid, `NoteTile`, empty, loading, error states |
| `Buttercup/ContentView.swift` | remove the old `NotesTab` and the DEBUG readout |

---

## Acceptance Criteria
- [ ] AC1: As `adam@example.com`, opening the Notes tab shows the current week Mon–Sun with today Accent and ringed, and today's seed notes newest first.
- [ ] AC2: Strip cells show up to 3 mini-cards from that day's newest images; empty days show none.
- [ ] AC3: Tapping a past day, an empty day and a future day in the current week each select it, with the 0.15 s cross-fade and no haptic. The header never says "Today".
- [ ] AC4: Swiping the strip pages by week and keeps the weekday. It stops at the pairing week (about 45 days back in the seed) and at the current week.
- [ ] AC5: The unsent seed note appears nowhere.
- [ ] AC6: Stopping the local stack and reopening shows the load-failed state; "Try again" recovers after `supabase start`.
- [ ] AC7: Inserting a note for Sam today with SQL makes it fade in at the top of today's grid.
- [ ] AC8: Switching to Calling and back keeps the selected day.
- [ ] AC9: VoiceOver reads the strip as adjustable with week actions and tiles as "Note from …". At AX sizes the grid is one column.
- [ ] AC10: Checked in light and dark against mockup states 1–3, and the build check passes.

## Required Changes
Paste spec §12 items 2, 3, 7 and 8 into `design.md`: the week strip rules, the Note tile without tape, `doodle-tape` marked unused, and the Dynamic Type line. Also paste the Notes half of item 6 (week view, no doodle).

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Fetching and image loads stutter while swiping weeks | Med | Janky paging | Fetch on settle, not during the drag; cache images in `NotesStore` |

---
*Status: READY — ticket [18]*
