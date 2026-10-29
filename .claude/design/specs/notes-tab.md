# Notes tab: week strip, day grid, month calendar and note dialog

Oct 29, 2026 · approved by Adam (mockup v3) · designer run 2
**Mockup**: https://claude.ai/artifact/FrJNkLhFSWXHBGEyfyVTvY (v3, all in light and dark through the page switch):
- Week view: today with 3 notes; the previous week after a swipe, Thu 22 selected; an empty future day.
- Month view: October with your dots, Sam's dots and spill days, in light and dark.
- Note dialog: note 1 of 3 over the week view (light); your own note 4 of 4 (dark).
- The toggle button with both labels and its pressed state.
- The proposed dot tokens.

**Source**: [mockups/notes-tab.html](../mockups/notes-tab.html)
**Feature spec**: [notes-widget-spec.md](../../context/notes-widget-spec.md) ("Calendar")
**Decisions**:
- D1–D18 were settled by Adam before v1.
- N1–N10 are the designer's, approved with the mockup.
- Q1–Q4 are Adam's answers to the v1 open questions.
- F1–F2 are Adam's v2 feedback.
- All are indexed in §13.

## 0. Revisions to existing docs

This spec changes the documents below. They are not edited here: the designer only writes under `.claude/design/`. The developer follows this spec where they differ. Whoever next updates those documents copies these rows in. The ready-to-paste text is in §12.

