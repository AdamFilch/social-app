# [16]: Send a note

**Depends on:** [10] Note Draw tab and [15] Outbox merged. Best after [11]–[14], so every kind of content is exported.

This ticket makes **Send** work. Once the note has anything on it, Send turns yellow with its sticker shadow. Tapping it clears the selection, flattens the canvas into one 1000 × 1000 image (photo, strokes, stickers and text, without the outline, hint or trash), hands it to the outbox from [15], and closes the screen at once. On the screen underneath, a quiet toast says "Sent to Sam", or "Sends when you're back online" if the phone is offline, with the success haptic.

## Summary
Adds `NoteRenderer` (draft → 1000 × 1000 HEIC via `ImageRenderer`), connects Send to `NotesStore.send`, and adds `NoteToast`, shown by the app root above the tab bar. Removes the DEBUG "Send test note" button from [15].

## Scope
**MVP**
- Send enabled when `hasProgress`, disabled at 40% with no shadow otherwise (spec §4.1)
- `NoteRenderer`: render the canvas content at 1000/398 scale, without Outline, hint, selection or trash. Encode as HEIC (about 150 KB).
- Send → render → `NotesStore.send` → `onSent(result)` → dismiss. No spinner and no failed state (D7, D8).
- `NoteToast` at the app root: online `checkmark` "Sent to {partner}", offline `wifi.slash` "Sends when you're back online". Fade in 0.15 s, hold 2.5 s, fade out 0.2 s. Tap to dismiss. A second send replaces the text.
- `.success` haptic when the toast appears. The toast is a VoiceOver announcement.

**Out of scope**
- The pending badge on your own tile in the Notes grid (spec follow-up, Notes-tab ticket)
- Partner notification and widget push

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| N1 | Send flow | Outbox, close at once, toast after | Adam, 2026-10-28 (spec D7–D8) | User |
| N2 | Send haptic | `.success` | Adam kept design.md §8 | User |
| N3 | Render path | `ImageRenderer` over a non-interactive copy of the canvas content, with `PKDrawing.image(from:scale:)` for strokes | `PKCanvasView` doesn't render through `ImageRenderer` | Claude — straightforward |

## End-to-End Flows
```
Draw + sticker ─ Send ─► render 1000² HEIC ─► NotesStore.send ─► cover closes
Notes tab ─► toast "Sent to partner" + success haptic ─► fades after 2.5 s
Offline ─ Send ─► toast "Sends when you're back online" ─► sent later by [15]
```

## File Reference
| File | Role |
|---|---|
| `Buttercup/Notes/NoteRenderer.swift` | **new** |
| `Buttercup/Notes/NoteToast.swift` | **new** |
| `Buttercup/Notes/NewNoteView.swift` | Send wiring |
| `Buttercup/ContentView.swift` | toast overlay; remove the DEBUG button |

---

## Acceptance Criteria
- [ ] AC1: Send is at 40% with no shadow on an empty note, and live with the shadow after a stroke, sticker, text or photo.
- [ ] AC2: Send closes the cover at once. The toast "Sent to Partner" shows 12 pt above the tab bar with the success haptic, and fades as timed.
- [ ] AC3: The uploaded image is 1000 × 1000 HEIC and matches the canvas: no outline, hint, selection outline or trash badge, and stickers and text are in the right place and size.
- [ ] AC4: With the local stack stopped, the toast reads "Sends when you're back online". After `supabase start` the note uploads once.
- [ ] AC5: VoiceOver announces the toast text, and Send's label is "Send to {partner}".
- [ ] AC6: The build check passes, and an end-to-end send is checked with the seed users.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Rendered text or sticker positions drift from the screen | Med | Note looks different | Render from the same `NoteItem` fractions, and check AC3 against a screenshot |

---
*Status: READY — ticket [16]*
