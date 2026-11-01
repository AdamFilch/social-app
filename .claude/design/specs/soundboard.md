# Sounds: shared soundboard tab, recording, editing and the in-call Sounds tray

Oct 31, 2026 · approved by Adam (mockup v2) · designer run 2
**Mockup**: https://claude.ai/artifact/Ud9W7ujkQKhMEdk4qtiRFZ (v2, 13 phones, all in light and dark through the page switch):
- Sounds tab: empty first run; full grid with one sound playing; long-press menu; reorder drag.
- Record and name: recording dialog with the 10 s countdown; "Name this sound" empty (Save disabled) and filled (Save enabled, playing back); "Discard this sound?" confirm.
- Edit and delete: Edit sheet with name, emoji and trimmer; delete confirm.
- In a call: tray on Sounds with one playing; tray recording both voices; audio call with the tray on Sounds and the face pills dimmed; the partner's "Adam is recording" pill.
- The four-tab bar in both modes.

**Source**: [mockups/sounds.html](../mockups/sounds.html)
**Decision log**: `~/.claude/plans/please-start-working-on-elegant-raven.md`
**Decisions**:
- S1–S30: Adam's drill (S26–S30 settled by Claude as straightforward).
- M1–M18: the designer's, approved with the mockup.
- A1–A5: Adam's answers to the mockup v1 questions.
- F1–F5: the mockup's flags against design.md, all resolved.
- All are indexed in §13.

**Depends on:** [in-call-screen.md](in-call-screen.md) for the tray (tickets [5]/[6], not built yet), [notes-tab.md](notes-tab.md) for the Dialog card, PRD 15 for the outbox.

## 0. Revisions to existing docs

This spec changes the documents below. The in-call spec (R1–R5) is a design spec that isn't built yet, so it **has been edited** here, with each passage marked *(amended: soundboard)*. The `.claude/context/` documents (R6–R10) are **not** edited here: tickets paste in the text from §12.

| # | Document and current text | Replaced by | Decision |
| --- | --- | --- | --- |
| R1 | in-call-screen.md §0 R4 / C15, §4.1 "Order": "In state C: Stickers · Mute · Camera · Audio route · End call" | The Stickers button is first in the bar in **every** call state: Stickers · Mute · Camera · Route · End. Applied | A1, F1 |
| R2 | in-call-screen.md §3.3 steps 1–2 and N7: "The tray opens on the last tab used in this app session" | Still the last tab used, except when stickers aren't possible (audio call, camera off, back camera) or the partner is big: then it opens on Sounds. With the partner big and your front camera on, a face tab first swaps your view big (state C). Applied | A1, M17, M18 |
| R3 | in-call-screen.md §8 "Camera off (yours)" and "Back camera": "The Stickers button and Add stickers are disabled (40%)" | Only Add stickers on the medium tile is disabled. The Stickers button opens the tray on Sounds with the face tabs at 40% and the line "Stickers come back when your camera's on". The 10-sticker cap and the heat pause never touch Sounds. Applied | A1, M17 |
| R4 | in-call-screen.md §0 R5, §5 `EffectTab`: "Stickers · Emoji · Text · Draw · Hats · Glasses" | `… · Glasses · Sounds`. `EffectTab.needsFace` is false only for `sounds`. Applied | S1, M11 |
| R5 | in-call-screen.md §9 "Stickers (bar)" label "Add stickers", disabled hint | The bar button reads "Effects and sounds" and is never disabled. Applied | A1 |
| R6 | design.md §6 Tab bar: "three equal tabs"; icons `phone` / `note.text` / `star` | Four equal tabs: Calling · Notes · Sounds · Hobbies; Sounds uses `speaker.wave.2` | S15, M14, F5 |
| R7 | design.md §3 colour tokens (no "playing" fill) | New token `PlayTint` (§6.3) | M3 |
| R8 | design.md §5 Sticker shadow, §6 Dialog card, §6 Buttons "Destructive: Always confirm first" | A creating tile under a scrim drops its sticker shadow. A Dialog card may ignore scrim taps while it holds unsaved work. Discarding a fresh recording confirms like any destructive action | F3, F4, A3 |
| R9 | technical-spec §1 Motion: "Custom bottom tab bar (Calling / Notes / Hobbies)"; §3 RLS "write only your own"; §3 Realtime publication; §4 (images only) | Four tabs; `sounds` is the one user table either partner may update and delete; `sounds` joins the realtime publication; a new "Sounds (audio)" section | S15, S23, S26–S29 |
| R10 | Decision log S9: "Name this sound" **sheet** | A step inside the recording Dialog card, above the keyboard (a sheet over a dialog would stack two modal styles). Approved with mockup v1 | S9, M6 |

## 1. Problem and goal

Adam and his partner want little in-jokes on tap: Miso's meow, a laugh, "ba dum tss". Nothing in buttercup holds audio today, and calls carry only voices.

Goal:
- A shared board of short clips that either of you records in two steps (record, name) and that turns up on both phones.
- One tap plays a sound: for you alone outside a call, for both of you in a call.
- Fixing a sound later (rename, trim, emoji) never slows down saving a new one.

## 2. User and situation

- **Who:** Adam and Sam, each on an iPhone 11.
- **Outside a call:** on the sofa or in bed, one hand, relaxed. Usually a quick visit: play one, maybe record one, leave. Sometimes the ringer switch is on silent (A2).
- **In a call:** mid-conversation, phone held or propped, eyes on the partner. The sound has to land now, so the tray stays open and a tap is the whole gesture (S25).
- **Job:** play a clip at the right moment, or catch a funny moment (alone, or both voices in a call) before it's gone.
- **What matters most:** tap speed and recognising a tile at a glance (emoji + title, S22). Recording has to be one tap away and impossible to lose by a stray touch.
- **Constraints:** design.md (tokens, one sticker per screen, quiet motion, T3 haptics), S1–S30, A1–A5, the in-call spec, iPhone 11 heat (calls already run ARKit and effects), 10 s max (S6). Out of scope: push notifications for new sounds (S23), voice effects (video-calls-spec, after v1), sounds in the note composer (S1).

## 3. Flow

### 3.1 Entry

- **Tab:** the bar's third tab, Sounds (S15). It opens on the grid at the top. You keep your scroll position across tab switches.
- **Call:** the Stickers button in the control bar (R1), then the Sounds pill (last in the row, M11). Or the tray opens straight on Sounds when stickers aren't possible (R2).

### 3.2 Play (tab and tray)

1. Tap a tile: it plays from `trim_start_ms` to `trim_end_ms`.
   - Outside a call: on your phone only (S3), through the `.playback` audio session, so it plays with the silent switch on (A2). It ducks nothing; other audio is interrupted the system way.
   - In a call: played locally and sent to the partner through the call audio (S2), even while you're muted (S24). The partner gets no visual cue (A5).
2. The tile fills with PlayTint left to right at the clip's real pace and shows a stop badge (M3).
3. Tap the same tile: it stops (S14). Tap another: the first stops and the new one starts (S14).
4. When it ends, the tint fades out. The tray stays open (S25).
5. The file comes from the App Group cache (S29). If it isn't cached yet (a sound Sam added moments ago), the tile downloads it first; see §8.

