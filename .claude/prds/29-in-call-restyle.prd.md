# [29]: In-call restyle

**Depends on:** [28]: Face sticker tracking. Build on its branch.

This ticket gives the call screen and the effects tray the buttercup look from the approved in-call design spec, [.claude/design/specs/in-call-screen.md](.claude/design/specs/in-call-screen.md) (mockup: [.claude/design/mockups/in-call-screen.html](.claude/design/mockups/in-call-screen.html)). During a call the partner fills the screen. The name and timer sit in a frosted pill at the top and four frosted control circles sit at the bottom. Your small tile can be dragged to any corner. Tap it to get the medium tile with Expand, Flip and Add stickers. Expand makes your own view big, and a Stickers button joins the bar. The tray becomes an in-view panel covering half the screen, with pill tabs Stickers · Emoji · Text. The Emoji tab shows Apple's full emoji set in categories, with skin tones on long-press. The Text tab has a live preview. Placing, moving and removing stickers keeps [28]'s 3D behaviour.

## Summary
A restyle of [3]'s call chrome and [5]'s tray to match the spec, built to the spec's §10 acceptance criteria. It also delivers spec revisions R1, R4–R8. R2 and R3 belong to the drawing pad and ship with [6]. Where the spec and [28] disagree on sticker behaviour, [28] wins (D54). Unchanged: call logic in `CallStore`, LiveKit, ARKit, the compositor, and the gestures. There are no backend changes.

## Users
- **Primary**: Adam and his partner on iPhone 11s during a video call.
- **Not for**: the outgoing, incoming and Reconnecting screens (spec C17).

## Scope
**MVP**
- Everything in spec §10, with Draw, Hats and Glasses tabs hidden (D53)

**Out of scope**
- Draw tab and pad (spec §3.5, §4.9) — ships with [6]
- Hats and Glasses tabs (§4.8) — ship with the hats ticket
- Landscape — portrait only (spec §11.2)

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [Blast Radius](#blast-radius)
4. [File Reference](#file-reference)
5. [Acceptance Criteria](#acceptance-criteria)
6. [Required Changes](#required-changes)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D7 | Visual design (from [5]) | Plain SwiftUI first, separate restyle ticket from the designer's spec | This is that ticket | User |
| D42 | Ticket split (from [28]) | [29] stacked on [28] | Small PRs | User |
| D44 | Face lost (from [28]) | Instant hide; replaces the spec's "Face lost: stickers freeze" row in §8 | Device feedback | User |
| D47 | Adding with no face (from [28]) | Disabled tray with "Show your face to add stickers", using the spec's 10-cap disabled treatment (§8) | Device feedback | User |
| D53 | Restyle scope | Spec §10 as written; Draw, Hats and Glasses tabs hidden until their tickets ship (spec R5: "a tab is listed only when its feature is enabled") | User picked the full spec | User |
| D54 | Spec vs [28] | Where the spec describes sticker placement (§3.3 step 4 "pins to the nearest face point", §8 "Face lost"), [28]'s anchor, hide and no-face rules apply. The §4.10 selected outline follows [28]'s projected quad (a rounded outline around its 4 corners, 8 pt out) instead of a rotated rectangle | [28] is newer and was decided on device | Claude — straightforward |

## Overview
The spec is the source of truth for layout, tokens, type, motion, haptics, states and accessibility. Its §5 lists the components to build. `EffectTab` here only has `stickers, emoji, text`. The emoji data is Apple's full set in Unicode `emoji-test.txt` order (spec §4.6). Bundle a generated list for the minimum iOS version rather than parsing at runtime, and exclude emoji the device can't render.

Non-obvious design decisions:
1. **The panel is not a `.sheet`** (spec R1). It is drawn inside `InCallView`, covers the control bar, and closes when a sticker lands. The current `.sheet` with detents in [StickerTray.swift](Buttercup/Effects/StickerTray.swift) goes.
2. **Two colour schemes on one screen** (spec §6.1). The call chrome is forced dark; the panel follows the system scheme.
3. **New tokens** `CallFrost` and `OnDanger` (spec §12.2) are added to `Assets.xcassets` if they aren't already there.

## Blast Radius
| Change | What breaks |
|---|---|
| Tray becomes an in-view panel | [6] puts the pad inside this panel (spec §3.5) |
| `EffectTab` and the panel's tab row | [6] and the hats ticket add their tabs here |
| Tile state machine (spec §3.2) | [3] D39–D40 behaviour, now restyled |

## File Reference
| File | Role |
|---|---|
| [Buttercup/Calling/InCallView.swift](Buttercup/Calling/InCallView.swift) | Chrome, tiles, bar, panel host |
| [Buttercup/Effects/StickerTray.swift](Buttercup/Effects/StickerTray.swift) | Becomes the panel content (Stickers, Emoji, Text) |
| [Buttercup/Effects/StickerGestures.swift](Buttercup/Effects/StickerGestures.swift) | Selected outline per spec §4.10 and D54 |
| `Buttercup/Calling/` and `Buttercup/Effects/` | **new** components from spec §5, in as few files as reads well |
| `Buttercup/Assets.xcassets` | `CallFrost`, `OnDanger` **new** if missing |
| `Buttercup/Resources/` | Generated emoji list **new** |

---

## Acceptance Criteria
- [ ] AC1: Every criterion in spec §10, except the Draw ones, holds. Check each one on the iPhone 17 simulator in a two-simulator call (adam and partner), in light and dark mode, and note the evidence for each.
- [ ] AC2: The pill row shows Stickers · Emoji · Text only.
- [ ] AC3: The face-lost and no-face states behave as [28] (D44, D47), not as the spec's "freeze" row.
- [ ] AC4 (device): Drag from the tray onto the face on an iPhone: the panel slides away as the finger crosses its top, and the drop follows [28]'s anchor rules.
- [ ] AC5: Builds for the simulator and `generic/platform=iOS`; the minimum iOS 18 runtime launches the call screen.

## Required Changes
- **Chrome and tiles**: spec §4.1–4.3, §7 (corner snap, medium tile, swap).
- **Panel**: spec §4.4–4.7, §8 Effects states, with [28]'s no-face state as one more disabled reason.
- **Selection and trash**: spec §4.10, with D54's quad outline.
- **Accessibility**: spec §9.
- **Don't commit** the local `Buttercup.xcodeproj` edits on this machine (LAN `SUPABASE_URL`, `DEVELOPMENT_TEAM`).

## Features Catalog
- **Extends**: #2 Calls
- **Closes known gaps**: TBD — read the Calls entry in `.claude/context/features.md` on `main` when filing

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Full emoji strip is slow to scroll | Low | Jank in tray | `LazyHGrid`; bundled list, no runtime parsing |
| Drag out of a non-sheet panel conflicts with the panel's swipe-down | Med | Missed drops | Swipe-down only on grabber and header (spec §4.4) |

---
*Status: READY — ticket [29]*
