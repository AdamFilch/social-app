# New Note Screen: draw, photo, stickers, text and send

Oct 28, 2026 · approved by Adam (mockup v4) · designer run 2, revised for the outbox send
**Mockup**: https://claude.ai/artifact/GLgYnRxwsCit3FhxCSB8Yt (v4: Draw empty; Draw with strokes, stickers and a selected sticker with trash; Stickers tab; Emoji tab; Text with keyboard, one-row colours and font chips; Photo viewfinder; Photo taken and drawn on, Retake red; camera denied; "Discard this note?" dialog; "Sends when you're back online" toast over the Notes tab; every state in light and dark through the page switch)
**Source**: [mockups/new-note-screen.html](../mockups/new-note-screen.html)
**Feature spec**: [notes-widget-spec.md](../../context/notes-widget-spec.md) ("Making a note")
**Decisions**: D1–D27 (Adam, 2026-10-28, `~/.claude/plans/i-want-to-plan-velvet-sutherland.md`), A1–A6 (Adam's answers to the run 1 open questions) and L1–L3 (Adam's layout changes for v2 and v3). On 2026-10-28 Adam rewrote D7 and D8 to send through the outbox and superseded L3 (v4). All are listed in the mockup's legend and indexed in §13.

## 0. Revisions to existing docs

This spec changes the documents below. They are not edited here. The developer follows this spec where they differ, and whoever next updates those documents copies these rows in.

| # | Document and current text | Replaced by | Decision |
| --- | --- | --- | --- |
| R1 | notes-widget-spec "Photo background: take a photo with the front or back camera, or pick one from the camera roll, then draw on it" | Camera only, front or back, no camera roll. The camera opens on the one used last time, and on the back camera the very first time | D24, A5 |
| R2 | notes-widget-spec "Drawing: Apple's PencilKit tools: pen, pencil, marker, crayon, watercolour, fountain pen, eraser, lasso, ruler, undo and redo, any colour" | Pen, eraser and undo only, one pen width, 10 fixed ink colours (R3). `PKCanvasView` stays the engine with its tool picker hidden, as in the in-call pad | D14–D15 |
| R3 | notes-widget-spec "any colour"; design.md §3 (no ink colours) | A 10-colour ink palette for strokes and text: Ink, Accent, the 5 NotePaper pastels, Red, Orange, White. Red #E5483B and Orange #FF8A3D become content tokens `NoteInkRed` and `NoteInkOrange`, the same in both modes (§12) | D15, A3, A4 |
| R4 | notes-widget-spec "Text: type words onto the note, with a choice of font, size and colour" | Four fonts: Rounded (SF Pro Rounded), Serif (New York), Handwritten (Noteworthy), Mono (SF Mono). Size by pinching the placed text. Colour from the same 10 dots. Otherwise the in-call text tool, unchanged | D18, A2, A3 |
| R5 | notes-widget-spec "Face sticker: take a selfie (or pick a photo) and buttercup cuts out the face shape…"; "How it's built" Vision `VNGenerateForegroundInstanceMaskRequest` | Deferred. The Face tab is shown greyed out and can't be tapped. No Vision work in this ticket | D17 |
| R6 | notes-widget-spec "Shape stickers: basic shapes such as heart, star, circle and square" | Shapes come through the Stickers tab, which shows the bundled sticker PNGs (the same set as calls). Heart, star, circle and square must be among those PNGs | D16, D19 |
| R7 | design.md §6 Sheet: "If the sheet has unsaved work (a drawn note), confirm before it is dismissed: 'Discard this note?' with 'Discard' (destructive) and 'Keep drawing'" | The note editor is a full-screen cover, not a sheet. Its confirmation is a system alert: title "Discard this note?", message "You will lose your progress if you proceed", buttons "Discard" (destructive) and "Keep editing" (cancel) | D1, D9, A6 |
| R8 | design.md §5 Sticker shadow table (no row for the note editor); in-call spec §4.7 Add has the sticker shadow | New note: the shadow is on Send. The Text tab's Add has no shadow on this screen | D6 |
| R9 | design.md §6 Colour dots (single row only) | Two layouts: a 2-row grid that scrolls sideways (Draw) and a single row that scrolls sideways (Text) | L1 |
| R10 | technical-spec §Motion "Creating something (note, item, call options) opens a sheet with detents" | Making a note opens a full-screen cover. Items and call options are unchanged | D1 |

## 1. Problem and goal

"Make a note" on the Notes tab and "Send one back" on the Calling tab's latest-note card (design.md §7) need somewhere to go. This is the screen where you make one square, widget-shaped note and send it to your partner.

Goal: from tap to sent in a few seconds. The note is the screen; the tools sit under it where the thumb is. Nothing you made is lost without one clear question first.

## 2. User and situation

- **Who:** Adam or Sam, on an iPhone 11, sending a note to the other.
- **Where and how:** anywhere: on the sofa, at work, on a walk. Usually one-handed, thumb on the lower half, in a short burst between other things. Photo notes are often outdoors in bright light.
- **Job:** say "thinking of you" with something small and personal: a doodle, a photo with a heart on it, a word in a nice font.
- **What matters most:** the note itself, big and exactly as it will look on the widget, and a Send that's always in the same place.
- **Constraints:** design.md (tokens, one sticker shadow, quiet motion, haptics T3, SF Pro Rounded), D1–D27, A1–A6, L1–L3. Portrait only. The note is saved at 1000 × 1000 (D12). Out of scope: the face sticker (R5), the camera roll (R1), re-editing a placed text, saving drafts.

## 3. Flow

### 3.1 Entry and exit

