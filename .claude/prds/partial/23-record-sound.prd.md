# [23]: Record and name a sound

**Depends on:** [21] Sounds backend and [22] Sounds tab merged. Blocks [27].

This ticket makes "+ Record" on the Sounds tab work, outside calls (spec [soundboard.md](../design/specs/soundboard.md) §3.3, §4.5–§4.7, §8 Record and name). One tap starts recording from the mic at once, in a Dialog card over the dimmed tab, with a 10 s countdown track and a big Stop. Stop, or reaching 10 s, crossfades the card into "Name this sound" above the keyboard. The title is required, Play re-listens, and Save adds the new tile right after "+ Record" on both phones. The save goes through the outbox, so it works offline. Discarding asks first. Leaving the app while recording or naming throws the clip away.

## Summary
Adds a `SoundRecorder` (mic only, mono AAC `.m4a`, 10 s cap, live levels), the record and naming Dialog card, the "Discard this sound?" confirm, a `SoundsStore.save(fileURL:title:durationMs:)` writer, and an `uploadSound` kind on the outbox from [15]. No backend changes.

## Scope
**MVP**
- **`SoundRecorder` (new):** `AVAudioRecorder` on `.playAndRecord`, mono AAC 44.1 kHz ~64 kbps, writing to the App Group. It stops itself at 10 s (S6) and publishes levels for the bars.
- **Mic permission:** asked on the first "+ Record". Denied shows the "Microphone is off" card with "Open Settings" and `.error` (§8).
- **Record card (§4.5, M4, M5):** recording starts on the tap. The waveform track is the 10 s timeline, with elapsed time on the left and time left on the right, updated each second, and the 88 pt Stop. ✕ stops and opens the discard confirm.
- **Naming (§4.6, M6, R10):** the same card crossfades above the keyboard with the field focused. Save is disabled until there's a non-space character; 30-character limit with a counter; Play re-listens with a playhead; Return saves.
- **Discard confirm (§4.7, A3):** "Discard this sound?" with Keep / Discard; a scrim tap counts as Keep.
- **Scrim (F4):** taps on the scrim do nothing while recording or naming. "+ Record" drops its sticker shadow under any scrim (F3).
- **Save:** `SoundsStore.save` writes a local copy and an `uploadSound` outbox action with an id made on the phone (S28). The flusher uploads `{sender_id}/{id}.m4a` with `upsert: false` (409 = done) and inserts the row (23505 = done), the same as `sendNote` in [15]. The tile shows at once from the local copy and stays when the row arrives.
- **Leaving:** backgrounding, or an incoming CallKit call, while recording or naming discards the clip and closes the card with no prompt (§8, S21).
- **Accessibility (§9):** focus on Stop, then on the field; "Stopped at 10 seconds" and "Saved {title}" announcements; the escape gesture opens the confirm.

**Out of scope**
- Trim and emoji, which are only in Edit (S12): [24]. Recording in a call: [27].

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| S6 | Max length | 10 s, auto-stop | Soundboard-sized | User |
| S8 | Gesture | Tap to start, tap to stop | Hands-free, accessible | User |
| S9 | Title | Required; Play; Save disabled while empty; Discard | Meaningful names | User |
| S12 | When edited | Saving asks only for a title | Quickest | User |
| S19 | New lands | At the top, after "+ Record" | Easy to find | User |
| S28 | Writes | Outbox `uploadSound`, id made on the phone | Same as PRD 15 | Claude — straightforward |
| S30 | Off-call recording | Mic only | Only the mic exists | Claude — straightforward |
| A3 | Discard | Confirms ("Discard this sound?") | design.md: destructive actions confirm | User |
| M4–M6, F3, F4, R10 | One tap records; the countdown track; naming in the same card; shadow and scrim rules | As the spec | Approved with mockup v2 | User |
| R1 | Leaving mid-record | Background or incoming call discards, no prompt | Same rule as S21 (spec §8) | Claude — straightforward |

## End-to-End Flows
```
tap "+ Record" ─► (first time: mic prompt) ─► recording card ─► bars fill
Stop or 10 s ─► naming above keyboard ─► type title ─► Save
  └─► local copy + uploadSound ─► tile first after "+ Record" ─► flusher uploads + inserts ─► partner sees it
✕ / Discard ─► "Discard this sound?" ─► Keep: back to naming │ Discard: nothing stored
offline Save ─► tile shows at once ─► uploads when the network returns
background mid-record ─► clip discarded, card closed
```