| # | Document and current text | Replaced by | Decision |
| --- | --- | --- | --- |
| R1 | notes-widget-spec "Calendar": "Each day with notes shows them as small stacked cards… Tap a day to open a dialog with all of that day's notes in time order… From the dialog you can favourite a note, save it to Photos, or unsend it" | The Notes tab has two views: a week view (strip + the selected day's grid) and a month view (calendar with dots). Tapping a month day opens its week with that day selected. Tapping a note tile opens the note dialog, which pages newest first. Favourite, Save and Unsend move to a later ticket. See this spec | D1, D4–D6, D18, Q2, F1 |
| R2 | design.md §7 Notes: "The title and month… The doodle is the tape on the newest tile" | The title and the month toggle pill, "Make a note", then the week strip, then the selected day's header and grid. There is no doodle | D10, N10, F2 |
| R3 | design.md §6 Note tile: "**New (unseen by you):** the 3 pt Highlight ring…" and "**Doodle:** the tape strip sits on the newest tile in the Notes grid only" | Remove the tape line. The unseen ring stays in the system for later, but the Notes tab doesn't use it (no seen state, D17) | D17, F2 |
| R4 | design.md §6 Week strip: "Today is an Accent cell. Tapping a day opens that day's notes, as the calendar does" and "up to three stacked mini-cards in that day's NotePaper colours" | Today = Accent fill. Selected = an Outline ring outside the cell. Today and selected = both. Mini-cards are tiny crops of the day's newest note images (§4.3) | D13–D14, N1, S1 |
| R5 | design.md §10 doodle table, `doodle-tape` "Across the top edge of the newest note tile in the Notes grid" | `doodle-tape` has no place. Keep the asset in the table, marked "unused, kept for later". It costs nothing, and the Hobbies or widget work may want it | N10, F2 |
| R6 | design.md §3 colour tokens (no dot colours) | Two new tokens: `NoteDotMine` and `NoteDotPartner` (§6.3) | D7, N5 |
| R7 | design.md §6 (no dialog component) | New component: Dialog card (§5) | F1, N7 |
| R8 | technical-spec "Colours" token list | Add `NoteDotMine` and `NoteDotPartner` with light and dark values | N5 |

## 1. Problem and goal

`NotesTab` in `Buttercup/ContentView.swift` is a lone "Make a note" button. Notes are sent (see the new-note spec), but there is nowhere in the app to look at them.

Goal:
- Open the tab and see today's notes, big, at once.
- Read any day in a tap or a swipe.
- See at a glance when you two wrote, and who wrote.
- Keep it quiet: no badges, bounces or haptics.

## 2. User and situation

- **Who:** Adam or Sam on an iPhone 11 (smallest supported: iPhone SE 3rd gen, 375 × 667), always paired. The tab isn't reachable unpaired.
- **Where and how:** idle moments, often one-handed. Usually right after a note has arrived ("what did Sam send?"), and sometimes in the evening, scrolling back ("what did we send last week?").
- **Job:**
  1. See today's notes.
  2. Open one big.
  3. Go back through earlier days.
  4. Get a sense of the rhythm between you ("12 from Sam this month").
- **What matters most:** today's notes on open with no taps; the note itself, big; and "Make a note" always in the same place.
- **Constraints:**
  - design.md: tokens, one sticker per screen, colour fades only, haptics T3.
  - D1–D18, Q1–Q4, F1–F2.
  - Portrait only.
  - The data is `notes (id, sender_id, image_path, created_at, unsent_at)` and `pairs.created_at`. No schema change.
- **Out of scope:**
  - Favourite, Save to Photos and Unsend (a later ticket; the dialog leaves room, §4.8).
  - The unseen ring and "New" badge (D17).
  - The queued (outbox) badge on your own tile (a follow-up from the new-note spec).
  - The home-screen widget.

## 3. Flow

### 3.1 Entry and default

- **Entry:** the Notes tab in the app tab bar.
- **Opening the tab** for the first time in an app session shows the week view, the current week, with today selected (D11).
- **Switching tabs and back** keeps the mode, week or month, and selected day you left.
- **Returning to the foreground** on a later calendar day resets to D11. This applies only if you were on the day that was today when you left. Otherwise your place is kept.

### 3.2 Week view

1. The week strip shows Monday to Sunday (D8). Today is Accent (D13). The selected day has the ring (N1).
2. **Tap a strip cell** to select it. The ring and the day content cross-fade (0.15 s). Any day can be selected, including empty and future days in the current week (D16).
3. **Swipe the strip** left for the next week or right for the previous one (D2). The same weekday stays selected (D3).
   - The strip follows the finger and snaps to a week page.
   - The day content cross-fades to the new selection when the page settles.
4. **Swipe limits:** see §3.5.
5. **Tap a note tile** to open the note dialog on that note (§3.4).
6. **Tap the toggle** ("October") to switch to the month view, showing the month of the selected day (D10).
7. **Tap "Make a note"** to open the new-note cover. That flow is unchanged.

### 3.3 Month view

1. A Monday-first calendar of one month (D6, D8). Spill days from the months either side fill the first and last rows, greyed (D9).
2. Each day shows up to two dots: yours in the left place and your partner's in the right place (D7, N4).
3. **Swipe the calendar** left for the next month or right for the previous one, within §3.5's limits.
4. **Tap a day**, a spill day included, to open the week view. It shows that day's week with that day selected, through the mode cross-fade (D18, D9).
5. **Tap the toggle** ("Current week") to open the week view on the current week with today selected (D10), wherever you were.
6. There's no separate "Today" control anywhere (Q1).

### 3.4 Note dialog

1. Opens on the tapped note (D4, F1). The day's notes page newest first, in the grid's order (D5, Q2).
2. **Swipe left** on the note for the next (older) note, and **right** for the newer one.
   - The pages stop at the first and last note.
   - There's no wrap-around and no crossing into another day.
   - The header (sender, time) and the pager update with each page.
3. **Close** with ✕ or a tap on the dimmed area outside the card (N7). Both return to the same grid, unchanged.
   - Swipe down doesn't close it. The note's horizontal swipe is the only gesture inside the card.
4. The note dialog shows the sender and the time only. There are no actions in this ticket (D4).

### 3.5 Swipe limits (Q4, N9)

- **Earliest:** the week, or month, that contains `pairs.created_at`, in the phone's time zone.
- **Latest:** the current week, or month.
- **At an edge,** a swipe doesn't advance. There's no message and no haptic. A custom bounce is not added; see §7 for the system edge.
- **Spill days and the limits:** a spill day in the month grid is tappable only if its week is within the limits.
  - Before pairing: shown greyed, not tappable, with no button trait.
  - After the current week: the same.
  - Example: if today were 20 Oct, Sun 1 Nov would not be tappable.
- **Future days:**
  - In the current week (strip) and the current month (grid), they're selectable and show the empty state (D16).
- **Month toggle in the week view:** always shows a month within the limits, because the selected day is always within them.

### 3.6 What counts as a note

- The note's `created_at` falls on that local calendar day, in the phone's time zone (notes-widget-spec).
- Notes with `unsent_at` set are left out everywhere: grid, strip, dots and counts.
- Notes from both people count. "You" means `sender_id` = the signed-in user.

## 4. Screens

All sizes are for the iPhone 11 (414 pt wide) with a 20 pt screen margin. The tab content sits between the status bar and the app tab bar (design.md §6 Tab bar).

### 4.1 Shared frame (both modes)

```
┌──────────────────────────────────────────┐
│ Notes                      [📅 October ] │  title row, 48 tall
│                                          │  20
│ ╭──────────────────────────────────────╮ │
│ │           ✎  Make a note              │▌│  56, sticker shadow
│ ╰──────────────────────────────────────╯ │
│                                          │  20
│   (week view §4.2 or month view §4.5)    │
│                                          │
├──────────────────────────────────────────┤
│   Calling        [Notes]       Hobbies   │  app tab bar
└──────────────────────────────────────────┘
```

- **Title:** "Notes", `.largeTitle` heavy, TextPrimary. There's no doodle (N10).
- **Toggle pill (D10, N6):** trailing, vertically centred on the title.
  - **Style:** Small secondary button: 40 pt visible with a 44 pt hit area, a pill shape, Surface fill, a 2 pt Outline and TextPrimary.
  - **Content:** a leading symbol (semibold, 18 pt), 6 pt to the label (`.subheadline` bold). Padding is 12 leading and 14 trailing.
  - **Week view:** `calendar` + the selected day's month name, `.month(.wide)`, e.g. "October".
  - **Month view:** `calendar.day.timeline.left` + "Current week" (sentence case, Q3).
  - **Width:** it's trailing-aligned and grows to the left. The longest label is "Current week" or "September". The label change cross-fades with the mode (§7).
- **Make a note:** the existing `PillButtonStyle(sticker: true)` at full width, 56 tall, with `pencil.tip` + "Make a note". It's the screen's only sticker shadow (D12), and it opens the new-note cover as today.
- **Fixed part:** the title row, "Make a note" and the week strip (or the month card) stay fixed. Only the day content (§4.3–§4.4) scrolls vertically.

### 4.2 Week view: strip (states 1–3)

```
 ┌──┐ ┌──┐ ┌──┐ ┏━━┓ ╔══╗ ┌──┐ ┌──┐
 │M │ │T │ │W │ ┃T ┃ ║F ║ │S │ │S │   day letter, caption bold
 │26│ │27│ │28│ ┃29┃ ║30║ │31│ │ 1│   date, headline, mono digits
 │▣ │ │▣ │ │  │ ┃▣ ┃ ║  ║ │  │ │  │   up to 3 stacked mini-cards
 └──┘ └──┘ └──┘ ┗━━┛ ╚══╝ └──┘ └──┘
               today  selected (ring)
```

- **Cells:** 7 equal cells with 6 pt gaps (about 48 × 74). Radius 14, Surface fill, a 2 pt Outline. Content is top-aligned with 6 pt top padding and 2 pt between rows.
  - **Day letter:** `.caption` bold, TextSecondary. It's the first letter of the localised weekday (`.weekday(.narrow)`).
  - **Date:** `.headline` bold (17), monospaced digits.
  - **Mini-cards:** up to 3 squares, 15 pt each, radius 4, with a 1.5 pt Outline. Each one after the first is offset 2.5 pt right and 1.5 pt up. Each square is the note image scaled down (S1). Show the day's three newest, with the newest on top. There's no "+n".
- **Today (D13):** Accent fill. The letter, date and mini-card outlines use OnAccent.
- **Selected (N1):** a 2 pt gap in Background, then a 2.5 pt Outline ring, drawn outside the cell's border so the layout doesn't shift. When today is selected it gets both.
- **Paging:** one page per week. See §3.2 and §3.5.
- **Next month's days:** in the strip they look like any other day (e.g. "1" for 1 Nov). Greying only applies in the month grid.

### 4.3 Week view: day header and grid (states 1 and 2)

```
 Thursday 29                     3 notes
 ┌───────────────┐ ┌───────────────┐
 │               │ │               │
 │   (note)      │ │   (note)      │   newest first, left→right,
 │ (S)           │ │ (A)           │   then the next row
 └───────────────┘ └───────────────┘
 ┌───────────────┐
 │ (S)           │
 └───────────────┘
```

- **Header:** the weekday and day, e.g. "Thursday 29" (`.weekday(.wide).day()`, `.title3` heavy).
  - Today also reads "Thursday 29", never "Today" (N3).
  - The count is trailing: "1 note", "3 notes" or "No notes" (`.subheadline` medium, TextSecondary, monospaced digits).
  - The two are baseline-aligned, with 14 pt from the strip to the header and 14 pt from the header to the grid.
- **Grid:** 2 columns with 16 pt gaps, so tiles are about 179 pt square.
  - The Note tile is from design.md §6: radius 20, 2.5 pt Outline, the image clipped inside, and a 24 pt sender avatar 8 pt in from the bottom-left.
  - Order: newest first, left to right, then the next row (Q2, N2).
  - Tiles carry no doodle, no ring, no "New" badge and no time (N10, D17).
- **Image loading:** a tile shows a Divider fill until its image loads. A load that fails keeps the Divider fill with a centred `exclamationmark.triangle` (TextSecondary), and the tile is still tappable. Images come through the same signed-URL path the widget uses.
- **Scrolling:** the grid scrolls vertically when the day has more than about 4 notes, with 24 pt bottom padding above the tab bar.

### 4.4 Week view: empty day (state 3)

```
 Friday 30                      No notes

               No notes yet
```

- "No notes yet", `.headline` in TextSecondary, centred, with 56 pt above it. There's nothing else: no doodle, no button and no prompt (D16).
- The copy is the same for past, today and future days. "Yet" still holds, because outbox notes can arrive late.

### 4.5 Month view (states 4 and 5)

```
 ╭──────────────────────────────────────╮
 │ October 2026                          │  title3 heavy
 │  M    T    W    T    F    S    S      │  caption bold, TextSecondary
 │  28   29   30    1    2    3    4     │  28–30 greyed (spill)
 │       ·r   ·b         b·              │
 │   5    6    7    8    9   10   11     │
 │       b·r                  ·r         │
 │  …                                    │
 │  26   27   28 ┏29┓  30   31    1      │  29 = today (Accent)
 │  b·r   ·r     ┃br┃                    │  1 = spill
 ╰──────────────────────────────────────╯
 23 notes this month
 ● 11 from you   ● 12 from Sam
```

- **Card:** design.md Card: Surface, a 2.5 pt Outline, radius 22. Padding is 14 top, 10 sides and 10 bottom; the cells need the width.
- **Month title:** "October 2026" (`.month(.wide).year()`, `.title3` heavy), inset 6 pt, with 4 pt below. There are no chevrons; swipe or the VoiceOver actions (§9).
- **Weekday row:** M T W T F S S, `.caption` bold, TextSecondary, 18 tall, Monday first (D8).
- **Day cells:** 7 columns with 2 pt gaps, rows 52 tall with 4 pt gaps, radius 14, and no fill or outline of their own (N8). Rows run 4–6 as the month needs.
  - **Number:** `.headline` bold, monospaced digits, 6 pt from the top.
  - **Dots:** 5 pt below the number, two fixed places 4 pt apart (left = yours, right = your partner's).
    - Each dot is 8 pt with a 1.5 pt Outline ring. The fill is `NoteDotMine` or `NoteDotPartner`.
    - An empty place stays reserved, so a lone partner dot sits on the right (N4).
    - Dots show presence, not count.
- **Today (D13):** Accent fill, a 2 pt Outline and an OnAccent number. The dot rings switch to OnAccent (N5).
- **Spill days (D9):** the number is `.headline` semibold in TextSecondary. The whole cell, dots included, is at 50% opacity. Tappability follows §3.5.
- **Summary (D6, N4):** 20 pt below the card, inset 4 pt.
  - **Line 1:** "23 notes this month" for the current month, or "23 notes in September" for any other. Zero reads "No notes this month" or "No notes in September". `.subheadline` bold, TextPrimary.
  - **Line 2,** the legend: a 10 pt `NoteDotMine` dot, "11 from you", 16 pt, a 10 pt `NoteDotPartner` dot, "12 from Sam". `.subheadline` medium, TextSecondary, 6 pt from dot to text, monospaced digits. Use the partner's display name.
  - **Counts:** they count notes in the month itself, not in the spill days.
- **Paging:** one page per month, within §3.5's limits.

### 4.6 Note dialog (states 6 and 7)

```
 (Notes tab, dimmed by the scrim, tab bar included)
  ╭────────────────────────────────────╮
  │ (S)  Sam                       (✕) │  avatar 40 · name · ✕ 44
  │      Thursday 29 Oct · 9:20 am     │
  │ ┌────────────────────────────────┐ │
  │ │                                │ │
  │ │           (note, 338)          │ │  pages left/right
  │ │                                │ │
  │ └────────────────────────────────┘ │
  │               ● ○ ○                │  pager
  ╰────────────────────────────────────╯
```

- **Scrim:** black at 42% (light) or 60% (dark), covering the whole tab, the app tab bar included. Tapping the scrim closes the dialog.
- **Card:** the Dialog card (§5): 20 pt from each screen edge (374 wide), centred vertically, Surface fill, radius 28, a 2.5 pt Outline, 16 pt padding and 14 pt between rows. There's no sticker and no blurred shadow.
- **Header row:**
  - A 40 pt avatar of the sender, then 12 pt to the text: name (`.headline`) over date and time (`.subheadline` medium, TextSecondary, monospaced digits).
  - Name: the partner's display name, or "You" for your own notes.
  - Date and time: "Thursday 29 Oct · 9:20 am" (`.weekday(.wide).day().month(.abbreviated)` + `.hour().minute()`).
  - Trailing: the Icon circle button `.plain` with `xmark`.
- **Note:** a square at full card width (338 on iPhone 11), radius 20, with a 2.5 pt Outline. The image is identical in both modes. It pages horizontally (§3.4).
- **Pager:** centred dots, 8 pt each, 8 pt apart, with a 1.5 pt Outline. The current dot is filled with Outline and the others with Divider. It's hidden when the day has one note.
- **Height:** about 450 pt. The later actions row (§4.8) adds about 58 pt.

### 4.7 Toggle button (mockup "The toggle button")

- See §4.1. The pressed state is the Small button press from design.md: the fill mixes 6% TextPrimary over 0.1 s ease-out, with no scale and no haptic.

### 4.8 Space reserved for later (not built)

- The Favourite, Save and Unsend ticket adds one row of small 44 pt pills under the pager, inside the dialog card. That makes the card about 508 pt, which centres on the SE with margin.
- Nothing is drawn now, and no placeholder.

## 5. Components

### Reuse (design.md §6; build the shared ones if this ticket lands first)

| Component | Use here |
| --- | --- |
| `PillButtonStyle` primary + sticker | "Make a note" (already exists) |
| `PillButtonStyle` small secondary | The toggle pill |
| `Card` | The month card |
| `NoteTile` | Grid tiles (no ring, no tape) and the dialog's note at a larger size |
| `Avatar` | 24 pt on tiles, 40 pt in the dialog |
| Icon circle button `.plain` | Dialog ✕ |
| `WeekStrip` | Build to §4.2 (design.md §6 Week strip, with R4) |

### New

**`MonthCalendar`**
- Props: `month: Date`, `today: Date`, `range: ClosedRange<Date>` (tappable weeks), `days: [Date: DayMarks]`, where `DayMarks = (mine: Bool, partner: Bool)`, and `onSelect: (Date) -> Void`.
- Layout as §4.5. It pages with its parent.

**`DayDots`**
- Props: `mine: Bool`, `partner: Bool`, `onAccent: Bool`.
- Two fixed 8 pt places, as §4.5. It's used in the month cells. The legend uses single 10 pt dots in the same style.

**`DialogCard`** (design-system component, R7)
- Props: `isPresented: Binding<Bool>`, `content`.
- It draws the scrim and the card as §4.6, and handles tap-outside and ✕ dismissal and the motion in §7.
- It has to cover the app tab bar. Present it either from the app root overlay (as `ContentView` does for the call screen) or as a `.fullScreenCover` with `.presentationBackground(.clear)` and the system transition turned off. Either is fine if it looks like §7.

**`NoteDialog`**
- Props: `notes: [Note]` (the day, newest first), `startID: Note.ID`, `partnerName: String`, `myID: UUID`.
- A paged note area (`TabView(selection:)` with `.page(indexDisplayMode: .never)`, or a paging `ScrollView`), with the header and the custom pager bound to the current page.

**`NotesTab`** (replaces the placeholder)
- State: `mode: .week | .month`, `selectedDay: Date`, `visibleMonth: Date`.
- Data: one query per visible range, of `notes(id, sender_id, image_path, created_at)` where `unsent_at is null`. It runs for the strip's week and the month grid's 6-week span.
- Refetch when the tab appears, when the app returns to the foreground, and when a note is sent from this phone. If a realtime channel on `notes` exists, insert arriving notes with the 0.15 s fade. Otherwise the refetches are enough for this ticket.

## 6. Visual details

### 6.1 Colour use

| Element | Token |
| --- | --- |
| Screen | Background |
| Strip cells, month card, toggle, dialog card | Surface, Outline borders |
| Today cell (strip and grid) | Accent fill, OnAccent content |
| Selected ring | Background gap, Outline ring |
| "Make a note" | Accent, OnAccent, Outline, sticker in Outline |
| Day letters, counts, legend text, empty state, spill numbers, dialog time | TextSecondary |
| Your dot / partner's dot | `NoteDotMine` / `NoteDotPartner` (new, §6.3) |
| Pager | Outline (current), Divider (others), Outline ring |
| Scrim | black 42% (light) / 60% (dark) |
| Image placeholder | Divider |

No Highlight anywhere on this screen (D17).

### 6.2 Type

| Text | Style |
| --- | --- |
| "Notes" | `.largeTitle` heavy |
| Toggle label | `.subheadline` bold |
| "Make a note" | `.headline` bold |
| Strip day letter | `.caption` bold |
| Strip date, month day number | `.headline` bold, monospaced digits (spill: semibold) |
| Day header | `.title3` heavy |
| Count, summary legend, dialog time | `.subheadline` medium, monospaced digits |
| Summary line 1 | `.subheadline` bold |
| Month title | `.title3` heavy |
| Weekday letters | `.caption` bold |
| Empty state | `.headline` (TextSecondary) |
| Dialog name | `.headline` |

### 6.3 New tokens (R6, R8)

| Token | Light | Dark | On Surface (L / D) | On Accent (L / D) | Role |
| --- | --- | --- | --- | --- | --- |
| `NoteDotMine` | #2F6FDB | #79AEFF | 4.67 / 6.83 | 3.02 / 1.49* | Your notes' dot and legend dot |
| `NoteDotPartner` | #E5483B | #FF7A6E | 3.87 / 6.06 | 2.51 / 1.67* | Partner's notes' dot and legend dot |

\* On the today cell, the 1.5 pt OnAccent ring (11.6:1 against Accent) carries the shape. Position (left = you) and the legend words back up the colour, so colour is never the only signal.

The light partner value matches `NoteInkRed`, and the dark one matches dark `Danger`. They're separate tokens so Danger keeps meaning "something went wrong" and note ink can change on its own. NotePaperBlue was rejected for the dots: 1.4:1 on Surface.

### 6.4 Spacing and sizes summary (iPhone 11)

| Item | Value |
| --- | --- |
| Screen margin | 20 |
| Between title row, button, strip/card | 20 |
| Title row height | 48 |
| Toggle | 40 visible / 44 hit, padding 12 / 14, symbol 18 |
| Make a note | 56, full width, sticker 3,3 |
| Strip cell | ~48 × 74, gap 6, radius 14, border 2 |
| Mini-card | 15, radius 4, border 1.5, offset 2.5 / −1.5 |
| Selected ring | gap 2 + ring 2.5 |
| Strip → header → grid | 14 / 14 |
| Grid | 2 columns, gap 16, tile ~179, radius 20, border 2.5, avatar 24 at 8 |
| Empty state top | 56 |
| Month card | radius 22, border 2.5, padding 14 / 10 / 10 |
| Month cell | ~48 × 52, row gap 4, column gap 2, radius 14 |
| Day dots | 8, ring 1.5, gap 4, 5 below number |
| Summary | 20 below card, legend dots 10, 16 between items |
| Dialog card | 374 wide, padding 16, row gap 14, radius 28, border 2.5 |
| Dialog note | 338 square, radius 20, border 2.5 |
| Pager dots | 8, gap 8, ring 1.5 |

## 7. Motion and haptics

- **Mode switch (D15):** everything below "Make a note" cross-fades over 0.18 s ease-out, and the toggle's label and symbol cross-fade with it. Nothing slides, scales or bounces. The title and button don't move.
- **Selecting a day:** the ring fades out on the old cell and in on the new one, and the day content cross-fades, both over 0.15 s ease-out.
- **Week and month swipes:** these are direct manipulation. The content follows the finger and settles to the page with the system paging deceleration, with no overshoot animation added.
  - At a limit (§3.5) the page doesn't advance.
  - If the paging container shows the system edge resistance, accept it. Don't add any bounce of your own. Deviation from the mockup: the mockup shows a still page, but suppressing the system edge isn't worth custom scroll code.
- **Dialog open:** the scrim fades 0 → 1, and the card fades and scales 0.96 → 1, both over 0.2 s ease-out.
- **Dialog close:** a 0.15 s fade of both.
- **Dialog paging:** the system paging, as for swipes.
- **Arriving notes and loaded images:** a 0.15 s fade in.
- **Reduce Motion:** fades only. The dialog's scale is dropped; the cross-fades stay.
- **Haptics:** none on this screen, on taps, swipes, edges or the dialog (T3). The tab bar's own `.selection` is unchanged.

## 8. States

| State | What shows |
| --- | --- |
| Default on open | Week view, current week, today selected (state 1) |
| Day with notes | Header + count + newest-first grid |
| Empty day (past, today, future) | Header with "No notes" and "No notes yet" (state 3) |
| Past week | No Accent cell in the strip; the ring only (state 2) |
| Long day (5+ notes) | Grid scrolls under the fixed header, button and strip |
| Loading (first fetch, or a new week or month) | Strip and grid render with dates and empty cells. Tiles show the Divider placeholder at their final size (the count is known from the first query). Mini-cards and dots fade in. No spinner unless the fetch takes over 1 s; then a small `ProgressView` sits where the grid's first row would be |
| Load failed | In place of the grid: "Couldn't load notes. Try again", `.body` in TextSecondary, with a Small secondary "Try again" button. Mini-cards and dots stay empty. The toggle, strip paging and "Make a note" still work |
| Image failed | That tile keeps the Divider fill with a warning glyph and is still tappable; the dialog shows the same |
| Month with no notes | No dots; "No notes this month" / "No notes in September" and the legend with zeros |
| Earliest and latest page | Swipe does nothing (§3.5) |
| Spill day outside the limits | Greyed and not tappable |
| Dialog, one note | No pager, no paging |
| Dialog, first or last note | Paging stops at that end |
| Your own note in the dialog | Name reads "You" with your avatar (state 7) |
| A note arrives while open | Refetch or realtime insert with a 0.15 s fade; if it's for the selected day it appears first in the grid |
| Note unsent by the sender while shown | Disappears on the next refetch. If it's open in the dialog, the dialog closes |

No destructive actions exist in this ticket.

## 9. Accessibility

- **Touch targets:** the toggle is 44 hit, strip cells are 48 × 74, month cells are ~48 × 52, tiles are 179, and the dialog ✕ is 44. The scrim is the whole screen.
- **Contrast:** all text pairs are from design.md §3 and pass AA in both modes. Dots follow §6.3.
- **Spill days:** they're at 50% opacity on purpose, as a secondary hint. The same dates appear at full strength in their own month, and VoiceOver labels them fully.
- **Never colour alone:**
  - Today = Accent fill and the VoiceOver word "today".
  - Selected = a ring shape and the selected trait.
  - Dots = colour and position and the legend words.
- **VoiceOver:**
  - **Toggle:** "Show month, October" (week view) or "Show current week" (month view); button.
  - **Strip:** the whole strip is one adjustable element. Its label is "Week of 26 October", and its value is the selected day, e.g. "Thursday 29 October, today, 3 notes". Swipe up or down changes the selected day. There are custom actions "Previous week" and "Next week", each present only when allowed by §3.5. Each cell is reachable too, with a label like "Wednesday 28 October, no notes" and the selected trait.
  - **Day header:** a header trait.
  - **Tiles:** "Note from Sam, 9:20 am" or "Note from you, 8:05 am"; button; the hint "Opens the note".
  - **Month card:** custom actions "Previous month" and "Next month", within the limits.
    - Each day reads like "Tuesday 27 October, notes from Sam", "notes from you and Sam" or "no notes". Today adds "today".
    - Spill days add "September". Spill days outside the limits are not buttons.
  - **Summary:** read as one element: "23 notes this month, 11 from you, 12 from Sam".
  - **Dialog:** `.isModal`. Focus starts on the sender name. The note's label is "Note from Sam, Thursday 29 October, 9:20 am, note 1 of 3", with adjustable or scroll actions for the next and previous note. The ✕ label is "Close". The escape gesture (two-finger scrub) closes the dialog.
  - **Doodles:** none on this screen.
- **Dynamic Type:**
  - The title, header, counts, empty state, summary and dialog text scale fully.
  - The title row wraps at accessibility sizes, with the toggle moving under the title, leading-aligned.
  - The strip and month cells cap their text at `.accessibility1` and support the Large Content Viewer (`.accessibilityShowsLargeContentViewer`). Their widths are set by the screen, and growing them would break the week paging. This replaces design.md §12's "the week strip scrolls horizontally inside its own row", which conflicts with D2's paging.
  - At accessibility sizes the grid becomes one column (design.md §12).
- **Reduce Motion:** §7.
- **Reduce Transparency:** no effect, because nothing here is translucent apart from the scrim, which stays.

## 10. Acceptance criteria

- [ ] Opening the Notes tab shows the week view on the current week, Monday to Sunday, with today Accent and selected (ring) and today's notes below (D8, D11, D13, N1).
- [ ] The title row shows "Notes" and a Small secondary pill reading the selected day's month name with a `calendar` symbol. In the month view it reads "Current week" with `calendar.day.timeline.left` (D10, Q3, N6).
- [ ] "Make a note" is full width, 56 tall, with the sticker shadow, in both modes, and opens the new-note cover (D12).
- [ ] Strip cells show the day letter, date and up to 3 mini-cards cropped from the day's newest note images (D14, S1).
- [ ] Tapping any strip cell, including empty and future days, selects it. The ring and content cross-fade in 0.15 s, with no haptic (D16, D15).
- [ ] Swiping the strip pages by week. The same weekday stays selected (D2, D3).
- [ ] Swiping can't go before the week containing `pairs.created_at` or after the current week (Q4, N9).
- [ ] The day header reads "Thursday 29" with "3 notes", "1 note" or "No notes". It never reads "Today" (D1, N3).
- [ ] The grid is 2 columns, 16 pt gaps, newest first. Tiles have a 24 pt sender avatar and no tape, ring, badge or time (Q2, N2, N10, D17).
- [ ] An empty day shows "No notes yet" only (D16).
- [ ] The toggle cross-fades to the month view of the selected day's month in about 0.18 s, with no slide or bounce (D10, D15).
- [ ] The month grid is Monday-first. Spill days are greyed at 50% and open their week when tapped, if within the limits (D6, D8, D9).
- [ ] Each month day shows a left dot (`NoteDotMine`) if you sent a note that day and a right dot (`NoteDotPartner`) if your partner did. Places stay fixed. On today the dot rings are OnAccent (D7, N4, N5).
- [ ] The summary shows "N notes this month" (or "in <Month>") and the legend "X from you · Y from <partner>", counting only the month's own days (D6).
- [ ] Swiping the month pages by month, from the pairing month to the current month only (Q4).
- [ ] Tapping a month day switches to the week view with that week and day selected (D18).
- [ ] "Current week" always returns to the current week with today selected (D10). There is no other "Today" control (Q1).
- [ ] Tapping a tile opens the dialog over a scrim that covers the tab bar:
  - card 20 pt from the edges, radius 28, 2.5 pt Outline;
  - the sender avatar, name ("You" for your own), date and time, and ✕;
  - the note at full card width and a pager (F1, N7, D4).
- [ ] In the dialog, swiping left goes to the older note and right to the newer one, stopping at the ends. The header and pager update (D5, Q2).
- [ ] ✕ and a tap on the scrim close the dialog. Swipe down does nothing (N7).
- [ ] The dialog opens with a 0.2 s fade and 0.96 → 1 scale, and closes with a 0.15 s fade. With Reduce Motion there's no scale (§7).
- [ ] No haptic fires anywhere on this screen except the tab bar's own (D15).
- [ ] Unsent notes (`unsent_at` set) never appear in tiles, mini-cards, dots or counts (§3.6).
- [ ] Loading, load-failed and image-failed states match §8.
- [ ] VoiceOver labels, adjustable strip, custom actions and modal dialog match §9. At accessibility text sizes the grid is one column and the strip and month cells cap at `.accessibility1` with the Large Content Viewer.
- [ ] Checked in light and dark on the simulator with `adam@example.com`, which has seed notes. Add seed notes across at least two weeks and both senders if the seed lacks them (fixed UUIDs, CLAUDE.md).
- [ ] The build check passes (CLAUDE.md).

## 11. Open questions

None open. Closed:

1. **Q1, a quick way back to today:** no. "October" then "Current week", or swipe.
2. **Q2, tile order:** newest first. The dialog pages in the same order.
3. **Q3, label case:** "Current week".
4. **Q4, swipe range:** from the pairing month or week to the current month or week, using `pairs.created_at`.

### Follow-ups for other tickets

- **Note actions:** Favourite, Save to Photos and Unsend in the dialog (§4.8).
- **Outbox badge:** a queued badge on your own tile while it's still in the outbox (from the new-note spec).
- **Unseen ring and "New" badge:** need a seen state on notes (D17).

## 12. Proposed design-system changes (for design.md's decision log)

Ready-to-paste text for R2–R8:

1. **design.md §3, colour tokens:** add rows.
   - `NoteDotMine` *new* | #2F6FDB | #79AEFF | "Dot and legend for your own notes in the Notes month view".
   - `NoteDotPartner` *new* | #E5483B | #FF7A6E | "Dot and legend for your partner's notes in the Notes month view".
   - Add the contrast rows from §6.3.
2. **design.md §6 Week strip:** replace the last two bullets with:
   - "Mini-cards are 15 pt crops of the day's three newest note images, newest on top."
   - "Today is an Accent cell. The selected day has a 2 pt Background gap and a 2.5 pt Outline ring outside the cell. Today and selected shows both."
   - "Swiping pages by week; the same weekday stays selected."
3. **design.md §6 Note tile:** delete "**Doodle:** the tape strip sits on the newest tile in the Notes grid only." Add: "The Notes tab doesn't use the New ring until notes have a seen state."
4. **design.md §6, new "Dialog card":**
   - A centred Surface card, 20 pt from the screen edges, radius 28 (radius.sheet), with a 2.5 pt Outline, 16 pt padding and 14 pt between rows. There's no sticker and no blurred shadow.
   - The scrim is black at 42% (light) or 60% (dark) and covers the tab bar.
   - It closes with a 44 pt ✕ Icon circle button or a tap on the scrim.
   - It opens with a 0.2 s ease-out fade and a 0.96 → 1 scale, and closes with a 0.15 s fade. With Reduce Motion it's a fade only.
   - First use: the Notes note dialog.
5. **design.md §6, new "Day dots":**
   - Two fixed 8 pt places (left = you, right = partner), 1.5 pt Outline rings (OnAccent on an Accent cell), with a legend beside them.
6. **design.md §7 Notes:** replace with:
   - "The title and the month toggle pill, then the full-width sticker 'Make a note'."
   - "Then the week strip and the selected day's header and 2-column grid, or the month card with dots and a summary."
   - "There is no doodle."
   - "Spec: [notes-tab.md](../design/specs/notes-tab.md)."
7. **design.md §10:** set the `doodle-tape` row's "Where" to "Unused (removed from the Notes grid 2026-10-29); kept for later".
8. **design.md §12:** replace "the week strip scrolls horizontally inside its own row" with "week-strip and month cells cap at `.accessibility1` and use the Large Content Viewer".
9. **technical-spec "Colours":** add "Notes dots: `NoteDotMine`, `NoteDotPartner` (light and dark)".
10. **notes-widget-spec "Calendar":** replace the bullets with:
    - "The Notes tab shows a week strip with the selected day's notes (newest first) and a month calendar with a dot for each person who sent a note that day."
    - "Tapping a month day opens its week."
    - "Tapping a note opens a dialog that pages through that day's notes."
    - "Favourite, Save and Unsend come in a later ticket."
    - "Full design: [notes-tab.md](../design/specs/notes-tab.md)."
    - Keep the time-zone bullet.

## 13. Decision index

| Decision | Where |
| --- | --- |
| D1 week strip, selected day's 2-column grid with sender tags, "Thursday 29 · 3 notes" | §4.2, §4.3 |
| D2 swipe the strip for previous or next week | §3.2 |
| D3 same weekday stays selected | §3.2 |
| D4 tap tile → full-size view with sender and time only | §3.4, §4.6 |
| D5 the view swipes through the day's notes, opening on the tapped one | §3.4 |
| D6 month view, 7 columns, swipe for month, summary line | §3.3, §4.5 |
| D7 up to 2 dots, viewer-relative blue and red | §4.5, §6.3 |
| D8 weeks start Monday | §3.2, §4.5 |
| D9 spill days greyed, tap opens their week | §4.5, §3.5 |
| D10 toggle pill "October" / "Current week" | §4.1, §3.3 |
| D11 default: week view, current week, today | §3.1 |
| D12 "Make a note" at the top in both modes | §4.1 |
| D13 today is Accent in strip and grid | §4.2, §4.5 |
| D14 strip cells: letter, date, up to 3 mini-cards | §4.2 |
| D15 0.15–0.2 s crossfade, minimal motion, no haptics on taps | §7 |
| D16 empty and future days tappable, "No notes yet" | §4.4 |
| D17 no unseen ring or "New" badge | §4.3, §11 |
| D18 tap a month day → week view with that day | §3.3 |
| N1 selected = Outline ring; today = Accent | §4.2 |
| N2 (rewritten for Q2) newest first; tiles carry no doodle | §4.3 |
| N3 header never says "Today" | §4.3 |
| N4 fixed dot places; summary doubles as legend | §4.5 |
| N5 `NoteDotMine` / `NoteDotPartner`; OnAccent rings on today | §6.3 |
| N6 toggle is a Small secondary pill with a leading symbol | §4.1 |
| N7 (rewritten for F1) note view is a dialog card; ✕ or tap outside closes it; 0.2 s fade and scale | §4.6, §7 |
| N8 month cells have no outlines; only today is filled | §4.5 |
| N9 swipes stop at the paired and current edges, with no bounce, message or haptic | §3.5, §7 |
| N10 the Notes tab has no doodle | §4.1, R2, R5 |
| Q1 no separate "Today" control | §3.3 |
| Q2 newest first, in the grid and the dialog | §3.4, §4.3 |
| Q3 "Current week" | §4.1 |
| Q4 limits from `pairs.created_at` to now | §3.5 |
| F1 full-size note is a dialog over the dimmed tab | §4.6 |
| F2 remove the tape doodle | §4.3, R3, R5 |

### Decided in this spec (not covered by D, N, Q or F)

- **S1, mini-cards:** notes have no stored paper colour (`notes` holds only `image_path`). So the strip's mini-cards are 15 pt crops of the note images, the day's three newest, newest on top. The mockup's flat pastels stood in for these.
- **Month summary wording:** "this month" for the current month, "in September" otherwise. Counts cover the month's own days only.
- **Position memory:** you keep your place across tab switches. The tab resets to D11 on a new day only if you were on the old today.
- **Spill days outside the limits:** greyed and not tappable.
- **Swipe-edge resistance:** the system paging resistance at a limit is accepted (§7).
- **Strip and month cells at accessibility sizes:** text caps at `.accessibility1` with the Large Content Viewer, replacing design.md §12's horizontal-scroll rule.
- **Loading, error and image-failed states:** as in §8.
- **Unsent notes:** excluded everywhere. A note that is open when it's unsent closes the dialog on the next refetch.
