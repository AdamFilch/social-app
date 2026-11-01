# [24]: Edit, delete and reorder sounds

**Depends on:** [21] Sounds backend and [22] Sounds tab merged. Independent of [23].

This ticket adds the ways to manage the shared board, all on the Sounds tab only (spec [soundboard.md](../design/specs/soundboard.md) §3.4–§3.5, §4.8–§4.11, §8 Edit and delete). Long-pressing a sound opens the system menu with Edit and Delete. Edit opens a sheet to rename, pick or remove an emoji, and trim the start and end on a waveform. The original file is never touched, and only the trim points are saved. Delete asks first, then removes the sound and its file for both partners. Keeping the finger down and moving turns the long-press into a drag: a dashed slot shows where the tile will land, and the new order is saved once for both of you. Everything goes through the outbox, so it also works offline.

## Summary
Adds the long-press menu, the Edit sheet with `EmojiWell` and `SoundTrimmer`, the delete confirm, drag-to-reorder with VoiceOver move actions, three writers on `SoundsStore` (`update`, `delete`, `reorder`) and three outbox kinds (`updateSound`, `deleteSound`, `reorderSounds`). No backend changes.

## Scope
**MVP**
- **Long-press menu (§4.8, M7):** the system context menu with Edit and Delete. "+ Record" has none. The system's own lift spring is accepted (F2).
- **Edit sheet (§4.10, S10, S11, M8, M9):**
  - Cancel / "Edit sound" / Save; Save is disabled until something changes.
  - Name field: the same 30-character rule as [23].
  - Emoji well: opens the emoji keyboard; "Remove" returns to 🔊 (S13).
  - Trimmer: Photos-style, two Accent handles on the waveform, the cut ends dimmed, steps of 0.1 s, at least 0.5 s kept. Play trimmed plays only the kept part.
  - Cancel with changes asks "Discard changes?" (Keep editing / Discard).
  - A sound deleted by the partner while you edit closes the sheet with no message.
- **Delete (§4.11, S7, M10):** "Delete “{title}”?" with Delete / Keep. On confirm the tile fades out at once. The outbox deletes the row (RLS allows either partner, [21] B3), then removes the file through the Storage API.
- **Reorder (§4.9, S17–S20):** long-press, then move: the tile follows the finger, others make room around a dashed slot, nothing can be dropped before "+ Record". The drop calls `reorder_sounds` with the full new order. "Move earlier" / "Move later" accessibility actions do the same.
- **Outbox:** `updateSound` (title, emoji, trim), `deleteSound` and `reorderSounds`. The local grid changes at once; the server order replaces it when realtime arrives.
- **Writers on `SoundsStore`:** `update(_:title:emoji:trimStartMs:trimEndMs:)`, `delete(_:)` and `reorder(_ ids: [UUID])`.

**Out of scope**
- Any of this in the call tray, which only plays (S20).

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| S7 | Delete | Either partner, after a confirm | Shared board | User |
| S10 | Editing | Rename, trim start/end, emoji | | User |
| S11 | Trim storage | Original kept + trim offsets | Undoable | User |
| S13 | Emoji | Optional; 🔊 default | | User |
| S17 | Order | Drag to reorder | Favourites stay put | User |
| S18 | Order scope | One shared order | Shared board | User |
| S20 | Where | Sounds tab only | No accidental drags mid-call | User |
| S28 | Writes | Through the outbox | Same as PRD 15 | Claude — straightforward |
| M7–M10, F2 | Menu, Edit sheet, trimmer, delete confirm, system lift | As the spec | Approved with mockup v2 | User |
| E1 | Cancel with changes | "Discard changes?" confirm | Spec decision §13 | Claude — straightforward |
| E2 | Concurrent reorder | The last drop wins; the grid then shows the server order | `reorder_sounds` from [21] B2 | Claude — straightforward |
| E3 | Deleting the file | Delete the row, then remove the file with the Storage API | [21] B3 | Claude — straightforward |

## End-to-End Flows
```
long-press ─► menu: Edit │ Delete
Edit ─► rename / emoji / trim ─► Save ─► updateSound ─► partner's tile updates
Delete ─► "Delete “Ribbit”?" ─► Delete ─► tile fades ─► row deleted ─► file removed ─► gone for both
long-press + move ─► dashed slot ─► drop ─► reorderSounds ─► reorder_sounds RPC ─► partner's grid reorders
partner reorders while you drag ─► your drop wins ─► server order shown
```

## Blast Radius
| Change | What breaks |
|---|---|
| Long-press on tiles | Must not break the tap-to-play from [22] |
| New outbox kinds | The flusher's order: an edit after a delete of the same sound must count as done |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Sounds/EditSoundSheet.swift` | **new** sheet, `EmojiWell`, Discard-changes confirm |
| `Buttercup/Sounds/SoundTrimmer.swift` | **new** |
| `Buttercup/Sounds/SoundsTab.swift` | menu, delete confirm, drag and VoiceOver actions |
| `Buttercup/Sounds/WaveformTrack.swift` | reused from [23] if merged, otherwise **new** here |
| `ButtercupKit/Sources/ButtercupKit/SoundsStore.swift` | `update`, `delete`, `reorder` |
| `ButtercupKit/Sources/ButtercupKit/Outbox.swift` | three new kinds |

---

## Acceptance Criteria
- [ ] AC1: Long-press shows Edit and Delete; "+ Record" has no menu.
- [ ] AC2: Edit renames, sets and removes the emoji, and trims in 0.1 s steps keeping at least 0.5 s. The file in `sounds` is unchanged (same size and hash), and only the row changes.
- [ ] AC3: Play trimmed, and the tile afterwards, play only the kept part.
- [ ] AC4: Cancel with changes asks "Discard changes?"; Save is disabled with no changes.
- [ ] AC5: Delete asks first, then removes the row and the file. As adam, deleting a partner's sound works.
- [ ] AC6: Long-press and drag reorders with a dashed slot, never before "+ Record". The partner's grid shows the new order without a reload. Move earlier / later work in VoiceOver.
- [ ] AC7: Two `reorder_sounds` calls in a row from both users leave positions 1…n with no duplicates (SQL check).
- [ ] AC8: Offline (stack stopped), an edit, a delete and a reorder show at once and reach the server after `supabase start` and a foreground.
- [ ] AC9: Checked against mockup states 3, 4, 7 and 8 in light and dark, and the build check passes.

## Required Changes
- **technical-spec.md:** add "edit sound, delete sound, reorder sounds" to the outbox list (spec §12 technical-spec item 2).

## Features Catalog
- **Extends**: Sounds (from [22])

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The context menu and the drag fight over the long-press | Med | One of them doesn't start | Use SwiftUI's `.contextMenu` plus `.draggable`/`.dropDestination` (the system hands over to the drag after movement), and test on a device |
| A file removal fails after the row is gone | Low | An orphan file in storage | Accepted; out of scope in [21] |

---
*Status: READY — ticket [24]*
