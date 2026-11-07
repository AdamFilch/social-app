#!/bin/sh
set -e
cd "$(dirname "$0")/.."
for f in supabase/seed-sounds/*/*.m4a; do
  supabase --experimental storage cp --local --content-type audio/mp4 "$f" "ss:///sounds/${f#supabase/seed-sounds/}"
done