- **Entry:** "Make a note" (Notes tab) and "Send one back" (Calling, latest-note card) both present `NewNoteView` with `.fullScreenCover`. The screen is the same and starts blank, in Draw mode, on the Draw tab, with the pen and Ink selected (D1, D2).
- **Exit without sending:** ✕, or a swipe down that starts in the top band (above the canvas, §7). With progress (§3.2), the discard alert shows first (§3.9).
- **Exit by sending:** Send closes the cover at once and a toast shows on the screen underneath (§3.8).
- The cover uses the system full-screen-cover transition. There's no custom animation.

### 3.2 Modes and progress

- Two modes: **Draw** (white canvas) and **Photo** (camera, then the photo as background). The pen | camera toggle switches between them (D3, L2).
- **Progress** means any stroke, sticker or text on the canvas, or a taken photo (D11). Text typed into the field but not added is not progress.
- **Switching mode** with progress shows the discard alert. Discard clears everything and opens the other mode blank. Without progress, the switch happens at once (D9).
- **Retake** (Photo mode only, A1) goes back to the viewfinder. With only a photo there is no alert. With anything on the photo, the alert shows first (D9–D11).

### 3.3 Draw tab

1. Draw with one finger. Strokes are 9 pt wide on screen (as in calls) in the selected colour.
2. Eraser removes whole strokes (vector eraser). It never removes stickers, text or the photo.
3. Undo steps back through strokes and erasures. It doesn't undo stickers; the trash removes those.
4. Picking a colour while the eraser is on switches back to the pen.

### 3.4 Stickers and Emoji tabs

1. **Tap** a cell: the sticker appears at the canvas centre at its default size, already selected (§3.6), with a light impact haptic (D19).
2. **Drag** a cell onto the canvas: it lands under the finger, not selected, with a light impact haptic. Released outside the canvas, nothing is added.
3. Emoji long-press opens the skin-tone picker, as in calls.
4. No cap on the number of stickers (D21).

### 3.5 Text tab

1. Tap Text: the field takes focus and the keyboard rises. The text tools (field, dots, font chips) sit on top of the keyboard (§4.5).
2. Type, pick a colour and a font. The text previews live on the canvas, centred horizontally in the part of the canvas still visible above the tools.
3. Add (or Return): the text is placed exactly where it previewed, selected (§3.6). The keyboard goes and the tools go back under the tab row. The field clears.
4. Dismiss the keyboard without adding: the tools go back under the tab row and keep the typed text until you change tab or close the screen.
5. A placed text can be moved, pinched, rotated and removed. It can't be edited; remove it and type it again.

### 3.6 Selection and editing

- Every sticker and text can be moved with one finger, pinched to resize (0.3× to 4× of default) and rotated with two fingers, whether or not it is selected (D20).
- Tap a sticker to select it: an Accent outline and the trash badge appear (§4.12). Tap the trash to remove it.
- While something is selected, the canvas doesn't draw. The next tap on empty canvas only deselects, then drawing works again.
- Strokes sit under stickers and text. The latest sticker or text added is on top; moving one brings it to the top.
- The selection outline and the trash are never saved into the note.

### 3.7 Photo mode

1. Tap the camera side of the toggle. On first use, iOS asks for camera access (§4.9 covers a refusal).
2. The viewfinder fills the canvas square. Pinch to zoom (1× to 5×). Flash and flip sit beside the shutter; there are no tabs (D22, D23).
3. Tap the shutter. The shutter, flash and flip fade out, the photo becomes the canvas background, and the tab row with the Draw tab fades in (D25).
4. From here every tool works as in Draw mode, on top of the photo.
5. Retake turns red once a photo exists (D5) and goes back to step 2 (§3.2 for the alert).
- **Which camera:** the one used last time, remembered on the device (`@AppStorage`). The very first time it is the back camera (A5).
- **Front camera:** the preview is mirrored, and the photo is saved mirrored too, so it looks exactly as it did on screen.
- **Flash:** off by default each time. It toggles between off and on for the back camera. On the front camera the button is disabled (40%), so there's no screen-flash in v1.
- **Crop:** the square centre of the capture, scaled to the 1000 × 1000 note.

### 3.8 Sending

1. Send is enabled once there is progress (D6).
2. Tap Send: the selection clears and the note is flattened to one 1000 × 1000 HEIC (technical-spec §Notes flow step 1). It is saved in the App Group with its `OutboxAction` and a note id made on the phone (D7).
3. The cover closes at once with the normal system transition. There is no spinner, no waiting and no failed state on this screen (D7, D8).
4. The toast shows on the screen underneath (§4.11), with the `.success` haptic (design.md §8):
   - **Online** (per `NWPathMonitor` at the moment of Send): "Sent to {partner}".
   - **Offline:** "Sends when you're back online".
5. The outbox flusher uploads in the background and retries when `NWPathMonitor` reports a connection. The phone-made id means a retry never makes two notes (technical-spec §1 Outbox). This screen plays no part in that (D8).
6. The new note shows in the Notes grid straight away from the local store.

### 3.9 Discard alert

- Shown for: mode switch, ✕, swipe down, and Retake with something on the photo, but only when there is progress (D9–D11).
- System `.alert`: title "Discard this note?", message "You will lose your progress if you proceed", buttons "Keep editing" (`.cancel`) and "Discard" (`.destructive`) (A6).
- Discard does what was asked: switch to the other mode blank, close the cover, or go back to the viewfinder. Keep editing does nothing.

## 4. Screens

Positions are for iPhone 11 (414 × 896, safe top 48, safe bottom 34). On other phones the canvas is the screen width minus 16, everything above it keeps its offsets from the safe top, and the tab row and tools follow the canvas.

### 4.1 Shared frame

