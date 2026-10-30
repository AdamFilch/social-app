# [16]: Send a note

**Depends on:** [10] Note Draw tab and [15] Outbox merged. Best after [11]–[14], so every kind of content is exported.

This ticket makes **Send** work. Once the note has anything on it, Send turns yellow with its sticker shadow. Tapping it clears the selection, flattens the canvas into one 1000 × 1000 image (photo, strokes, stickers and text, without the outline, hint or trash), hands it to the outbox from [15], and closes the screen at once. On the screen underneath, a quiet toast says "Sent to Sam", or "Sends when you're back online" if the phone is offline, with the success haptic.

## Summary
Adds `NoteRenderer` (draft → 1000 × 1000 HEIC via `ImageRenderer`), connects Send to `NotesStore.send`, and adds `NoteToast`, shown by the app root above the tab bar. Removes the DEBUG "Send test note" and "Resend latest note" buttons and `NotesStore.resendLatest()` from [15].

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
| `Buttercup/ContentView.swift` | toast overlay; remove the DEBUG "Send test note" and "Resend latest note" buttons |
| `ButtercupKit/Sources/ButtercupKit/NotesStore.swift` | remove the DEBUG `resendLatest()` |

---

## Acceptance Criteria
- [x] AC1: Send is at 40% with no shadow on an empty note, and live with the shadow after a stroke, sticker, text or photo.
- [ ] AC2: Send closes the cover at once. The toast "Sent to Partner" shows 12 pt above the tab bar with the success haptic, and fades as timed.
- [x] AC3: The uploaded image is 1000 × 1000 HEIC and matches the canvas: no outline, hint, selection outline or trash badge, and stickers and text are in the right place and size.
- [ ] AC4: With the Mac's Wi-Fi off, the toast reads "Sends when you're back online", and after Wi-Fi comes back the note uploads once.
- [x] AC4b: With `supabase stop`, the toast reads "Sent to Partner" (the network path is fine, the known risk in [15]). After `supabase start`, backgrounding and reopening the app uploads the note once.
- [ ] AC5: VoiceOver announces the toast text, and Send's label is "Send to {partner}".
- [x] AC6: The build check passes, and an end-to-end send is checked with the seed users.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Rendered text or sticker positions drift from the screen | Med | Note looks different | Render from the same `NoteItem` fractions, and check AC3 against a screenshot |

---
*Status: PARTIAL — PR #14*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ✅ done | iPhone 17 Pro sim as adam: empty cover has no Send target (disabled, 40%, no shadow, screenshot); Send became "Send to Partner" and live with the shadow after a stroke alone, a sticker alone, an added text alone and a photo alone (`-notePhotoStub YES`). Unadded preview text does not enable it |
| AC2 | ⚠️ unverified (haptic only) | Cover closes at once; "Sent to Partner" toast with `checkmark` sits 12.3 pt above the tab bar (screenshot at 3x: toast bottom 2332 px, bar top 2369 px); visible at 0.8 s, gone by 3.8 s; a tap fades it at once. The `.success` haptic is wired (`sensoryFeedback(.success, trigger: toastCount)`) but the Simulator can't play haptics |
| AC3 | ✅ done | Downloaded `11111111…/82d9ca27….heic` from local Storage: `sips` 1000 × 1000, format heic. No outline, hint, selection outline or trash, though the text was selected when Send was tapped. Feature bounding boxes as fractions of the side, screen vs upload: cross 0.280–0.720 / 0.350–0.650 on both; emoji 0.850–0.992 vs 0.850–0.998; text 0.312–0.642 / 0.948–0.992 vs 0.312–0.640 / 0.948–0.994. Colours match once the P3-tagged HEIC is converted to sRGB (heart 241,117,92 on both). The photo note (`88340bf7…`) also matches |
| AC4 | ⚠️ unverified | Needs the Mac's Wi-Fi off and on by a person |
| AC4b | ✅ done | `supabase stop` → sticker note sent → toast "Sent to Partner"; `supabase start` → still 2 adam rows; Home, then reopen (same pid) → row and object `6eba35d0…` appear once |
| AC5 | ⚠️ unverified (announcement only) | Send's accessibility label reads "Send to Partner" (UI snapshot). The toast posts `AccessibilityNotification.Announcement(message)` and is hidden from VoiceOver focus, but VoiceOver can't be heard in the Simulator |
| AC6 | ✅ done | `supabase db reset && supabase test db` PASS, `supabase db lint` no schema errors, build check `BUILD SUCCEEDED`; end-to-end sends as adam created one `notes` row and one object each |

### Needs attention
- On a device or with VoiceOver: confirm the `.success` haptic plays when the toast appears (AC2) and that VoiceOver speaks the toast text (AC5).
- AC4 by hand: Notes tab → turn the Mac's Wi-Fi off → send a note → toast "Sends when you're back online" → Wi-Fi on → exactly one new row in `notes`. The same run also closes [15] AC2.