### 3.3 Record and name, outside a call

1. Tap "+ Record" (S16). The first time, iOS asks for the microphone. Denied: the dialog shows the denied state (§8).
2. Recording starts at once (M4) from the mic only (S30). The Dialog card opens over the dimmed tab with the countdown track and Stop (§4.5).
3. Tap Stop (S8), or reach 10 s and it stops by itself (S6).
4. The card crossfades to "Name this sound" and rides above the keyboard (M6, R10). The field has focus.
5. Optional: Play to re-listen (S9).
6. Type a title. Save turns on when it has a non-space character (S9).
7. Save (or Return): the card closes. The new tile appears right after "+ Record" (S20), on both phones (S23). The write goes through the outbox (S28).
8. Way out: Discard, or ✕ while recording (recording stops at that moment), opens "Discard this sound?" (A3). Keep returns to naming with the keyboard up. Discard closes everything; nothing is stored.
9. Leaving the app while recording or naming discards the clip, with no prompt (same rule as S21). Scrim taps do nothing during steps 2–6 (F4).

### 3.4 Long-press menu, edit and delete (tab only)

1. Long-press a sound tile: the system context menu with Edit and Delete (S10, M7). "+ Record" has no menu.
2. **Edit:** the Edit sheet (§4.8): rename, emoji (S13), trim (S11). Save writes the changes; Cancel with changes asks "Discard changes?" (Discard / Keep editing).
3. **Delete:** "Delete “Ribbit”?" (S7, M10). Delete removes the row and the file for both of you. Either of you can delete any sound (S7, S26).

### 3.5 Reorder (tab only)

1. Long-press a sound tile, then move without lifting (S17, M7). The menu goes away and the tile follows the finger.
2. A dashed slot shows where it lands; the others make room.
3. Release: the new order is saved once for both of you (S18) and Sam's grid changes live (S23).
4. "+ Record" stays first: you can't drop before it, and it can't be moved.
5. VoiceOver and Switch Control: "Move earlier" / "Move later" actions on each tile (§9).
6. The tray has no long-press menu and no drag (S19).

### 3.6 In a call

1. Open the tray: the Stickers button (any call state, R1). It opens on Sounds when stickers aren't possible or the partner is big, otherwise on the last tab used (R2).
2. **Play:** §3.2. The tray stays open.
3. **Record:** "+ Record" swaps the panel content in place (M12), recording your mic and the partner's audio (S4). The partner sees "Adam is recording" (S5) until you stop, discard or save.
4. Stop (or 10 s): the panel becomes the naming step and rides on the keyboard, like the Text tab (§4.11).
5. Save: back to the grid with the new sound first after "+ Record". ✕ or Discard: "Discard this sound?" over the call (A3).
6. **The call ends mid-recording or mid-naming:** the clip is discarded with no prompt (S21). The panel closes with the call screen.
7. **Audio call, or your camera off or flipped:** the face pills are at 40% and inert, with the second hint line (M17). Turning your front camera on with the tray open brings them back (0.15 s fade); you stay on Sounds.
8. **Partner big, front camera on:** the face pills work; tapping one swaps your view big first (M18), then shows that tab.

## 4. Screens

All sizes in points on iPhone 11 (414 × 896, safe area top 48, bottom 34).

### 4.1 Sounds tab, frame (states 1–4)

```
┌──────────────────────────────────────────┐
│ 9:41                                ▭   │
│ Sounds                                   │ largeTitle heavy, 48 tall row
│ ┌────────┐ ┌────────┐ ┌────────┐          │ grid top = safe top + 76
│ │(+)     │▘│🐱     ■│ │🦖      │          │ 3 × 116.67 wide, 12 gaps
│ │Record  │ │Miso's  │ │Sam's   │          │ 108 tall
│ └────────┘ └────────┘ └────────┘          │
│ ┌────────┐ ┌────────┐ ┌────────┐          │
│ │🔊      │ │😂      │ │🥁      │          │
│ │Good mo…│ │That la…│ │Ba dum  │          │
│ └────────┘ └────────┘ └────────┘          │ scrolls vertically
├══════════════════════════════════════════┤
│  ☎       ▤      [ 🔊 ]      ☆            │ 4-tab bar
│ Calling  Notes  Sounds   Hobbies         │
└──────────────────────────────────────────┘
```

- Title row as on Notes: "Sounds", `.largeTitle.weight(.heavy)`, 20 pt side margins. No toggle, no other button (M2), no doodle (M16).
- Grid: `LazyVGrid` with 3 flexible columns, 12 pt spacing both ways, 20 pt from the screen sides, 20 pt under the title row. It scrolls vertically inside a `ScrollView`; the title row scrolls with it (as on Notes). Bottom content inset clears the tab bar.
- Order: "+ Record", then sounds by `position` ascending (S18, S20).

### 4.2 Sound tile (M1, S22)

- 116.67 × 108 (column width × fixed height), radius 20 continuous (radius.note), Surface fill, 2.5 pt Outline (`border.default`).
- Padding 10 top, 12 sides, 11 bottom. Contents pinned top and bottom:
  - Emoji, 30 pt (`.system(size: 30)`), top-leading. 🔊 when `emoji` is null (S13).
  - Title, `.subheadline.weight(.bold)` (15), TextPrimary, bottom-leading, at most 2 lines, tail truncation.
- **Playing (M3):**
  - A PlayTint rectangle fills from the leading edge, under the content, its width = played fraction of the trimmed length. It grows linearly (`.linear(duration: remaining)`), because it is real progress.
  - Stop badge: a 26 pt TextPrimary circle, 9 pt in from the top-trailing corner, holding a 9 pt Surface rounded square (radius 2).
  - On end or stop the tint fades out over 0.15 s.
- **Pressed:** fill fades 6% toward TextPrimary over 0.1 s, no scale (design.md Buttons).
- The whole tile is one button.

### 4.3 "+ Record" tile (M2, S16, F3)

- Same frame as a sound tile, Accent fill, OnAccent content, with the sticker shadow (Outline, 3/3 offset): the tab's one creating action.
- Top: a 34 pt circle with a 2 pt OnAccent ring and an 18 pt `plus` (stroke 2.8). Bottom: "Record", `.subheadline.weight(.bold)`.
- **Under a scrim** (any dialog or sheet on this tab): the sticker shadow is removed, so the card's confirming action is the only sticker (F3).

### 4.4 Empty tab (state 1)

- The grid with only "+ Record" in the first slot (the same place as in the full grid).
- 28 pt under the grid, centred, 12 pt side insets:
  - "No sounds yet. Record one for Sam?" `.headline`, TextPrimary.
  - 6 pt gap, then "Up to 10 seconds. Sounds you save show up for you both." `.subheadline.weight(.semibold)`, TextSecondary.
- Shown only while both of you have no sounds. It goes as soon as one exists (S23).

### 4.5 Recording dialog, outside a call (state 5)

