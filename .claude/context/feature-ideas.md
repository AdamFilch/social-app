# buttercup feature ideas

Oct 18, 2026 · @Adam

## Overview

buttercup is a private iPhone app for Adam and his partner, with 1:1 video calls, Locket-style notes on a widget and a shared reading tracker. Opening it to other people and adding group calls come later, so v1 choices shouldn't block them.

- **Install:** TestFlight or Xcode on a paid Apple Developer account ($99/yr). No App Store review needed for v1.
- **Stack:** Swift + SwiftUI, LiveKit for calls, Supabase for the backend. iPhone first, Mac later.
- **Details:** the full reasoning is in tech-stack.md in the project files.

## Video calls with face effects

Calls ring like a real phone call. Stickers, text, pad drawings, flat glasses and hats (with editable text) pin to a spot on your face, and face paint can go on later. Everything is baked into the video your partner sees and cleared after each call. Your partner putting stickers on you comes later, then a Mac app. FaceTime dropped its effects in iOS 26, so nothing built in does this anymore.

Full spec: [Video calls with face effects spec](https://claude.ai/code/artifact/0f35d9c6-2985-42b5-930b-221656129b74)

## Notes widget (Locket-style)

You make a small square note with drawings, a photo, a face cut-out sticker, shapes, emoji or text, and send it. It shows on your partner's small home screen widget, which can show the latest note, the last 5, your favourites or all of today. Every note also lands in a shared calendar, and you can favourite, save or unsend them.

Full spec: [Notes widget spec](https://claude.ai/code/artifact/0752e2e3-0869-46ea-bd29-f632e6211067)

## Hobby tracker

Started as a shared reading tracker and became a hobby tracker on 2026-10-19 with fixed presets: reading, TV shows and video games. You see each other's current items and progress and whether you each did a hobby today, and log it with one tap from a widget, Siri or a Shortcuts automation.

Full spec: [hobby-tracker-spec.md](hobby-tracker-spec.md)

## Later and open questions

Going public, group calls and the Mac app all come after the two-person version works.

- **Going public:** sign in with a phone number, find friends from contacts, report and block, App Store review.
- **Group calls:** the same call setup, with more people in a room.

* [x] Which sticker set should come first? Emoji, text and image stickers.
* [x] Is the Mac Books helper worth building? Kept as a later idea.

All decisions from 2026-10-19 are in [decisions.md](decisions.md).
