#!/bin/sh
set -e
cd "$(dirname "$0")/.."
for f in supabase/seed-notes/*/*.heic; do
  supabase --experimental storage cp --local --content-type image/jpeg "$f" "ss:///notes/${f#supabase/seed-notes/}"
done