```
│ ░░░░░░░░░░░░░░ scrim ░░░░░░░░░░░░░░░░░░ │
│ ┌──────────────────────────────────────┐ │
│ │ ● Recording                     (✕)  │ │ header 44
│ │ ┌──────────────────────────────────┐ │ │
│ │ │ ||||||||||||| · · · · · · · · ·  │ │ │ track 72, the 10 s timeline
│ │ └──────────────────────────────────┘ │ │
│ │ 0:04                       6 s left  │ │
│ │               ( ■ )                  │ │ Stop 88
│ │     Stops by itself at 10 seconds    │ │
│ └──────────────────────────────────────┘ │
```

- **Dialog card** (design.md §6): centred, 20 pt side margins, radius 28, 2.5 pt Outline, 16 padding, 14 between rows. Scrim black 42% (light) / 60% (dark), over the tab bar. **Scrim taps do nothing** (F4).
- **Header:** a 12 pt static Danger dot, 10 pt gap, "Recording" `.title3.weight(.heavy)`, then a `.plain` Icon circle ✕ trailing.
- **Track (M5):** full width, 72 tall, radius 16, Background fill, 2 pt Outline, 10 pt inner side padding.
  - The width is the full 10 s. Level bars (3 pt wide, 2 pt apart, radius 1.5, TextPrimary) are added left to right, one per ~190 ms (52 bars across 10 s at this width), each bar's height from the input level (min 4, max 54).
  - Not yet recorded: 4 pt dots in TextSecondary at 35%.
