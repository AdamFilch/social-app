# buttercup design system

Oct 19, 2026 · approved by Adam · **Mockup**: https://claude.ai/artifact/C3QVDouTjcQZEoruGFxDqi (tokens and contrast; Calling, Notes and Hobbies homes in light and dark; component sheet in both modes)

The look: **Buttercup Field by day, Sticky Note by night.** Light mode is buttercup yellow, leaf green and warm cream with dark leaf-green ink outlines. Dark mode is Sticky Note's brown-black paper with cream ink, tuned so that yellow and green play the same roles. The mode follows the phone's system setting.

Sources: [product.md](product.md), [decisions.md](decisions.md) (T3–T6, T13, T17), [technical-spec.md](technical-spec.md) (Design system, Haptics, Motion), `Buttercup/ContentView.swift`. The colour tokens in section 3 are in `Buttercup/Assets.xcassets`. The shared components in section 6 haven't been built yet.

## 1. Brand personality

buttercup is a private app for two people. It should feel like something one of them made for the other.

- **Fun, quirky, minimal.** The fun is in shape and colour: thick ink outlines, a green "new" ring, one sticker-shadowed button, one small doodle. Layouts stay plain.
- **Still, not bouncy.** Playful at rest, quiet in motion. Colour fades, no springs or slides. Haptics only where T3 allows.
- **Warm and personal.** It always uses the partner's name and talks like a person.
- **References:** Locket (chunky borders, highlight rings), Note-it (pastel paper).

## 2. Principles

| Principle | Do | Don't |
| --- | --- | --- |
| Fun is visual, not animated | Outlines, rings, a sticker shadow, one doodle | Springs, bounces, wiggles, confetti, sliding indicators, idle loops |
| Yellow is for doing | Accent fills the thing you tap: call buttons, the primary button, the selected tab, a done chip | Yellow text, yellow backgrounds for whole cards or screens |
| Green is for new | Highlight rings and the "New" badge mark only what you haven't seen. They go away once seen | Green as a success colour, a selected state or decoration |
| One sticker per screen, at most | The sticker shadow marks the single creating action ("Make a note") | A sticker on each of several equal actions (Audio and Video, every +1) |
| One doodle per screen, at most | One static, decorative doodle near the title or on a tile | Several doodles, doodles you can tap, animated doodles |
| Content brings the colour | Notes, photos and NotePaper pastels carry most of the colour | Tinting chrome with pastels |
| Never colour alone | "Missed" with a crossed phone; "You read today" next to the check badge | A red icon or green dot as the only signal |
| Talk like a person | "Call Sam", "Couldn't reach Sam. Try again" | "Initiate call", "Error 503" |

## 3. Colour tokens

The six existing asset-catalog names first, then proposed additions (*new*). Each colour set has an Any (light) and a Dark appearance.

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| Accent | #FFC61A | #FFCB2E | Fill for tappable things: call buttons, primary button, selected tab pill, selected chip, progress fill. Never text. |
| Background | #FFF8E2 | #1B1814 | Screen ground, icon tiles, progress track |
| Surface | #FFFDF5 | #28241F | Cards, list groups, tab bar, sheets, secondary buttons |
| TextPrimary | #1E2A1A | #FFF8E2 | Titles, body, labels |
| TextSecondary | #56634F | #B7AC9E | Metadata, unselected tab labels |
| Danger | #C2362B | #FF7A6E | "Missed", "Unsend", error text and icons |
| OnAccent *new* | #1E2A1A | #1B1814 | Text and icons on Accent |
| Outline *new* | #1E2A1A | #EDE3CC | All borders, the sticker shadow |
| Highlight *new* | #377D33 | #8BD06E | "New to you" ring and badge fill |
| OnHighlight *new* | #FFFDF5 | #1B1814 | Text on Highlight (the "New" badge) |
| Divider *new* | #EDE6CC | #3A342D | 1.5 pt row dividers inside list groups |

**NotePaper pastels** (*new*, the same in both modes because they are part of the note image):

