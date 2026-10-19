# buttercup decision log

Settled with Adam on 2026-10-19 in a question round about the open points in the specs.

| # | Decision |
|---|---|
| Q1 | Hobby tracking uses a general hobby model; reading is the first hobby |
| Q2 | v1 has audio-only calls as well as video calls |
| Q3 | Voice changer comes later, after v1 |
| Q4 | Notes can be unsent for 4 hours |
| Q5 | Hobbies come from a fixed preset list, no custom hobbies |
| Q6 | Two call buttons (audio and video); camera can be turned on or off during a call; turning it on starts ARKit and effects |
| Q7 | Missed calls: a notification plus an in-app call history, no voicemail |
| Q8 | Accounts pair with a one-time invite link after Sign in with Apple |
| Q9 | Presets: reading (chapters), TV shows (season and episode), video games |
| Q10 | Every hobby gets a daily "did it today" check-in plus a +1 button |
| Q11 | Mac Apple Books helper stays as a later idea |
| Q12 | First face effects: emoji, text and image stickers |
| Q13 | TV details come from TMDB (free key, "powered by TMDB" credit) |
| Q14 | Game details come from IGDB (needs a Twitch developer account; secret kept in a Supabase Edge Function) |
| Q15 | Several current items per hobby per person; finished items move to a history |
| Q16 | One widget per hobby, chosen in Edit Widget, showing both people |
| Q17 | Games track both percent complete and hours played |
| Q18 | Widget shows each person's most recently logged item, with an option to pin one item |
| Q19 | "Did it today" is per hobby; +1 is per item |
| Q20 | Notes, call history and hobby logs are kept forever |
| Q21 | Game +1 adds one hour; percent is set by hand in the app |
| Q22 | TV +1 moves to the next episode and rolls into the next season using TMDB episode counts |
| Q23 | Each person's avatar is an initial on a pastel tint saved on their profile; a photo comes later |
| Q24 | Audio and Video call buttons are equal; dark mode follows the phone's setting |

## Technical decisions

| # | Decision |
|---|---|
| T1 | Supabase is the only backend (CloudKit can't create call tokens or send VoIP pushes) |
| T2 | iOS 26 and newer only |
| T3 | Minimal haptics: `.selection` on tab change only, no haptic on ordinary buttons (visual spring press only); `.success` on call connected and note sent, `.error` on failure, a light tap when a sticker drops |
| T4 | Custom brand look, not standard Liquid Glass |
| T5 | Colours are named tokens in the asset catalog; Adam picks the values later |
| T6 | Custom bottom tab bar (Calling / Notes / Hobbies) with a quiet 0.15 s colour fade, no sliding; zoom transitions and springs into detail screens |
| T7 | Plain SwiftUI, an `@Observable` store per feature, async/await; only packages are LiveKit and supabase-swift |
| T8 | SwiftData cache in the App Group, read directly by widgets |
| T9 | Supabase Realtime while the app is open; pushes and widget pushes when closed |
| T10 | Actions that change several rows are Postgres functions (RPC); simple reads and inserts go direct under RLS |
| T11 | Partners are stored in a `pairs` table |
| T12 | Offline outbox in SwiftData; ids made on the phone so retries never duplicate |
| T13 | Font is SF Pro Rounded |
| T14 | Each note is one 1000 px HEIC; thumbnails are made on the phone |
| T15 | A shared `catalog_entries` table holds book, show and game details |
| T16 | Unanswered calls stop ringing after 45 s and become missed |
| T17 | Brand look is Buttercup Field (light) and Sticky Note (dark); colour values in [design.md](design.md) replace T5's placeholders; all buttons are pills; sticker shadow at most once per screen |
