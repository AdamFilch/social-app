# buttercup features catalog

What the app does today, one entry per feature. Status words: **Built**, **Built (partial)**, **Planned**. Never renumber or rename entries; other documents link to their anchors. New features are appended after the last entry with a matching index row.

## Index

| # | Feature | Status |
|---|---|---|
| 1 | [Accounts and pairing](#1-accounts-and-pairing) | Built |
| 2 | [Calls](#2-calls) | Built (partial) |
| 3 | [Notes](#3-notes) | Built (partial) |

---

## 1. Accounts and pairing

**Status:** Built

**What it does:** Signs a person in with a six-digit email code, asks for their name, and pairs them with their partner. Once paired, the app opens on the Calling / Notes / Hobbies tab shell with the partner's name on the Calling tab.

**Flow:**
1. Email screen: type an email, "Send code". Supabase emails a six-digit code (locally caught by Mailpit at `http://127.0.0.1:54324`).
2. Code screen: type the code, "Sign in". A wrong or expired code shows "That code didn't work." and stays on the screen.
3. Name screen: type a name, "Continue". Saves `profiles.display_name` and `profiles.time_zone` (from the phone).
4. Pair screen: an invite is created on arrival; "Invite" opens the share sheet with `buttercup://invite/CODE` and "Pair with me on buttercup", and the code is shown as selectable text. The partner opens the link or pastes the code and taps "Pair", which calls `accept_invite`. The inviter's screen refreshes every 5 s and on becoming active, so it moves on once the partner accepts.
5. Ready: each phone sets its own `avatar_tint` to the first NotePaper colour (Blue, Pink, Green, Lilac, Yellow) the partner isn't using; on a collision the later-created profile moves on next launch.
6. Sign out: a button on the Calling tab (and on the Pair screen) returns to the email screen.

**Rules:**
- State: no session → email; empty `display_name` → name; no partner profile visible → pair; otherwise the tab shell. The partner's `profiles` row is only readable once paired (RLS), so its presence decides paired vs unpaired.
- A `buttercup://invite/CODE` link opened while signed out or before the name is set is kept in memory and accepted once the app reaches the Pair screen. Links opened while already paired are ignored.
- Invite errors: `invite_not_found` "That code isn't right.", `invite_expired` "That invite has expired. Ask for a new one.", `invite_used` "That invite was already used.", `cannot_pair_self` "That's your own invite.", `already_paired` "You're already paired."
- Session is stored by `supabase-swift` in the Keychain (`kSecAttrAccessibleAfterFirstUnlock`) and survives relaunch.
- Debug builds talk to local Supabase (`http://127.0.0.1:54321`); Release builds to the hosted project. Set by the `SUPABASE_URL` / `SUPABASE_ANON_KEY` build settings, read from `Info.plist`.
- Failed actions play the `.error` haptic; nothing else has a haptic.

**Code:** `ButtercupKit/Sources/ButtercupKit/SessionStore.swift` (client, `Profile`, `SessionStore`), `Buttercup/Onboarding.swift` (email/code, name, pair screens), `Buttercup/ButtercupApp.swift` (root switch, `onOpenURL`), `Buttercup/ContentView.swift` (`CallingTab`), `Buttercup/Info.plist` (URL scheme, Supabase keys), `supabase/config.toml` + `supabase/templates/code.html` (email code template). Spec: [prds/completed/2-foundation-sign-in-pairing.prd.md](../prds/completed/2-foundation-sign-in-pairing.prd.md).

**Known gaps:**
- Sign in with Apple is not built (needs a paid Apple Developer account).
- No unpairing.
- Screens are plain SwiftUI, not yet restyled to the design system.

---

## 2. Calls

**Status:** Built (partial): backend and app screens are built; simulator-to-browser media (AC1), two-device calls (AC2) and the partner-side view of a camera toggle (AC6) are not yet verified.

**What it does:** Creates, answers and ends 1:1 audio and video calls between paired partners. A call is one `calls` row plus a LiveKit room named after its id; the functions return LiveKit tokens, and the apps follow status changes over Realtime.

**Flow:**
1. `start-call {kind}` finds the partner, inserts a `ringing` row with `room_name = id`, and returns `{call, token, livekit_url}`.
2. The callee's app sees the insert over Realtime `postgres_changes` on `calls`.
3. `answer-call {call_id}` (callee) sets `answered` + `answered_at` and returns the callee's token. Repeating it on an answered call returns a fresh token (reconnect).
4. `end-call {call_id, reason}` sets `declined` (callee, from ringing), `cancelled` / `missed` (caller, from ringing) or `ended` (either, from answered), with `ended_at`.
5. A `pg_cron` job (`sweep-ringing-calls`, every minute) marks calls still ringing after 60 s as `missed`.
6. App: the Calling tab shows the partner, Audio and Video buttons and Recent calls ("No calls yet. Give {name} a ring?" when empty). Tapping a button shows "Calling {name}…" with Cancel; the callee gets a "{name} is calling" sheet with Answer and Decline.
7. App in-call screen: partner feed full size, a self tile (tap for the mid tile with Flip and ↗, ↗ swaps the views), Mute, Camera, audio route and Hang up, a call timer, and "Connecting…" / "Reconnecting…" banners.

**Rules:**
- One active (`ringing` or `answered`) call per pair, enforced by the `calls_one_active_per_pair` index. If the partner's call is already ringing, `start-call` returns `{call, incoming: true}` and no token; repeating my own ringing call returns it again.
- An `answered` call whose LiveKit room is empty (both apps died) is ended by the next `start-call`; if someone is in the room, `start-call` returns 409 `busy`.
- Errors are `{error}`: 400 `bad_request`, 401 `unauthorized`, 403 `not_paired`, 404 `call_not_found`, 409 `busy` / `call_not_ringing` (with `status`) / `invalid_transition`. `end-call` on a finished call returns it unchanged.
- Tokens: identity = user id, 2 h TTL, join/publish/subscribe for that room only. Never stored in `calls`.
- The app only reads `calls` (RLS: caller or callee); all writes go through the functions with the service role.
- App: `end()` sends `cancelled` from outgoing, `declined` from incoming, otherwise `ended`. An unanswered outgoing call sends `missed` after 45 s. "Reconnecting…" shows when the partner leaves the room or the app's LiveKit connection drops (including quick reconnects), and the call sends `ended` if it hasn't recovered after 30 s.
- App: if both partners tap Call at once, the second `start-call` returns `incoming: true` and that phone shows the incoming sheet.
- App: on the simulator the camera is a looping test clip (`TestClipCapturer` into a `BufferCapturer`); Flip does nothing there.
- Local LiveKit is `livekit-server --dev` (`devkey` / `secret`). Functions reach it at `LIVEKIT_API_URL` (`http://host.docker.internal:7880`); apps use `LIVEKIT_URL` (`ws://127.0.0.1:7880`).

**Code:** `supabase/functions/start-call/index.ts`, `supabase/functions/answer-call/index.ts`, `supabase/functions/end-call/index.ts`, `supabase/functions/_shared/supabase.ts` (admin client, auth, `loadCall`, `transition`), `supabase/functions/_shared/livekit.ts` (tokens, room participant check), `supabase/functions/.env.example`, `supabase/migrations/20261020082738_calls_rules.sql` (index, sweep, cron), `supabase/functions/tests/calls.test.ts`, `supabase/tests/database/calls_rules.test.sql`, `ButtercupKit/Sources/ButtercupKit/CallStore.swift`, `ButtercupKit/Sources/ButtercupKit/Call.swift`, `Buttercup/Calling/` (Calling tab, outgoing, incoming sheet, in-call, test clip capturer), `Buttercup/ContentView.swift` (call overlay, sheet, alerts), `Buttercup/ButtercupApp.swift` (`CallStore`, `resync()` on becoming active). Spec: [prds/completed/3-backend-calls.prd.md](../prds/completed/3-backend-calls.prd.md), [prds/partial/3-frontend-calls.prd.md](../prds/partial/3-frontend-calls.prd.md).

**Known gaps:**
- AC1 unverified: simulator ↔ meet.livekit.io media, including partner audio reaching the app.
- AC2 unverified: a Video call between two iPhones (two simulators on one Mac can't both publish).
- AC6 partner side unverified: the other side showing video when the camera turns on and the initial again when it turns off.
- No VoIP, cancel or missed-call pushes ([8]).
- Functions are not deployed to the hosted project; that needs a LiveKit Cloud project and `supabase secrets set`.

---

## 3. Notes

**Status:** Built (partial): the new note screen's frame, the Draw, Stickers, Emoji and Text tabs with placing and editing, Photo mode, the outbox that uploads notes, Send with its toast, the read path (`notes(in:)`, `image(for:)`, `changes()`, `pairedAt`), and the Notes tab week view (strip and day grid). VoiceOver on the week view ([18] AC9) hasn't been heard. The Wi-Fi offline check ([15] AC2, [16] AC4) and the send haptic and VoiceOver announcement on a device ([16] AC2, AC5) haven't been run.

**What it does:** The Notes tab shows a Monday-first week strip that pages by week from the pairing week to the current week, and the selected day's notes in a newest-first 2-column grid. "Make a note" on the Notes tab opens the New Note Screen as a full-screen cover. You can draw on the white canvas with a pen in 10 ink colours, erase whole strokes and undo, place stickers, emoji and typed text that you move, pinch, rotate and remove. In Photo mode you take a square photo with the camera and use every tool on top of it. Send flattens the note to a 1000 × 1000 HEIC, queues it in the outbox, closes the cover and shows a toast.

**Flow:**
1. Notes tab [18]: "Notes" (`.largeTitle` heavy), then the full-width "Make a note" (`pencil.tip`, primary pill, 56 tall, sticker shadow) that presents `NewNoteView` with `.fullScreenCover`, then the week strip; only the day content below scrolls. On open the current week shows with today selected.
   - Strip: 7 cells (Surface, 2 pt Outline, radius 14, ~48 × 74) with the narrow weekday, the date in monospaced digits and up to 3 stacked 15 pt crops of the day's newest note images. Today is Accent with OnAccent content; the selected day has a 2.5 pt Outline ring 2 pt outside the cell. Tapping any cell (past, empty, future) selects it with a 0.15 s fade and no haptic.
   - Paging: a paging `ScrollView` with one page per week from the week containing `pairedAt` to the current week; when a swipe settles, the same weekday in the new week is selected and that week is fetched.
   - Day: header "Saturday 31" (never "Today", header trait) with "No notes", "1 note" or "N notes"; a 2-column grid (1 column at accessibility sizes) of `NoteTile`s (radius 20, 2.5 pt Outline, 24 pt sender `Avatar` with an Outline ring 8 pt in from the bottom-left), newest first. Tiles do nothing on tap yet. An empty day shows "No notes yet".
   - States: before the week's first fetch, a `ProgressView` appears after 1 s; a failed fetch shows "Couldn't load notes. Try again" with a small secondary "Try again" and empties the strip's mini-cards; a tile whose image fails keeps the Divider fill with `exclamationmark.triangle`.
   - Refresh: on appear, on returning to the foreground, after a send, and on every `NotesStore.changes()` event; new notes fade in over 0.15 s. Returning to the foreground on a new day moves the selection to the new today only if the old today was selected. The tab keeps its selection across tab switches.
   - VoiceOver: the strip is one adjustable element ("Week of 26 October", value like "Saturday, 31 October, today, 4 notes"; swipe up or down changes day) with "Previous week" / "Next week" actions only within the limits; each cell is a button with the same style of label and the selected trait. Tiles read "Note from Partner, 9:20" or "Note from you, …". Strip text caps at `.accessibility1` with the Large Content Viewer.
2. The cover opens blank, in Draw mode, on the Draw tab: ✕ on the left and a disabled Send (40%, no shadow) on the right of the top bar, the pen | camera toggle on the right of the mode row, a white square canvas (screen width − 16, radius 20, 2.5 pt Outline), and the tab row Draw · Stickers · Emoji · Text · Face.
3. Draw tab: Pen, Eraser and Undo (44 pt circles, the selected tool Accent with a 2 pt Outline) above `ColourDots` in a 2 × 5 grid that scrolls sideways, in the order Ink, Buttercup, Yellow, Pink, Blue, Green, Lilac, Red, Orange, White. Pen and Ink are selected on open.
4. Drawing with one finger makes 9 pt strokes in the selected colour. The eraser removes whole strokes. Undo steps back through strokes and erasures and is at 40% when there is nothing to undo. Picking a colour while the eraser is on switches back to the pen.
5. The hint "Draw something for {partner}" sits on an empty canvas and fades out over 0.15 s on the first stroke; it comes back if the canvas is empty again.
6. Stickers tab: `StickerGrid` with 2 rows of 84 pt Surface cells (radius 16, art fitted in 58 pt), scrolling sideways, every PNG in `assets/stickers/` in file-name order, and the hint "Tap one, or drag it onto the note". With no PNGs it shows "No stickers yet.".
7. Tap a cell: the sticker fades in at the canvas centre, selected, with a light impact haptic. Long-press and drag a cell onto the canvas: it lands under the finger, unselected, with the same haptic. Released outside the canvas, nothing is added.
8. Any placed sticker moves with one finger, pinches (0.3–4× of its default 30% of the canvas side) and rotates with two fingers, selected or not; moving one brings it to the top. Tap selects it: a 2.5 pt light Accent outline 8 pt out that rotates with it, and an upright 32 pt trash badge (44 pt hit) on the outline's top-right corner, moving to another corner when that would leave the canvas. The trash removes it. While something is selected the canvas doesn't draw, and a tap on empty canvas only deselects.
9. Emoji tab: `EmojiStrip(rows: 2)`, one sideways strip of Apple's emoji in Unicode order in 72 pt cells (emoji at 40 pt), one section per category (Smileys, People, Animals, Food, Activity, Travel, Objects, Symbols, Flags) with its label above the first column, 20 pt between sections. Under it, nine 44 pt category chips; the chip for the section at the strip's leading edge has a Divider disc and updates as you scroll. Tapping a chip scrolls that section's label to the leading edge (0.35 s ease-out). Tap or drag an emoji to place it as in step 7.
10. Long-press (0.3 s) an emoji that has skin tones: a Surface capsule above the cell shows the default and five tones (44 pt cells, current one on a Divider disc). Tapping one places that tone at the centre, selected, and the cell shows it from then on. A tap elsewhere in the strip or a scroll closes it. Emoji without tones ignore the long-press.
11. Text tab: the field takes focus and the keyboard rises. The text tools (`TextStickerComposer`) sit on the keyboard as a 136 pt Surface panel with 28 pt top corners (4 pt top padding, then three 44 pt rows), covering the lower canvas and the tab row: the 44 pt field ("Type something", 30 characters, `.done`) and 44 pt Add (no sticker shadow, 40% while the trimmed text is empty), `ColourDots(.row)` with the 10 ink colours scrolling sideways, and four font chips Rounded · Serif · Handwritten · Mono, each label in its own font (selected chip Accent with a leading checkmark). With the keyboard down the same three rows sit under the tab row on the Background (622, 666 and 710 on an iPhone 11).
12. While the trimmed text isn't empty, it previews live on the canvas at 52 pt in the chosen font and colour with an Ink outline, centred horizontally and in the visible part of the canvas; the hint hides meanwhile. Add or Return places it there, selected, with the light impact haptic, then the field clears and the keyboard closes. Done on an empty field only closes the keyboard. Tapping the note above the panel closes the keyboard without adding: the draft stays in the field and the preview re-centres in the whole canvas; tapping the field brings the keyboard back with the draft. While the keyboard is up, that tap doesn't draw or select. Leaving the tab clears unadded text, which never counts as progress. Font and colour reset to Rounded and Ink each time the cover opens. Placed text can't be edited again; it moves, pinches, rotates and deletes like a sticker.
13. Face is at 40% and can't be tapped ("Face stickers, coming later").
14. Photo mode (the camera side of the toggle): the first time, iOS asks for camera access. The live preview fills the canvas square (aspect fill, same radius and Outline) and pinches to zoom 1–5×. In place of the tab row, a camera row centred 96 pt below the canvas holds Flash (`bolt.slash` / `bolt`), the shutter (a 76 pt ring with a 3 pt Outline around a 62 pt Accent disc) and Flip, 56 pt apart. Retake sits grey on the left of the mode row (Divider fill, not tappable) and Send stays disabled.
15. The camera opens on the lens used last (the back camera the first time). Flash is off each time the cover opens, toggles on the back camera and is disabled (40%) on the front.
16. The shutter takes the photo: it is cropped to the square centre, scaled to 1000 × 1000 (mirrored on the front camera, as the preview is), and becomes the canvas background. The camera row fades out and the tab row fades in on the Draw tab (0.15 s), Retake turns red (Danger fill, 2 pt Outline, OnDanger text), and every tab works on top of the photo. No haptic; iOS plays its own shutter sound.
17. Retake with only a photo goes straight back to the viewfinder; with any stroke or item on it the discard alert shows first.
18. With camera access denied, the square is a Surface panel with `video.slash`, "Camera is off for buttercup", "Turn it on in Settings to take a photo for {partner}." and an Open Settings pill; access is checked again whenever the app returns to the foreground. With no camera (the Simulator) or restricted access it says "No camera available" with no button. In both, the camera row stays at 40% and the toggle still works. An interrupted session (a call, another app) shows the last frame at 40% until it resumes.
19. ✕, a swipe down that starts above the canvas, the VoiceOver escape gesture and the mode toggle act at once when there is no progress.
20. Send is live (Accent, sticker shadow) once the note has progress. Tapping it clears the selection, renders the note, hands it to `NotesStore.send` and closes the cover at once. No spinner and no failed state.
21. When the cover has closed, the app root shows a toast 12 pt above the tab bar: a Surface capsule with a 2 pt Outline, 48 tall, an 18 pt symbol and bold subheadline text. Online (per `NWPathMonitor` at that moment): `checkmark` "Sent to {partner}"; offline: `wifi.slash` "Sends when you're back online". It fades in over 0.15 s, holds 2.5 s and fades out over 0.2 s; a tap fades it out at once, and a second send replaces it. It plays the `.success` haptic and is posted as a VoiceOver announcement (not focusable). Discarding a note shows no toast.

**Rules:**
- `NoteDraft` holds `mode`, `photo`, `drawing`, `history` (undo stack of earlier drawings), `items` and `selection`; `hasProgress` is a photo, any stroke or any item, so one stroke or sticker makes ✕ ask first. `add`, `remove` and `bringToFront` edit the items.
- `NoteItem` has `kind` (`.sticker(name)`, `.emoji(String)` or `.text(String, NoteFont, Color)`), `center` as a fraction of the canvas side, `scale` and `rotation`. Stickers and emoji are squares 30% of the canvas side; text is 52/398 of the side in font size, sized to its own line and shrinking to fit the canvas width, and its selection outline and trash badge follow its measured size. Items sit above the strokes in array order, newest on top. Undo never touches items.
- Emoji data is `Buttercup/Resources/emoji.json`, generated from Unicode `emoji-test.txt` 18.0: fully-qualified emoji only, no components, tone variants stored under their base. At load, any emoji (or tone set) the running iOS can't draw as a single Apple Color Emoji glyph is dropped, so the strip matches the installed emoji font.
- The chosen tone is remembered per emoji on the device (`@AppStorage` key `emojiTone.<emoji>`). Emoji cells read their system name and the hint "Double-tap to add to the note"; toneable cells have one VoiceOver action per tone. Category labels are headers; the current chip has `.isSelected`. A placed emoji reads its name ("Grinning face").
- Placed items have VoiceOver actions Remove, Make bigger, Make smaller, Rotate left, Rotate right and Move up/down/left/right; the canvas value reads e.g. "2 stickers and drawing".
- The canvas is a `PKCanvasView` with `drawingPolicy = .anyInput`, `PKInkingTool(.monoline, width: 4.5)` (which renders 9 pt) and `PKEraserTool(.vector)`; `PKToolPicker` is never shown. It is forced to light appearance and inks use their light values, so strokes look the same in light and dark.
- Ink colours are content colours, the same in both modes: Ink and Buttercup use the light TextPrimary and Accent values; Red and Orange are `NoteInkRed` #E5483B and `NoteInkOrange` #FF8A3D.
- Each dot and tool has its VoiceOver name and `.isSelected` on the current one; haptics: none on tools or dots.
- With progress, those actions show "Discard this note?" / "You will lose your progress if you proceed" / Keep editing / Discard, and Discard does the action (a mode switch clears the draft and opens the other mode blank).
- Swipe down follows the finger and closes past 30% of the height or faster than 600 pt/s; otherwise it eases back over 0.2 s. With Reduce Motion it doesn't follow the finger. A drag that starts on the canvas never dismisses.
- `NoteFont` is `rounded` (SF Pro Rounded heavy), `serif` (New York bold), `handwritten` (`Noteworthy-Bold`, a system font, asserted at launch in Debug) and `mono` (SF Mono bold), with `font(size:)`; chip labels are 16, 16, 18 and 14 pt. Note text and chips ignore the screen's rounded font design.
- `TextSticker` draws the outline as 24 offset Ink copies behind the fill, 3.5/52 of the font size out (a 7 pt stroke behind the fill at 52 pt). `TextStickerComposer` takes `colours`, `fonts` (nil hides the chips), `addHasShadow` and `preview` (`.inline` draws an 80 pt preview box for calls; notes use `.external`).
- Placed text reads its words in VoiceOver.
- `Camera` (`@Observable`) owns one `AVCaptureSession` (`.photo` preset, the wide-angle camera, `AVCapturePhotoOutput`) and configures, starts and stops it on its own queue. The session runs only while the cover is in Photo mode with no photo and the app is active. The front/back choice is `@AppStorage("noteCameraFront")`. The photo output's connection is rotated to portrait and mirrored for the front camera.
- Debug simulator builds launched with `-notePhotoStub YES` use the first frame of `test-clip.mp4` as the viewfinder and the captured photo, so the photo flow can be checked without a camera.
- VoiceOver: Flash reads "Off" / "On", Switch camera reads "Back" / "Front", the shutter is "Take photo", Retake is "Retake photo", and the canvas value starts with "Photo" once a photo is taken ("Photo with 2 stickers and drawing").
- `NoteRenderer.heic(draft, side:)` draws a non-interactive copy of the canvas content (white ground, photo filled to the square, `PKDrawing.image(from:scale:)` under light traits, then items via the shared `NoteItemContent`) with `ImageRenderer` at scale 1000/side, in light appearance, without the outline, hint, selection or trash, and encodes it with `heicData()` (Display P3). Positions come from the same `NoteItem` fractions as the screen.
- Send's VoiceOver label is "Send to {partner}", with the hint "Draw or add something first" while disabled.
- Outbox [15]: `NotesStore.send(imageData:)` writes the image to `notes/{id}.heic` in the App Group `group.com.adamfilchoir.buttercup`, saves a `Note` and an `OutboxAction` (`sendNote`) in a SwiftData store in the same group, and returns `.online` or `.offline` from `NWPathMonitor` at that moment. The flusher runs on launch, after each enqueue, when `NWPathMonitor` becomes satisfied and whenever the app becomes active. It handles actions oldest first, bumps `attempts`, and keeps failed ones for the next run.
- Read path [17]: `NotesStore.notes(in: DateInterval)` returns `NoteRecord`s (`id`, `senderId`, `imagePath`, `createdAt`) with `unsent_at is null` and `created_at` in `[start, end)`, newest first. `image(for:)` downloads the object from the `notes` bucket with the signed-in session and caches the `UIImage` in an `NSCache` keyed by note id; it returns `nil` on failure. `changes()` is an `AsyncStream<Void>` that yields on any change to `notes` over the realtime channel `notes`; callers refetch, so an unsent note drops out. `SessionStore.pairedAt` is the caller's `pairs.created_at`, loaded in `refresh()`, `nil` when unpaired.
- Days and weeks use `NotesTab.calendar`: the device's current calendar and time zone with `firstWeekday = 2`. Fetched notes are kept per week start for the session.
- Seed data: the pair is created 45 days back; notes `b0000000-…-0001` to `-0012` from both people spread over 20 days (three today, a Partner-only day 3 days back, `-0008` unsent), with 1000 × 1000 images in `supabase/seed-notes/` uploaded by `supabase/seed-notes.sh` after `supabase db reset`.
- `sendNote` uploads `{sender_id}/{note_id}.heic` to the `notes` bucket with `upsert: false`, then inserts the `notes` row with the phone-made id. A storage 409 and a `23505` on the insert both count as done, so a retry never duplicates. On success the action is deleted and the local `Note` stays.

**Code:** `Buttercup/ContentView.swift` (toast overlay), `Buttercup/Notes/NotesTab.swift` (`NotesTab`, selection, fetch and refresh), `Buttercup/Notes/WeekStrip.swift`, `Buttercup/Notes/DayGrid.swift` (`DayGrid`, `NoteTile`, `NoteImage`), `Buttercup/Calling/CallingView.swift` (`Avatar`), `Buttercup/Notes/NewNoteView.swift` (cover, layout, alert, swipe down, `NoteTab`), `Buttercup/Notes/NoteDraft.swift` (`NoteDraft`, `NoteMode`), `Buttercup/Notes/NoteItem.swift`, `Buttercup/Notes/NoteItemView.swift` (gestures, selection, `NoteItemContent`, `TrashBadge`), `Buttercup/Notes/NoteRenderer.swift`, `Buttercup/Notes/NoteToast.swift`, `Buttercup/Notes/NoteFont.swift`, `Buttercup/DesignSystem/TextStickerComposer.swift` (`TextStickerComposer`, `TextSticker`), `Buttercup/DesignSystem/StickerGrid.swift` (`StickerGrid` with `rows` and `cellFill`, `Stickers` catalog), `Buttercup/DesignSystem/EmojiStrip.swift` (`EmojiStrip` with `rows`, `Emoji` catalog, `EmojiCategory`, `EmojiEntry`), `Buttercup/DesignSystem/SkinTonePicker.swift`, `Buttercup/Resources/emoji.json`, `assets/stickers/` (bundled as a folder reference), `Buttercup/Notes/ModeToggle.swift`, `Buttercup/Notes/NoteCanvas.swift` (white square, `PKCanvasView`, hint, items layer, drop), `Buttercup/Notes/DrawTools.swift` (`DrawTools`, `DrawTool`, `InkColour`), `Buttercup/DesignSystem/ColourDots.swift` (`.row` and `.grid(rows:)`), `Buttercup/Assets.xcassets` (`NoteInkRed`, `NoteInkOrange`, `OnDanger`), `Buttercup/Notes/CameraView.swift` (`Camera`, `CameraView`), `Buttercup/Notes/CameraRow.swift`, `Buttercup/Notes/RetakeButton.swift`, `Buttercup/Notes/CameraBlockedView.swift`, `Buttercup/Info.plist` (`NSCameraUsageDescription`), `Buttercup/DesignSystem/PillTabRow.swift`, `Buttercup/DesignSystem/Buttons.swift` (`PressableButtonStyle`, `PillButtonStyle`, `IconCircleButton`), `ButtercupKit/Sources/ButtercupKit/Outbox.swift` (`OutboxAction`, `Outbox` flusher), `ButtercupKit/Sources/ButtercupKit/NotesStore.swift` (`Note`, `NoteRecord`, `NotesStore.send`, `notes(in:)`, `image(for:)`, `changes()`), `ButtercupKit/Sources/ButtercupKit/SessionStore.swift` (`pairedAt`), `supabase/seed.sql`, `supabase/seed-notes/`, `supabase/seed-notes.sh`, `Buttercup/Buttercup.entitlements` (App Group), `Buttercup/ButtercupApp.swift` (model container, `NotesStore`, flush on becoming active). Spec: [design/specs/new-note-screen.md](../design/specs/new-note-screen.md), [prds/completed/9-new-note-shell.prd.md](../prds/completed/9-new-note-shell.prd.md), [prds/completed/10-note-draw-tab.prd.md](../prds/completed/10-note-draw-tab.prd.md), [prds/completed/11-note-stickers.prd.md](../prds/completed/11-note-stickers.prd.md), [prds/completed/12-note-emoji-tab.prd.md](../prds/completed/12-note-emoji-tab.prd.md), [prds/completed/13-note-text-tab.prd.md](../prds/completed/13-note-text-tab.prd.md), [prds/completed/14-note-photo-mode.prd.md](../prds/completed/14-note-photo-mode.prd.md), [prds/partial/15-outbox-note-upload.prd.md](../prds/partial/15-outbox-note-upload.prd.md), [prds/partial/16-note-send.prd.md](../prds/partial/16-note-send.prd.md), [prds/completed/17-notes-read-path.prd.md](../prds/completed/17-notes-read-path.prd.md), [design/specs/notes-tab.md](../design/specs/notes-tab.md), [prds/partial/18-notes-week-view.prd.md](../prds/partial/18-notes-week-view.prd.md).

**Known gaps:**
- Tone picker is tap to pick, not slide to pick.
- [15] AC2 and [16] AC4 unverified: the Wi-Fi off / on check needs a person.
- [16] AC2 and AC5 unverified on a device: the `.success` haptic and the VoiceOver announcement of the toast.
- The toast says "Sent to {partner}" while the server is down but the network is up; the outbox still delivers it later.
- No partner push after a note is uploaded (`push-partner`).
- [18] AC9 unverified: VoiceOver speech and custom actions on the week view need a person.
- Tiles don't open the note dialog yet ([19]); no month view ([20]); no widget, favourites or unsend.
