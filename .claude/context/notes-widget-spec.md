# Notes widget spec

Oct 19, 2026 · @Adam

You make a small square note (drawing, photo, face sticker, shapes, emoji, text) and send it. It appears on your partner's small home screen widget and in a shared calendar of notes. Agreed with Adam on 2026-10-19; this replaces the earlier daily photo widget idea.

## Making a note

- **Canvas:** a square the shape of the small iOS widget, saved at about 1000 × 1000 px so it stays sharp on the widget and in Photos (size inferred).
- **Drawing:** Apple's PencilKit tools: pen, pencil, marker, crayon, watercolour, fountain pen, eraser, lasso, ruler, undo and redo, any colour.
- **Photo background:** take a photo with the front or back camera, or pick one from the camera roll, then draw on it.
- **Face sticker:** take a selfie (or pick a photo) and buttercup cuts out the face shape on the phone with Apple's Vision subject cut-out, then places it as a sticker.
- **Shape stickers:** basic shapes such as heart, star, circle and square.
- **Emoji stickers:** any emoji.
- **Text:** type words onto the note, with a choice of font, size and colour.
- **Editing stickers:** every sticker and text box can be moved, resized, rotated and deleted after placing.
- **Sending:** everything is flattened into one image and sent. No limit on notes per day.

## Receiving

- Your partner gets a notification with **text only, no preview**, for example "New note from Adam".
- Their widget refreshes straight away through a WidgetKit push (iOS 26). iOS limits how often these arrive, so a quick burst of notes can reach the widget a little late. The app always has them.

## The widget

Small size only, and it only ever shows **your partner's** notes. You pick a mode in the widget's settings (long-press, Edit Widget).

| Mode | What it shows |
| --- | --- |
| Latest | Your partner's newest note. After 3 days with no new note it keeps showing the last one; nothing changes. |
| Slideshow of last 5 | Rotates through your partner's 5 newest notes. |
| Favourites | Rotates through your own favourites list. |
| All of today | Rotates through every note your partner sent today. Before their first note of the day, it shows their latest note (assumed). |

- Rotating modes switch on a rough timer, about every 15 to 30 minutes. iOS picks the exact moment, because widgets can't animate.
- Tapping the widget opens that note in the app.
- Before the first note ever, the widget shows a placeholder asking you to send one.

## Calendar

- A month view in the app. Each day with notes shows them as **small stacked cards**, and it includes **both of your notes**.
- **Tap a day** to open a dialog with all of that day's notes in time order, showing who sent each one.
- From the dialog you can favourite a note, save it to Photos, or unsend it if it's yours and still allowed.
- "Today" and day boundaries follow each phone's own time zone (assumed).

## Favourites and saving

- **Each of you has your own favourites list.** You can favourite any note, yours or your partner's, with a heart.
- The Favourites widget mode reads from your own list.
- Any note can be saved to the phone's photo library as an image.

## Unsend

- You can unsend your own note **within 4 hours** of sending it.
- Unsending removes it from the calendar and from your partner's widget, and a widget refresh goes out.
- It's also removed from both favourites lists (assumed). A copy already saved to Photos can't be pulled back.

## Not in v1

- Reactions (such as a heart) and replies to a note.
- Medium and large widgets, and lock screen widgets.

## How it's built

- **Editor:** SwiftUI, with PencilKit's `PKCanvasView` for drawing and a SwiftUI layer for stickers and text, flattened with `ImageRenderer`. Face cut-out uses Vision's `VNGenerateForegroundInstanceMaskRequest` (iOS 17+).
- **Backend:** Supabase. A `notes` table (id, sender, created\_at, image path, unsent\_at) and a `favourites` table (user, note\_id). Images go in Supabase Storage; the free 1 GB holds thousands of notes at a few hundred KB each (inferred).
- **Send and unsend:** an Edge Function stores the note and sends the text-only notification plus a WidgetKit push. Unsend checks the 4-hour window, marks the note unsent, deletes the image and pushes a widget refresh.
- **Widget:** WidgetKit with an `AppIntentConfiguration` for the mode setting. The app caches recent notes and favourites, already shrunk, in a shared App Group folder so the widget never downloads full images. Rotating modes hand iOS a timeline of entries 15 to 30 minutes apart.
- **Keeping notes:** notes are kept forever; nothing is auto-deleted.

## Open questions

- [x] Confirm the unsend rule: yes, you can unsend for 4 hours after sending (confirmed 2026-10-19).
