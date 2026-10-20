# In-call screen: tiles, control bar, effects tray and drawing pad

Oct 20, 2026 · approved by Adam (mockup v2) · designer run 2
**Mockup**: https://claude.ai/artifact/Ug28oBLwcbFWh3Gacp3LC4 (default call; small tile in another corner, muted and camera off; medium tile me; medium tile partner after swap; swapped with Stickers in the bar; partner camera off; tray Emoji at start and after a category jump, Text with keyboard, Stickers, Hats, Glasses, Filters; pad empty and drawn; sticker selected with trash; panels in light and dark)
**Source**: [mockups/in-call-screen.html](../mockups/in-call-screen.html)
**Tickets**: restyles [3] Frontend Calls (D7) and the UI of [5] Face stickers and [6] Drawing-pad stickers
**Decisions**: C1–C18 (Adam, 2026-10-20, `~/.claude/plans/please-use-taste-skills-binary-pelican.md`) and N1–N7 (Adam's answers to the run 1 open questions), listed in the mockup's legend

## 0. Revisions to PRDs [5] and [6]

This spec changes these tickets. The PRDs themselves are not edited here; the developer follows this spec where they differ.

| # | PRD text | Replaced by | Decision |
| --- | --- | --- | --- |
| R1 | [5] "Tray (sheet with detents)", "tray sheet at medium detent; dragging out of the tray dismisses it to its small detent" | A fixed panel, 50% of the screen height with no detents, drawn inside the call view (not a `.sheet`). It covers the control bar and closes when a sticker lands on the face | C3, C4 |
| R2 | [6] D22 "PencilKit canvas + `PKToolPicker`" | `PKCanvasView` with its tool picker hidden, driven by the pad's own toolbar (pen, eraser, undo, 5 colour dots) | C6, N2 |
| R3 | [6] "Done" / "Cancel" buttons, full-height pad sheet | ✕ icon circle (left) and ✓ Accent icon circle (right) in the pad header; the pad replaces the tray panel in place | C7, C14 |
| R4 | [3] D40 / [5] main bar "keeps mute, camera on/off, audio route, hang up" | Unchanged while the partner is big. While your own view is big, a Stickers button joins the bar on the far left | C15 |
| R5 | [5] tabs Emoji · Text · Images, [6] adds Draw | Pill tabs Stickers · Emoji · Text · Draw · Hats · Glasses · Filters. "Images" is renamed "Stickers" and comes first. Hats, Glasses and Filters appear only when their tickets ship | N3 |
| R6 | [5] "Emoji grid (system emoji keyboard input)" | Apple's full emoji set in the tray's own grid, grouped into categories with jump chips. Long-press opens the skin-tone picker. No system keyboard and no search | N4 |
| R7 | [5] "Images tab empty: No image stickers yet." | "No stickers yet." | N3 |
| R8 | [5]/[6] "sticker in drag mode" (undefined) | Defined in §3.6: the new sticker appears pinned to the nose point, already selected, ready to drag | Spec |

## 1. Problem and goal

[3], [5] and [6] build the call screen in plain SwiftUI (D7). This spec gives it the buttercup look and settles how the self tile, the effects tray and the drawing pad behave, so the restyle ticket can be built and checked against one document.

Goal: during a call the partner's face is the screen. Controls are quiet, dark and few, and putting something silly on your face takes two touches: open the tray, drag.

## 2. User and situation

- **Who:** Adam and Sam, each on an iPhone 11, on a 1:1 video call.
- **Where and how:** at home, phone held in one hand at arm's length or propped up. Mostly relaxed, not in a hurry. The thumb reaches the bottom third easily; the top corners are a stretch.
- **Job:** keep talking while seeing each other, and now and then make the other laugh with a sticker, a drawing or a hat.
- **What matters most:** the faces. Anything over the video must stay out of the way, read at a glance over any picture, and never cover a face for long.
- **Constraints:** portrait only in v1; design.md (tokens, quiet motion, minimal haptics T3, SF Pro Rounded T13), C1–C18 and N1–N7, iPhone 11 heat budget (effects pause at critical heat, D35), front camera only for effects (D33), at most 10 stickers (D23), effects cleared after the call (D34). Out of scope: outgoing, incoming and Reconnecting screens (C17).

## 3. Flow

### 3.1 Entry and exit

- **Entry:** the call connects (`CallStore` phase `answered`). The in-call screen replaces the outgoing screen or incoming sheet with a 0.2 s cross-fade and the `.success` haptic (T3).
- **Exit:** End call, or the partner hangs up. The screen fades out over 0.2 s to the Calling tab. Stickers are cleared (D34).

### 3.2 Tiles

```
            tap small tile                  tap ↗ (Expand)
[A] Partner big ─────────────► [B] Medium (me) ──────────────► [C] Me big
 me small (corner)  ◄─────────  dim 40%                         partner small
            tap dim                │ tap Add stickers           │
                                   └───────────► [C] + tray ◄───┘ tap Stickers in bar
[C] ── tap partner's small tile ──► [D] Medium (partner) ── tap ↗ ──► [A]
                                    ◄── tap dim ──
```

- The small tile can be dragged to any corner in states A and C (§7 motion).
- In state C with the tray open, the partner's small tile moves to the top corner on its side.
- Stickers are placed and edited only in state C (D41). Selecting a sticker is possible only there.

### 3.3 Tray

1. Open: Add stickers (medium tile, state B) goes to state C and opens the tray, or the Stickers button in the bar (state C).
2. The tray opens on the last tab used in this app session (N7). The first open opens on Stickers.
3. Tap a pill to switch tabs. Tabs don't change on a horizontal swipe; horizontal swipes scroll the tab's grid (C5).
4. Drag a cell up out of the panel onto your face. As the finger crosses the panel's top edge, the panel slides away and the control bar fades back. Release on the big view: the sticker pins to the nearest face point (per [5]), light impact haptic, tray stays closed (C4).
5. Drag back below the panel's top edge before release: the panel returns and nothing is added.
6. Tap a cell (single-pointer and VoiceOver alternative to dragging): the sticker is added at the nose point, selected, and the tray closes (§3.6).
7. Close without adding: ✕, swipe down on the panel's header area, or the accessibility escape gesture. The control bar fades back.

### 3.4 Text tab

1. Tap Text. The field takes focus and the keyboard rises; the panel shrinks to its content (292 pt) and rides on top of the keyboard (N1).
2. Type. The preview updates on each keystroke. Pick a colour dot.
3. Add (or Return): the sticker is added at the nose point, selected (§3.6); the keyboard and tray close.
4. Dismiss the keyboard without adding (keyboard dismiss, or tap outside the field inside the panel): the panel grows back to 448 pt and keeps the typed text until the tray closes.

### 3.5 Draw tab and pad

1. Tap Draw: the tab row and grid cross-fade to the pad header, canvas and toolbar inside the same panel (C14).
2. Draw. ✓ and Undo turn on after the first stroke.
3. ✓: strokes are cropped to their bounds and turned into a sticker ([6]), added at the nose point and selected (§3.6); the panel closes.
4. ✕ or swipe down: the drawing is discarded with no confirmation (C7) and the tray comes back on the tab you were on before Draw. The pad remembers nothing.

### 3.6 New sticker and selection ("drag mode", R8)

- A sticker made with tap, Add or ✓ appears at the nose point at its default size, already **selected**: Accent outline in your preview, trash visible. Drag it to where you want it; it re-pins on release (D19).
- A sticker dropped by dragging from the tray is placed but not selected.
- Tap a sticker on your face: it is selected and the trash appears (C13). Tap the trash: removed. Tap anywhere else: deselected and the trash fades out.
- Pinch to resize and twist to rotate a sticker as in [5] D19. These work whether or not it is selected.

### 3.7 Filters (when the filters ticket ships)

Tap a swatch: the look applies to the video at once, the tray stays open, and the swatch shows the selection ring. Tap None to clear. One look at a time.

### 3.8 Hats and glasses (deferred)

How a hat or glasses go on (drag like a sticker, or tap to wear and follow the head), how many at once, and whether they count toward the 10 cap are **deferred to the hats ticket**. This spec only fixes their tabs and grid look (§4.8).

## 4. Screens

All sizes are in points on iPhone 11 (414 × 896, safe area top 48, bottom 34). Positions are given from the safe area so they work on other phones.

### 4.1 Call chrome (states A and C)

```
┌──────────────────────────────────────────┐
│ 9:41                              5G ▭  │ status bar (light content)
│            ( Sam  4:12 )      ┌──────┐  │ name pill, top centre
│                               │ you  │  │ small tile 100×150
│                               │      │  │
│          partner video        └──────┘  │
│           (full bleed)                   │
│                                          │
│                                          │
│                                          │
│   ( 🎙 )   ( 📹 )   ( 🔊 )   ( ☎︎ )       │ control bar, 56 pt circles
│              ─────────                   │ home indicator
└──────────────────────────────────────────┘
State C: ( ☺︎+ ) joins on the far left: ( ☺︎+ ) ( 🎙 ) ( 📹 ) ( 🔊 ) ( ☎︎ )
```

- **Big video:** full bleed, ignoring safe areas, `scaledToFill`.
- **Name pill:** centred, top = safe top + 10, height 32, horizontal padding 14, frosted (§6.2). Partner's name in `.subheadline.bold()` TextPrimary (dark), then the timer in `.subheadline.weight(.semibold).monospacedDigit()` at TextPrimary 85% opacity, 8 pt apart. Not interactive. The name truncates at the tail so the timer always shows (pill max width 220).
- **Small tile:** 100 × 150, radius 20 continuous, 16 from the side edges. Top corners: top = safe top + 8. Bottom corners: bottom edge = control bar top − 16. Shadow `.shadow(color: .black.opacity(0.35), radius: 10, y: 6)`. No border.
- **Control bar:** `HStack` of 56 pt circles spread with equal spacing across the width minus 16 pt on each side; bottom of the circles = safe bottom + 12 (iPhone 11: circles from 794 to 850). Always visible, except under an open panel (C3).
- **Order:** Mute · Camera · Audio route · End call. In state C: Stickers · Mute · Camera · Audio route · End call (C15). End call is always last, on the right.
- Status bar uses light content (`.preferredColorScheme(.dark)` on the call chrome).

### 4.2 Medium tile (states B and D)

```
┌──────────────────────────────────────────┐
│            ( Sam  4:31 )                 │
│  ░░░░░░░░░░░ dim 40% ░░░░░░░░░░░░░░░░░░  │
│  ░░  ┌──────────────────────────┐  ░░░░  │
│  ░░  │ (↗)                 (⟲📷)│  ░░░░  │  ↗ Expand · Flip camera
│  ░░  │                          │  ░░░░  │
│  ░░  │        your video        │  ░░░░  │  290 × 435
│  ░░  │                          │  ░░░░  │
│  ░░  │                    (☺︎+) │  ░░░░  │  Add stickers
│  ░░  └──────────────────────────┘  ░░░░  │
│   ( 🎙 )   ( 📹 )   ( 🔊 )   ( ☎︎ )       │  bar above the dim, still live
└──────────────────────────────────────────┘
```

- Width 70% of screen width (290 on iPhone 11), aspect 2:3 (435), radius 28 continuous, centred horizontally and vertically in the space between safe top and the control bar top. Shadow `.shadow(color: .black.opacity(0.45), radius: 20, y: 12)`.
- Dim: `Color.black.opacity(0.4)` over the big video and the name pill, under the medium tile and the control bar. Tapping the dim returns the tile to its corner.
- Buttons are 44 pt frosted circles, 12 pt in from the tile's corners, 22 pt symbols.
  - **Me (B):** Expand top-left, Flip camera top-right, Add stickers bottom-right (C10).
  - **Partner (D):** Expand top-left only (C11).
- Tapping the medium tile's video (not a button) does nothing.

### 4.3 Partner camera off

- The big view becomes Background (dark) with, centred as one group: `Avatar` 128 pt (initial in `.system(size: 58, weight: .heavy, design: .rounded)` on the partner's `avatar_tint`, 2.5 pt Outline), 14 pt gap, the name in `.title2.weight(.heavy)` TextPrimary, then `video.slash` 15 pt + "Camera off" in `.subheadline.weight(.semibold)` TextSecondary.
- The same layout fills **your own** tile when your camera is off: the `Avatar` is 56 pt (2 pt Outline) on your tint, with no text. The medium tile uses a 96 pt avatar.

### 4.4 Effects panel: shared frame

```
┌──────────────────────────────────────────┐
│ (face visible above)          ┌──────┐   │ partner small tile, top corner
│                               └──────┘   │
╞══════════════════ ▔▔ ════════════════════╡ panel top, radius 28
│ (✕)  Stickers [ Emoji ]  Text  Draw  Ha… │ header: ✕ fixed + pill row
│                                          │
│              tab content                 │
│                                          │
│              ─────────                   │
└──────────────────────────────────────────┘
```

- Height: 50% of the full screen height (448 on iPhone 11), full width, pinned to the bottom including the bottom safe area. Top corners radius 28 continuous (radius.sheet), bottom corners square. Fill Surface. No border or shadow; it is not a `.sheet`.
- **Grabber:** 36 × 5, radius 2.5, TextSecondary at 45%, centred 7 pt from the top. Swipe down on the grabber or header closes the panel (§7).
- **Header:** top 20, height 44, 16 pt side insets.
  - ✕ icon circle at the leading edge (§6.4). It stays in the same place for the tray and the pad.
  - The pill row fills the rest of the header, in a horizontal `ScrollView` with no indicators that runs to the panel's trailing edge (the last visible pill is cut by the edge). 4 pt between pills, 4 pt leading inset after ✕.
- **Tab pill:** 36 visible, 44 hit, horizontal padding 14, `.subheadline.weight(.bold)`.
  - Unselected: no fill, TextSecondary.
  - Selected: Accent fill, 2 pt Outline, OnAccent.
  - When a tab is selected, the row scrolls it fully into view.
- **Content area:** from 80 pt below the panel top to the bottom safe area.
- **Light and dark:** the panel follows the system appearance, using the Surface, Background, Outline, Accent, OnAccent, TextPrimary, TextSecondary and Divider tokens. Everything around it stays dark (C2).
- When the panel is open:
  - The control bar and the trash are hidden.
  - The partner's small tile moves to the top corner on its side (C8).
  - The name pill stays.

### 4.5 Stickers tab (grid tabs: Stickers, Hats, Glasses, Filters)

- `LazyHGrid` with 3 fixed rows of 84, cells 84 × 84, 8 pt spacing both ways, 16 pt leading inset. It scrolls horizontally. Cell width and inset are chosen so a fifth column peeks in at the trailing edge on a 414 pt screen.
- Cell: Background fill, radius 16, no border. Image `scaledToFit` in a 58 pt box, centred.
- Hint below the grid, 12 pt under the last row (top 364 from the panel top): "Drag one onto your face", `.subheadline.weight(.medium)`, TextSecondary, centred.
- Content: every PNG in `assets/stickers`, in file-name order.

### 4.6 Emoji tab

```
│ (✕) Stickers [ Emoji ] Text Draw Hats Gl…│
│ Smileys                                  │ 13 pt label at category start
│  😀   😃   😄   😁   😆   🥹  ·  ·  ·     │ 3 rows × 72
│  😅   😂   🤣   🥲   ☺️   😊             │
│  😇   🙂   🙃   😉   😌   😍             │
│ (☺) 👤  🐾  🍴  ⚽  🚗  💡  ♡  ⚑         │ 9 category chips, 44 each
```

- **Strip:** one horizontal `ScrollView` containing a `LazyHGrid` with 3 rows of 72 and 4 pt spacing. There is one `Section` per category, 20 pt between sections, and a 16 pt leading inset. Top of the strip is 76 below the panel top.
- **Category label:** the section header, 18 tall, above the first column of each category, leading-aligned, `.footnote.weight(.bold)`, TextSecondary. It scrolls with its section (not pinned).
- **Emoji cell:** 72 × 72, no fill, emoji at 40 pt (`.system(size: 40)`), centred.
- **Data:** Apple's full emoji set for the running iOS version, in Unicode `emoji-test.txt` order. Components and skin-tone variants are excluded from the strip (tones are reached by long-press).
- **Category chips:** a row of nine 44 × 44 slots, edge to edge, centred, top 346 from the panel top. Nine slots fill 396 of the 414 pt width; this row does not scroll.
  - Each slot holds a 36 pt disc with a 20 pt symbol, TextSecondary.
  - The chip for the category at the leading edge of the strip is current: Divider disc, TextPrimary symbol. It updates as you scroll.
  - Tapping a chip scrolls the strip so that category's label sits at the leading edge.
- **Categories and Unicode groups:**

| Label | Unicode group | Chip symbol |
| --- | --- | --- |
| Smileys | Smileys & Emotion | `face.smiling` |
| People | People & Body | `person` |
| Animals | Animals & Nature | `pawprint` |
| Food | Food & Drink | `fork.knife` |
| Activity | Activities | `soccerball` |
| Travel | Travel & Places | `car` |
| Objects | Objects | `lightbulb` |
| Symbols | Symbols | `heart` |
| Flags | Flags | `flag` |

- **Skin tones:** long-press (0.4 s, finger still) on an emoji that has tone variants opens the tone picker, like the keyboard.
  - It is a Surface capsule (radius pill, 2 pt Outline) above the cell, holding the default plus five tones as 44 pt cells with the emoji at 34 pt.
  - Slide or tap to pick. The cell then shows the picked tone, and that tone is remembered per emoji on this device (`@AppStorage`).
  - Moving the finger more than 10 pt before 0.4 s starts a drag instead.
  - Emoji without tone variants ignore the long-press.
- No hint line on this tab; the chips take its place.

### 4.7 Text tab (keyboard up)

```
│ (✕) Stickers Emoji [ Text ] Draw Hats …  │ panel 292 tall, sits on keyboard
│ ( hi sam|                    ) [ Add ]▘  │ field + Add, 48 tall
│      ●  ●  (●)  ●  ●  ●                  │ 6 dots, 44 hit
│ ▒▒▒▒▒▒▒▒▒▒▒▒  hi sam  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  │ live preview on checkerboard, 80
├──────────────────────────────────────────┤
│              system keyboard             │
```

- **Panel:** while the field has focus, the panel's height is its content (292). Its bottom sits on the keyboard's top (`.safeAreaInset`/keyboard layout guide), with square bottom corners. Without focus it is the usual 448 panel with the same content top-aligned.
- **Row 1 (top 80):**
  - Text field: height 48, pill, Background fill, 2 pt Outline, horizontal padding 18, `.body.weight(.semibold)`.
  - Placeholder "Type something", TextSecondary. Submit label `.done`, 30 character limit.
  - The field is the label's only input. VoiceOver label "Sticker text".
  - Add button: 10 pt from the field. Small primary pill, height 48, horizontal padding 20, Accent, 2.5 pt Outline, `StickerShadow` (the tray's one creating action), `.headline`. Disabled while the trimmed text is empty (40% opacity, no shadow).
- **Row 2 (top 140):** six colour dots centred, 4 pt apart (§6.5): Ink (`TextPrimary` light value #1E2A1A), Accent, NotePaperPink, NotePaperBlue, NotePaperGreen, NotePaperLilac. Ink is the default.
- **Row 3 (top 196):** preview, full width minus 16 pt insets, height 80, radius 16, checkerboard (§6.6). It shows the text exactly as the sticker will render: `.system(size: 40, weight: .heavy, design: .rounded)` in the chosen colour, with a 7 pt Ink (#1E2A1A) outline drawn behind the fill. It shrinks to fit (`minimumScaleFactor(0.4)`, one line). With an empty field, the preview shows the placeholder text "Type something" at 40% opacity.

### 4.8 Hats, Glasses and Filters tabs

- **Hats and Glasses:** the Stickers grid (§4.5) with the hat or glasses PNGs. No hint line until the hats ticket decides behaviour (§3.8).
- **Filters:** the same grid; each cell is a filter swatch.
  - **Swatch:** a 52 pt circle showing a still frame of your own face (captured when the tab opens) with the look applied, then the name 7 pt below it in `.caption.weight(.heavy)` (12). The name is TextSecondary, or TextPrimary when selected.
  - **Selected:** a 2.5 pt Background gap and a 2.5 pt Outline ring around the circle.
  - None is first. Hint: "Tap a look to try it. None turns it off".
  - Ticket [7] (heat test) may upgrade swatches to live crops if iPhone 11 has the headroom.

### 4.9 Pad (Draw tab)

```
│ (✕)              Draw              (✓)   │ ✓ Accent, 40% until a stroke
│ ┌──────────────────────────────────────┐ │
│ │▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│ │ canvas 382 × 262, checkerboard
│ │▒▒▒▒▒▒▒▒ ( Draw something to wear ) ▒▒│ │ hint until first stroke
│ │▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│ │
│ └──────────────────────────────────────┘ │
│ [✎] ⌫  ↶            ●  ●  (●)  ●  ●      │ tools · 5 dots
```

- **Header:** ✕ icon circle leading, "Draw" in `.headline` centred, ✓ icon circle trailing (Accent variant, §6.4). ✓ is disabled (40%, not tappable) until the canvas has a stroke.
- **Canvas:** top 80, 16 pt insets, height 262 (fills down to the toolbar with 12 pt gap), radius 20, 2 pt Outline, checkerboard behind a transparent `PKCanvasView`. `drawingPolicy = .anyInput`; the tool picker is never shown (R2).
- **Empty hint:** "Draw something to wear", centred, `.subheadline.weight(.semibold)`, TextSecondary, in a Surface capsule (padding 4 × 12). It fades out on the first stroke.
- **Toolbar (top 354, height 44, 16 pt insets):**
  - Leading: Pen, Eraser and Undo as 44 pt circles, 6 pt apart, with 22 pt symbols (`pencil.tip`, `eraser`, `arrow.uturn.backward`). The selected tool gets an Accent fill and a 2 pt Outline. Undo is never "selected" and is 40% while there is nothing to undo.
  - Trailing: five colour dots (§6.5): Ink, Accent, NotePaperPink, NotePaperBlue, NotePaperGreen (N2). The default is Pink.
- **Ink:** `PKInkingTool(.pen, color:, width: 9)`. The eraser is `PKEraserTool(.vector)`. Choosing a colour while the eraser is on switches back to the pen.

### 4.10 Sticker selected, with trash (state C)

- **Selected outline:** in your preview only, never composited into the outgoing video. `RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Accent, lineWidth: 2.5)`, 8 pt outside the sticker's on-screen bounds, rotating with the sticker.
- **Trash:** a 56 pt frosted circle centred horizontally, its bottom 16 above the control bar top, with a `trash` symbol 26 pt in Danger (dark value). It is shown only while a sticker is selected and the panel is closed.

## 5. Components

### Reuse (from design.md §6; not built yet, build them if this ticket lands first)

- `Avatar` (camera-off views)
- `PillButtonStyle` small primary with `StickerShadow` (Add)
- `PressableButtonStyle` press feedback (all buttons here: fill darkens over 0.1 s, no scale)

### New

| Component | Props | Notes |
| --- | --- | --- |
| `CallControlButton` | `symbol`, `label`, `style: .frosted / .active / .end`, `size: .bar (56) / .tile (44)`, `isEnabled` | Circle. `.frosted`: §6.2. `.active`: Accent fill, OnAccent symbol (mute on, camera off). `.end`: Danger fill, OnDanger symbol. Symbol 26 pt (bar) or 22 pt (tile), semibold |
| `NamePill` | `name`, `elapsed: Duration` | Frosted pill, `TimelineView(.periodic(by: 1))` for the timer |
| `VideoTile` | `participant`, `size: .small / .medium / .big`, `cameraOff` | One view for both people; camera-off content per §4.3. Buttons are passed in as an overlay |
| `CornerSnapper` | `corner: Corner`, `allowedRect` | Drag gesture + snap logic (§7) for the small tile |
| `EffectsPanel` | `selection: EffectTab`, `isOpen` | Panel frame, grabber, header with ✕ and `PillTabRow`, swaps to `DrawingPad` |
| `PillTabRow` | `tabs: [EffectTab]`, `selection` | Horizontal scroll, scrolls the selection into view |
| `StickerGrid` | `items`, `onDrag`, `onTap` | 3-row `LazyHGrid`, 84 cells |
| `EmojiStrip` | `categories`, `onDrag`, `onTap` | Sections, labels, chips, long-press tone picker |
| `SkinTonePicker` | `base: String`, `selection` | Capsule of 6 × 44 cells |
| `TextStickerComposer` | `text`, `colour`, `onAdd` | Field row, dots, preview |
| `DrawingPad` | `onCancel`, `onConfirm(CIImage)` | Header, canvas, toolbar |
| `ColourDots` | `colours`, `selection` | §6.5 |
| `IconCircleButton` | `symbol`, `label`, `style: .plain / .accent` | §6.4 |
| `TrashButton` | `onRemove` | 56 frosted, Danger symbol |
| `Checkerboard` | `square: 12` | §6.6 |

`EffectTab` is an enum: `stickers, emoji, text, draw, hats, glasses, filters`. A tab is listed only when its feature is enabled.

## 6. Visual details

### 6.1 Colour use

- The call chrome is always dark: apply `.environment(\.colorScheme, .dark)` to everything except the effects panel, so tokens resolve to their dark values.
- The panel uses `.environment(\.colorScheme, systemScheme)`, read from the scene before the override.
- No Outline and no sticker shadow anywhere over video (C1). Outlines appear only inside the panel and on avatars.
- Accent over video only on the active thing: Mute on, Camera off (N5), the selected-sticker outline. Inside the panel: the selected tab pill, the selected pad tool, ✓, Add.
- Danger (dark value #FF7A6E) fills End call, with OnDanger (*new*, §11) for its symbol, and colours the trash symbol.

### 6.2 Frosted fill (*new* token `CallFrost`)

`Circle()` or `Capsule()` filled with `.ultraThinMaterial` (dark scheme), with `CallFrost` on top. `CallFrost` is #342F29 at 55%. Symbols and text on it are TextPrimary (dark, #FFF8E2).

Over a white frame the result is about #8F8B86, which gives the cream symbol about 3.1:1, meeting the 3:1 non-text minimum. Over darker video it is higher.

### 6.3 Type

| Element | Style |
| --- | --- |
| Name in pill | `.subheadline.bold()` |
| Timer | `.subheadline.weight(.semibold).monospacedDigit()` |
| Camera-off name | `.title2.weight(.heavy)` |
| "Camera off" | `.subheadline.weight(.semibold)`, TextSecondary |
| Tab pill | `.subheadline.weight(.bold)` |
| Category label | `.footnote.weight(.bold)`, TextSecondary |
| Hints | `.subheadline.weight(.medium)`, TextSecondary |
| Pad title | `.headline` |
| Text field | `.body.weight(.semibold)` |
| Add | `.headline` |
| Filter name | `.caption.weight(.heavy)` |

The root `.fontDesign(.rounded)` applies (T13).

### 6.4 Icon circle buttons in the panel

- `.plain`: 44 pt circle, Background fill, 2 pt Outline, 20 pt symbol, TextPrimary.
- `.accent`: Accent fill, 2.5 pt Outline, OnAccent symbol.
- Disabled: 40% opacity.

### 6.5 Colour dots

- 44 × 44 hit area, 30 pt visible circle with a 2 pt Outline. The fill is the colour itself; NotePaper and Ink are the same in both modes.
- Selected: a 3 pt gap in the panel's Surface, then a 2.5 pt Outline ring (`.overlay(Circle().strokeBorder(...).padding(-5.5))`).
- Selection fades over 0.15 s.

### 6.6 Checkerboard

12 pt squares alternating Background and Divider (panel tokens), drawn with `Canvas` once and tiled. It marks transparency in the pad and the text preview.

### 6.7 Spacing and radius summary

| Element | Size / position (pt, iPhone 11) | Radius |
| --- | --- | --- |
| Control circle | 56; circles 794–850 | full |
| Name pill | 32 tall, top 58 | pill |
| Small tile | 100 × 150; insets 16; top 56 or 628 | 20 |
| Medium tile | 290 × 435, centred above the bar | 28 |
| Medium tile button | 44, 12 from corners | full |
| Panel | 414 × 448 (292 with keyboard) | 28 top |
| Header | top 20, 44 tall | — |
| Tab pill | 36 visible / 44 hit | pill |
| Grid cell | 84, gap 8, 3 rows | 16 |
| Emoji cell | 72, gap 4, 3 rows; 20 between sections | — |
| Category chip | 44 slot, 36 disc; top 346 | full |
| Colour dot | 30 visible / 44 hit | full |
| Canvas | 382 × 262, top 80 | 20 |
| Toolbar | top 354, 44 tall | — |
| Trash | 56, bottom = bar top − 16 | full |
| Selected outline | 2.5 pt, 8 pt out | 16 |

## 7. Motion and haptics

Fades and ease-outs only; no springs, no bounce, nothing idles (C18, design.md §8).

| Moment | Animation |
| --- | --- |
| Button press | Fill darkens (12% OnAccent on Accent, 6% TextPrimary on frost), `.easeOut(duration: 0.1)`; no scale |
| Small tile drag | Follows the finger 1:1. On release, the target corner is the nearest corner to (release point + velocity × 0.15 s); move there with `.easeOut(duration: 0.3)` |
| Tile to top corner when a panel opens, and back | `.easeOut(duration: 0.3)` |
| Small → medium | Tile scales from its corner to the centre, dim fades 0 → 0.4, buttons fade in, `.easeOut(duration: 0.25)` |
| Medium → small | Reverse, `.easeOut(duration: 0.2)` |
| Expand (swap) | Medium tile scales to fill the screen while the other video fades into the small tile, `.easeOut(duration: 0.3)` |
| Panel opens | Slides up from the bottom with opacity 0 → 1, `.easeOut(duration: 0.3)`; control bar fades out over 0.15 s |
| Panel closes (✕, swipe, drop, tap-add) | Slides down with opacity → 0, `.easeOut(duration: 0.25)`; control bar fades in over 0.2 s |
| Swipe down to close | Panel follows the finger down 1:1. Releasing past 30% of its height, or with downward velocity > 600 pt/s, closes it; otherwise it eases back up over 0.2 s |
| Tab change | Pill fills cross-fade 0.15 s; content cross-fades 0.15 s; `ScrollViewReader.scrollTo` the pill with `.easeOut(duration: 0.25)` |
| Category chip jump | `scrollTo(category, anchor: .leading)` with `.easeOut(duration: 0.35)` |
| Draw ↔ tray | Cross-fade 0.15 s in place |
| Keyboard up / down (Text) | Panel height follows the keyboard animation curve (`.animation(.easeOut(duration: 0.25))` keyed to keyboard height) |
| Selection outline, trash | Opacity fade `.easeOut(duration: 0.15)` |
| Camera on/off (either person) | Cross-fade 0.2 s |
| Tone picker | Fade in 0.15 s; out 0.1 s |
| Pad empty hint | Fades out 0.15 s on first stroke |

**Reduce Motion:** slides, scales and the tile's travel become opacity cross-fades of 0.2 s. The tile fades out at its old corner and in at the new one. Colour fades stay.

**Haptics (T3):**
- `.impact(weight: .light)` when a sticker lands on the face, by drag, tap, Add or ✓.
- `.success` on connect.
- `.error` when an action fails (camera flip, route change).
- Nothing on tray tabs, chips, dots, tools, snaps or buttons.

## 8. States

### Call

| State | What shows |
| --- | --- |
| Default (A) | Partner big, you small top-right, 4-button bar |
| Small tile in any corner | One of four corners; the bottom ones sit 16 above the bar |
| Medium, you (B) / partner (D) | §4.2 |
| Swapped (C) | You big, partner small, 5-button bar |
| Mute on | Mute circle `.active`, `mic.slash` |
| Camera off (yours) | Camera circle `.active`, `video.slash`. Your tile shows your avatar. The Stickers button and Add stickers are disabled (40%), because there's no face (D34 keeps placed stickers for later) |
| Back camera (after Flip) | Stickers button and Add stickers disabled; stickers hidden from video (D33) and shown again on flip back |
| Partner camera off | §4.3 in the big view or the partner's tile |
| Audio route | `AVRoutePickerView` inside the circle with the frosted style. The symbol follows the current route: `speaker.wave.2` speaker, `iphone` receiver, `airpods` / `headphones`, `car` for CarPlay |
| Long partner name | Name truncates in the pill (max 220 wide); timer always shows |
| Call ends | Fade out to the Calling tab |
| Action fails | `.error` haptic; the button returns to its prior state. Nothing else |

### Effects

| State | What shows |
| --- | --- |
| Tray open on each tab | §4.4–4.9 |
| Stickers empty (no PNGs) | Grid replaced by "No stickers yet.", centred in the content area, `.body`, TextSecondary |
| 10 stickers placed | Grid cells, emoji and Draw/Text actions at 40% and not interactive. The hint line (Stickers) and the chip row (Emoji) are replaced by "That's 10. Remove one to add more." in `.subheadline.weight(.medium)`, TextSecondary. Text: Add disabled. Draw: ✓ disabled after drawing, with the same line under the canvas |
| Too hot (thermal `.critical`, D35) | Stickers hidden from video. Opening the tray shows the same disabled treatment with "Stickers are paused while your phone cools down." The line goes away when the heat drops |
| Dragging a sticker out | A copy of the glyph at 1.2× follows the finger, 0.9 opacity; the panel slides away once the finger is above its top edge |
| Drag cancelled | Panel fades back; copy fades out at the finger |
| Face lost | Stickers freeze where they were (D20); no UI |
| Sticker selected | §4.10 |
| Text empty / long | Add disabled; preview shows the placeholder. Beyond 30 characters, input stops; the preview shrinks to fit |
| Pad empty / drawn | ✓ and Undo 40% / full |
| Filter selected | Ring on the swatch; video shows the look |

No loading states: all tray content is bundled.

## 9. Accessibility

- **Touch targets:** every control is at least 44 × 44 (bar 56, trash 56, tiles' buttons 44, pills 44 hit, dots 44, chips 44, tone cells 44). Adjacent hit areas may touch (dots, chips) because their visible shapes are spaced.
- **Contrast:**
  - Frosted symbols are at least 3:1 even over white video (§6.2).
  - OnAccent on Accent is 11.65:1 (dark Accent).
  - OnDanger on Danger (dark) is about 6.9:1.
  - Panel text pairs as design.md §3.
  - The selected-sticker outline (Accent) is a selection hint; selection is also announced and shown by the trash.
- **Never colour alone:** mute and camera off change their symbol; the selected tab, dot, chip and filter each have a fill change or ring; the selected pad tool has a fill.
- **Dynamic Type:**
  - Name pill and tab pills scale up to `.accessibility1` (`.dynamicTypeSize(...DynamicTypeSize.accessibility1)`), then stop. The tab row already scrolls.
  - Hints and labels in the panel wrap.
  - Grid cells, emoji, dots and control circles are fixed size.
- **Reduce Motion:** §7. **Reduce Transparency:** `CallFrost` becomes #342F29 at 90% with no material.
- **VoiceOver order:** name pill → big video → small tile → control bar left to right → trash (when shown). With the panel open: ✕ → tabs → content → chips.
- **VoiceOver labels:**

| Element | Label | Value / hint / actions |
| --- | --- | --- |
| Name pill | "Sam" | value "4 minutes 12 seconds"; `.updatesFrequently` |
| Big video | "Sam's video" / "Sam, camera off" | — |
| Small tile (yours) | "Your video" / "You, camera off" | hint "Double-tap for camera options"; actions "Move to top left", "Move to top right", "Move to bottom left", "Move to bottom right" |
| Small tile (partner, state C) | "Sam's video" | hint "Double-tap to show options" |
| Dim area | — | `accessibilityAction(.escape)` shrinks the tile |
| Expand | "Make my view big" / "Make Sam big" | — |
| Flip camera | "Flip camera" | value "Front" / "Back" |
| Add stickers (tile) / Stickers (bar) | "Add stickers" | disabled hint "Turn on your front camera to add stickers" |
| Mute | "Mute" / "Unmute" | value "Muted" when on |
| Camera | "Turn camera off" / "Turn camera on" | value "Camera off" when off |
| Audio route | "Audio output" | value: route name ("Speaker", "iPhone", "AirPods") |
| End call | "End call" | — |
| Trash | "Remove sticker" | — |
| Placed sticker | "Flower sticker" / "Text sticker, hi sam" / "Drawing sticker" | actions "Remove", "Make bigger", "Make smaller" |
| Panel ✕ | "Close stickers" (tray), "Back to stickers" (pad) | escape action closes |
| Tab pill | "Emoji" | trait `.isSelected` when selected; `.isHeader` on the row container "Effects" |
| Sticker / hat / glasses cell | file name made readable ("Party hat") | hint "Double-tap to add to your face" |
| Emoji cell | system emoji name ("grinning face") | hint "Double-tap to add. Actions for skin tone"; custom actions per tone |
| Category label | "Smileys" | `.isHeader` |
| Category chip | "Smileys" | `.isSelected` for current |
| Text field | "Sticker text" | — |
| Colour dot | "Ink", "Yellow", "Pink", "Blue", "Green", "Lilac" | `.isSelected` |
| Text preview | "Preview, hi sam, pink" | — |
| Add | "Add sticker" | — |
| Filter swatch | "Warm" | `.isSelected`; hint "Double-tap to apply" |
| Pad canvas | "Drawing canvas" | — |
| Pen / Eraser / Undo | "Pen" / "Eraser" / "Undo" | `.isSelected` on the tool |
| ✓ | "Use drawing" | disabled when empty |

- **Dragging alternatives:** tapping a tray cell adds the sticker (§3.3 step 6); placed stickers have Remove and size actions; the small tile has move actions.

## 10. Acceptance criteria

Call chrome
- [ ] The call screen is locked to portrait.
- [ ] The call view forces the dark scheme; the effects panel follows the system scheme.
- [ ] No Outline or sticker shadow is drawn over video; the frosted fill is `.ultraThinMaterial` + `CallFrost`.
- [ ] Name pill is centred at safe top + 10 with the partner's name and a monospaced timer that ticks each second.
- [ ] Control bar: 56 pt circles evenly spaced, bottom at safe bottom + 12, order Mute · Camera · Route · End; Stickers is added first while you are big.
- [ ] Mute on and camera off fill Accent and swap to slashed symbols; End call is Danger with an OnDanger symbol.
- [ ] Audio route opens the system route picker and its symbol follows the route.

Tiles
- [ ] Small tile 100 × 150, radius 20, shadow, 16 from the side edges; it snaps to the corner nearest the projected release point with a 0.3 s ease-out and never overlaps the bar.
- [ ] Tap the small tile: medium tile (70% width, 2:3, radius 28) centred above the bar with a 40% dim; the bar stays interactive; tap the dim to shrink.
- [ ] Medium (you): Expand, Flip, Add stickers at the specified corners. Medium (partner): Expand only.
- [ ] Expand swaps the views; tapping the partner's small tile then Expand swaps back.
- [ ] Camera-off views match §4.3 for both people.

Panel
- [ ] Tray and pad are an in-view panel of 50% screen height with 28 pt top corners, not a `.sheet`; it covers the bar and the bar returns on close.
- [ ] The partner's small tile moves to a top corner while the panel is open.
- [ ] ✕, swipe down past 30% (or fast), and the escape gesture all close it.
- [ ] Pill row lists Stickers · Emoji · Text · Draw (plus Hats · Glasses · Filters when enabled), scrolls horizontally, and scrolls the selected pill into view. Tabs change only on tap.
- [ ] The tray reopens on the last tab used in the session; the first open of a session shows Stickers.
- [ ] Stickers grid: 3 rows of 84 pt cells, scrolls horizontally, fifth column peeks; hint line shown; empty state reads "No stickers yet."
- [ ] Emoji: Apple's full set in a 3-row strip of 72 pt cells, sections with labels at their start, nine chips that jump with a 0.35 s ease-out and highlight the current category.
- [ ] Long-press an emoji with tones shows the 6-option picker; the pick is remembered per emoji.
- [ ] Text: with focus, the panel is 292 tall on the keyboard; Add is disabled when empty; six dots; preview matches the final sticker.
- [ ] Draw swaps in place; ✕ returns to the previous tab without confirmation; ✓ and Undo are disabled until a stroke; five colours; no `PKToolPicker`.
- [ ] Drag a cell out over the face: panel slides away, drop pins with a light haptic, panel stays closed. Drag back down cancels.
- [ ] Tap a cell, Add or ✓: the sticker appears at the nose point, selected, and the panel closes.

Stickers on face
- [ ] Tap a sticker: Accent outline in the preview only (verified not present in the partner's video) and the 56 pt trash appears 16 above the bar.
- [ ] Trash removes it; tapping elsewhere deselects and hides the trash.
- [ ] 10-cap, thermal and camera-off/back-camera states disable the tray as in §8.

Motion, haptics, accessibility
- [ ] No spring animations anywhere in the call screen; values as in §7; Reduce Motion turns movement into 0.2 s fades.
- [ ] Haptics only as §7.
- [ ] Every control has a 44 pt or larger hit area and the VoiceOver label, value and actions in §9.
- [ ] Reduce Transparency switches the frosted fill to 90% `CallFrost`.

## 11. Open questions

None open. Closed on 2026-10-20 by the main session:

1. **Hats and glasses** (how they go on, how many at once, the 10 cap): deferred to the hats ticket.
2. **Orientation:** the call screen is portrait-only in v1.
3. **Tap to add:** yes, for everyone. Tapping a cell adds the sticker at the nose point (§3.3 step 6).
4. **Filter swatches:** a still frame of your face, captured when the Filters tab opens. Ticket [7] (heat test) may upgrade them to live crops.

## 12. Design-system changes (approved by Adam, applied to design.md on 2026-10-20)

1. **Call chrome section:**
   - Always dark (forced dark scheme).
   - No Outline or sticker shadow over video.
   - Controls are frosted circles.
   - Accent only for active or "off" states (mute, camera off) and selection.
2. **New tokens:**
   - `CallFrost`: #342F29 at 55%, used over `.ultraThinMaterial` (dark).
   - `OnDanger`: #1B1814 in dark. Not needed in light for now, because the Danger fill only appears in the dark call chrome.
3. **Shadow exception:** floating video tiles (small and medium) get a soft black shadow. They are the only blurred shadows in the app, because they genuinely float over moving video.
4. **New shared pieces:**
   - `IconCircleButton` (44, `.plain` / `.accent`).
   - `ColourDots` with the gap-and-ring selection, also used for filter swatches.
   - `Checkerboard` for transparency.
5. **Selection grammar inside panels:**
   - Accent fill for the one selected tab or tool.
   - Outline ring for selected colours and swatches.
   - Divider disc for the current category chip.
   - Never two Accent selections in one row.
6. **Haptics:** no `.selection` haptic on in-panel tabs. T3's tab-change haptic stays limited to the app's tab bar.
