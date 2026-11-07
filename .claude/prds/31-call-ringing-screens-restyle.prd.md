# [31]: Outgoing and incoming restyle

**Depends on:** [30]: Calling tab restyle. Build on its branch.

This ticket gives the two ringing screens the buttercup look. They are the last call screens still in [3]'s plain SwiftUI (in-call spec C17 left them out).

- **Outgoing:** after you tap Audio or Video, the screen is always dark, like the in-call screen it fades into. It shows your partner's large avatar, "Calling Sam…", "Video call" or "Audio call", and one Danger end circle labelled "Cancel".
- **Incoming:** a Surface sheet with the partner's avatar, "Sam is calling", the call kind, and two labelled circles: Decline in Danger and Answer in Accent.

There is no mockup for these screens. They are styled from [design.md](../context/design.md) tokens and the [29] in-call controls, and the Decision Log marks those choices so Adam can redirect them. CallKit ([8]) later replaces the in-app incoming sheet for closed and locked phones (D24 in [3]). Until then this sheet is what the callee sees.

## Summary
A visual restyle of `OutgoingView` and `IncomingSheet` that reuses `CallControlButton` from `InCallView.swift`. There are no changes to `CallStore`, the call flow, timeouts or the backend.

## Users
- **Primary**: Adam and his partner placing or receiving a call with the app open.
- **Not for**: CallKit's system ringing UI ([8]).

## Scope
**MVP**
- Outgoing screen layout, always dark
- Incoming sheet layout with labelled Decline / Answer circles
- `CallControlButton` moved to `DesignSystem/` so both screens and `InCallView` share it

