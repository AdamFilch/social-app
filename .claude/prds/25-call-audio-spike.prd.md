# [25]: Call audio spike

**Depends on:** [3] Frontend Calls (calls connect with audio both ways) and [22] Sounds tab merged. Blocks [26] and [27]. Runs before [4]–[6]; it needs no tray.

This ticket is a time-boxed prototype that answers the riskiest question in the Sounds feature before any in-call UI is built (spec [soundboard.md](../design/specs/soundboard.md) §11.2 risk 1). It proves, on two iPhone 11s in a real LiveKit call, that a sound file can reach the partner through the call audio even while you're muted, plays locally without echoing back, and that both voices can be captured into one 10 s `.m4a`. It also measures the heat cost. The result is a short written decision, plus the minimal code the later tickets build on, behind a DEBUG-only button on the call screen.

## Summary
Builds a `CallSoundMixer` prototype in ButtercupKit next to `CallStore`. It tries option (a), mixing into the live mic track and muting by zeroing the mic samples, and option (b), a second short-lived published audio track for sounds. It also adds a `CallSoundCapture` that mixes the local mic with the remote participant's audio track and encodes AAC. DEBUG buttons on `InCallView` play a seed sound and record 10 s. The findings go into a "Call audio" section in technical-spec.md, and this PRD's Decision Log records the chosen option.

## Scope
**MVP**
- **Play into the call:** with each option, a seed sound reaches the partner, both unmuted and muted (S24), and plays locally (S2).
  - Check that the speaker route doesn't echo it back.
  - Check the mic still works after the sound ends.
  - Check that mute and unmute in the control bar still behave as before.
- **Capture both voices (S4):** record 10 s of your mic plus the partner's remote audio into one mono AAC `.m4a` and play it back on the Sounds tab player. Note any offset between the voices and fix it if it's more than about 100 ms.
- **Audio session:** document how LiveKit's session (`.playAndRecord`) and the app's `.playback` from [22] hand over when a call starts while a sound plays (stop playback first) and when it ends.
- **Heat:** a 10-minute video call on two iPhone 11s with a sound every 30 s and one recording, compared with the same call without them, using the thermal-state logging from [7] if it exists, else `ProcessInfo.thermalState` logs.
- **Decision:** pick (a) or (b), with the reasons and numbers, written into technical-spec.md "Call audio" and this PRD.

**Out of scope**
- The tray UI, the partner pill and the in-call naming step: [26] and [27].
- Voice effects (after v1).

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| S2 | In-call play | Mixed into the outgoing call audio and played locally, so both hear it | Shared soundboard | User |
| S4 | In-call recording | Both voices | Catch moments together | User |
| S24 | Muted | Sounds still go out | Deliberate tap | User |
| P1 | Timing | Spike right after [3], before [4]–[6] | Test the riskiest part early | User |
| P2 | Option (a) or (b) | TBD — decided by this spike's measurements | Spec §11.2 | — |

## End-to-End Flows
```
call connected ─► DEBUG "Play seed sound" ─► (a) mixed into mic track │ (b) second track
  └─► partner hears it, you hear it, mic still fine ─► repeat while muted
DEBUG "Record 10 s" ─► mic + remote track ─► mono AAC ─► play back on Sounds tab
10-min call with sounds ─► thermal log ─► compare to baseline ─► decision
```

## File Reference
| File | Role |
|---|---|
| `ButtercupKit/Sources/ButtercupKit/CallSoundMixer.swift` | **new** prototype |
| `ButtercupKit/Sources/ButtercupKit/CallSoundCapture.swift` | **new** prototype |
| `Buttercup/Calling/InCallView.swift` | DEBUG buttons |
| `.claude/context/technical-spec.md` | "Call audio" findings |

---

## Acceptance Criteria
- [ ] AC1: On two iPhone 11s, the partner hears a played sound both unmuted and muted, and the sender hears it locally, for the chosen option.
- [ ] AC2: No audible echo of the sound comes back on the speaker route, and the mic works normally after it.
- [ ] AC3: A 10 s capture contains both voices with an offset under about 100 ms, and plays back on the Sounds tab.
- [ ] AC4: Mute, unmute, and starting a call while a sound plays outside it all behave correctly.
- [ ] AC5: The heat comparison is written down with thermal states over time for both runs.
- [ ] AC6: technical-spec.md has a "Call audio" section with the decision (a) or (b), and P2 in this PRD is filled in.
- [ ] AC7: The build check passes; the DEBUG buttons don't exist in Release.

## Features Catalog
- **Extends**: Sounds; Calls (#1)

## Open Questions
- [ ] Is there a second iPhone 11 available for the run? If not, a recent iPhone plus the Simulator can answer AC1–AC4, but AC5 (heat) needs the iPhone 11.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The LiveKit iOS SDK doesn't expose a hook to mix into the captured mic | Med | Option (a) is impossible | Option (b) needs only public publish APIs |
| Echo cancellation removes the sound from the mic path or doubles it | Med | Partner hears it badly | Measure both options; (b) keeps the sound off the mic path |

---
*Status: READY — ticket [25]*
