# [30]: Calling tab restyle

**Depends on:** [29]: In-call restyle merged (shared `DesignSystem/` components), and [19]: Note dialog merged (`NoteDialog`, `OpenNotes`).

This ticket gives the Calling tab the buttercup look from the approved design-directions mockup ([.claude/design/mockups/design-directions.html](../design/mockups/design-directions.html), the `SCREENS.calling` markup, artifact https://claude.ai/artifact/C3QVDouTjcQZEoruGFxDqi) and [design.md](../context/design.md) §5–§7 and §10. The tab opens on "Calling" with the flower doodle beside it and today's date. Below that are three blocks:

- **Partner card:** avatar, name, "Last call yesterday · 42 min", and the equal Audio / Video pills.
- **Latest-note card:** the partner's newest note as a 112 pt tile. It has a Highlight ring and a "New" badge until you open it, and a small "Send one back" button.
- **Recent calls:** a list group of icon-tile rows. Missed calls show `phone.down` and the word "Missed" in Danger.

"Sign out" moves from the bottom of this tab into the Settings tab.

The outgoing screen and incoming sheet are restyled separately in [[31]: Outgoing and incoming restyle](31-call-ringing-screens-restyle.prd.md).

## Summary
A restyle of [3]'s plain `List` Calling tab into the mockup layout, plus two small new pieces. The first is the latest-note card, with an on-device "seen" flag (D2). The second is the first doodle asset, `doodle-flower`. Call logic in `CallStore` is unchanged, and so is the notes read path in `NotesStore`. There are no backend changes.

## Users
- **Primary**: Adam and his partner opening the app to call each other or to glance at the latest note.
- **Not for**: the outgoing, incoming and in-call screens ([31], [29]).

## Scope
**MVP**
- Title row with `doodle-flower` and the date
- Partner card with last-call subtitle and the equal call pair (stacking at accessibility sizes)
- Latest-note card with the New ring and badge (local seen flag), opening `NoteDialog`, and "Send one back" opening `NewNoteView`
- Recent calls list group with icon tiles
- Sign out moved to Settings → Account
- `doodle-flower` asset (light and dark) and a tiny `Doodle` view

**Out of scope**
- Outgoing and incoming screens: [31]
- A server-side seen state, or syncing "seen" between devices (D2)
- Call history paging, call detail screens or calling back from a row
- `doodle-sparkle`, `doodle-squiggle` and `doodle-tape`: these ship with the screens that use them

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [Behaviour](#behaviour)
4. [Blast Radius](#blast-radius)
5. [File Reference](#file-reference)
6. [Acceptance Criteria](#acceptance-criteria)
7. [Required Changes](#required-changes)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D1 | Ticket split | [30] Calling tab home; [31] outgoing + incoming | Small PRs; the tab has a mockup, the ringing screens don't | User |
| D2 | Latest-note "New" state | `@AppStorage("lastSeenNoteID")` on the device; ring + "New" while the partner's newest note id differs; opening it (tile tap) sets it | Notes have no seen state (Notes spec D17); a local flag needs no schema change | User |
| D3 | Sign out | Moves to Settings as an "Account" section; removed from Calling | The mockup has no Sign out; Settings exists now | User |
| D4 | Latest-note window | Newest partner note in the last 30 days via `NotesStore.notes(in:)`; card hidden if none | Reuses the existing read; no new query | Claude |
| D5 | Last-call subtitle | From the newest `calls.history` row: "Last call {relative day} · {duration}" for answered calls, "Missed call {relative day}" for missed, "No calls yet" when empty | The mockup shows the answered form; the rest follows the voice rules (design.md §11) | Claude |
| D6 | Doodle asset | Vector SVG imageset `doodle-flower` with light/dark appearances, traced from the mockup's `DOODLE.flower` | design.md §10 | Claude |
| D7 | Container | `ScrollView` + `VStack` on `Background` instead of `List` | Cards and list groups are custom shapes (design.md §6) | Claude |

## Overview
```
┌───────────────────────────────┐
│ Calling ✿            Mon 19 Oct│  largeTitle heavy · doodle 34 · subheadline TextSecondary
│ ┌───────────────────────────┐ │
│ │ (S) Sam                   │ │  Avatar 56 + Outline 2.5 · headline
│ │     Last call yesterday·42m│ │  subheadline TextSecondary
│ │ [☎ Audio ]   [▶ Video ]   │ │  call pair, 56 tall, equal halves, no sticker
│ └───────────────────────────┘ │
│ ┌───────────────────────────┐ │
│ │ ╔═════╗  (New)            │ │  112 tile, 3 + 3 Highlight ring when unseen
│ │ ║ note║  Note from Sam    │ │  headline
│ │ ╚═════╝  12 min ago       │ │  subheadline TextSecondary
│ │          [✎ Send one back]│ │  small secondary pill
│ └───────────────────────────┘ │
│ Recent calls                  │  title3 heavy
│ ┌───────────────────────────┐ │
│ │ [▶] Video call    9:12 pm │ │  rows ≥ 62, 1.5 Divider between
│ │     Today · 38 min        │ │
│ │ [☏̸] Audio call    2:04 pm │ │  phone.down + "Missed" in Danger, bold
│ │     Missed                │ │
│ └───────────────────────────┘ │
└───────────────────────────────┘
```
Content padding is 16 pt horizontally, with 16 pt between blocks. The tab bar is unchanged.

## Behaviour
### Title row
- "Calling" in `.largeTitle` heavy, with `doodle-flower` at 34 pt and 6 pt after it. It is not a navigation bar.
- Trailing: today as "Mon 19 Oct" (`Date.FormatStyle` weekday abbreviated, day, month abbreviated; device locale), `.subheadline` semibold, TextSecondary.

### Partner card
- Card: Surface, 2.5 pt Outline, radius 22, padding 16, 14 pt between children.
- Header row:
  - `Avatar(profile: partner, size: 56, outline: 2.5)`.
  - Name in `.headline`.
  - Subtitle in `.subheadline`, TextSecondary, following D5.
- Call pair:
  - Two `Button`s with `PillButtonStyle(height: 56)` (primary, no sticker), equal widths.
  - Labels `Label("Audio", systemImage: "phone.fill")` / `Label("Video", systemImage: "video.fill")`.
  - Each calls `calls.startCall(video:)` as today.
  - Disabled when `calls.phase != .idle` or `session.partner == nil`. `PillButtonStyle` already renders 40% opacity.
- At `dynamicTypeSize.isAccessibilitySize` the pair is a `VStack` of full-width pills.

### Latest-note card
- Data:
  - On appear and on each `NotesStore.changes()` tick, fetch `notes(in: last 30 days)` and take the first row whose `senderId == session.partner?.id`.
  - Keep that day's notes (same calendar day as the latest), newest first, for the dialog.
  - If there are none, the card isn't shown. A fetch error keeps the previous value.
- Layout: a Card holding an `HStack(alignment: .top, spacing: 14)`.
- Tile:
  - `NoteImage(note:)` at 112 × 112, radius 20, 2.5 pt Outline.
  - **Unseen:** `note.id.uuidString != lastSeenNoteID`. Draw a 3 pt Background gap, then a 3 pt Highlight ring outside the tile's border (design.md §5 "ring"), so the layout doesn't shift.
  - Tapping the tile sets `lastSeenNoteID` and opens the note dialog through the root `openNotes` binding: `OpenNotes(notes: dayNotes, current: note.id)`. The ring fades out over 0.15 s.
- Meta column:
  - "New" badge (shown only when unseen): a Highlight pill with OnHighlight text, `.caption` bold, 2 pt Outline.
  - "Note from {name}" in `.headline`.
  - A relative time ("12 min ago", `.relative(presentation: .named)`) in `.subheadline` TextSecondary.
  - "Send one back": `PillButtonStyle(kind: .secondary, size: .small)` with `pencil.tip`. It presents `NewNoteView` as a `fullScreenCover`, exactly as `NotesTab` does (`isComposing`, plus the same `onSent` toast hook passed down from `ContentView`).
- Accessibility:
  - The tile is one element: "New note from Sam, 12 min ago" (or the same without "New"), with the button trait and the hint "Opens the note".
  - The badge is hidden from VoiceOver because the tile label carries it.

### Recent calls
- Header "Recent calls" in `.title3` heavy, with 24 pt above it and 10 pt below.
- List group: one Card with padding 0 × 16. Rows are at least 62 pt, with a 1.5 pt Divider between rows and none after the last.
- Row:
  - 38 pt icon tile: Background fill, 2 pt Outline, radius 12, semibold 19 pt symbol.
    - Answered or other: `video` / `phone` in TextPrimary.
    - Missed: `phone.down` in Danger.
  - Title: "Video call" / "Audio call" in `.headline`.
  - Subtitle, `.subheadline`:
    - Answered: "{Today / Yesterday / Mon 12 Oct} · {N min}" in TextSecondary.
    - Missed: "Missed" in Danger, bold.
    - Declined / cancelled: "Declined" / "Cancelled" in TextSecondary.
  - Trailing: the start time ("9:12 pm", device locale) in `.subheadline`, monospaced digits, TextSecondary.
  - A row is not tappable.
- Empty history: a Surface card with the flower doodle, "No calls yet" (`.headline`) and "Give {name} a ring?" (`.footnote` TextSecondary), centred. The doodle in the title row is hidden while this card shows, so the screen keeps one doodle (design.md §10).
- `calls.history == nil` (still loading): the section isn't shown.

### Sign out (Settings)
- `SettingsView` gets a second `Section("Account")` with `Button("Sign out", role: .destructive) { Task { await session.signOut() } }`.
- Remove the Sign out section from `CallingView`.

### Motion and haptics
- Nothing animates on load. Pressed buttons use the existing 0.1 s fill fade. No haptics (T3).

## Blast Radius
- `Buttercup/Calling/CallingView.swift`: rewrite the body. Keep `Avatar` where it is, since `NoteTile`, `InCallView` and others use it. Replace `CallRow` with the new row.
- `Buttercup/ContentView.swift`: pass `open: $openNotes` and `onSent: showToast` into `CallingView`.
- `Buttercup/SettingsView.swift`: the Account section. It needs `@Environment(SessionStore.self)`.
- `Buttercup/Assets.xcassets/doodle-flower.imageset/`: new.
- `Buttercup/DesignSystem/Doodle.swift`: new, about 10 lines.
- `.claude/context/features.md`: §1 step 6 ("Sign out: a button on the Calling tab") becomes Settings, and §2 step 6 describes the new tab.
- No changes to `ButtercupKit`, `supabase/` or the seed.

## File Reference
| File | Use |
| --- | --- |
| `Buttercup/DesignSystem/Buttons.swift` | `PillButtonStyle` (call pair, Send one back) |
| `Buttercup/Notes/DayGrid.swift` | `NoteImage` for the tile |
| `Buttercup/Notes/NoteDialog.swift` | `OpenNotes`, `NoteDialog` |
| `Buttercup/Notes/NotesTab.swift:106` | The `fullScreenCover` + `NewNoteView` pattern to copy |
| `ButtercupKit/.../NotesStore.swift` | `notes(in:)`, `changes()` |
| `ButtercupKit/.../CallStore.swift` | `history`, `loadHistory()`, `startCall(video:)`, `phase` |
| `.claude/design/mockups/design-directions.html` | `SCREENS.calling`, `DOODLE.flower` |
| `.claude/context/design.md` | §5 radii, borders and ring; §6 Card, List row and Buttons; §7 Calling; §10 Doodles |

## Acceptance Criteria
Run `supabase db reset && supabase/seed-notes.sh`, then sign in as `adam@example.com` on the iPhone 17 simulator.

- [x] AC1: The tab matches the mockup in light and dark: title, doodle and date; the partner card; the latest-note card; Recent calls. Check with screenshots in both modes.
- [x] AC2: The subtitle follows D5 for the seed history. With every call deleted locally (`delete from calls`), it reads "No calls yet" and the empty Recent calls card shows the doodle, with no doodle by the title.
- [x] AC3: Audio and Video each start a call (the outgoing screen appears). Both are at 40% while a call is active.
- [x] AC4: The latest-note card shows partner note `b0000000-0000-0000-0000-000000000002` with the Highlight ring and "New".
- [x] AC5: Tapping the tile opens `NoteDialog` on that note, with today's partner and own notes pageable. After closing, the ring and badge are gone, and they stay gone after a relaunch.
- [x] AC6: A new note sent from partner (second simulator) appears in the card with "New" without restarting the app.
- [x] AC7: "Send one back" opens New Note; sending shows the same toast as the Notes tab.
- [x] AC8: Missed rows show `phone.down` and the word "Missed" in Danger. Answered rows show the day and duration.
- [x] AC9: Sign out is gone from Calling and works from Settings → Account.
- [x] AC10: At an accessibility text size the call pair stacks full width and nothing clips. VoiceOver reads the note tile label, and the doodle is skipped.
- [ ] AC11: Builds with the build check in CLAUDE.md. The iOS 18 runtime launches the tab.

## Required Changes
- **Calling tab**: Behaviour §Title row, §Partner card, §Latest-note card, §Recent calls.
- **Settings**: Behaviour §Sign out.
- **Asset**: `doodle-flower` and `Doodle` (`accessibilityHidden(true)`, `allowsHitTesting(false)`).
- **Docs**: update `features.md` (Blast Radius).
- **Don't commit** local `Buttercup.xcodeproj` or `Config/Local.xcconfig` edits.

## Features Catalog
- **Extends**: #1 Foundation (Sign out moves), #2 Calls (Calling tab)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The "seen" flag differs between two devices on one account | Low | "New" shows again on the other device | Accepted (D2); a server seen state can come later |
| A 30-day fetch on every `changes()` tick | Low | Extra requests | `notes(in:)` returns a few dozen rows; same pattern as `DayGrid` |

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ✅ done | Light and dark screenshots on iPhone 17 (iOS 26.1) as adam: title + flower + "Sat, 7 Nov", partner card, latest-note card with ring and badge, Recent calls rows |
| AC2 | ✅ done | Seed history reads "Last call today · 1 min"; with an answered row deleted it reads "Missed call today"; after `delete from calls` it reads "No calls yet", the empty card shows the doodle and the title has none |
| AC3 | ✅ done | Audio and Video each showed "Calling Partner…"; while ringing both pills were disabled in the UI tree (the outgoing screen covers the tab, so the 40% opacity from `PillButtonStyle` is not visible) |
| AC4 | ✅ done | Card showed `b0000000-…0002` (14.36) with the ring and "New"; VoiceOver label "New note from Partner, 5 hours ago" |
| AC5 | ✅ done | Tile opened `NoteDialog` on 14.36 and paged to 10.48 and to adam's 18.24; after closing and relaunching the ring and badge stayed gone |
| AC6 | ✅ done | partner@example.com on a second simulator (iPhone 17 Pro) sent a note; adam's card switched to it with "New" and "now" without a restart |
| AC7 | ✅ done | "Send one back" opened New Note; sending showed the "Sent to Partner" toast |
| AC8 | ✅ done | Local test rows: missed shows `phone.down` and bold "Missed" in Danger; answered shows "Yesterday · 42 min" |
| AC9 | ✅ done | No Sign out on Calling; Settings → Account → Sign out returned to the email screen |
| AC10 | ✅ done | At AX5 the call pair stacks full width, the note card and call rows stack their contents and nothing clips; the tile reads as one element with its label, the doodle is absent from the accessibility tree |
| AC11 | ⚠️ unverified | Build check passes; no iOS 18 simulator runtime is installed, so the iOS 18 launch was not run |

### Needs attention
- Install an iOS 18 simulator runtime (Xcode → Settings → Components), launch the app on it as adam@example.com and check the Calling tab, then move this PRD to `completed/`.

*Status: PARTIAL — PR #28*
