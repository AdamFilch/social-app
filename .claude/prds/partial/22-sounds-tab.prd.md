# [22]: Sounds tab, browse and play

**Depends on:** [21] Sounds backend merged. Blocks [23], [24] and [26].

This ticket adds the fourth tab, **Sounds**, between Notes and Hobbies (spec [soundboard.md](../design/specs/soundboard.md) §3.1–§3.2, §4.1–§4.4, §4.17, §6, §8 Tab). It shows the shared board as a 3-column grid, with "+ Record" first and then the pair's sounds in their shared order. Tapping a tile plays its trimmed range on your phone only, with the silent switch on too. The tile fills with PlayTint at the clip's real pace and shows a stop badge. Only one sound plays at a time. Every sound file is cached in the App Group so a tap plays at once. When your partner adds, edits, reorders or deletes a sound, your grid follows over realtime. "+ Record" is drawn but does nothing until [23].

## Summary
Adds a `SoundsStore` (fetch, realtime, App Group file cache), a `SoundPlayer` (`.playback`, one at a time, trim range, progress), the `SoundsTab` grid with `SoundTile` and `RecordTile`, the `PlayTint` token, and the fourth tab in the custom tab bar. No backend changes.

## Scope
**MVP**
- **Tab bar (S15, R6):** four equal tabs Calling · Notes · Sounds · Hobbies. Sounds uses `speaker.wave.2` (`.fill` when selected). Recheck the other three tabs and the Notes toast position.
- **`SoundsStore` (new, ButtercupKit):**
  - `sounds() async throws -> [SoundRecord]`: the pair's rows ordered by `position`.
  - `changes() -> AsyncStream<Void>`: yields on any change to `sounds` (the same pattern as `NotesStore.changes()`); the tab refetches.
  - `file(for:) async throws -> URL`: returns the cached `Sounds/{id}.m4a` from the App Group, downloading it first if missing. Files are fetched when a row first arrives and removed when the row is gone.
  - The last list is kept in the App Group so the grid shows at once on launch and offline.
