# Hobby tracker spec

Oct 19, 2026 · @Adam

You each see what the other is reading, watching and playing, how far along you are, and whether you did each hobby today. You log progress in buttercup with one tap, because Apple Books, Goodreads and other apps can't share progress. Reading was agreed on 2026-10-18; the general hobby model, TV shows and games were settled with Adam on 2026-10-19 (see [decisions.md](decisions.md)).

## Hobbies

A fixed preset list. You can't add your own hobbies.

| Hobby | Progress | +1 button | Details from |
| --- | --- | --- | --- |
| Reading | Chapter | Next chapter | Open Library (cover, title, chapter count) |
| TV shows | Season and episode | Next episode, rolls into episode 1 of the next season using TMDB's episode counts | TMDB (poster, title, episode lists), with a "powered by TMDB" credit |
| Video games | Percent complete and hours played | +1 hour; percent is set by hand in the app | IGDB (cover, title) |

## Items

- Each person can have **several current items per hobby** at once, for example two books and three shows.
- You search once for an item and its details are saved.
- When you finish an item it moves to that hobby's **history**.

## What you see

- Each person's current items per hobby, with cover, title and progress.
- Whether each of you did each hobby today.
- Shown in the app and on widgets.

## Logging

- **Did it today** is per hobby ("read today"), whichever item it was.
- **+1** is per item.
- **Widget:** an interactive widget with the check-in and +1 buttons.
- **Siri and Shortcuts:** a "Log progress" action (App Intents) that also works from the Action button.
- **Nearly automatic reading:** a Shortcuts automation on each phone, "when Books closes, run Log progress". You close Books and buttercup asks "Read today? Which chapter?" with one tap to confirm. This is the closest to automatic that iOS allows.

## Widgets

- **One widget per hobby.** You pick the hobby in Edit Widget and can stack them in a Smart Stack.
- Each widget shows **both of you**.
- By default it shows each person's **most recently logged item** for that hobby. In Edit Widget you can pin one specific item instead.
- When one of you logs, the partner's widget refreshes through a WidgetKit push.

## Why it can't be automatic

- **Goodreads** closed its API to new developers in December 2020 and disabled existing keys ([Infodocket](https://www.infodocket.com/2020/12/13/report-goodreads-plans-to-retire-api-access-disables-existing-api-keys/)).
- **Apple Books on iPhone** has no public way for other apps to read the current book or progress. Its Shortcuts actions open books but don't report progress ([Matthew Cassinelli](https://matthewcassinelli.com/apps/books/)).

## Later: Mac helper

Books on a Mac keeps reading progress in local database files. A small Mac helper could read the current book and percentage and post it to buttercup. It's undocumented, so a macOS update could break it, and it only works if the phone's progress syncs to the Mac through iCloud. It stays a later idea.

## How it's built

- **Backend:** a `hobby_kind` enum (reading, tv, games) and the tables `catalog_entries` (shared book, show and game details), `items`, `logs` and `checkins`. Every column is listed in [technical-spec.md](technical-spec.md) §2; +1 and check-ins run as Postgres functions (§3).
- **Lookups:** the `catalog-search` Edge Function calls Open Library, TMDB and IGDB and saves results in `catalog_entries`, so the API keys and IGDB's Twitch secret never ship in the app.
- **Widget:** an interactive WidgetKit widget whose buttons run App Intents, with an `AppIntentConfiguration` for choosing the hobby and an optional pinned item.
- Data is kept forever.
- More background is in tech-stack.md section 7.
