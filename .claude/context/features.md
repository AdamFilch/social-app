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

**Status:** Built (partial): the new note screen's frame and the Draw, Stickers, Emoji and Text tabs with placing and editing; the Text tab leaves 255 pt of canvas (not the planned 272) above the iOS 26 keyboard on an iPhone 11. Photo and sending come in [14]–[16].

**What it does:** "Make a note" on the Notes tab opens the New Note Screen as a full-screen cover. You can draw on the white canvas with a pen in 10 ink colours, erase whole strokes and undo, place stickers, emoji and typed text that you move, pinch, rotate and remove. Photo and sending come in later tickets.

**Flow:**
1. Notes tab: a temporary "Make a note" button (primary pill with the sticker shadow) presents `NewNoteView` with `.fullScreenCover`.
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
14. Photo mode shows a blank Surface square and hides the tab row; the camera comes in [14].
15. ✕, a swipe down that starts above the canvas, the VoiceOver escape gesture and the mode toggle act at once when there is no progress.

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
- Send stays disabled until [16].

**Code:** `Buttercup/ContentView.swift` (`NotesTab`), `Buttercup/Notes/NewNoteView.swift` (cover, layout, alert, swipe down, `NoteTab`), `Buttercup/Notes/NoteDraft.swift` (`NoteDraft`, `NoteMode`), `Buttercup/Notes/NoteItem.swift`, `Buttercup/Notes/NoteItemView.swift` (gestures, selection, `TrashBadge`), `Buttercup/Notes/NoteFont.swift`, `Buttercup/DesignSystem/TextStickerComposer.swift` (`TextStickerComposer`, `TextSticker`), `Buttercup/DesignSystem/StickerGrid.swift` (`StickerGrid` with `rows` and `cellFill`, `Stickers` catalog), `Buttercup/DesignSystem/EmojiStrip.swift` (`EmojiStrip` with `rows`, `Emoji` catalog, `EmojiCategory`, `EmojiEntry`), `Buttercup/DesignSystem/SkinTonePicker.swift`, `Buttercup/Resources/emoji.json`, `assets/stickers/` (bundled as a folder reference), `Buttercup/Notes/ModeToggle.swift`, `Buttercup/Notes/NoteCanvas.swift` (white square, `PKCanvasView`, hint, items layer, drop), `Buttercup/Notes/DrawTools.swift` (`DrawTools`, `DrawTool`, `InkColour`), `Buttercup/DesignSystem/ColourDots.swift` (`.row` and `.grid(rows:)`), `Buttercup/Assets.xcassets` (`NoteInkRed`, `NoteInkOrange`), `Buttercup/DesignSystem/PillTabRow.swift`, `Buttercup/DesignSystem/Buttons.swift` (`PressableButtonStyle`, `PillButtonStyle`, `IconCircleButton`). Spec: [design/specs/new-note-screen.md](../design/specs/new-note-screen.md), [prds/completed/9-new-note-shell.prd.md](../prds/completed/9-new-note-shell.prd.md), [prds/completed/10-note-draw-tab.prd.md](../prds/completed/10-note-draw-tab.prd.md), [prds/completed/11-note-stickers.prd.md](../prds/completed/11-note-stickers.prd.md), [prds/completed/12-note-emoji-tab.prd.md](../prds/completed/12-note-emoji-tab.prd.md), [prds/partial/13-note-text-tab.prd.md](../prds/partial/13-note-text-tab.prd.md).

**Known gaps:**
- Text tab on an iPhone 11 (iOS 26.1 simulator): the iOS 26 keyboard is taller than the spec assumed, so with the panel cut to 136 pt, 255 pt of canvas stays visible with the predictive bar, not 272; three 44 pt rows cap it at 259 [13].
- Text's light haptic and two-finger pinch and rotate of placed text are unchecked on a physical iPhone [13].
- Tone picker is tap to pick, not slide to pick.
- No camera or Retake [14], no outbox [15], no sending [16].
- No Notes tab home, widget, calendar, favourites or unsend.
