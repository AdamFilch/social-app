# buttercup: product overview

Start here. This page says what buttercup is, why it exists, who it's for and what it does. Each feature has a short summary and a link to its full spec.

## What it is

buttercup is a private iPhone app with three features: audio and video calls with face effects, a notes widget, and hobby tracking. It's built with Swift and SwiftUI, uses LiveKit for calls and Supabase for the backend, and is installed with TestFlight or Xcode, so v1 skips App Store review. iPhone comes first and a Mac app comes later.

## Why

- **Calls with fun on top.** Apple removed FaceTime's effects (stickers, filters, Memoji) in iOS 26, so nothing built into the iPhone offers them anymore. buttercup brings them back in its own calls.
- **Staying close day to day.** Small drawn or photo notes that show up on the other person's home screen, similar to Note-it or Locket.
- **Sharing hobbies.** Apple Books, Goodreads and other apps can't share progress, so buttercup lets you log what you're reading, watching and playing and see each other's progress.

## Who it's for

Adam and his partner, for personal use. Both use an iPhone 11. Opening the app to other people, group calls and the Mac app come later, so v1 choices shouldn't block them.

## Features

### 1. Calls with face effects (most important)

1:1 audio and video calls that ring like a real phone call (CallKit and VoIP push) and keep going in Picture-in-Picture. You can turn the camera on or off during a call, and missed calls show in a call history. You pin stickers, emoji, text, pad drawings, and flat glasses and hats (with editable text) to a spot on your face, and add filters to the whole video or just your face. Effects are baked into the video your partner sees and cleared after each call. Later: your partner putting stickers on you, a voice changer, and a Mac app.

Full spec: [video-calls-spec.md](video-calls-spec.md). Face tracking choices: [face-tracking-options.md](face-tracking-options.md).

### 2. Notes widget (Note-it / Locket-style)

You make a small square note with drawings, a photo, a face cut-out sticker, shapes, emoji or text, and send it. It shows on your partner's small home screen widget, which can show the latest note, the last 5, your favourites or all of today. Every note also lands in a shared calendar, and you can favourite, save or unsend it (within 4 hours).

Full spec: [notes-widget-spec.md](notes-widget-spec.md).

### 3. Hobby tracking

A shared tracker with a fixed set of hobbies: reading (chapters), TV shows (season and episode) and video games (percent and hours). You can each have several items going at once, see each other's progress and whether you each did a hobby today, and log it with one tap from a per-hobby widget, Siri or a Shortcuts automation.

Full spec: [hobby-tracker-spec.md](hobby-tracker-spec.md).

## Other context

- [design.md](design.md): brand look, colour tokens, type, components, motion and voice.
- [technical-spec.md](technical-spec.md): how the app is built, design system and haptics, every database table and column, functions and pushes.
- [tech-stack.md](tech-stack.md): the stack, why it was picked, and the build order.
- [ios-limits.md](ios-limits.md): what iOS won't let the app do.
- [feature-ideas.md](feature-ideas.md): the original feature overview and later ideas.
- [decisions.md](decisions.md): every product decision settled on 2026-10-19.
- [features.md](features.md): features catalog, what is built today and where the code lives.
- [../../assets/README.md](../../assets/README.md): formats for face-effect assets.