**Out of scope**
- Self camera preview behind the outgoing screen for video calls
- Ringtones and ringing animation (pulsing avatar): design.md says nothing idles or loops
- CallKit and PushKit: [8]

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [Behaviour](#behaviour)
4. [Blast Radius](#blast-radius)
5. [File Reference](#file-reference)
6. [Acceptance Criteria](#acceptance-criteria)
7. [Required Changes](#required-changes)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D1 | Scope (from [30]) | Restyle both outgoing and incoming, even though [8] later replaces the incoming sheet | Users see it until [8] ships | User |
| D2 | Design source | No mockup; design.md tokens + [29] in-call controls | No mockup exists; run the designer agent first if this should look different | Claude, from design.md; no mockup |
| D3 | Outgoing colour scheme | Always dark (`.preferredColorScheme(.dark)` on the view) | It cross-fades into the always-dark in-call screen; no light→dark flash | Claude, from design.md; no mockup |
| D4 | Buttons | `CallControlButton` at 72 pt: `.end` for Cancel and Decline, `.active` (Accent) for Answer, each with a caption label under it | Same circles as the in-call bar; labels because these are the only actions on screen | Claude, from design.md; no mockup |
| D5 | Shared button | Move `CallControlButton` from `InCallView.swift` to `DesignSystem/Buttons.swift` unchanged, except the symbol size scales with `size` (26 at 56, 30 at 72) | Three screens use it | Claude |
| D6 | No ringing motion | Static avatar, no pulse | design.md: nothing idles or loops | Claude, from design.md |

## Overview
```
Outgoing (dark, full screen)        Incoming (sheet, .medium)
┌───────────────────────┐           ┌───────────────────────┐
│                       │           │          ──           │
│        ( S )          │ 128       │        ( S )          │ 88
│     Calling Sam…      │ title     │    Sam is calling     │ title2
│      Video call       │ sub       │      Video call       │ sub
│                       │           │                       │
│                       │           │   (☏̸)        (▶)     │ 72 circles
│         (☏̸)          │ 72 End    │  Decline     Answer   │ caption bold
│        Cancel         │           └───────────────────────┘
└───────────────────────┘
```

## Behaviour
### Outgoing (`OutgoingView`)
- The full screen is filled with `Background`, with `.preferredColorScheme(.dark)` (D3) and a light status bar. `ContentView`'s existing 0.2 s opacity transition and `.animation(value: calls.phase)` stay as they are.
- The centred stack sits a third of the way down:
  - `Avatar(profile: partner, size: 128, outline: 2.5)`.
  - 20 pt gap, then "Calling {name}…" in `.title` heavy, TextPrimary, one line, scaling down to a minimum of 0.7.
  - 6 pt gap, then "Video call" / "Audio call" (from `calls.call?.isVideo`) in `.subheadline` semibold, TextSecondary.
- Bottom, 32 pt above the safe area:
  - `CallControlButton(symbol: "phone.down.fill", label: "Cancel", style: .end, size: 72)`, which calls `calls.end()`.
  - "Cancel" in `.caption` bold, TextPrimary, 8 pt below the circle, hidden from VoiceOver because the button carries the label.
- `.error` haptic on a failed end stays wherever it lives today.

### Incoming (`IncomingSheet`)
- Sheet settings: `.presentationDetents([.medium])`, `.presentationCornerRadius(28)`, `.presentationBackground(Color("Surface"))`, `.presentationDragIndicator(.hidden)` and `.interactiveDismissDisabled()`. It follows the system colour scheme.
- Stack, centred, 24 pt padding:
  - `Avatar(size: 88, outline: 2.5)`.
  - 14 pt gap, then "{name} is calling" in `.title2` heavy.
  - 4 pt gap, then "Video call" / "Audio call" in `.subheadline` semibold, TextSecondary.
- Button row: two columns, 56 pt apart, centred, 24 pt below the text.
  - Decline: `CallControlButton(symbol: "phone.down.fill", label: "Decline", style: .end, size: 72)`, which calls `calls.end()`.
  - Answer: `CallControlButton(symbol: isVideo ? "video.fill" : "phone.fill", label: "Answer", style: .active, size: 72)`, which calls `calls.answer()`.
  - Captions "Decline" / "Answer" in `.caption` bold, 8 pt below each circle.
- At accessibility text sizes the text wraps to multiple lines, and the circles keep their size.
- The `.success` haptic on connect is unchanged.

## Blast Radius
- `Buttercup/Calling/OutgoingView.swift`, `Buttercup/Calling/IncomingSheet.swift`: rewrite the bodies.
- `Buttercup/Calling/InCallView.swift` → `Buttercup/DesignSystem/Buttons.swift`: move `CallControlButton` (D5). The in-call bar must look identical afterwards.
- `.claude/context/features.md` §2 step 6: describe the new screens.
- No `CallStore`, `ContentView` or backend changes.

## File Reference
| File | Use |
| --- | --- |
| `Buttercup/Calling/InCallView.swift` | `CallControlButton` (styles `.frosted` / `.active` / `.end`), `Frost` |
| `Buttercup/Calling/CallingView.swift` | `Avatar(profile:size:outline:)` |
| `Buttercup/ContentView.swift` | Overlay transition and the `.sheet` for `.incoming`, unchanged |
| `.claude/context/design.md` | §3 type, §4 colour, §6 Buttons, §11 voice ("Sam is calling") |

## Acceptance Criteria
Use two simulators: `adam@example.com` and `partner@example.com`, with the backend, `livekit-server --dev` and `supabase functions serve` running.

- [ ] AC1: Adam taps Audio. The outgoing screen is dark (with the device in light mode too) and shows the avatar, "Calling Sam…" (partner's name), "Audio call" and a labelled Cancel circle.
- [ ] AC2: Cancel ends the call. The newest `calls` row is `cancelled`, and the screen fades back to the Calling tab.
- [ ] AC3: Partner's simulator shows the incoming sheet in its system scheme, with radius 28, the avatar, "Adam is calling", the kind, and Decline / Answer circles with captions.
- [ ] AC4: Decline sets `declined` on both sides. In a new call, Answer connects both phones to the in-call screen with no light flash on the caller's side.
- [ ] AC5: A Video call shows `video.fill` on Answer and "Video call" on both screens.
- [ ] AC6: The in-call bar looks unchanged after moving `CallControlButton`. Compare screenshots before and after.
- [ ] AC7: At an accessibility text size nothing clips. VoiceOver reads "Cancel", "Decline" and "Answer" once each.
- [ ] AC8: Builds with the CLAUDE.md build check. The iOS 18 runtime shows both screens.

## Required Changes
- **Outgoing**: Behaviour §Outgoing.
- **Incoming**: Behaviour §Incoming.
- **Shared button**: D5.
- **Docs**: `features.md` §2.
- **Don't commit** local `Buttercup.xcodeproj` or `Config/Local.xcconfig` edits.

## Features Catalog
- **Extends**: #2 Calls

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The dark outgoing screen surprises in light mode | Low | Feels inconsistent | D3 is marked as Claude's call; easy to flip |
| [8] CallKit makes the incoming restyle short-lived | High | Throwaway work | Small change; D1 accepted by Adam |
