# [7]: 30-minute heat test

**Depends on:** [5]: Face stickers merged (and [6] if built first).

This ticket has no code (D3). It is a test Adam and his partner run on their two iPhone 11s before hats and face paint are built. They hold a 30-minute video call with face tracking and stickers on, write down how hot and how smooth it gets every 5 minutes, and use the result to decide whether the sticker cap, frame rate or resolution need to come down before more effects are added. The iPhone 11 is the oldest phone that runs iOS 26 and the one most likely to heat up (video-calls-spec Phones).

## Summary
A checklist and a results table. The outcome is either "go: build hats and face paint as planned" or a list of settings to change, which becomes a small follow-up ticket.

## Users
- **Primary**: Adam and his partner, holding both phones.
- **Not for**: the developer agent (it can't run this).

## Scope
**MVP**
- Two runs: Wi-Fi on both; and one phone on cellular
- Results table filled in below; decision recorded

**Out of scope**
- An on-screen thermal or fps overlay — not wanted (D3). [4] already logs `thermalState` changes to the Xcode console, which can be read afterwards if a phone is plugged in.

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Test procedure](#test-procedure)
3. [Results](#results)
4. [Acceptance Criteria](#acceptance-criteria)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D3 | Heat test (step 4) | Checklist-only PRD, no code | It's a manual test | User |
| D23 | Sticker cap | Max 10 on the face at once; revisit after step 4 | Predictable load on iPhone 11 | User |
| D35 | Heat fallback | `ProcessInfo.thermalState == .critical` hides stickers, restored below it (spec) | Spec | Claude — straightforward |

## Test procedure
**Setup (both phones)**
1. Charge to at least 80%, unplug, and close other apps. Brightness at about 70%, Low Power Mode off.
2. Room temperature, phones held or on a stand (not on a sofa cushion).
3. Start a **Video** call. Each person places **5 stickers** (mix of emoji, text and an image or drawing).

**Every 5 minutes (0, 5, 10 … 30), each person notes**
- Battery %
- Feel: cool / warm / hot / too hot to hold
- Smoothness: does the partner's video or your stickers stutter? (none / some / a lot)
- Did stickers disappear on their own? That means `.critical` thermal fallback (D35)

**Run 2:** repeat with one phone on cellular (Wi-Fi off).

## Results
| Run | Phone | Min | Battery % | Feel | Stutter | Stickers off? |
|---|---|---|---|---|---|---|
| 1 Wi-Fi | Adam | 0 | | | | |
| … | | | | | | |

**Decision rule**
- Stickers switched off before 30 min, or a lot of stutter by 20 min → follow-up ticket: lower the cap (D23) to 5 and/or ARKit to 24 fps, then re-run.
- Hot but smooth to 30 min → go, but build hats as flat images only (already planned).
- Warm and smooth → go.

---

## Acceptance Criteria
- [ ] AC1: Both runs are completed and the Results table is filled in for both phones.
- [ ] AC2: A decision is written under Results (go / follow-up with named changes).
- [ ] AC3: If follow-up, a new PRD exists for the changes before build step 6 starts.

---
*Status: READY — ticket [7]*