- **`SoundPlayer` (new):** `AVAudioPlayer` on `.playback` (A2). It plays `trim_start_ms`…`trim_end_ms`, publishes progress, and plays one sound at a time; tapping the playing tile stops it (S14). It stops if the playing sound is deleted.
- **Grid (§4.1–§4.3, M1, M2):** 3 columns of 116 × 108 tiles, 12 pt gaps. `RecordTile` (Accent, sticker shadow) is always first. `SoundTile` shows the emoji (🔊 when null, S13) and a 2-line title, nothing else (S22).
- **Playing (M3):** PlayTint fills from the left at the clip's pace, plus the stop badge.
- **Empty (§4.4):** "+ Record" plus the two-line copy, which goes as soon as any sound exists.
- **States (§8 Tab):** loading from the cached list, not cached yet (16 pt `ProgressView` in the badge spot, tap again cancels), download failed (`.error`, the title replaced for 3 s by "Couldn't load. Try again" in Danger), offline plays cached sounds.
- **Position memory:** the scroll position is kept across tab switches.
- **Accessibility (§9):** tile label is the title; hint "Double-tap to play"; playing value "Playing", hint "Double-tap to stop"; "+ Record" reads "Record a sound". Two columns at accessibility sizes.
- **`PlayTint` token:** a new asset-catalog colourset (#FFE490 / #68571F).

**Out of scope**
- Recording, naming: [23]. Long-press menu, edit, delete, reorder: [24]. In calls: [26].

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| S3 | Off-call play | Plays on your phone only | No push needed | User |
| S13 | Emoji | Optional; 🔊 by default | One less step | User |
| S14 | Overlap | One at a time; tapping the playing tile stops it | Clean | User |
| S15 | Tabs | Calling · Notes · Sounds · Hobbies, label "Sounds" | Notes keeps second place | User |
| S16 | Record tile | "+ Record" is the first tile | One place to record | User |
| S22 | Tile | Title + emoji only | Cleaner tiles | User |
| S23 | Partner adds | Appears over realtime, no push | Quiet | User |
| S29 | Playback | Files cached in the App Group | Instant taps | Claude — straightforward |
| A2 | Silent switch | Plays anyway (`.playback`) | Tapping is deliberate | User |
| M1–M3, M14, M16 | Grid, record tile, PlayTint, icon, no doodle | As the spec | Approved with mockup v2 | User |
| T1 | "+ Record" before [23] | Drawn, no action | Same as tiles before [19] (PRD 18 W3) | Claude — straightforward |
| T2 | Refresh model | `changes()` signals, the tab refetches | Same as `NotesStore.changes()` (PRD 17 P4) | Claude — straightforward |

## End-to-End Flows
```
open Sounds ─► cached list at once ─► sounds() ─► grid by position ─► missing files download
tap tile ─► file(for:) ─► SoundPlayer trim range ─► PlayTint fill ─► ends, tint fades
tap playing tile ─► stops     tap another ─► first stops, second plays
partner adds / deletes ─► realtime ─► refetch ─► tile appears / fades out (stops if playing)
offline ─► cached sounds play; uncached tile shows "Couldn't load. Try again"
```

## Blast Radius
| Change | What breaks |
|---|---|
| Fourth tab | Tab bar layout and the toast offset (PRD 16) on small phones and at large text |
| App Group files | The App Group container from PRD 15 gains a `Sounds/` folder |

## File Reference
| File | Role |
|---|---|
| `ButtercupKit/Sources/ButtercupKit/SoundsStore.swift` | **new** `SoundRecord`, store, cache |
| `Buttercup/Sounds/SoundPlayer.swift` | **new** |
| `Buttercup/Sounds/SoundsTab.swift` | **new** grid, states |
| `Buttercup/Sounds/SoundTile.swift` | **new** `SoundTile`, `RecordTile` |
| `Buttercup/ContentView.swift` | fourth tab |
| `Buttercup/ButtercupApp.swift` | inject `SoundsStore` |
| `Buttercup/Assets.xcassets/PlayTint.colorset` | **new** |

---

## Acceptance Criteria
- [ ] AC1: The tab bar shows four equal tabs in the order Calling · Notes · Sounds · Hobbies.
- [x] AC2: As adam, Sounds shows "+ Record" and then the 6 seed sounds in `position` order, with 🔊 on the one without an emoji.
- [ ] AC3: Tapping a sound plays only its trimmed range (check the trimmed seed sound), with the silent switch on too, and the tile fills at the clip's pace.
- [x] AC4: Tapping the playing tile stops it; tapping another switches.
- [x] AC5: Inserting, updating and deleting a partner sound with SQL shows on the grid within a few seconds. Deleting the playing sound stops it.
- [x] AC6: After the files are cached, stopping the local stack and relaunching still shows the grid and plays the sounds.
- [x] AC7: With no sounds (delete them with SQL) the empty copy shows; "+ Record" does nothing.
- [x] AC8: VoiceOver labels match §9 for tiles and "+ Record"; accessibility sizes give two columns.
- [x] AC9: Checked in light and dark against mockup states 1–2 and the tab bar, and the build check passes.

## Required Changes
- **design.md:** paste spec §12 design items 1, 2 (the row only), 5, 6, 9 and 10.
- **technical-spec.md:** paste spec §12 technical-spec item 1, `sounds` in the realtime list from item 2, and the cache and `.playback` bullets of item 7.

## Features Catalog
- **Extends**: New feature, Sounds

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Four tabs crowd the bar at large text | Med | Labels clip | Follow the design.md tab-bar rule; labels use the Large Content Viewer |

---
*Status: PARTIAL — PR #29*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ❌ not done | Order is Calling · Notes · Sounds · Hobbies, but the bar has five tabs: the Settings tab (added after this PRD, holds Sign out and appearance) is kept last |
| AC2 | ✅ done | As adam: "+ Record", then Good morning, Boop, Ta-da (🔊), Love you, Dinner is ready, Night night, matching `position` -5…0 |
| AC3 | ⚠️ unverified | Trim and fill verified: "Love you" (1.2 s of 2.3 s) fills at pace and stops after about 1.2 s. The silent switch can't be toggled on the simulator; the player uses `.playback` |
| AC4 | ✅ done | Screenshot burst: Dinner playing, tap Good morning switches, tap again stops it well before its 1.66 s end |
| AC5 | ✅ done | SQL insert (Miso's meow), update (Boop → "Boop boop", emoji) and delete each showed within about 5 s; deleting it while playing removed the tile and stopped it |
| AC6 | ✅ done | `supabase stop`, relaunch: grid shown from `Sounds/list.json`, Dinner is ready played from the cached file |
| AC7 | ✅ done | `delete from sounds`: "+ Record" plus "No sounds yet. Record one for Partner?" and the second line; tapping "+ Record" does nothing |
| AC8 | ✅ done | AX tree: tiles labelled by title (emoji not read), value "Playing" while playing, "+ Record" reads "Record a sound"; two columns at accessibility-large |
| AC9 | ✅ done | Checked in light and dark (grid, playing, empty) against spec §4.1–§4.4; build check passes |

### Needs attention
- Decide whether Settings stays a fifth tab or moves (for example into the Calling header); then AC1 can close.
- Check the silent switch on a device: with the ringer off, tapping a sound still plays.