| Token | Hex | Also used for |
| --- | --- | --- |
| NotePaperYellow | #FFE88A | Book cover placeholder |
| NotePaperPink | #FFC6D9 | Partner's avatar tint (Sam) |
| NotePaperBlue | #BFDDFF | Your avatar tint (Adam) |
| NotePaperGreen | #C9EDB6 | Game cover placeholder |
| NotePaperLilac | #DCCDFF | TV cover placeholder |

Avatar tints are per person, not per device: each person keeps the same tint on both phones. The tint is saved on the profile (`profiles.avatar_tint`, Q23). Adam starts as blue and his partner as pink.

### How the two modes stay one brand

- Accent is buttercup yellow in both modes. Dark mode moves Sticky Note's lemon #FFD84A to #FFCB2E.
- Highlight is leaf green in both modes. Dark mode replaces Sticky Note's pink #FF8FB4 with #8BD06E.
- Light Background #FFF8E2 is the same colour as dark TextPrimary, so the cream that is paper by day is ink by night.
- Dark Outline is warmed to #EDE3CC to sit with the cream text. Sticky Note's #E9DFD1 was greyer.
- Light ink is a very dark leaf green (#1E2A1A), not black, so outlines feel related to the yellow.

### Contrast (WCAG 2.x)

| Foreground | Background | Needs | Light | Dark |
| --- | --- | --- | --- | --- |
| TextPrimary | Background | 4.5 | 14.11 | 16.66 |
| TextPrimary | Surface | 4.5 | 14.72 | 14.52 |
| TextSecondary | Background | 4.5 | 6.01 | 7.92 |
| TextSecondary | Surface | 4.5 | 6.26 | 6.91 |
| OnAccent | Accent | 4.5 | 9.52 | 11.65 |
| OnHighlight | Highlight | 4.5 | 4.98 | 9.56 |
| Danger | Surface | 4.5 | 5.35 | 6.06 |
| Danger | Background | 4.5 | 5.13 | 6.96 |
| Outline | Background | 3 | 14.11 | 13.86 |
| Outline | Surface | 3 | 14.72 | 12.08 |
| Highlight | Background | 3 | 4.77 | 9.56 |
| Highlight | Surface | 3 | 4.98 | 8.33 |
| Accent | Background | n/a | 1.48 | 11.65 |
| Divider | Surface | n/a | 1.23 | 1.25 |
| TextPrimary (light) | each NotePaper | 4.5 | 10.15–12.25 | same |

Everything passes AA. Two pairs are low on purpose:
- **Accent on Background (light)** is a fill colour. It always has an Outline around it and OnAccent text on it, so its own contrast doesn't carry meaning.
- **Divider** is a quiet hint. Rows are also separated by height (62 pt).

## 4. Type

SF Pro Rounded (T13): set `.fontDesign(.rounded)` once at the root. Use Apple text styles so Dynamic Type works; only the weights are custom. Headings are heavier than usual so they keep up with the 2.5 pt outlines.

| Role | Text style | Size at default | Weight | Example |
| --- | --- | --- | --- | --- |
| Screen title | `.largeTitle` | 34 | heavy | Calling |
| Partner name, hobby name | `.title2` / `.title3` | 22 / 20 | heavy | Sam, Reading |
| Section header | `.title3` | 20 | heavy | Recent calls, Today |
| Button label, row title, card heading | `.headline` | 17 | bold | Make a note, Video call |
| Body, empty states | `.body` | 17 | regular | No calls yet. Give Sam a ring? |
| Metadata | `.subheadline` | 15 | medium, TextSecondary | Yesterday · 42 min |
| Badge | `.footnote` | 13 | bold | New |
| Tab label, week-strip day letter | `.caption` | 12 | bold | Calling |

- Times, durations, dates and progress use `.monospacedDigit()`.
- Sentence case everywhere, including badges ("New", not "NEW"). No letter-spaced capitals.
- Titles are nouns ("Calling", "Notes", "Hobbies"), not greetings.

## 5. Scales

### Spacing (4 pt base)

| pt | Use |
| --- | --- |
| 4 | Icon to label inside a button |
| 8 | Inside chips; avatar to text in small rows |
| 12 | Between buttons; list icon to text; inside a hobby card |
| 16 | Card padding; gap between cards |
| 20 | Screen side margin |
| 24 | Section breaks; sheet padding |
| 32 | Large breaks, empty-state padding |

### Radius (continuous corners everywhere)

| Token | pt | Use |
| --- | --- | --- |
| radius.xs | 8 | Cover placeholders |
| radius.sm | 12 | Icon tiles (38 pt), week-strip day cells use 14 |
| radius.note | 20 | Note tiles: matches the small widget corner |
| radius.card | 22 | Cards, list groups |
| radius.sheet | 28 | Sheet top corners |
| radius.pill | full | Every button, chip, badge, tab pill, progress bar |

All buttons are pills, one shape for everything you tap. Nested shapes use the outer radius minus the padding.

### Border width

| Token | pt | Use |
| --- | --- | --- |
| border.hairline | 1.5 | Row dividers (Divider colour) |
| border.small | 2 | Chips, icon tiles, small buttons (40 pt), tab pill, avatars ≤ 28 pt, progress bar |
| border.default | 2.5 | Cards, buttons, note tiles, avatars ≥ 40 pt, tab bar top edge |
| ring | 3 + 3 gap | Highlight ring, drawn outside the item's own border |

Draw borders with `.strokeBorder` on `RoundedRectangle(cornerRadius:style: .continuous)` so they sit inside the frame and never shift layout.

### Sticker shadow

A solid copy of the shape in `Outline`, offset 3 pt right and 3 pt down, with no blur. Draw it as a second shape behind (not `.shadow()`, which blurs). Use it at most once per screen, on the single creating action.

| Screen | Sticker on |
| --- | --- |
| Calling | Nothing. Audio and Video are equal. |
| Notes | "Make a note" |
| Hobbies | Nothing. Every +1 is equal. |
| Sheets | The confirming action ("Send", "Add") |

## 6. Components

All touch targets are at least 44 × 44 pt. Where the visible shape is smaller, extend the hit area with `.contentShape`.

### Card

- Surface fill, 2.5 pt Outline, radius 22, padding 16, 14 pt between children.
- Cards never get a sticker shadow. Only a button does.
- A card that opens a detail screen uses the zoom transition from the tech spec. Its pressed state is a 0.1 s fade of the fill toward Background, with no scale.

### List group and row

- One card holds the rows, with padding 0 × 16. Rows are at least 62 pt tall, with a 1.5 pt Divider between them and none after the last.
- Row anatomy: a 38 pt icon tile (Background fill, 2 pt Outline, radius 12), a title (headline), a subtitle (subheadline, TextSecondary), and trailing metadata (subheadline, monospaced digits).
- Missed call: the icon tile glyph is `phone.down` in Danger, and the subtitle is the word "Missed" in Danger, bold.

### Buttons

| Variant | Size | Fill / text | Border | Notes |
| --- | --- | --- | --- | --- |
| Primary | 52 tall (56 when full-width on a screen) | Accent / OnAccent | 2.5 Outline | Sticker shadow. One per screen |
| Call | 56 tall, equal halves of the card | Accent / OnAccent | 2.5 Outline | No sticker. Icon `phone.fill` / `video.fill` + "Audio" / "Video" |
| Secondary | 52 tall | Surface / TextPrimary | 2.5 Outline | |
| Small | 40 visible, 44 hit | Surface / TextPrimary | 2 Outline | Inline actions, e.g. "Send one back" |
| Text | 44 hit | none / TextPrimary | none | Sheet "Cancel" |
| Destructive | Small or Secondary size | Surface / Danger | Outline | Icon + word, e.g. "Unsend". Always confirm first |

- **Pressed:** the fill mixes 12% OnAccent (or 6% TextPrimary on Surface buttons) and the sticker offset goes to 0, over 0.1 s ease-out. No scale, no spring, no haptic (T3).
- **Disabled:** 40% opacity, Outline kept, no sticker.
- **Loading:** the label is replaced by a `ProgressView` tinted OnAccent. The width doesn't change.
- **Large Dynamic Type:** at accessibility sizes, the call pair stacks vertically at full width.

### Tab bar (T6)

- Surface fill, a 2.5 pt Outline top edge, three equal tabs. Replaces `.background(.bar)` in `ContentView.swift`.
- Each tab has its own 60 × 34 pt pill behind a 21 pt icon, with a caption-bold label under it.
- Selected: the pill fills with Accent and gets a 2 pt Outline, the icon switches to `.fill`, and the label turns TextPrimary. Unselected: no pill fill, TextSecondary.
- Changing tabs fades the old pill out and the new one in over 0.15 s ease-out. Nothing moves between tabs.
- `.selection` haptic on change only.
- Icons: `phone` / `note.text` / `star`, with `.fill` versions when selected.

### Chips

- 36 pt visible, 44 pt hit area, pill, 2 pt Outline, headline-weight 15 pt label.
- Default: Surface fill. Selected or done: Accent fill, OnAccent text, a leading `checkmark`.
- Used for "Did it today?" / "Done today" and for hobby filters.
- **+1 button:** a 48 pt circle, Surface fill, 2.5 pt Outline, bold "+1". It is a button with `accessibilityLabel("Add one chapter")` (or "Next episode", "Add one hour").

### Avatar

- A circle with the person's initial (heavy weight) in TextPrimary (light) on their NotePaper tint, with an Outline border. Sizes: 56 (partner card), 40, 28 (hobby card header), 24 (note tile sender tag).
- **Did it today badge:** a 15 pt Accent circle with a check, 2 pt Outline, at the bottom right. It always comes with a sentence ("You read today · Sam hasn't yet").
- **Photo later:** a photo replaces the initial inside the same circle and border, clipped with `.clipShape(Circle())`. Layout doesn't change. Leave room for an image URL on `profiles` when that work starts.
- Accessibility label: the person's name.

### Note tile

- Square, radius 20 (the same corner as the small widget), 2.5 pt Outline. The note image is clipped inside.
- **Sender tag:** a 24 pt avatar, 8 pt in from the bottom-left corner.
- **New (unseen by you):** the 3 pt Highlight ring with a 3 pt gap. Where there is room, a "New" badge appears next to the tile. Both fade out over 0.15 s once you have opened the note.
- **Sizes:** 112 on the Calling card, half-width in the Notes grid (about 181 on iPhone 11), and full width in the note viewer.
- **Doodle:** the tape strip sits on the newest tile in the Notes grid only.
- **Accessibility label:** "Note from Sam, 12 minutes ago, new".

### Small widget

- 169 × 169 pt on iPhone 11. The note image is full-bleed, and the system clips the corners, so there is no border.
- A 28 pt avatar of the sender sits 10 pt in from the bottom-left corner.
- **Before the first note:** a Surface background, the flower doodle, "No notes yet" (headline) and "Ask Sam to send one" (footnote, TextSecondary), all centred.
- In dark mode the empty state uses the dark tokens. The note image never changes.
- Per-hobby widgets follow the same rules: Surface background, both avatars with done badges, the item title and a progress bar.

### Sheet

- System sheet with detents and `.presentationBackground(Surface)`, with 28 pt top corners. Keep the system grabber.
- **Header row:** "Cancel" as a text button on the left, the title (headline) in the centre, and the confirming action as a small primary pill with the sticker on the right ("Send", "Add").
- If the sheet has unsaved work (a drawn note), confirm before it is dismissed: "Discard this note?" with "Discard" (destructive) and "Keep drawing".

### Progress bar

- 12 pt tall, pill, 2 pt Outline, Background track, Accent fill, with a 2 pt Outline at the fill's end.
- It always comes with a text value ("Chapter 12 of 19") and `accessibilityValue`.

### Week strip (Notes)

- Seven cells, about 48 × 74 pt each, with 6 pt gaps, radius 14 and a 2 pt Outline on Surface.
- Each cell shows the day letter (caption), the date (headline, monospaced digits), and up to three stacked mini-cards in that day's NotePaper colours.
- Today is an Accent cell. Tapping a day opens that day's notes, as the calendar does.

## 7. Screens (as mocked up)

- **Calling:**
  - The partner card comes first: avatar, name, last call, and the equal Audio / Video pair.
  - Then the latest-note card: the tile with the ring, "New", "Note from Sam", the time, and a small "Send one back" button.
  - Then "Recent calls" as a list group.
  - The doodle is the flower next to the title. There is no sticker.
- **Notes:**
  - The title and month, then the full-width sticker primary "Make a note".
  - Then the week strip.
  - Then "Today" with a count, over a two-column grid of tiles with sender tags.
  - The doodle is the tape on the newest tile.
- **Hobbies:**
  - One card per hobby. The header has an icon tile, the hobby name and both avatars with done badges, and a status sentence sits under it.
  - Your current item has a cover placeholder, title, progress text, progress bar and a +1 button.
  - The partner's current item sits underneath in secondary text, with their avatar.
  - The doodle is the sparkle next to the title. There is no sticker.

These are design-system references, not feature specs. Each tab still gets its own spec run.

## 8. Motion and haptics

- **Colour and opacity fades only:**
  - Selection changes and rings: 0.15 s ease-out.
  - Button press: 0.1 s ease-out.
  - Default animation `.smooth` with no bounce.
- **No springs.** Replace the `.snappy` spring in `PressableButtonStyle` with the press fade above (see Proposed changes).
- **Zoom transitions** into detail screens stay as in the tech spec. With Reduce Motion on they become fades. Colour fades always stay.
- **Nothing idles, loops or animates in on load.** Doodles are static.
- **Haptics exactly as T3:**
  - `.selection` on tab change.
  - `.success` when a call connects or a note is sent.
  - `.error` on failure.
  - `.impact(weight: .light)` when a sticker drops.
  - Nothing on ordinary buttons, chips or +1.

## 9. Iconography

- SF Symbols at **semibold** weight, 17–21 pt, so their strokes match 2.5 pt outlines.
- Use outline symbols by default and `.fill` only for the selected tab and inside Accent call buttons.
- Icons in tiles: `video`, `phone`, `phone.down` (missed), `book`, `tv`, `gamecontroller`.
- Actions: `pencil.tip` (make or reply to a note), `checkmark` (done), `trash` (unsend), `heart` (favourite).
- Every icon has a visible label next to it or an `accessibilityLabel`. Decorative icons beside text are hidden.

## 10. Doodles and stickers

Four SVG assets, drawn once and exported as template-free PDF or SVG in the asset catalog. Each has a light and a dark appearance: its fill uses Accent or Highlight, and its strokes use Outline (2.4 pt at 40 pt artboard).

| Asset | Size | Where |
| --- | --- | --- |
| `doodle-flower` | 34 pt | Next to the Calling title; empty widget; empty states about calls |
| `doodle-sparkle` | 30 pt | Next to the Hobbies title; "all done today" moments |
| `doodle-tape` | 52 × 18 pt | Across the top edge of the newest note tile in the Notes grid |
| `doodle-squiggle` | 110 × 14 pt | Under a title in onboarding and pairing screens |

**Rules for doodles:**
- At most one per screen.
- Always `.accessibilityHidden(true)` and `.allowsHitTesting(false)`.
- Never animated.
- Never on top of text.

**Face-effect stickers** in calls and notes are content, not chrome, and are outside this system.

## 11. Voice and microcopy

- Lowercase **buttercup** everywhere.
- **Use the partner's name.** Never "partner" or "user": "Call Sam", "Note from Sam", "Sam is calling".
- **Empty states suggest the next step:**
  - "No calls yet. Give Sam a ring?"
  - "No notes yet. Draw Sam something?"
  - "Nothing on the go. Add a book?"
- **Errors say what happened and what to do, with no exclamation marks:**
  - "Couldn't reach Sam. Try again"
  - "Note didn't send. It'll go when you're back online"
- **Destructive actions say exactly what happens:** "Unsend (you have 3 h 12 min)". The confirmation reads "Unsend this note? It disappears from Sam's widget too."
- **Status sentences sit next to visual signals:**
  - "You read today · Sam hasn't yet"
  - "You both watched today"
  - "No one has played today"
- **Buttons say what happens:** "Make a note", "Send", "Done today". Never "Submit" or "OK".

## 12. Accessibility checklist

- All text pairs pass AA in both modes (section 3). Outlines and rings pass 3:1.
- Touch targets are at least 44 pt. Call buttons are 56, rows 62, +1 is 48 and chips have a 44 pt hit area.
- Nothing is shown by colour alone: missed, new, done and selected each have a word or a symbol change.
- Dynamic Type at all sizes. At accessibility sizes the call pair stacks, the Notes grid becomes one column and the week strip scrolls horizontally inside its own row.
- With Reduce Motion, zooms become fades. Nothing else moves anyway.
- VoiceOver labels:
  - Avatars use the person's name.
  - Note tiles use the sender, the time and whether it's new.
  - +1 buttons name the unit.
  - The progress bar gives its value.
  - Doodles are hidden.

## 13. Changes from the draft (2026-10-19 run 1)

- Chose one direction: Buttercup Field light with Sticky Note dark. The dark Accent, Highlight and Outline are tuned to match the light roles.
- Audio and Video are equal Accent pills with no sticker. The sticker moved to the single creating action per screen.
- All buttons are now pills; the draft had 16 pt corners.
- "NEW" became "New" (sentence case).
- Avatar is an initial on a stable per-person NotePaper tint, with a photo later in the same frame.
- Added the `OnAccent` token (it replaces the "ink on accent" rule) and the NotePaper pastels as tokens.
- Added the components the draft lacked: chips, +1, progress bar, week strip, widget, sheet.
- The taste-skill plugin files were read directly. It couldn't be loaded as a skill this session, and `brandkit` is only a "moved" stub. Taken from it:
  - Sentence case instead of tracked capitals.
  - One decided button shape.
  - Nouns as titles.
  - People shown as stable initials with tints.
  - One ground, one ink, one accent.
- Not taken, because the brief wins:
  - Its bans on outlines and on shadows at rest. The Locket outlines and the sticker shadow are the brand.
  - Its springs, scroll reveals and staggered entrances. They conflict with quiet motion.
  - Its non-rounded fonts. SF Pro Rounded is T13.

## 14. Design-system changes (applied to technical-spec.md)

Applied on 2026-10-19 to [technical-spec.md](technical-spec.md) and [decisions.md](decisions.md) (T17, Q23). For item 8, the avatar tint is saved on the profile.

1. **Design system › Colours:** fill the six existing tokens with the values in section 3. Add `OnAccent`, `Outline`, `Highlight`, `OnHighlight`, `Divider` and the five `NotePaper*` colours. This resolves T5's "Adam picks the values later".
2. **Design system › Look:** add "Buttercup Field light / Sticky Note dark; mode follows the system setting".
3. **Design system › Shared constants** in `ButtercupKit`:
   - Spacing 4/8/12/16/20/24/32.
   - Radius 8/12/20/22/28/pill (continuous).
   - Border 1.5/2/2.5.
   - Ring 3 + 3 gap.
   - Sticker offset 3,3.
4. **Design system › Shared components** in `ButtercupKit`:
   - `Card`
   - `ListGroup` and `ListRow`
   - `PillButtonStyle` (primary, call, secondary, small, text, destructive)
   - `StickerShadow` modifier
   - `HighlightRing` modifier
   - `Chip`
   - `PlusOneButton`
   - `Avatar` (initial now, photo later)
   - `NoteTile`
   - `ProgressBar`
   - `Doodle` (the four assets)
5. **Haptics › PressableButtonStyle:** replace "scale 0.96 with a `.snappy` spring" with "fill darkens and sticker offset goes 3 → 0 over 0.1 s ease-out; no scale". The haptic table is unchanged.
6. **Motion:**
   - Default animation `.smooth` with no bounce.
   - Selection and new-item rings fade over 0.15 s ease-out.
   - Nothing idles, loops or animates on appear.
7. **Motion › Tab bar:** per-tab pills that cross-fade (no shared moving indicator), the selected icon uses `.fill`, Surface background with a 2.5 pt Outline top edge. This replaces `.background(.bar)` and `Color.primary/.secondary` in `ContentView.swift`.
8. **Database › profiles (later):** an optional `avatar_path` for the photo avatar, and optionally an `avatar_tint` if the fixed tint per person should be stored rather than assigned.
9. **Decision log:** add a T-decision: "Brand look is Buttercup Field (light) / Sticky Note (dark); sticker shadow at most once per screen; all buttons are pills."