```
┌──────────────────────────────────────────┐
│ 9:41                                5G ▭ │
│ (✕)                           [ Send ]▘  │ top bar: top 56, 44 tall
│ (Retake)                      ( ✎ | 📷 ) │ mode row: top 108, 44 tall
│┌────────────────────────────────────────┐│
││                                        ││ canvas 398 × 398, top 160
││              white note                ││ radius 20, 2.5 Outline
││                                        ││
│└────────────────────────────────────────┘│
│ [Draw] Stickers  Emoji  Text  Face       │ tab row: top 574
│                                          │ tab content: 630 to safe bottom
│                 ─────                    │
└──────────────────────────────────────────┘
```

- **Screen:** Background fill. The chrome follows light and dark; the canvas stays white in both (D27).
- **Top bar** (top 56): ✕ icon circle (`.plain`) at 16 from the left; Send at 19 from the right (16 plus the 3 pt sticker offset). Nothing else lives here (L2).
- **Send:** small primary pill, 44 tall, at least 84 wide, horizontal padding 20, Accent, 2.5 pt Outline, `StickerShadow`, label "Send" in `.headline`. Disabled: 40%, no shadow (D6).
- **Mode row** (top 108):
  - **Retake** on the left, Photo mode only (A1). Pill 40 visible / 44 hit, padding 0 16 (12 before the icon), symbol `arrow.counterclockwise` 18 pt + "Retake" in `.subheadline.weight(.bold)`, 6 pt between them.
    - Grey (before a photo): Divider fill, TextSecondary, not tappable.
    - Red (after a photo): Danger fill, 2 pt Outline, OnDanger text (§12 adds a light value for OnDanger) (D5).
  - **Mode toggle** on the right at 16 from the edge (D3, L2): a 44 pt pill with Surface fill, 2 pt Outline and 2 pt inner padding, holding two 46 × 36 segments with `pencil.tip` and `camera`, 21 pt. The current segment gets a Divider disc and a TextPrimary symbol; the other is TextSecondary. It is never Accent, so Send stays the one yellow control up here.
  - In Draw mode the left side of the row is empty. The row never collapses, so the canvas doesn't move between modes.
