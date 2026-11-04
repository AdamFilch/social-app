# buttercup

Private iOS 18+ app (Swift/SwiftUI) with a Supabase backend. Start with [.claude/context/product.md](.claude/context/product.md); the build details are in [.claude/context/technical-spec.md](.claude/context/technical-spec.md).

## Layout

| Path | What |
| --- | --- |
| `Buttercup/` | iOS app target |
| `ButtercupKit/` | Local Swift package: Supabase client, models, `SessionStore` |
| `supabase/migrations/` | Postgres schema, RLS, RPCs, storage and realtime setup |
| `supabase/seed.sql` | Local test data: two paired users, one unpaired user, a sample catalog |
| `supabase/tests/database/` | pgTAP tests |
| `supabase/functions/tests/` | Deno tests for the Edge Functions |
| `.claude/prds/` | Numbered tickets for the developer agent |

## Backend

Prereqs: `brew install supabase/tap/supabase livekit livekit-cli deno`, Docker Desktop running.

| Task | Command |
| --- | --- |
| Liveness check (run first) | `supabase status` |
| Start local stack | `supabase start` |
| Rebuild DB from migrations + seed | `supabase db reset` |
| Upload seed note images (after every reset) | `supabase/seed-notes.sh` |
| Tests | `supabase test db` |
| Lint | `supabase db lint` |
| New migration | `supabase migration new <name>` |
| LiveKit dev server (keys `devkey` / `secret`) | `livekit-server --dev` |
| Serve Edge Functions | `cp -n supabase/functions/.env.example supabase/functions/.env && supabase functions serve --env-file supabase/functions/.env` |
| Function tests (needs the two above running) | `supabase status -o env > supabase/functions/tests/.env && deno test --allow-net --allow-env --allow-read --env-file=supabase/functions/tests/.env supabase/functions/tests/` |
| Deploy to hosted | `supabase db push` (project `nxqcwchrigseounzkvvz`) |

Schema changes always go in a new migration; never edit one that has been pushed. The database password and service-role key live only in the shell environment (`SUPABASE_DB_PASSWORD`) and are never committed.

Edge Functions live in `supabase/functions/` (shared helpers in `_shared/`). Local LiveKit values sit in the gitignored `supabase/functions/.env`; hosted values are set with `supabase secrets set`. `supabase db reset` restarts the containers; `supabase functions serve` reconnects on its own, but its first requests can return 502 for a few seconds.

Backend tickets are verified with `supabase db reset && supabase test db && supabase db lint`, plus the function tests when functions change; there is no UI to check.

## Running the app

Needs Xcode 26 and an iOS 26 Simulator, plus an iOS 18 runtime to check the minimum version. Start the backend first (`supabase status`, then `supabase start` if it's down).

The **Debug** configuration points at the local stack (`SUPABASE_URL = http://127.0.0.1:54321` from `Config/Debug.xcconfig`, and the local demo anon key as a build setting in `Buttercup.xcodeproj`; both are read through `Buttercup/Info.plist`). **Release** points at the hosted project. Don't swap these values in a commit.

| Task | Command |
| --- | --- |
| Build check | `xcodebuild -project Buttercup.xcodeproj -scheme Buttercup -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build` |
| Run | Open `Buttercup.xcodeproj`, pick the `Buttercup` scheme and an iPhone simulator, press Run |

Sign-in uses an email code. Locally no mail is sent: open Mailpit at http://127.0.0.1:54324 and copy the 6-digit code.

Seed users (all with password `password`; the app uses email codes, the tests use the password):

| Email | State after sign-in |
| --- | --- |
| `adam@example.com` | Named and paired with partner, lands on the tabs |
| `partner@example.com` | Named and paired with adam, lands on the tabs |
| `stranger@example.com` | Unpaired, lands on the pair screen |
| any new email | Fresh account, goes through name and pairing |

To test pairing, run two simulators: one shows its invite code on the pair screen, the other pastes it into "Or paste their code". The pair screen polls every 5 seconds, so the first one moves on by itself.

`127.0.0.1` only reaches the Mac from the Simulator. On a physical iPhone, copy `Config/Local.xcconfig.example` to the gitignored `Config/Local.xcconfig` with the Mac's LAN IP, and set `LIVEKIT_URL` in `supabase/functions/.env` to the same IP (see the README).

## Testing well

Run the loop in this order and stop at the first failure:

1. `supabase status`: confirm the stack is up.
2. `supabase db reset && supabase/seed-notes.sh`: rebuild from migrations and seed, so tests never run against leftover state, then upload the seed notes' images (a reset empties the bucket).
3. `supabase test db`: pgTAP tests.
4. `supabase db lint`: must report no errors.
5. When `supabase/functions/` changed: start `livekit-server --dev` and `supabase functions serve` (see Backend), wait out the 502 and 503 responses, then run the function tests.
6. When the app changed: run the build check above, then sign in on a simulator with the seed user that reaches the screen you touched and step through it.

What to add with a change:

- A new table, policy or RPC gets pgTAP cases next to the existing ones in `supabase/tests/database/`. Cover the paired user, the partner and `stranger@example.com` (who must be denied).
- A new or changed Edge Function gets cases in `supabase/functions/tests/`. Use the `signIn`, `call` and `reset` helpers in `calls.test.ts`.
- New fixture data goes in `supabase/seed.sql` with fixed UUIDs, so tests can refer to it.

There is no Xcode test target yet; app changes are checked by building and a manual simulator run.