- **Time row**, 8 pt under the track: elapsed "0:04" `.title2.weight(.heavy).monospacedDigit()` leading; "6 s left" `.subheadline.weight(.bold).monospacedDigit()` TextSecondary trailing. Both update each second.
- **Stop:** an 88 pt circle, Accent fill, 2.5 pt Outline, 28 pt OnAccent rounded square (radius 6), centred. No sticker (it ends an action, it doesn't create one).
- **Caption:** "Stops by itself at 10 seconds", `.subheadline.weight(.semibold)`, TextSecondary, centred.

### 4.6 "Name this sound", outside a call (states 6 and 6b)

```
│ ┌──────────────────────────────────────┐ │
│ │ Name this sound                      │ │
│ │ (▶) ┌──────────────────────────────┐ │ │ play 44 + track 52
│ │     │ ||||||||||||||||||||||||||   │ │ │
│ │     └──────────────────────────────┘ │ │
│ │ Name                                 │ │
│ │ ( Like Miso's meow|           0/30 ) │ │ field 48
│ │ Discard                    [ Save ]▘ │ │ text button · primary 52
│ └──────────────────────────────────────┘ │
├──────────────────────────────────────────┤
│               system keyboard            │
```

- The recording content crossfades into this content inside the same card (0.15 s). The card's bottom sits 12 pt above the keyboard; it moves with the keyboard's own animation.
- **Header:** "Name this sound", `.title3.weight(.heavy)`. No ✕: Discard is the way out.
- **Player row:** a 44 pt `.accent` Icon circle (Play `play.fill` / Stop `stop.fill`), 10 pt gap, then the track at 52 tall showing the whole clip's bars (static). While playing, a 2.5 pt Danger playhead moves across linearly.
- **Label:** "Name", `.subheadline.weight(.bold)`, TextSecondary, 6 pt above the field. Always visible.
- **Field:** 48 tall pill, Background fill, 2 pt Outline, 18 pt horizontal padding, `.body.weight(.semibold)`. Placeholder "Like Miso's meow" in TextSecondary. A counter "0/30" `.footnote.weight(.bold).monospacedDigit()` TextSecondary trailing inside. Limit 30 characters; input stops at 30. Submit label `.done`.
- **Footer:** "Discard" Text button (`.headline`, TextPrimary) leading; "Save" Primary button (52, Accent, sticker) trailing.
  - Save disabled while the trimmed title is empty: 40%, no sticker (S9).
  - Return saves when Save is enabled.

### 4.7 "Discard this sound?" (state 6c, A3)

- Opens from Discard (naming) or ✕ (recording). The keyboard goes down; the naming card stays, under a **second scrim** of black 30%.
- A Dialog card centred over it, z-above:
  - Title "Discard this sound?", `.title3.weight(.heavy)`.
  - Body "You'll lose this recording. Sam never hears it." `.body`.
  - Two equal Secondary buttons (52), 12 pt apart: "Keep" (TextPrimary) and "Discard" (Destructive: Surface fill, Danger text, `trash` icon), Discard on the right.
- A tap on its scrim counts as Keep. Keep from naming brings the keyboard back with the typed name; Keep from recording goes to the naming step with the clip as recorded up to the ✕.

### 4.8 Long-press menu (state 3)

- System `.contextMenu` on each sound tile, preview = the tile itself (`.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20, style: .continuous))`).
- Items: "Edit" (`pencil`), "Delete" (`trash`, `.destructive` role, red by the system).
- The system lift, blur and its built-in scale and haptic are accepted (F2).

### 4.9 Reorder (state 4)

- Started by moving after the long-press (§3.5). Use `.draggable` / `.dropDestination` on the grid items (or `onDrag`/`onDrop` with a drop delegate), with the system drag preview.
- The gap where the tile will land is drawn as a **slot**: the tile frame with a 2.5 pt dashed TextSecondary border and no fill.
- Other tiles move to their new places with `.easeOut(duration: 0.2)`. Near the top or bottom edge the scroll view auto-scrolls.
- The first cell ("+ Record") is never a drop target: dropping there puts the tile at position 1.
- The new order is committed once, on drop (§10 RPC).

### 4.10 Edit sheet (state 7)

```
│ Cancel          Edit sound        [Save]▘│ sheet header
│ Name                                     │
│ ( Miso's meow                    11/30 ) │
│ Emoji                                    │
│ [ 🐱 ]  ( Remove )  Shows 🔊 when there's none
│ Trim                       5.5 s of 6.8 s│
│ ▐▒▒[|||||||||||||||||||||||||]▒▒▒▒▌      │ trimmer 76
│ start 0.4 s                  end 5.9 s   │
│ ( ▶ Play trimmed )                       │
```

- System sheet at `.large`, `.presentationBackground(Surface)`, grabber kept. Header row (design.md Sheet): "Cancel" Text button, "Edit sound" `.headline` centred, "Save" small primary pill (40 tall, sticker) trailing. Save is disabled while the name is empty or nothing changed.
- 20 pt sides, 18 pt between groups; labels as in §4.6.
- **Name:** the same field as §4.6, prefilled.
- **Emoji (S13, M8):** a 64 pt well (radius 16, 2 pt Outline, Background fill) showing the emoji at 36 pt, or 🔊 when none. Tapping the well focuses a hidden text field whose input mode is the emoji keyboard; the first emoji typed replaces the old one and the keyboard closes. "Remove" (Small button) sets it to none and is hidden when there's none. Hint "Shows 🔊 when there's none", `.subheadline.weight(.semibold)`, TextSecondary.
- **Trim (S11, M9):**
  - Label row: "Trim" and, trailing, "5.5 s of 6.8 s" (kept length of full length, monospaced).
  - Trimmer: full width, 76 tall, the clip's whole waveform on the Background track (radius 16, 2 pt Outline).
  - Two handles: 20 × 80 pt visible (radius 8, Accent, 2.5 pt Outline, a 3 × 22 OnAccent grip), 44 pt wide hit area each.
  - Between the handles, a frame of 3 pt Outline lines along the top and bottom edges. Outside them, a Background overlay at 78% dims the cut parts.
  - Handles snap to 0.1 s steps; at least 0.5 s stays between them. Dragging a handle shows its time in the label under it.
  - Times row under the trimmer: "start 0.4 s" leading, "end 5.9 s" trailing, `.footnote.monospaced()`, values bold TextPrimary.
- **Play trimmed:** a Small secondary pill with `play.fill`, "Play trimmed". While playing it reads "Stop" (`stop.fill`), the hint "Playing the trimmed part" shows beside it, and a Danger playhead runs across the kept part only.
- Trim stores `trim_start_ms` / `trim_end_ms`; the file is never changed (S11, A4). Moving both handles back to the ends restores the whole clip.

### 4.11 Delete confirm (state 8)

- Dialog card over the tab: title "Delete “Ribbit”?" (`.title3.weight(.heavy)`), body "It goes for both of you. Sam won't have it either." (`.body`), then "Keep it" and "Delete" as in §4.7.
- No ✕; a scrim tap keeps it (F4).

### 4.12 In-call tray, Sounds tab (state 9)

- The tray frame is in-call-screen.md §4.4. The Sounds pill is last; selecting it scrolls it into view.
- Grid: `LazyHGrid`, 3 fixed rows of 84, cells **120** wide (M11), 8 pt spacing, 16 pt leading inset, horizontal scroll. Content top 80 from the panel top. A fourth column peeks in at 392 pt.
- **Sound cell:** Background fill, radius 16, no border (tray grid style). Padding 9 × 10. Emoji 24 pt top-leading; title 13 pt heavy rounded (`.system(size: 13, weight: .heavy, design: .rounded)`, size from `@ScaledMetric(relativeTo: .caption)`), 2 lines, tail. Playing: the PlayTint fill and a 22 pt stop badge (8 pt square in Background).
- **"+ Record" cell:** Accent fill, 2 pt Outline, sticker shadow (the panel's one creating action), 28 pt plus circle, "Record".
- **Hint:** top 364, "Tap to play for you both", `.subheadline.weight(.medium)`, TextSecondary, centred (S2, S24).
- Taps only: no long-press menu, no drag out of the tray (S19). The panel stays open after a tap (S25).

### 4.13 Tray with stickers unavailable (state 9b)

- Audio call, your camera off, or back camera. The big view shows the partner (camera-off layout of in-call-screen.md §4.3 when their camera is off), centred in the area above the panel.
- Pill row: every face pill at 40% opacity, not interactive; Sounds selected (Accent), row scrolled to it.
- Hint becomes two lines: "Tap to play for you both" and, 2 pt under it, "Stickers come back when your camera's on" in `.footnote.weight(.semibold)`, TextSecondary.
- Front camera turns on while open: the pills fade to full over 0.15 s and the second line fades out. You stay on Sounds.

### 4.14 Tray recording both voices (state 10)

- "+ Record" crossfades the content area (0.15 s) to:
  - Header (in place of the pill row): ✕ `.plain` Icon circle leading (opens "Discard this sound?"), "Recording you and Sam" `.headline` centred, a 44 pt spacer trailing.
  - Content from top 84, 16 pt insets, 14 between rows: the 72 pt track (§4.5, showing the mixed level of both voices), the time row, a **72 pt** Stop centred, and the caption "Sam is told you're recording".
- After Stop or 10 s, the naming step (§4.15).

### 4.15 Tray naming step (not mocked; follows the Text tab)

- The panel shrinks to its content and rides on the keyboard, square bottom corners (in-call-screen.md §4.7).
- Header: ✕ leading (opens the discard confirm), "Name this sound" `.headline` centred.
- Row 1 (top 80): Play 44 + track 52.
- Row 2 (top 146): the Name field (48, flexible, counter inside) and "Save" as a small primary pill 48 tall with the sticker, 10 pt apart, exactly like the Text tab's field + Add. Save disabled while empty.
- No visible "Name" label above the field here, to keep the panel short; VoiceOver label "Name". The placeholder reads "Name this sound".
- Panel height 210 (80 + 52 + 14 + 48 + 16).
- Save: the panel grows back to 448 on the Sounds grid with the new sound after "+ Record".

### 4.16 Partner's call screen (state 11)

- A frosted pill (`.ultraThinMaterial` + CallFrost, in-call-screen.md §6.2), 32 tall, centred, **8 pt under the name pill** (top = safe top + 50).
- A 10 pt static Danger (dark) dot, 8 pt gap, "{name} is recording" in `.subheadline.bold()`, TextPrimary (dark). Padding 12 leading, 14 trailing.
- Shown while the partner's app has sent `recording: started` and not yet `stopped` (§10 Data). Fades in 0.2 s, out 0.15 s. No pulse.
- Not interactive. It never moves with the small tile and no snap corner reaches it.

### 4.17 Four-tab bar

- design.md Tab bar, with four equal columns over 414 pt (about 99.5 each, 8 pt bar side padding). Each keeps the 60 × 34 pill.
- Order and icons: Calling `phone`, Notes `note.text`, Sounds `speaker.wave.2`, Hobbies `star`; `.fill` when selected (S15, M14).
- No badge for new sounds (S23).

## 5. Components

### Reuse (design.md §6, in-call-screen.md §5)

- Tab bar (now four tabs), Dialog card (Notes), Sheet header, `PillButtonStyle` (primary with `StickerShadow`, secondary, small, text, destructive), `IconCircleButton` (`.plain`, `.accent`), `PressableButtonStyle`.
- In the call: `EffectsPanel`, `PillTabRow` (with a new `disabled` set), `CallControlButton`, `NamePill`, the frosted fill.

### New

| Component | Props | Notes |
| --- | --- | --- |
| `SoundTile` | `sound`, `size: .tab / .tray`, `progress: Double?` | §4.2 / §4.12. `progress` non-nil = playing: PlayTint fill width and stop badge |
| `RecordTile` | `size: .tab / .tray`, `sticker: Bool` | §4.3; `sticker` false under a scrim |
| `SoundsGrid` | `sounds`, `playingID`, `onPlay`, `onEdit`, `onDelete`, `onMove` | Tab grid with context menu and drag-reorder (§4.8, §4.9) |
| `TraySoundsGrid` | `sounds`, `playingID`, `onPlay`, `onRecord` | 3-row horizontal grid, taps only |
| `WaveformTrack` | `levels: [Float]`, `mode: .recording(elapsed, limit) / .playback(progress?)`, `height` | §4.5 / §4.6; recording dots for unrecorded time; Danger playhead |
| `SoundTrimmer` | `levels`, `durationMs`, `start`, `end` (bindings), `playhead` | §4.10; 0.1 s snap, 0.5 s minimum, adjustable for VoiceOver |
| `RecordFlow` | `context: .tab / .call`, `onSaved` | State machine recording → naming → (confirm) → saved/discarded; renders as a Dialog card (tab) or panel content (call) |
| `EmojiWell` | `emoji: String?` | §4.10; forces the emoji keyboard, single emoji |
| `RecordingPill` | `name` | §4.16, frosted |
| `SoundPlayer` | (service) | One shared player in `ButtercupKit`: `play(sound)`, `stop()`, `playingID`, `progress`. Routes to `AVAudioPlayer` outside a call and to the call audio in a call (§10) |
| `SoundRecorder` | (service) | Mic only outside a call (S30); mic + remote track in a call (S4); 10 s cap; level stream for the track |
| `SoundsStore` | (store) | SwiftData + realtime + outbox, like `NotesStore`; App Group file cache (S29) |

## 6. Visual details

### 6.1 Colour use

- Accent: "+ Record" tile, Stop, Play (in naming), Save, trimmer handles, selected tab and tray pill. Never two Accent selections in one row (the tray pill row keeps one).
- PlayTint: only the "playing now" fill.
- Danger: the recording dot, the playhead, Delete / Discard text, the partner pill's dot. All come with words ("Recording", "Delete", "is recording"), so colour is never alone.
- Outline: tile borders, track border, trimmer frame. Never over video.
- Call chrome stays dark; the tray panel follows the system scheme (in-call-screen.md §6.1).

### 6.2 Type

| Element | Style |
| --- | --- |
| Tab title | `.largeTitle.weight(.heavy)` |
| Tile title | `.subheadline.weight(.bold)` |
| Tray cell title | 13 pt heavy rounded, `@ScaledMetric` |
| Empty state | `.headline` / `.subheadline.weight(.semibold)` TextSecondary |
| Dialog / card titles | `.title3.weight(.heavy)` |
| Elapsed | `.title2.weight(.heavy).monospacedDigit()` |
| Time left, trim length | `.subheadline.weight(.bold).monospacedDigit()` TextSecondary |
| Field labels | `.subheadline.weight(.bold)` TextSecondary |
| Field | `.body.weight(.semibold)` |
| Counter, trim times | `.footnote.weight(.bold).monospacedDigit()` |
| Captions, hints | `.subheadline.weight(.semibold)` TextSecondary |
| Partner pill | `.subheadline.bold()` |

### 6.3 New token: PlayTint (R7)

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| PlayTint *new* | #FFE490 (Accent 45% into Surface) | #68571F (Accent 30% into Surface) | Fill showing how far a sound has played |

| Pair | Needs | Light | Dark |
| --- | --- | --- | --- |
| TextPrimary on PlayTint | 4.5 | 11.95 | 6.66 |
| Stop badge (TextPrimary) on PlayTint | 3 | 11.95 | 6.66 |

In the tray the fill sits on a Background cell instead of Surface; the same token is used (the difference is under 2%).

### 6.4 Sizes summary (iPhone 11)

| Element | Size | Radius |
| --- | --- | --- |
| Sound tile (tab) | 116.67 × 108, gaps 12 | 20 |
| Sound cell (tray) | 120 × 84, gaps 8, 3 rows | 16 |
| Stop badge | 26 (tab), 22 (tray) | full |
| Recording track | full × 72 (52 in naming) | 16 |
| Level bar | 3 wide, 2 apart, 4–54 tall | 1.5 |
| Stop | 88 (dialog), 72 (tray) | full |
| Name field | 48 | pill |
| Emoji well | 64 | 16 |
| Trimmer | full × 76; handles 20 × 80, 44 hit | 16 / 8 |
| Partner pill | 32 tall, top safe + 50 | pill |
| Tab bar | 4 × ~99.5, pill 60 × 34 | pill |

## 7. Motion and haptics

Fades and ease-outs only; no springs, nothing idles (design.md §8).

| Moment | Animation |
| --- | --- |
| Tile press | Fill fade 0.1 s ease-out, no scale |
| Play | PlayTint width `.linear(duration: remaining)`; on end or stop, fade out `.easeOut(duration: 0.15)` |
| Record dialog open / close | Dialog card: 0.2 s fade + 0.96 → 1 scale ease-out / 0.15 s fade |
| Recording → naming, naming → confirm | 0.15 s crossfade in place |
| Card follows the keyboard | The keyboard's own curve and duration |
| Level bars | Each new bar appears at its height, no grow-in; stop when recording stops |
| Playhead | Linear with playback |
| Reorder | Dragged tile 1:1 with the finger; others `.easeOut(duration: 0.2)`; drop the same ease, no overshoot |
| New tile / deleted tile | Opacity 0.15 s; neighbours `.easeOut(duration: 0.2)` |
| Tray tab swaps (grid ↔ recording ↔ naming) | 0.15 s crossfade; panel height follows the keyboard (in-call §7) |
| Face pills enable / disable | Opacity 0.15 s |
| Partner pill | In 0.2 s, out 0.15 s |
| Context menu | System (F2) |

**Reduce Motion:** neighbour moves and the dialog scale become 0.2 s crossfades. The play fill becomes a static half-width PlayTint plus the stop badge for the whole playback, so "playing" still shows without movement.

**Haptics (M15, T3):** none of our own on play, stop, record, save, discard, reorder, edit or delete. `.error` when the mic can't start, a download fails while you're waiting to play, or a save fails. The tab bar keeps `.selection`; the tray's Sounds pill has none. The system context menu's own long-press feedback stays (F2).

## 8. States

### Tab

| State | What shows |
| --- | --- |
| Empty | §4.4 |
| Loading (first open, no cache) | The grid from SwiftData if any; otherwise "+ Record" alone, no empty copy until the first fetch answers |
| Full, scrolling | Title scrolls with the grid; tab bar fixed |
| Playing | §4.2 on one tile at most |
| Not cached yet | Tapping shows a 16 pt `ProgressView` in the stop-badge spot until the file is ready, then plays. Tapping again cancels |
| Download fails | The progress goes, `.error` haptic, and the tile's title is replaced for 3 s by "Couldn't load. Try again" in Danger. Nothing else |
| Long title | 2 lines, tail ellipsis; full title in VoiceOver and Edit |
| Sam adds / edits / deletes | Appears, updates or fades out live (S23). If the deleted one was playing, it stops |
| Sam reorders while you drag | Your drop wins as the last write (§11.2); the grid then shows the server order |
| Offline | Plays cached sounds. New recordings and edits wait in the outbox (S28) and show at once on your phone. Delete and reorder also queue |

### Record and name

| State | What shows |
| --- | --- |
| Mic not yet allowed | The system prompt on the first "+ Record" |
| Mic denied | The Dialog card with header "Microphone is off" (no dot), body "buttercup can't use the microphone. Turn it on in Settings", "Open Settings" secondary and a ✕. `.error` haptic |
| Recording | §4.5 |
| 10 s reached | Stops and moves to naming, VoiceOver "Stopped at 10 seconds" |
| Very short (< 0.5 s) | Kept; trimming can't shorten it further |
| Naming empty / filled | §4.6 |
| Discard confirm | §4.7 |
| Save fails (local write) | Card stays, "Couldn't save. Try again" under the field in Danger, `.error` |
| App goes to background | Clip discarded, dialog closed, no prompt |
| A call starts (incoming CallKit) while recording on the tab | The recording is discarded and the dialog closes, the same rule as S21 |

### Edit and delete

| State | What shows |
| --- | --- |
| Edit, nothing changed | Save disabled |
| Cancel with changes | "Discard changes?" Dialog card: "Keep editing" / "Discard" |
| Sound deleted by Sam while you edit | Sheet closes, no message |
| Delete confirm | §4.11 |

### Call

| State | What shows |
| --- | --- |
| Tray on Sounds | §4.12 |
| Stickers unavailable | §4.13 |
| Recording | §4.14; partner sees §4.16 |
| Muted | Sounds still go out (S24); nothing extra shown |
| Call ends while recording or naming | Discarded, no prompt (S21) |
| Partner's "stopped" message never arrives | The pill hides 12 s after "started" (10 s cap + 2 s), or when the partner leaves the room |
| Remote audio missing (partner muted) | Records your mic only; nothing extra shown |
| Too hot (D35) | Sounds keep working; only the face tabs pause |

## 9. Accessibility

- **Touch targets:** tiles 116 × 108, tray cells 120 × 84, Stop 88/72, Icon circles 44, handles 44 hit, field 48, tab pills 44.
- **Contrast:** §6.3 and design.md §3. The Danger dot and playhead never carry meaning alone.
- **Dynamic Type:** tile titles scale to `.accessibility1`; at accessibility sizes the tab grid goes to two columns (as the Notes grid) and tile height grows to fit three lines. Tray cells and the stop badge are fixed size; their titles cap at `.xxxLarge` and use the Large Content Viewer. Dialog text wraps; the naming card scrolls if it can't fit above the keyboard.
- **Reduce Motion:** §7. **Reduce Transparency:** the partner pill follows the frosted rule (CallFrost 90%).
- **VoiceOver focus:** opening the record dialog puts focus on Stop; naming puts focus on the field; confirms put focus on their title. The escape gesture = ✕ while recording, Discard while naming (both open the confirm), Keep in confirms, Cancel in Edit.

| Element | Label | Value, hint, actions |
| --- | --- | --- |
| + Record tile | "Record a sound" | hint "Up to 10 seconds" (call: "Records you and Sam, up to 10 seconds") |
| Sound tile | title ("Miso's meow"); emoji not read | hint "Double-tap to play" (call: "Double-tap to play for you both"). Playing: value "Playing", hint "Double-tap to stop". Actions (tab only): "Edit", "Delete", "Move earlier", "Move later" |
| Recording track | "Recording" | value "4 of 10 seconds", updated every 2 s |
| Stop | "Stop recording" | — |
| ✕ while recording | "Discard recording" | — |
| Play / Stop (naming, Edit) | "Play sound" / "Stop" | — |
| Name field | "Name" | hint "Required" |
| Save (disabled) | "Save" | hint "Add a name first" |
| Emoji well | "Emoji, cat" / "Emoji, none" | hint "Double-tap to choose" |
| Remove | "Remove emoji" | — |
| Trim handles | "Start" / "End" | adjustable, ±0.1 s; value "0.4 seconds" |
| Dimmed face pill | "Stickers" | dimmed; hint "Turn on your front camera to use stickers" |
| Partner pill | "Adam is recording" | announced once, politely; focus doesn't move |
| Auto-stop | — | announcement "Stopped at 10 seconds" |
| Save done | — | announcement "Saved Miso's meow" |

- **Dragging alternative:** Move earlier / later actions (§3.5).

## 10. Acceptance criteria

Tab and bar
- [ ] The tab bar has four equal tabs, Calling · Notes · Sounds · Hobbies, Sounds with `speaker.wave.2`.
- [ ] Sounds shows a 3-column grid of 108 pt tiles, "+ Record" first (Accent, sticker), then sounds by `position`.
- [ ] Tiles show only the emoji (🔊 when none) and a 2-line title.
- [ ] The empty tab shows "+ Record" and the two-line copy; the copy goes when any sound exists.
- [ ] Tapping a tile plays the trimmed range on the phone, with the silent switch on too; the tile fills with PlayTint at the clip's pace and shows a stop badge.
- [ ] Only one sound plays; tapping the playing tile stops it; tapping another switches.
- [ ] Long-press shows Edit and Delete; "+ Record" has none.
- [ ] Long-press then drag reorders with a dashed slot; nothing lands before "+ Record"; the order changes on the partner's phone without a reload; Move earlier / later work in VoiceOver.

Record and name
- [ ] One tap on "+ Record" starts recording in a Dialog card; the track fills over 10 s with live bars; elapsed and time left update each second.
- [ ] Stop or 10 s moves to "Name this sound" above the keyboard; Save is disabled until a non-space character; 30-character limit with a counter.
- [ ] Play re-listens with a playhead.
- [ ] Discard and ✕ ask "Discard this sound?"; Keep returns; Discard stores nothing.
- [ ] Scrim taps do nothing while recording or naming; "+ Record" has no sticker shadow under any scrim.
- [ ] Save shows the new tile right after "+ Record" on both phones, also when saved offline (outbox).
- [ ] Backgrounding the app during recording or naming discards the clip.

Edit and delete
- [ ] Edit renames, sets or removes the emoji, and trims in 0.1 s steps keeping at least 0.5 s; the original file is unchanged.
- [ ] Play trimmed plays only the kept part.
- [ ] Delete asks first, then removes the sound and its file for both partners; either partner can delete any sound.

Call
- [ ] The Stickers button is in the bar in every call state and opens the tray on Sounds when stickers aren't possible or the partner is big.
- [ ] With your camera off or flipped, the face pills are at 40% and inert, with the second hint line.
- [ ] Tapping a sound plays it for both, including while muted; the tray stays open.
- [ ] "+ Record" in the tray records both voices; the partner sees "Adam is recording" until stop, save or discard (or 12 s).
- [ ] Ending the call mid-recording discards the clip.
- [ ] No long-press or drag in the tray.

Backend
- [ ] `sounds` rows are readable, updatable and deletable by the sender and their partner, insertable only as yourself; `stranger@example.com` is denied everything (pgTAP).
- [ ] Bucket `sounds`: write to your own folder, read and delete your own or your partner's (pgTAP or function test).
- [ ] `reorder_sounds` rewrites all positions of the pair's sounds in one transaction; two concurrent calls never leave duplicate positions.
- [ ] `sounds` is in the realtime publication; no push is sent.

## 11. Open questions, technical risks and ticket split

### 11.1 Open questions

None for Adam. Adam's answers A1–A5 closed the mockup's questions. Left to the tickets (implementation, not design):
- Whether in-call playback is mixed into the mic track or sent as a second published audio track (§11.2, risk 1). Both meet S2/S24 as far as the partner can hear.
- The exact `position` scheme (§11.2, risk 2).

### 11.2 Technical risks (for the PRD planner)

1. **Call audio: mixing playback out, capturing both voices in.** Prototype this first, on the two iPhone 11s.
   - **Playback into the call (S2, S24):** the clip must reach the partner through the published audio while your mic is muted. LiveKit's mute stops the mic track, so either (a) the app mutes by zeroing mic samples in a custom capture/processing step and keeps the track live so mixed clip samples still flow, or (b) the app publishes a second, short-lived audio track for sounds. (a) is "mixed into the outgoing audio" literally; (b) is simpler and survives mute naturally. Local playout must not be picked up again by the mic (check echo cancellation with the speaker route).
   - **Recording both voices (S4):** tap the remote participant's audio track (an `AudioRenderer` on the remote track) and the local mic PCM, mix into one mono buffer, encode AAC. Clock drift and the remote jitter buffer delay need a small alignment.
   - **Heat:** calls already run ARKit, Vision and effects compositing. Measure the extra cost of a second track or the mixer, and of encoding, with the heat test from PRD 7. video-calls-spec puts voice effects after the heat test for the same reason.
   - **Audio session:** LiveKit owns the session (`.playAndRecord`, voice chat) in a call; outside calls the app uses `.playback` for playing (A2) and `.playAndRecord` while recording. Switching must not fight CallKit when a call starts mid-playback (stop playback first).
2. **Shared reorder (S18).** Both partners can drag at the same moment. Use one RPC, `reorder_sounds(ordered_ids uuid[])`, that locks the pair's sound rows (`for update`), checks the ids are exactly the pair's sounds, and rewrites `position` 1…n in one transaction. The last commit wins; there are never duplicate or missing positions. A unique constraint can't be per pair because `sounds` has no `pair_id` (S27), so the RPC carries the guarantee; consider a deferrable check in the ticket. New sounds (S20) get `position = min(pair positions) − 1` from a `before insert` trigger, so an offline insert doesn't need to know the order; the next reorder renumbers.
3. **Tray dependency.** The tray is tickets [5]/[6], not built yet. Ship the tab and backend first; the in-call part waits for the tray and for risk 1's prototype.

### 11.3 Suggested ticket split

| # | Ticket | Contains | Depends on |
| --- | --- | --- | --- |
| T1 | Sounds backend | `sounds` table, RLS (S26), `sounds` bucket and policies, insert trigger for `position`, `reorder_sounds`, realtime publication, seed rows with fixed UUIDs and a seed upload script for `.m4a` files (like `seed-notes.sh`), pgTAP | — |
| T2 | Sounds tab: play and organise | Four-tab bar, `SoundsStore` (SwiftData, realtime, App Group cache), grid, `SoundPlayer` (`.playback`), long-press menu, delete confirm, reorder, empty and error states, PlayTint token | T1 |
| T3 | Record, name and edit (outside calls) | `SoundRecorder` (mic only), record dialog, naming, discard confirm, outbox `uploadSound` (+ update, delete, reorder actions), Edit sheet with emoji well and trimmer | T1, T2 |
| T4 | Call audio spike | Risk 1 prototype on two iPhone 11s: mixing while muted, both-voices capture, heat numbers; pick (a) or (b) | Calls ([3]) |
| T5 | Sounds in calls | Stickers button in every bar state, tray Sounds tab, face-pill disabling, in-call recording and naming, LiveKit data message and partner pill, call-end discard | [5]/[6], T3, T4 |

## 12. Paste-ins for the context docs

Ready-to-paste text for R6–R9. Tickets paste these; this spec doesn't edit `.claude/context/`.

### design.md

1. **§3 Colour tokens:** add a row: `PlayTint` *new* | #FFE490 | #68571F | "Fill showing how far a sound has played (Sounds tiles). Nothing else". Add contrast rows: "TextPrimary | PlayTint | 4.5 | 11.95 | 6.66".
2. **§5 Sticker shadow:** add a row to the table: "Sounds | '+ Record' (the first tile); in the call tray, the '+ Record' cell". Add a bullet: "A creating tile or button under a scrim (a dialog or sheet is open) drops its sticker shadow, so the card's confirming action is the only sticker on screen."
3. **§6 Buttons, Destructive:** keep "Always confirm first" and add: "This includes throwing away fresh work: 'Discard this note?' and 'Discard this sound?' both confirm, with 'Keep' / 'Keep drawing' as the safe choice."
4. **§6 Dialog card:** add: "While it holds unsaved work (a recording, a name being typed), scrim taps do nothing. A confirm card can stack over another card with its own 30% scrim. Confirms (Delete, Discard) close with their safe button or a scrim tap and have no ✕."
5. **§6 Tab bar:** replace "three equal tabs" with "four equal tabs" and the icons line with "`phone` / `note.text` / `speaker.wave.2` / `star`, with `.fill` versions when selected". Labels: Calling, Notes, Sounds, Hobbies.
6. **§6, new "Sound tile":**
   - "Tab: 3 columns, 108 pt tall, radius 20, Surface, 2.5 pt Outline, 12 pt gaps. Emoji 30 pt top-left (🔊 when none), title subheadline bold bottom-left, 2 lines."
   - "Tray: 120 × 84, radius 16, Background, no border, 3 rows that scroll sideways."
   - "Playing: PlayTint fills from the left at the clip's pace, with a stop badge (TextPrimary circle, Surface square) top-right."
   - "'+ Record' tile: Accent, OnAccent plus-in-circle and 'Record', sticker shadow; always first."
7. **§6, new "Waveform track":** "Background, 2 pt Outline, radius 16. Recording: 3 pt level bars fill a fixed 10 s width; unrecorded time is 4 pt dots. Playback: a 2.5 pt Danger playhead. Trim: Accent handles with an Outline frame; the cut parts are dimmed."
8. **§3 Danger role:** add "the recording dot and the playback playhead".
9. **§7 Screens:** add "**Sounds:** the title, then a 3-column grid of sound tiles with '+ Record' first. No doodle, no other button. Spec: [soundboard.md](../design/specs/soundboard.md)."
10. **§8 Haptics:** add "No haptics on sounds (play, record, save, reorder); `.error` when the mic or a sound fails."

### technical-spec.md

1. **§1 Motion:** "Custom bottom tab bar (Calling / Notes / Sounds / Hobbies)".
2. **§1 Sync and offline:** add `sounds` to the realtime subscriptions and to the outbox list: "upload sound, edit sound, delete sound, reorder sounds".
3. **§2 Database, new table `sounds`:**

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid pk | made on the phone (S28) |
| sender_id | uuid | → profiles; who recorded it |
| title | text | 1–30 characters, required |
| emoji | text null | one emoji; null shows 🔊 |
| audio_path | text | `{sender_id}/{id}.m4a` in the `sounds` bucket |
| duration_ms | int | ≤ 10000 |
| trim_start_ms | int | default 0 |
| trim_end_ms | int | default `duration_ms`; `0 ≤ start`, `end ≤ duration_ms`, `end − start ≥ 500` |
| position | int | shared order for the pair; set by a `before insert` trigger to the pair's minimum − 1 (new sounds first); rewritten by `reorder_sounds` |
| created_at | timestamptz | |

   "The pair's library is every row whose `sender_id` is you or your partner. No push is sent for sounds."
4. **§3 Row-level security:** add: "`sounds` is the exception to 'write only your own': select, update and delete are allowed when `sender_id = auth.uid() or is_paired_with(sender_id)`; insert only with `sender_id = auth.uid()`. A stranger sees and changes nothing."
5. **§3 RPC:** add rows:
   - "`reorder_sounds(ordered_ids uuid[])` | Locks the pair's sound rows, checks the ids are exactly that set, rewrites `position` 1…n in one transaction".
   - No delete RPC: the app deletes the row under RLS, then removes the file with the Storage API under the bucket delete policy. Supabase Storage blocks deleting `storage.objects` rows from SQL (PRD [21] B3).
6. **§3 Realtime publication:** add `sounds`.
7. **New §4b "Sounds (audio)":**
   - "Recorded on the phone as mono AAC (`.m4a`, 44.1 kHz, about 64 kbps; 10 s ≈ 80 KB), at most 10 s. Outside a call, mic only. In a call, your mic mixed with the partner's remote LiveKit track."
   - "Offline, the file waits in the App Group with its `uploadSound` outbox entry; then it's uploaded to the private bucket `sounds` at `{sender_id}/{id}.m4a` and the row is inserted."
   - "Every sound file is cached in the App Group (`Sounds/{id}.m4a`) so playback starts at once; files are fetched when a row first arrives and removed when the row is deleted."
   - "Storage rules: write to your own folder; read and delete your own or your partner's."
   - "Trim is stored as `trim_start_ms` / `trim_end_ms`; the file is never rewritten."
   - "Audio session: outside calls, `.playback` while playing (plays with the silent switch on) and `.playAndRecord` while recording. In calls, LiveKit's session; a played sound goes to the partner through the call audio even while muted, and plays locally."
   - "The '{name} is recording' notice is a reliable LiveKit data message `{type: 'sound-recording', state: 'started' | 'stopped'}`; the receiver hides the pill after 12 s without a 'stopped'."
8. **§1 Haptics table:** unchanged (sounds add none).

## 13. Decision index

| Decision | Where |
| --- | --- |
| S1 Sounds tab + Sounds pill in the tray; not in the note composer | §3.1, §4.12, R4 |
| S2 in-call tap plays for both | §3.2, §11.2 |
| S3 off-call plays on your phone only | §3.2 |
| S4 in-call recording captures both voices | §3.6, §4.14, §11.2 |
| S5 partner sees "{name} is recording" | §4.16, §12 tech 7 |
| S6 10 s max, auto-stop | §4.5, §8 |
| S7 either partner deletes, with a confirm | §3.4, §4.11 |
| S8 tap to start, tap to stop | §3.3, §4.5 |
| S9 title required, Play, Save disabled while empty, Discard | §4.6, R10 |
| S10 Edit: rename, trim, emoji | §4.10 |
| S11 keep the original + trim points | §4.10, §12 |
| S12 trim and emoji only in Edit | §3.3, §4.6 |
| S13 emoji optional, 🔊 by default | §4.2, §4.10 |
| S14 one at a time; tap playing to stop | §3.2 |
| S15 Calling · Notes · Sounds · Hobbies | §4.17, R6 |
| S16 "+ Record" first, tab and tray | §4.3, §4.12 |
| S17–S20 long-press drag, one shared order, new first, tab only | §3.5, §4.9, §11.2 |
| S21 call ends mid-record → discarded | §3.6, §8 |
| S22 title + emoji only | §4.2 |
| S23 partner's sounds appear live, no push | §3.3, §8, §12 |
| S24 sounds go out while muted | §3.2, §11.2 |
| S25 tray stays open | §3.2, §4.12 |
| S26 one library per pair, both full rights, stranger denied | §10, §12 tech 4 |
| S27 `sounds` bucket and table columns | §12 tech 3, 7 |
| S28 outbox `uploadSound`, phone-made id | §3.3, §12 tech 2, 7 |
| S29 App Group cache | §3.2, §12 tech 7 |
| S30 off-call recording is mic only | §3.3, §12 tech 7 |
| M1 3 columns, 116 × 108 tiles | §4.1, §4.2 |
| M2 "+ Record" Accent with the sticker; no other button | §4.3 |
| M3 PlayTint fill + stop badge | §4.2, §6.3 |
| M4 one tap starts recording | §3.3 |
| M5 waveform is the 10 s timeline; 88 pt Stop | §4.5 |
| M6 naming in the same card above the keyboard | §4.6 |
| M7 system context menu, keep holding to drag | §4.8, §4.9 |
| M8 Edit sheet, emoji well, Remove | §4.10 |
| M9 Photos-style trimmer, 0.1 s steps, 0.5 s minimum | §4.10 |
| M10 delete confirm is a Dialog card | §4.11 |
| M11 Sounds last pill; 120 × 84 cells; hint | §4.12 |
| M12 in-call recording swaps the panel in place | §4.14 |
| M13 frosted partner pill under the name pill | §4.16 |
| M14 `speaker.wave.2` | §4.17 |
| M15 no new haptics | §7 |
| M16 no doodle on Sounds | §4.1 |
| M17 face pills dimmed with a reason when stickers aren't possible | §4.13, R2, R3 |
| M18 partner big: face pill swaps you big first | §3.6, R2 |
| A1 Stickers button always in the bar; opens on Sounds when needed | §3.6, R1–R3, R5 |
| A2 plays with the silent switch on (`.playback`) | §3.2, §12 tech 7 |
| A3 Discard confirms | §4.7 |
| A4 trim keeps the original (S11) | §4.10 |
| A5 no visual cue for the partner on play | §3.2 |
| F1 tray access in audio calls | R1–R3 |
| F2 system lift accepted | §4.8, §7 |
| F3 "+ Record" drops its sticker under a scrim | §4.3, §12 design 2 |
| F4 scrim ignored during unsaved work; confirms without ✕ | §4.5, §4.7, §4.11, §12 design 4 |
| F5 four tabs | §4.17, R6 |

### Decided in this spec (not covered by S, M, A or F)

- **Tray naming step layout** (not mocked): field + Save like the Text tab, panel 210 tall on the keyboard, no visible label (§4.15).
- **Bar button label** "Effects and sounds", never disabled (R5).
- **Pill timeout:** the partner pill hides 12 s after "started" without "stopped" (§8).
- **Background or incoming call while recording on the tab:** discarded, same as S21 (§8).
- **Mic denied, download failed, save failed, not-yet-cached** states (§8).
- **Edit Cancel with changes** asks "Discard changes?" (§3.4).
- **Field limit:** 30 characters with a counter.
- **Position:** insert trigger sets min − 1; `reorder_sounds` renumbers; last drop wins (§11.2).
- **Delete:** row under RLS, then the file through the Storage API (§12 tech 5, PRD [21] B3). S28 named only `uploadSound`; the edit, delete and reorder outbox actions follow the same pattern.
- **Audio format:** mono AAC m4a, ~64 kbps (§12 tech 7).
- **Dynamic Type:** two columns at accessibility sizes (§9).