- **Canvas** (top 160, left 8, 398 × 398): white (#FFFFFF), radius 20 continuous, with a 2.5 pt Outline drawn on top of the content with `.strokeBorder`. The Outline is chrome and is not part of the saved image (D12, D13).
- **Tab row** (top 574, Draw mode and Photo after capture): `PillTabRow` with Draw · Stickers · Emoji · Text · Face, starting 12 from the left and running to the trailing edge, scrolling sideways. Pills as in calls: 36 visible / 44 hit, padding 14, `.subheadline.weight(.bold)`; selected Accent with a 2 pt Outline (D16).
- **Tab content:** from 630 to the safe bottom.

### 4.2 Draw tab (states 1, 2, 7)

```
│ [Draw] Stickers  Emoji  Text  Face       │
│ [✎] ⌫  ↶                                 │ tools, top 634
│  ●  ●  ●  ●  ●                           │ dots: 2 rows × 5, top 690
│  ●  ●  ●  ●  ○                           │
```

- **Tools** (top 634, left 16): Pen, Eraser, Undo as 44 pt circles, 6 pt apart, 22 pt symbols `pencil.tip`, `eraser`, `arrow.uturn.backward`. The selected tool gets an Accent fill and a 2 pt Outline. Undo is never selected and is 40% while there is nothing to undo.
- **Colour dots** (top 690, left 16): `ColourDots` in `.grid(rows: 2)` layout (L1). Column-first order, 44 pt cells, 4 pt gaps, 236 × 92 for 10 dots. It sits in a horizontal `ScrollView`; on an iPhone 11 all 10 fit, so it only scrolls on narrower phones or at larger sizes.
- Order (§6.3): Ink, Accent, Yellow, Pink, Blue, Green, Lilac, Red, Orange, White. Default Ink.
- **Empty hint** (state 1): "Draw something for {partner}", centred on the canvas, `.subheadline.weight(.bold)`, TextSecondary (light value) on a Background (light value) capsule, padding 4 × 14. It uses the light values in both modes because it sits on the white canvas. It fades out on the first stroke, sticker or text, and is never saved.

### 4.3 Stickers tab (state 3)

- `StickerGrid` with **2 rows** of 84 (calls use 3), 8 pt gaps, at top 632, 16 pt leading inset, scrolling sideways, a fifth column peeking in.
- Cells: Surface fill (the screen is Background; the in-call panel was the other way round), radius 16, no border, art fitted in 58 pt.
- Hint at top 820, centred: "Tap one, or drag it onto the note", `.subheadline.weight(.medium)`, TextSecondary.
- Content: every PNG in `assets/stickers`, in file-name order (R6).
- No PNGs: "No stickers yet." centred in the content area, `.body`, TextSecondary.

### 4.4 Emoji tab (state 4)

- `EmojiStrip` with **2 rows** of 72 (calls use 3), 4 pt gaps, top 628. Category labels inline above each section's first column, `.footnote.weight(.bold)`, TextSecondary, 18 tall.
- Category chips: nine 44 pt slots, edge to edge from x 9, top 808, 36 pt discs; the current one has a Divider disc. Tap to jump.
- Data, tone picker and per-emoji tone memory exactly as in-call spec §4.6.
- No hint line.

### 4.5 Text tab (state 5)

```
│┌────────────────────────────────────────┐│ canvas visible 160–432 (272)
││              hi sam                    ││ live preview
╞══════════════════════════════════════════╡ tools on keyboard, top 432
│ ( hi sam|                    ) [ Add ]   │ field + Add, 12 from tools top
│  ●  ●  (●)  ●  ●  ●  ●  ●  ●  ○ ·  ·     │ one row, scrolls, 64
│ [Rounded] [Serif] [✓ Handwritten] [Mono] │ font chips, 116
├──────────────────────────────────────────┤ keyboard top 596
│              system keyboard             │
```

- **With the keyboard up:** the text tools are a Surface panel, 164 tall, full width, top corners radius 28, sitting on the keyboard (top 432 on iPhone 11, following the keyboard layout guide). It covers the lower part of the canvas, leaving 272 pt visible (160 to 432).
- **With the keyboard down:** the same three rows sit under the tab row at 630 (field), 682 (dots), 734 (chips), on the screen's Background. The tab row is visible.
- **Row 1, field and Add:**
  - Text field: as in-call §4.7. 48 tall, pill, Background fill, 2 pt Outline, `.body.weight(.semibold)`, placeholder "Type something", 30 characters, submit label `.done`.
  - Add: 10 pt from the field, 48 tall, Accent, 2.5 pt Outline, `.headline`, **no sticker shadow** (R8). Disabled while the trimmed text is empty.
- **Row 2, colours:** `ColourDots` in `.row` layout (L1). The same 10 colours as Draw (A3), one line 44 tall, from x 16 to the trailing edge, scrolling sideways. It is 476 wide, so the last dots are cut by the edge. Default Ink.
- **Row 3, font chips:** four chips centred, 8 pt apart, each label set in its own font (A2, R4):

| Chip | Font for the label and the text | Label size |
| --- | --- | --- |
| Rounded | `.system(size:, weight: .heavy, design: .rounded)` | 16 |
| Serif | `.system(size:, weight: .bold, design: .serif)` (New York) | 16 |
| Handwritten | `Font.custom("Noteworthy-Bold", size:)` | 18 (it reads small) |
| Mono | `.system(size:, weight: .bold, design: .monospaced)` (SF Mono) | 14 (it reads wide) |

  Chips are design.md chips (36 visible / 44 hit, 2 pt Outline, Surface); selected: Accent fill, OnAccent, leading `checkmark`. Default Rounded.
- **Preview and placed text:** in the chosen font and colour at 52 pt on screen, one line, with the 7 pt Ink (#1E2A1A) outline drawn behind the fill, as in calls, for every font. Before it's added, the preview sits centred horizontally and centred in the visible part of the canvas.
- Font and colour reset to Rounded and Ink each time the screen opens.

### 4.6 Face pill

- Last in the tab row, at 40% opacity, not tappable, not selectable (D17).
- VoiceOver: "Face stickers, coming later", trait `.notEnabled`.

### 4.7 Photo viewfinder (state 6)

- The live preview (`AVCaptureVideoPreviewLayer`, `.resizeAspectFill`) fills the canvas square inside the same radius and Outline (D22).
- **Camera row** centred on y 692: Flash (44 icon circle, Surface fill, `bolt.slash` / `bolt`), Shutter, Flip (44, `arrow.triangle.2.circlepath.camera`), 56 pt apart.
- **Shutter:** a 76 pt ring with a 3 pt Outline, holding a 62 pt Accent disc with a 2.5 pt Outline. No sticker shadow.
- No tab row (D23). Retake is grey. Send is disabled. The toggle shows the camera side.

### 4.8 Photo taken (state 7)

- The canvas shows the photo, with strokes, stickers and text on top.
- The camera row fades out and the tab row and Draw tab fade in, in its place (D25).
- Retake is red. Send is enabled.

### 4.9 Camera denied or unavailable (state 8)

- The canvas square becomes a Surface panel (not white, since it isn't the note), with centred content, 12 pt apart (D26):
  - `camera.slash` 44 pt, TextSecondary.
  - "Camera is off for buttercup", `.headline`.
  - "Turn it on in Settings to take a photo for {partner}.", `.subheadline.weight(.medium)`, TextSecondary, up to 280 wide.
  - "Open Settings": a secondary pill, 44 tall, Background fill, 2.5 pt Outline, `.headline`. It opens `UIApplication.openSettingsURLString`.
- Flash, shutter and flip stay in place at 40%, not tappable. The toggle still works.
- Access is checked again when the app comes back to the foreground; with access, the viewfinder starts.
- **No camera** (Simulator, or a restricted device): the same panel with "No camera available" and no button.

### 4.10 Discard alert (state 9)

- System alert (§3.9). It uses system colours and the system destructive red, not app tokens.

### 4.11 Toast after sending (state 10, over the Notes tab)

```
│ Notes                                    │ the screen you came from
│  …                                       │
│     ( ⌀  Sends when you're back online ) │ toast, 12 above the tab bar
├──────────────────────────────────────────┤
│   Calling      [Notes]      Hobbies      │
```

- Shown by the app root (the cover has already closed) over the screen you came from: the Notes tab or the Calling tab.
- A capsule, centred, 12 pt above the tab bar's top edge: Surface fill, 2 pt Outline, height 48, horizontal padding 18, 8 pt between symbol and text, at most screen width − 40.
- Content: an 18 pt symbol and `.subheadline.weight(.bold)` text in TextPrimary.
  - Online: `checkmark` + "Sent to {partner}".
  - Offline: `wifi.slash` + "Sends when you're back online".
- Fades in over 0.15 s as the cover finishes closing, stays 2.5 s, fades out over 0.2 s. It never moves. A tap fades it out at once. Touches around it go through.
- The `.success` haptic when it appears (design.md §8).
- A second send while a toast is showing replaces its text.

### 4.12 Selected sticker (states 2 and 3)

- **Outline:** `RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Accent light #FFC61A, lineWidth: 2.5)`, 8 pt outside the sticker's bounds, rotating with it. The light Accent is used in both modes because it sits on the white canvas.
- **Trash badge:** a 32 pt circle (44 pt hit), Surface fill, 2 pt Outline, `trash` 16 pt in Danger. Centred on the outline's top-right corner. If that would leave the canvas, it moves to the nearest corner that stays inside. It moves and rotates its position with the sticker, but the badge itself stays upright.
- Both fade in and out over 0.15 s. Never saved.

## 5. Components

### Reuse (from design.md §6 and the in-call spec §5; build them if this ticket lands first)

| Component | Use here | Change |
| --- | --- | --- |
| `IconCircleButton` `.plain` | ✕, flash, flip | none |
| `PillButtonStyle` small primary + `StickerShadow` | Send | none |
| `PillButtonStyle` secondary | Open Settings | none |
| `PressableButtonStyle` | every button | none |
| `PillTabRow` | Draw · Stickers · Emoji · Text · Face | add a `disabled` set of tabs, shown at 40%, not tappable |
| `StickerGrid` | Stickers tab | add `rows: Int` (calls 3, notes 2) and `cellFill` (calls Background, notes Surface) |
| `EmojiStrip` | Emoji tab | add `rows: Int` |
| `SkinTonePicker` | Emoji long-press | none |
| `TextStickerComposer` | Text tab | add `colours`, `fonts: [NoteFont]?` (no chips in calls), `addHasShadow: Bool` (false here), and a `preview: .inline / .external` switch (calls show the checkerboard preview; notes preview on the canvas) |
| `ColourDots` | Draw and Text | add `layout: .row / .grid(rows: Int)`, scrolling sideways in both |
| `Chip` | font chips | none |

### New

| Component | Props | Notes |
| --- | --- | --- |
| `NewNoteView` | `partnerName`, `onSent(NoteSendResult)` | The cover. Holds `NoteDraft`, mode and tab; shows the alert. Send renders, writes the outbox entry, calls `onSent(.online / .offline)` and dismisses |
| `NoteToast` | `message`, `symbol` | Shown by the app root over the tab bar, §4.11 |
| `NoteDraft` (`@Observable`) | `mode: .draw / .photo`, `photo: UIImage?`, `drawing: PKDrawing`, `items: [NoteItem]`, `selection: NoteItem.ID?` | `hasProgress` = photo != nil or strokes or items not empty |
| `NoteItem` | `id`, `kind: .sticker(name) / .emoji(String) / .text(String, NoteFont, Color)`, `center`, `scale`, `rotation` | Positions in canvas points (0…398), scaled to 1000 on export |
| `NoteCanvas` | `draft`, `tool`, `colour` | White square, photo layer, `PKCanvasView` (tool picker hidden, `.anyInput`), items layer, selection overlay, Outline on top |
| `NoteItemView` | `item`, `isSelected`, `onSelect`, `onRemove` | Drag, `MagnifyGesture`, `RotateGesture` together; shows outline and `TrashBadge` when selected |
| `TrashBadge` | `onRemove` | 32 visible / 44 hit, §4.12 |
| `ModeToggle` | `mode`, `onRequestChange` | Two-segment pill, §4.1; asks the parent so the alert can step in |
| `RetakeButton` | `hasPhoto`, `action` | Grey and red states, §4.1 |
| `CameraView` | `position`, `flash`, `onCapture(UIImage)` | `AVCaptureSession` + preview layer, pinch zoom 1–5×, square crop, mirroring per §3.7 |
| `CameraRow` | `flash`, `canFlash`, `onShutter`, `onFlip` | §4.7 |
| `CameraBlockedView` | `reason: .denied / .unavailable`, `partnerName` | §4.9 |
| `DrawTools` | `tool`, `canUndo`, `onUndo` | Pen, eraser, undo, §4.2 |
| `NoteFont` | enum `rounded, serif, handwritten, mono` with `font(size:)` | §4.5 table |
| `NoteRenderer` | `draft` → 1000 × 1000 HEIC | `ImageRenderer` at scale 1000/398 of the canvas without Outline, selection or hint |

## 6. Visual details

### 6.1 Colour use

- Chrome uses the design.md tokens and follows the system scheme: Background, Surface, TextPrimary, TextSecondary, Outline, Accent, OnAccent, Divider, Danger, OnDanger.
- The canvas is #FFFFFF in both modes. Anything drawn on it by the app (hint, selection outline) uses light-mode values, because the canvas is always light.
- Accent fills only: Send, the selected tab pill, the selected tool, the selected font chip, Add, the shutter disc and the selection outline. The mode toggle is never Accent.
- Danger: Retake after a photo (fill), the trash symbol.

### 6.2 Type

| Element | Style |
| --- | --- |
| Send, Add, Open Settings | `.headline` |
| Retake | `.subheadline.weight(.bold)` |
| Toast | `.subheadline.weight(.bold)`, TextPrimary |
| Tab pill | `.subheadline.weight(.bold)` |
| Canvas hint | `.subheadline.weight(.bold)` |
| Sticker hint | `.subheadline.weight(.medium)`, TextSecondary |
| Category label | `.footnote.weight(.bold)`, TextSecondary |
| Text field | `.body.weight(.semibold)` |
| Denied title / line | `.headline` / `.subheadline.weight(.medium)` |
| Note text | `NoteFont` at 52 pt, §4.5 |

The root `.fontDesign(.rounded)` applies (T13) to everything except the Serif, Handwritten and Mono note text and their chips.

### 6.3 Ink palette (R3)

| # | Name (VoiceOver) | Token | Value |
| --- | --- | --- | --- |
| 1 | Ink | TextPrimary light | #1E2A1A |
| 2 | Buttercup | Accent light | #FFC61A |
| 3 | Yellow | NotePaperYellow | #FFE88A |
| 4 | Pink | NotePaperPink | #FFC6D9 |
| 5 | Blue | NotePaperBlue | #BFDDFF |
| 6 | Green | NotePaperGreen | #C9EDB6 |
| 7 | Lilac | NotePaperLilac | #DCCDFF |
| 8 | Red | NoteInkRed *new* | #E5483B |
| 9 | Orange | NoteInkOrange *new* | #FF8A3D |
| 10 | White | (plain) | #FFFFFF |

These are content colours: the same in both modes, because they are part of the note image. Ink and Accent always use their light values. White's 2 pt Outline keeps its dot visible.

### 6.4 Spacing and sizes summary (iPhone 11)

| Element | Size / position (pt) | Radius |
| --- | --- | --- |
| ✕ | 44, top 56, left 16 | full |
| Send | 44 tall, ≥ 84 wide, top 56, right 19 | pill |
| Mode toggle | 44 pill, 2 × 46 × 36 segments, top 108, right 16 | pill |
| Retake | 40 visible / 44 hit, top 110, left 16 | pill |
| Canvas | 398 × 398, top 160, left 8 | 20 |
| Tab row | 36 / 44, top 574, from x 12 | pill |
| Draw tools | 44 circles, gap 6, top 634 | full |
| Draw dots | 2 rows × 5, 44 cells, gap 4 (236 × 92), top 690 | full |
| Sticker grid | 2 rows × 84, gap 8, top 632; hint 820 | 16 |
| Emoji strip | 2 rows × 72, gap 4, top 628; chips 808 | — |
| Text tools, keyboard up | 164 tall, top 432; field 12, dots 64, chips 116 | 28 top |
| Text tools, keyboard down | field 630, dots 682–726, chips 734–778 | — |
| Visible canvas, keyboard up | 160 to 432 (272) | — |
| Camera row | centred y 692; flash and flip 44, shutter 76, gaps 56 | full |
| Selection outline | 2.5, 8 out | 16 |
| Trash badge | 32 / 44, on the outline's corner | full |
| Toast | 48 tall, padding 18, 12 above the tab bar, ≤ width − 40 | pill |

## 7. Motion and haptics

Fades and ease-outs only; no springs, no bounce, nothing idles (D27, design.md §8).

| Moment | Animation |
| --- | --- |
| Open / close | System full-screen-cover transition |
| Swipe down to close | Starts only in the band above the canvas (y < 160). The screen follows the finger 1:1. Released past 30% of the height or faster than 600 pt/s: closes (or, with progress, eases back over 0.2 s and shows the alert). Otherwise eases back over 0.2 s |
| Button press | Fill darkens over 0.1 s ease-out, sticker offset 3 → 0; no scale |
| Mode switch (Draw ↔ Photo) | Canvas content and the area under it cross-fade 0.2 s; the toggle disc cross-fades 0.15 s |
| Retake appears / turns red | Opacity / colour fade 0.15 s |
| Capture | Viewfinder freezes on the frame and the camera row cross-fades to the tab row, 0.15 s |
| Tab change | Pill fills cross-fade 0.15 s; content cross-fades 0.15 s; the row scrolls the pill into view with `.easeOut(duration: 0.25)` |
| Category chip jump | `.easeOut(duration: 0.35)` |
| Keyboard up / down (Text) | Text tools follow the keyboard's own animation |
| Sticker added by tap | Fades in at the centre over 0.15 s; no scale |
| Selection outline, trash badge | Fade 0.15 s |
| Canvas hint | Fades out 0.15 s on first content |
| Send | The cover closes with the system transition |
| Toast | Fades in 0.15 s, holds 2.5 s, fades out 0.2 s; no movement |

**Reduce Motion:** the swipe-down follow becomes a plain fade on release; everything else is already a fade.

**Haptics (T3):**
- `.impact(weight: .light)` when a sticker, emoji or text lands on the canvas (tap, drop, Add).
- `.success` once when the toast appears after Send (design.md §8, Adam confirmed 2026-10-28).
- Nothing on tabs, tools, dots, chips, the toggle, Retake or the shutter. iOS plays its own shutter sound.

## 8. States

| State | What shows |
| --- | --- |
| Draw, empty | §4.2 with the hint; Send 40%; Undo 40% |
| Draw, with content | Strokes under stickers and text; Send live |
| Something selected | §4.12; drawing paused until a tap on empty canvas |
| Stickers / Emoji / Text tab | §4.3–4.5 |
| Stickers empty (no PNGs) | "No stickers yet." |
| Text empty | Add disabled; preview shows nothing on the canvas |
| Text long | Input stops at 30 characters; the placed text can be pinched smaller |
| Many stickers | No cap; each one stays movable |
| Photo, asking for access | The system prompt over a blank Surface square |
| Photo, viewfinder | §4.7 |
| Photo, front camera | Mirrored preview; flash 40% |
| Photo taken | §4.8 |
| Camera denied / unavailable | §4.9 |
| Discard alert | §4.10 |
| Sent, online | Cover closes; toast "Sent to {partner}"; `.success` haptic |
| Sent, offline | Cover closes; toast "Sends when you're back online"; `.success` haptic. The outbox sends it later |
| App backgrounded mid-draft | The draft stays in memory while the app lives. It isn't saved if iOS ends the app |
| Interrupted camera (call, other app) | The viewfinder shows the last frame at 40% until the session resumes |

## 9. Accessibility

- **Touch targets:** at least 44 × 44 everywhere: ✕, Send, Retake, toggle segments (46 × 36 visible inside a 44 tall pill; the hit area is the full 44 height), tab pills, tools, dots, chips, trash badge (44 hit), flash, flip, shutter (76). Neighbouring dot cells touch; their visible circles are 14 pt apart.
- **Contrast:**
  - All chrome text pairs as design.md §3.
  - OnDanger on Danger: dark 6.9:1; light (#FFFDF5 on #C2362B) 5.35:1.
  - The Divider disc in the toggle is a selection hint; the symbol also switches to TextPrimary from TextSecondary, and VoiceOver announces it.
  - Strokes and text on the note are content, not UI.
- **Never colour alone:** the selected tab, tool and chip have fills (the chip also has a check), the selected dot has a ring, the selected sticker has an outline and the trash, Retake's "grey" state is also not tappable and announced, and the toast has a symbol and words.
- **Dynamic Type:** chrome labels scale up to `.accessibility1`, then stop. The tab row and the colour rows scroll. The toast wraps to two lines in a taller capsule. Canvas, cells, dots and circles are fixed size.
- **VoiceOver order:** ✕ → Send → Retake → mode toggle → canvas items (in z-order) → canvas → tab row → tab content.
- **VoiceOver labels:**

| Element | Label | Value / hint / actions |
| --- | --- | --- |
| ✕ | "Close" | — |
| Send | "Send to {partner}" | disabled hint "Draw or add something first" |
| Toast | its text | posted as an announcement; not focusable |
| Retake | "Retake photo" | disabled when there is no photo |
| Mode toggle | "Draw" / "Photo" segments | `.isSelected` on the current one |
| Canvas | "Note" | value "Empty" / "Photo with 3 stickers and drawing"; with Pen on, hint "Draw with one finger" |
| Placed item | "Flower sticker" / "Text, miss you" / "Grinning face" | actions "Remove", "Make bigger", "Make smaller", "Rotate left", "Rotate right", "Move up/down/left/right" |
| Trash badge | "Remove sticker" | — |
| Tab pill | "Stickers" | `.isSelected`; Face: "Face stickers, coming later", `.notEnabled` |
| Pen / Eraser / Undo | "Pen" / "Eraser" / "Undo" | `.isSelected` on the tool |
| Colour dot | §6.3 name | `.isSelected` |
| Sticker / emoji cell | readable file name / system emoji name | hint "Double-tap to add to the note" |
| Text field | "Note text" | — |
| Font chip | "Rounded" / "Serif" / "Handwritten" / "Mono" | `.isSelected` |
| Add | "Add text" | — |
| Flash | "Flash" | value "Off" / "On"; disabled on the front camera |
| Shutter | "Take photo" | — |
| Flip | "Switch camera" | value "Back" / "Front" |
| Open Settings | "Open Settings" | — |

- **Dragging alternatives:** tapping a cell adds it at the centre; placed items have move, size, rotate and remove actions.
- **Escape gesture:** same as ✕ (with the alert when there is progress).

## 10. Acceptance criteria

Frame
- [ ] "Make a note" and "Send one back" both open `NewNoteView` as a full-screen cover, blank, in Draw mode, Draw tab, Pen, Ink.
- [ ] Top bar holds only ✕ (left) and Send (right). Send has the sticker shadow and is disabled (40%, no shadow) until there is progress.
- [ ] The row above the canvas has the mode toggle on the right in both modes and Retake on the left in Photo mode only. The canvas is in the same place in both modes.
- [ ] Canvas is screen width − 16, square, radius 20, white in light and dark, with a 2.5 pt Outline that is not in the saved image.
- [ ] Chrome follows the system scheme; the canvas, hint and selection outline look the same in both.

Draw and tabs
- [ ] Tab row: Draw · Stickers · Emoji · Text · Face, scrolling; Face at 40% and not tappable.
- [ ] Draw: pen, eraser (vector, strokes only), undo (strokes only, 40% when empty); one 9 pt pen width; no `PKToolPicker`.
- [ ] Draw dots: 10 colours in §6.3 order, in a 2-row grid that scrolls sideways.
- [ ] Stickers: 2-row grid of 84 pt cells with the hint; Emoji: 2-row strip with labels, jump chips and tone picker.
- [ ] Tap a cell: the item appears at the canvas centre, selected, with a light haptic. Drag a cell onto the canvas: it lands under the finger, unselected. No cap.
- [ ] Any item can be moved, pinched (0.3–4×) and rotated whether or not selected. Tap selects: outline and trash badge. The trash removes. A tap on empty canvas deselects without drawing.

Text
- [ ] Text tab: field + Add (no shadow), one sideways-scrolling row of the same 10 dots, four font chips each drawn in its own font (SF Pro Rounded, New York, Noteworthy, SF Mono).
- [ ] With the keyboard up, the text tools sit on the keyboard (164 tall on iPhone 11) and at least 272 pt of the canvas stays visible; the text previews live in that area in the chosen font and colour with the 7 pt Ink outline.
- [ ] Add places the text where it previewed, selected; Add is disabled for empty text; 30 character limit.

Photo
- [ ] Camera opens on the last-used camera; the first time ever, the back camera. No photo library access is requested or offered.
- [ ] Viewfinder fills the canvas square, pinch zoom 1–5×; under it only flash, shutter, flip; no tab row; Retake grey; Send disabled.
- [ ] Capture: the photo (square centre crop, mirrored for the front camera) becomes the background; camera row is replaced by the tab row; Retake turns red; Send enabled.
- [ ] Retake with only the photo goes straight back to the viewfinder; with anything on it, the alert shows first.
- [ ] Camera denied: the panel with "Camera is off for buttercup" and "Open Settings", which opens the app's Settings; access is rechecked on return. No camera: "No camera available".

Discard and send
- [ ] With progress, mode switch, ✕, swipe down (from the top band) and Retake-with-content show the alert "Discard this note?" / "You will lose your progress if you proceed" / "Keep editing" (cancel) / "Discard" (destructive). Without progress there is no alert.
- [ ] Send saves a 1000 × 1000 HEIC and an `OutboxAction` with a phone-made note id, then closes the cover at once. No spinner, no failed state.
- [ ] After the cover closes, the toast shows over the screen underneath: "Sent to {partner}" online, "Sends when you're back online" offline, with the `.success` haptic; fade in 0.15 s, 2.5 s, fade out 0.2 s.
- [ ] Offline, the note sends by itself once a connection returns, and only once.
- [ ] The new note appears in the Notes grid straight away.
- [ ] The saved image is 1000 × 1000 and matches the canvas exactly, without Outline, hint, selection or trash.

Motion and accessibility
- [ ] No springs; values as §7. Haptics only as §7.
- [ ] Every control has a 44 pt hit area and the VoiceOver label, value and actions in §9.
- [ ] Photo mode is checked on a physical iPhone; the Simulator shows the "No camera available" state.

## 11. Open questions

None open. Closed on 2026-10-28:

1. **Sending offline:** Adam chose the outbox (D7 and D8 rewritten). Send closes at once and the toast says whether the note went or will go.
2. **Editing placed text:** Adam confirmed placed text can't be edited again in v1.

### Follow-ups for other tickets

- **Notes-tab ticket:** a pending (queued) badge on the sender's own note tile in the Notes grid while its upload is still in the outbox. Out of scope here.

## 12. Proposed design-system changes (for design.md's decision log)

1. **New content tokens** `NoteInkRed` #E5483B and `NoteInkOrange` #FF8A3D, the same in both modes, beside the NotePaper pastels. Used only as note ink (§6.3).
2. **Ink palette:** the 10 colours in §6.3, in that order, for note strokes and note text.
3. **`OnDanger` light value** #FFFDF5 (5.35:1 on light Danger) for the red Retake. Until now the Danger fill only appeared in the dark call chrome.
4. **Sheet section → note editor:** replace "Discard this note?" with "Discard" and "Keep drawing" by the system alert in §3.9 ("Keep editing"), and say the note editor is a full-screen cover (R7, R10).
5. **Sticker shadow table:** add "New note: Send" (R8).
6. **Colour dots:** add the `.grid(rows: 2)` and `.row` layouts, both scrolling sideways (R9).
7. **Canvas rule:** a note canvas is white in both modes, and app marks drawn on it (hint, selection) use light-mode values.
8. **Mode toggle:** a two-segment pill whose current segment is a Divider disc, so it never competes with the primary Accent action nearby.
9. **Icons:** add `camera`, `camera.slash`, `arrow.counterclockwise` (retake), `bolt` / `bolt.slash`, `arrow.triangle.2.circlepath.camera` to §9.
10. **Screens §7:** add "New note" with the frame in §4.1.

## 13. Decision index

| Decision | Where |
| --- | --- |
| D1 same blank screen, full-screen cover | §3.1, R7, R10 |
| D2 opens in Draw | §3.1 |
| D3 pen \| camera toggle | §4.1 (position per L2) |
| D4 ✕ above Retake, just above the canvas | §4.1 |
| D5 Retake grey, then red | §4.1, §4.8 |
| D6 Send Accent, disabled until content | §4.1, §3.8 |
| D7 (rewritten v4) Send saves the note to the outbox and closes at once; toast after | §3.8, §4.11 |
| D8 (rewritten v4) no failed state on this screen; the flusher retries in the background | §3.8 |
| D9–D11 discard alert triggers and what counts as progress | §3.2, §3.9 |
| D12–D13 canvas size, radius, 1000 × 1000, always white | §4.1, §5 `NoteRenderer` |
| D14–D15 pen, eraser, undo, colour dots | §3.3, §4.2, R2, R3 |
| D16–D17 tab row, Face greyed out | §4.1, §4.6, R5 |
| D18 Text = in-call tool + font chips | §4.5, R4 |
| D19–D21 tap to centre selected, drag, gestures, trash, no cap | §3.4, §3.6, §4.12 |
| D22–D23 viewfinder fills the square, pinch zoom, flash/shutter/flip only | §3.7, §4.7 |
| D24 camera only | §3.7, R1 |
| D25 after capture: photo background, tab row | §3.7, §4.8 |
| D26 camera denied | §4.9 |
| D27 light/dark chrome, white canvas, quiet motion and haptics | §6.1, §7 |
| A1 Retake only in Photo mode | §4.1 |
| A2 Noteworthy for Handwritten | §4.5, R4 |
| A3 Text uses Draw's colours | §4.5, R3 |
| A4 no Black, 10 colours | §6.3, R3 |
| A5 last-used camera, back the first time | §3.7, R1 |
| A6 alert copy and buttons | §3.9, R7 |
| L1 Draw dots in a 2-row grid, Text dots in one row | §4.2, §4.5, R9 |
| L2 top bar ✕ and Send only; Retake and toggle in the row above the canvas | §4.1 |
| L3 Send becomes Retry, with the error line | superseded in v4 by the new D7 and D8; removed |

### Decided in this spec (not covered by D, A or L)

- One pen width (9 pt on screen); eraser and undo affect strokes only.
- Drag-dropped stickers land unselected; tapped ones land selected (as in calls).
- Drawing pauses while something is selected; the next tap only deselects.
- Text is not re-editable after Add (confirmed by Adam for v1); text renders at 52 pt; font and colour reset to Rounded and Ink on each open.
- Front-camera photos are saved mirrored, as previewed. Flash is off by default and disabled on the front camera. Zoom is 1–5×.
- Swipe down to close starts only above the canvas, so it never fights drawing.
- The toast sits 12 pt above the tab bar and is shown by the app root, so it outlives the cover.
- The cover uses the system full-screen transition.
- The trash is a badge on the selection's corner, because there is no control bar here.
- The "No camera available" variant of §4.9 for the Simulator and restricted devices.
