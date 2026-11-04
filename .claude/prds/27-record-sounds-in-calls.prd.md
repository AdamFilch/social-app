# [27]: Record sounds in calls

**Depends on:** [23] Record and name a sound and [26] Play sounds in calls merged.

This ticket makes "+ Record" in the call tray work (spec [soundboard.md](../design/specs/soundboard.md) §3.6 steps 3–6, §4.14–§4.16, §8 Call). Tapping it swaps the tray panel in place to the recording view, the way the Draw tab swaps in, and records both voices: your mic plus your partner's call audio. While it runs, your partner's call screen shows a frosted "Adam is recording" pill. Stop, or 10 s, turns the panel into a naming step on the keyboard, like the Text tab, and Save puts the new sound first in the grid for both of you. ✕ or Discard asks first. If the call ends mid-recording or mid-naming, the clip is thrown away with no prompt.

## Summary
Promotes [25]'s both-voices capture to production, reuses [23]'s naming rules, save path and discard confirm, and adds the in-call recording panel, the naming panel, a reliable LiveKit data message `{type: "sound-recording", state: "started" | "stopped"}`, and the partner's `RecordingPill`. Removes [25]'s DEBUG record button. No backend changes.

## Scope
**MVP**
- **Record panel (§4.14, M12):** "+ Record" swaps the panel in place; the waveform track and Stop are the same as [23]. Recording captures your mic plus the partner's remote track (S4). If the partner is muted, it records your mic only, with nothing extra shown.
- **Notice (S5, §4.16, M13):** "started" is sent when recording begins, "stopped" on stop, discard or save. The partner sees a frosted pill under the name pill with a still red dot and "{name} is recording". It hides on "stopped", when you leave the room, or 12 s after "started". VoiceOver announces it once, politely, without moving focus.
- **Naming (§4.15):** a field and Save on the keyboard, like the Text tab, with the same rules as [23] (required, 30 characters). Save goes through [23]'s `SoundsStore.save` and outbox, and the new sound is first in the grid.
- **Discard (A3):** ✕ or Discard opens "Discard this sound?" over the call.
- **Call ends (S21):** mid-recording or mid-naming, the clip is discarded with no prompt and the panel closes with the call screen.
- **Accessibility (§9):** the "+ Record" hint "Records you and Sam, up to 10 seconds" (with the partner's name).

**Out of scope**
- Editing in a call (S20). Push for new sounds (S23).

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| S4 | In-call recording | Both voices | Catch moments together | User |
| S5 | Notice | The partner sees "{name} is recording" | Consent | User |
| S6 | Max length | 10 s, auto-stop | | User |
| S9 | Title | Required | | User |
| S16 | Record control | First tile in the tray's Sounds grid | Control bar unchanged | User |
| S21 | Call ends mid-record | Discarded | Simplest | User |
| A3 | Discard | Confirms | design.md | User |
| M12, M13 | Panel swap; frosted pill | As the spec | Approved with mockup v2 | User |
| K1 | Pill timeout | The pill hides 12 s after "started" without "stopped" | 10 s cap + 2 s; spec decision §13 | Claude — straightforward |
| K2 | Notice transport | Reliable LiveKit data message | Spec §12 tech 7; no backend needed | Claude — straightforward |

## End-to-End Flows
```
tray Sounds ─► "+ Record" ─► panel swaps ─► "started" ─► partner sees pill
Stop / 10 s ─► naming on keyboard ─► Save ─► "stopped" ─► pill hides ─► sound first for both
✕ / Discard ─► "Discard this sound?" ─► Discard ─► "stopped" ─► nothing stored
hang up mid-record ─► clip discarded ─► partner's pill hides (left room)
"stopped" lost ─► pill hides after 12 s
```

## File Reference
| File | Role |
|---|---|
| `ButtercupKit/Sources/ButtercupKit/CallSoundCapture.swift` | production path from [25] |
| `Buttercup/Sounds/TrayRecordPanel.swift` | **new** record and naming panels |
| `Buttercup/Calling/RecordingPill.swift` | **new** |
| `ButtercupKit/Sources/ButtercupKit/CallStore.swift` | send and receive the data message |
| `Buttercup/Calling/InCallView.swift` | show the pill; remove the DEBUG record button |

---

## Acceptance Criteria
- [ ] AC1: "+ Record" in the tray swaps the panel and records both voices; the saved sound plays back with both, on two devices.
- [ ] AC2: The partner sees "{name} is recording" while it runs, and the pill hides on stop, save, discard, hang-up, or after 12 s if "stopped" is dropped (simulate by killing the sender's app).
- [ ] AC3: Naming follows [23]'s rules; Save puts the sound first in the grid on both phones.
- [ ] AC4: ✕ and Discard ask first; Discard stores nothing.
- [ ] AC5: Ending the call mid-recording or mid-naming discards the clip with no prompt.
- [ ] AC6: With the partner muted, it records your mic only and works normally.
- [ ] AC7: Checked against mockup states 10 and 11 in light and dark, and the build check passes.

## Required Changes
- **technical-spec.md:** the data-message bullet and the in-call recording line of spec §12 technical-spec item 7.

## Features Catalog
- **Extends**: Sounds; Calls (#1)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Capturing both voices plus effects pushes the iPhone 11 too hot | Med | Throttling mid-call | [25]'s heat numbers; recording is at most 10 s |

---
*Status: READY — ticket [27]*
