# [20]: Notes month view and toggle

**Depends on:** [18] Notes tab week view merged. Independent of [19]; the two can be built in parallel.

This ticket adds the Notes tab's second mode (spec [notes-tab.md](../design/specs/notes-tab.md) §3.3, §3.5, §4.1, §4.5, §6.3, §7):
- **Toggle pill:** sits in the title row. It reads the selected day's month ("October") in the week view, and "Current week" in the month view.
- **Month view:** a Monday-first calendar card for one month. Spill days are greyed, and each day has up to two dots: blue on the left if you sent a note that day, red on the right if your partner did.
- **Summary:** a line under the card with the month's totals, which doubles as the dot legend.
- **Swiping:** pages by month, between the pairing month and the current month.
- **Tapping a day:** opens its week in the week view, with that day selected.

## Summary
- **`NotesTab`:** gains a `mode` and the toggle pill. The content below "Make a note" cross-fades between the two modes.
- **New views:** `MonthCalendar` and `DayDots`.
- **Colours:** the `NoteDotMine` and `NoteDotPartner` tokens are added to the asset catalog.

## Scope
**MVP**
- **Toggle pill (§4.1, §4.7):**
  - A small secondary `PillButtonStyle`: 40 pt visible with a 44 pt hit area, Surface fill and a 2 pt Outline. It's trailing in the title row.
  - **Week view:** `calendar` + the selected day's month (`.month(.wide)`).
  - **Month view:** `calendar.day.timeline.left` + "Current week".
  - The pressed state is a 6% TextPrimary mix with no scale.
  - At accessibility sizes the title row wraps and the pill moves under the title.
- **Mode switch (D15):**
  - Everything below "Make a note", and the pill's label, cross-fades over 0.18 s ease-out.
  - Nothing slides. No haptic.
  - The month opens on the selected day's month.
  - "Current week" always returns to the current week with today selected.
- **`MonthCalendar` (§4.5):**
  - **Card:** radius 22, with padding 14 top and 10 on the sides and bottom.
  - **Title:** e.g. "October 2026" in `.title3` heavy. No chevrons.
  - **Weekday row:** M–S.
  - **Cells:** 4–6 rows of about 48 × 52, with no fill or outline of their own.
  - **Today:** an Accent fill and a 2 pt Outline.
  - **Spill days:** semibold TextSecondary numbers, with the whole cell at 50% opacity.
- **`DayDots`:**
  - two fixed 8 pt places, left for yours and right for your partner's;
  - each dot has a 1.5 pt Outline ring, which turns OnAccent on today;
  - they show that someone sent a note that day, not how many.
- **Tokens (§6.3):**
  - `NoteDotMine`: #2F6FDB light, #79AEFF dark.
  - `NoteDotPartner`: #E5483B light, #FF7A6E dark.
- **Summary (§4.5):**
  - "23 notes this month" for the current month, or "23 notes in September" for any other.
  - Zero reads "No notes this month" or "No notes in September".
  - The legend line reads "● 11 from you · ● 12 from Sam", using the partner's display name.
  - Counts cover only the month's own days, not the spill days.
- **Paging (§3.5):**
  - One page per month, from the month containing `pairedAt` to the current month.
  - The data is one `notes(in:)` query per visible grid span, up to 6 weeks.
- **Tapping a day (D18, D9):**
  - Switches to the week view on that day's week, with that day selected.
  - Spill days outside the swipe limits are greyed, can't be tapped, and have no button trait.
- **Refresh:** the same triggers as [18].
- **Accessibility (§9):**
  - The toggle reads "Show month, October" or "Show current week".
  - Days read like "Tuesday 27 October, notes from Sam" or "notes from you and Sam", adding "today" and the month name for spill days.
  - The month card has "Previous month" and "Next month" custom actions, present only within the limits.
  - The summary is read as one element.
  - Cell text caps at `.accessibility1` and uses the Large Content Viewer.

**Out of scope**
- A separate "Today" control (Q1)
- Note counts per day in the grid. Dots show presence only.

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| M1 | Month paging | The same bounded paging `ScrollView` as [18]'s strip, one page per month | One paging pattern on the screen | Claude — straightforward |
| M2 | Toggle style | A new `.small` secondary size on the existing `PillButtonStyle` | Spec §5 reuse row; no second button type | Claude — straightforward |

All spec decisions (D6–D10, D13, D15, D18, N4–N6, N8–N9, Q1, Q3–Q4) apply as written in spec §13.

## End-to-End Flows
```
week view, Thu 22 Oct ─ tap "October" ─► 0.18 s cross-fade ─► October grid, pill "Current week"
swipe right ─► September ─► "N notes in September" ─► swipe right at pairing month ─► stays
tap 15 Sep ─► week view, week of 14 Sep, Tue 15 selected, pill "September"
month view ─ tap "Current week" ─► current week, today selected
```

## Blast Radius
| Change | What breaks |
|---|---|
| `PillButtonStyle` small size | Existing callers keep the default size. Recheck "Make a note" and the new-note screen's Send |
| `NotesTab` mode state | [18]'s position memory now includes the mode (§3.1) |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Notes/NotesTab.swift` | mode, toggle, cross-fade |
| `Buttercup/Notes/MonthCalendar.swift` | **new** card, cells, summary |
| `Buttercup/DesignSystem/DayDots.swift` | **new** |
| `Buttercup/DesignSystem/Buttons.swift` | small secondary pill |
| `Buttercup/Assets.xcassets/NoteDotMine.colorset`, `NoteDotPartner.colorset` | **new** |

---

## Acceptance Criteria
- [ ] AC1: In the week view the pill reads the selected day's month with `calendar`. Tapping it cross-fades in about 0.18 s to that month, and the pill reads "Current week".
- [ ] AC2: As `adam@example.com` in October 2026, the grid is Monday-first, with Sep 28–30 and Nov 1 greyed at 50%, and today Accent.
- [ ] AC3: Seed days show a left blue dot for Adam's notes and a right red dot for Sam's. A Sam-only day has its dot on the right. On today the dot rings are OnAccent.
- [ ] AC4: The summary counts match the seed, without the unsent note, and the legend uses Sam's display name.
- [ ] AC5: Swiping pages by month and stops at the pairing month and the current month.
- [ ] AC6: Tapping a day opens its week with that day selected. Tapping an in-range spill day opens its week. A spill day before pairing does nothing.
- [ ] AC7: "Current week" returns to the current week with today selected from any month.
- [ ] AC8: VoiceOver reads the toggle, day labels, month actions and summary as in §9.
- [ ] AC9: Checked in light and dark against mockup states 4–5 and the toggle panel, and the build check passes.

## Required Changes
- **`design.md`:** paste spec §12 items 1 (dot tokens and contrast) and 5 (Day dots), and the rest of item 6 (the Notes month view).
- **`technical-spec`:** paste item 9 (Colours).
- **`notes-widget-spec`:** paste item 10, the new "Calendar" bullets that replace R1.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Month cells overflow on iPhone SE at large text | Med | Clipped numbers | Cap at `.accessibility1` and use the Large Content Viewer, per §9 |

---
*Status: READY — ticket [20]*
