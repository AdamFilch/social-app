# buttercup

Private iOS 26 app (Swift/SwiftUI) with a Supabase backend. Start with [.claude/context/product.md](.claude/context/product.md); the build details are in [.claude/context/technical-spec.md](.claude/context/technical-spec.md).

## Layout

| Path | What |
| --- | --- |
| `Buttercup/` | iOS app target |
| `ButtercupKit/` | Local Swift package: Supabase client, models, `SessionStore` |
| `supabase/migrations/` | Postgres schema, RLS, RPCs, storage and realtime setup |
| `supabase/seed.sql` | Local test data: two paired users plus a sample catalog |
| `supabase/tests/database/` | pgTAP tests |
| `.claude/prds/` | Numbered tickets for the developer agent |

## Backend

Prereqs: `brew install supabase/tap/supabase livekit livekit-cli deno`, Docker Desktop running.

| Task | Command |
| --- | --- |
| Liveness check (run first) | `supabase status` |
| Start local stack | `supabase start` |
| Rebuild DB from migrations + seed | `supabase db reset` |
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
