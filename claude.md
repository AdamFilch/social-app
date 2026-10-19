# buttercup

Private iOS 26 app (Swift/SwiftUI) with a Supabase backend. Start with [.claude/context/product.md](.claude/context/product.md); the build details are in [.claude/context/technical-spec.md](.claude/context/technical-spec.md).

## Layout

| Path | What |
| --- | --- |
| `Buttercup/` | iOS app target |
| `supabase/migrations/` | Postgres schema, RLS, RPCs, storage and realtime setup |
| `supabase/seed.sql` | Local test data: two paired users plus a sample catalog |
| `supabase/tests/database/` | pgTAP tests |
| `.claude/prds/` | Numbered tickets for the developer agent |

## Backend

Prereqs: `brew install supabase/tap/supabase`, Docker Desktop running.

| Task | Command |
| --- | --- |
| Liveness check (run first) | `supabase status` |
| Start local stack | `supabase start` |
| Rebuild DB from migrations + seed | `supabase db reset` |
| Tests | `supabase test db` |
| Lint | `supabase db lint` |
| New migration | `supabase migration new <name>` |
| Deploy to hosted | `supabase db push` (project `nxqcwchrigseounzkvvz`) |

Schema changes always go in a new migration; never edit one that has been pushed. The database password and service-role key live only in the shell environment (`SUPABASE_DB_PASSWORD`) and are never committed.

Backend tickets are verified with `supabase db reset && supabase test db && supabase db lint`; there is no UI to check.
