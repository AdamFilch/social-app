# [26]: Play sounds in calls

**Depends on:** [5] Face stickers (the effects tray) merged, [22] Sounds tab merged, and [25] Call audio spike done with its decision. [6] is not required. Blocks [27].

This ticket brings the soundboard into calls (spec [soundboard.md](../design/specs/soundboard.md) §3.6 steps 1–2 and 7–8, §4.12–§4.13, and the in-call-screen.md amendments R1–R5). The Stickers button is now first in the control bar in every call state, and the tray gains a **Sounds** pill, last in the row. Tapping a sound plays it for both of you through the call audio, even while you're muted, and the tray stays open so you can play another. When stickers aren't possible (an audio call, your camera off or flipped), the tray opens straight on Sounds and the face pills sit at 40% with a short reason. When your partner is big, the face pills still work and first swap your view big.

## Summary
Builds on [5]'s tray and [25]'s chosen call-audio path. Adds `EffectTab.sounds` (with `needsFace` false), the tray's Sounds grid (120 × 84 cells in three rows that scroll sideways), the always-present bar button, the open-on-Sounds rule, and the dimmed face pills. Promotes the [25] prototype code to production for playing and removes its DEBUG play button. No backend changes.

## Scope
**MVP**
- **Bar button (R1, R5, A1):** first in the bar in every call state: Stickers · Mute · Camera · Route · End. Labelled "Effects and sounds", never disabled.
- **Opening tab (R2):** the last tab used, except when stickers aren't possible or the partner is big, then Sounds.
- **Sounds pill (R4, M11):** last pill, after Glasses (Hats and Glasses only once their tickets ship). `EffectTab.needsFace` is false only for `sounds`.
- **Tray grid (§4.12):** the hint "Tap to play for you both", then "+ Record" (inactive until [27]) and the sounds in shared order, from the same `SoundsStore`. The PlayTint progress and the one-at-a-time rule are the same as [22]. Taps only play; there's no menu and no drag (S20).
- **Play (S2, S24, S25):** through [25]'s chosen path, for both, while muted too. The tray stays open. The partner sees no cue (A5).
- **Stickers unavailable (§4.13, R3, M17):** face pills at 40%, inert, with the line "Stickers come back when your camera's on". Turning the front camera on brings them back with a 0.15 s fade while you stay on Sounds. The 10-sticker cap and the heat pause never touch Sounds.
- **Partner big (M18):** the face pills work; tapping one swaps your view big first.
- **Accessibility (§9):** the hint "Double-tap to play for you both"; dimmed pills hint "Turn on your front camera to use stickers".

**Out of scope**
- Recording in a call: [27].

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| S1 | Where | A Sounds pill in the in-call tray | | User |
| S2 | In-call play | Both hear it | Shared soundboard | User |
| S20 | Tray | Taps only play; no reorder | No accidental drags | User |
| S24 | Muted | Sounds still go out | Deliberate tap | User |
| S25 | Tray | Stays open after a tap | Several in a row | User |
| A1 | Tray access | Stickers button always in the bar; opens on Sounds when stickers aren't possible | Sounds in audio calls | User |
| A5 | Partner cue | None; they just hear it | Quiet | User |
| M11, M17, M18 | Pill position and cells; dimmed face pills; partner-big swap | As the spec | Approved with mockup v2 | User |
| C1 | Bar label | "Effects and sounds", never disabled | Spec decision §13 | Claude — straightforward |
| C2 | Audio path | Whatever [25] decided (P2) | Spike result | Claude — straightforward |

## End-to-End Flows
```
any call ─► Stickers button ─► tray (Sounds if no face or partner big; else last tab)
tap sound ─► local + call audio ─► partner hears ─► tray stays open
muted ─► tap sound ─► partner still hears it
audio call ─► face pills 40% + reason ─► camera on ─► pills fade back, still on Sounds
partner big ─► tap Emoji ─► your view swaps big ─► Emoji tab
```

## Blast Radius
| Change | What breaks |
|---|---|
| Bar button in every state | [5]'s state-C-only rule; recheck the bar layout in each state from in-call-screen.md §4.1 |
| Camera-off rules | [5]'s disabled states (R3); recheck Add stickers on the medium tile |

## File Reference
| File | Role |
|---|---|
| The tray and `EffectTab` from [5] | Sounds tab, `needsFace`, opening rule, dimmed pills |
| `Buttercup/Calling/InCallView.swift` | bar button in every state |
| `Buttercup/Sounds/TraySoundsGrid.swift` | **new** |
| `ButtercupKit/Sources/ButtercupKit/CallSoundMixer.swift` | production path from [25] |

---

## Acceptance Criteria
- [ ] AC1: The Stickers button is first in the bar in every call state, never disabled, and reads "Effects and sounds".
- [ ] AC2: In an audio call, or with your camera off or flipped, the tray opens on Sounds and the face pills are at 40% and inert, with the reason line. Turning the camera on brings them back.
- [ ] AC3: With the partner big, the tray opens on Sounds and a face pill swaps your view big.
- [ ] AC4: Tapping a sound plays it for both of you, also while you're muted, and the tray stays open. Two devices, or a device plus meet.livekit.io.
- [ ] AC5: One sound at a time; there's no long-press or drag in the tray.
- [ ] AC6: A sound the partner adds mid-call appears in the tray grid.
- [ ] AC7: Checked against mockup states 9 and 9b in light and dark, and the build check passes.

## Required Changes
- **technical-spec.md:** the in-call audio session bullet of spec §12 technical-spec item 7, matching [25]'s decision.

## Features Catalog
- **Extends**: Sounds; Calls (#1)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| [5]'s tray was built without room for a non-face tab | Low | Rework in [5]'s code | in-call-screen.md is already amended (R1–R5), so [5] can plan for it |

---
*Status: READY — ticket [26]*