## File Reference
| File | Role |
|---|---|
| `Buttercup/Sounds/SoundRecorder.swift` | **new** |
| `Buttercup/Sounds/RecordFlow.swift` | **new** record card, naming, discard confirm |
| `Buttercup/Sounds/WaveformTrack.swift` | **new** recording bars and playhead |
| `ButtercupKit/Sources/ButtercupKit/SoundsStore.swift` | `save`, local copies |
| `ButtercupKit/Sources/ButtercupKit/Outbox.swift` | `uploadSound` kind |
| `Buttercup/Sounds/SoundsTab.swift` | "+ Record" opens the flow |
| `Buttercup/Info.plist` | `NSMicrophoneUsageDescription` (if not already set by calls) |

---

## Acceptance Criteria
- [x] AC1: One tap on "+ Record" starts recording; the track fills over 10 s with live bars, and elapsed and time left update each second.
- [x] AC2: Stop, or 10 s, moves to naming above the keyboard. Save stays disabled for spaces only; the field stops at 30 characters.
- [x] AC3: Play re-listens with a playhead.
- [x] AC4: Discard and ✕ ask first; Keep returns; Discard stores nothing (no row, no file, no outbox action).
- [x] AC5: Scrim taps do nothing while recording or naming, and "+ Record" has no sticker shadow under the scrim.
- [x] AC6: Save shows the new tile right after "+ Record", and it appears on partner's grid. One row and one `.m4a` exist in `sounds`.
- [ ] AC7: With the Mac's Wi-Fi off, Save still shows the tile; after Wi-Fi is back it uploads once. (Needs a person: mark not verified otherwise.)
- [x] AC8: Backgrounding while recording or naming discards the clip.
- [x] AC9: Mic denied shows the "Microphone is off" card.
- [ ] AC10: Checked against mockup states 5, 6, 6b and 6c in light and dark, and the build check passes.

## Required Changes
- **design.md:** paste spec §12 design items 2 (the bullet), 3, 4, 7 and 8.
- **technical-spec.md:** paste "upload sound" into the outbox list (item 2) and the recording and offline bullets of item 7.

## Features Catalog
- **Extends**: Sounds (from [22])

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Simulator mic input differs from a device | Med | Levels and quality untested | Check AC1–AC3 on a device once |

---
*Status: PARTIAL — PR #30*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ✅ done | iPhone 17 simulator: one tap on "+ Record" started recording; bars added left to right, "0:01 / 9 s left", "0:02 / 8 s left" |
| AC2 | ✅ done | Stop and the 10 s auto-stop both open naming; spaces only gave "3/30" with Save disabled; 39 typed characters stopped at 30/30 |
| AC3 | ✅ done | Play showed the stop glyph and a red playhead moving across the track |
| AC4 | ✅ done | Discard and ✕ open "Discard this sound?"; Keep (and a scrim tap) returned to naming; Discard closed the card, `Recordings/` empty, 6 rows, no new file |
| AC5 | ✅ done | Taps on the scrim during recording and naming did nothing; "+ Record" shows no sticker shadow under the scrim |
| AC6 | ✅ done | "Test meow" tile appeared right after "+ Record"; one `sounds` row (1818 ms, position -6) and one `.m4a` in storage. Partner visibility checked through the row (RLS), not on a second device |
| AC7 | ⚠️ unverified | Needs a person with the Mac's Wi-Fi off. Online upload and the flusher are verified; the offline path is not |
| AC8 | ✅ done | Home during recording, then relaunch: card closed, nothing stored |
| AC9 | ✅ done | `simctl privacy revoke microphone`: "Microphone is off" card with Open Settings and ✕ |
| AC10 | ⚠️ unverified | Light mode compared with states 5, 6, 6c and the build check passes. Dark mode, the soft keyboard (simulator used the hardware keyboard) and state 6b playing were not checked against the mockup in dark |

### Needs attention
- Turn Wi-Fi off, save a sound, check the tile shows, turn Wi-Fi on and check one upload (AC7).
- Check dark mode against the mockup, and the card above the soft keyboard.
- Check mic levels and quality on a device (the simulator uses the Mac's mic).
