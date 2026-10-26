# buttercup

A private iPhone app for two people: audio and video calls with face effects, a notes widget, and shared hobby tracking. It's built in Swift and SwiftUI for iOS 18 and newer, with a Supabase backend and LiveKit for calls. See [.claude/context/product.md](.claude/context/product.md) for the full picture.

**Status:** the backend, sign-in, pairing and calls work. Calls only ring while the other person has the app open; ringing a closed or locked phone comes later with CallKit. Notes and hobbies are still being built.

## Requirements

- A Mac with Xcode 26 (an iOS 18 Simulator runtime to test the oldest supported version)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/), running
- Homebrew tools:

  ```sh
  brew install supabase/tap/supabase livekit livekit-cli deno
  ```

## Quick start

1. Clone and start the local backend. The first run downloads Docker images and takes a few minutes.

   ```sh
   git clone https://github.com/AdamFilch/social-app.git
   cd social-app
   supabase start
   ```

   This applies the migrations and loads the test data in `supabase/seed.sql`.

2. Open `Buttercup.xcodeproj` in Xcode, pick the **Buttercup** scheme and an iPhone simulator, and press Run. Debug builds already point at your local backend.

3. Sign in with `adam@example.com`. No real email is sent; open Mailpit at http://127.0.0.1:54324, open the newest message and type the 6-digit code into the app.

Adam is already paired with a partner in the test data, so you land straight on the tabs.

## Test accounts

| Email | What you'll see |
| --- | --- |
| `adam@example.com` | Paired with partner, goes straight to the tabs |
| `partner@example.com` | Paired with adam, goes straight to the tabs |
| `stranger@example.com` | Not paired, goes to the pair screen |
| any other email | A new account: pick a name, then pair |

All the codes for every account show up in Mailpit.

### Try pairing

1. Run the app on two simulators (in Xcode, pick a second simulator and press Run again).
2. Sign in on each with `stranger@example.com` and a new email (for example `you@example.com`).
3. On one, copy the invite code from the pair screen. On the other, paste it under "Or paste their code" and tap **Pair**.

Both move on to the tabs within a few seconds.

### Try a call

Calls need LiveKit and the functions server, each in its own terminal:

```sh
livekit-server --dev
```

```sh
cp -n supabase/functions/.env.example supabase/functions/.env
supabase functions serve --env-file supabase/functions/.env
```

Ringing is a row in the `calls` table that reaches the other phone over Realtime, so the person you call must have the app open. LiveKit only carries the audio and video; you answer in the app, not in LiveKit.

1. Run the app on two simulators: in Xcode, pick a second simulator from the destination menu next to the scheme and press ⌘R. If Xcode asks whether to stop the first one, choose **Add**.
2. Sign in on one as `partner@example.com` and on the other as `adam@example.com`.
3. On partner's Calling tab, tap **Audio** or **Video**. Adam's simulator shows "Partner is calling"; tap **Answer**.

Two simulators on one Mac can't both send audio and video reliably, so use them to check ringing, answering, hanging up and call history. To check the media itself, use a browser as the other side (below), or your iPhone (see [Testing with one iPhone and a simulator](#testing-with-one-iphone-and-a-simulator)).

### Test audio and video with a browser

The browser joins the call's LiveKit room in Adam's place.

1. In Chrome, open https://meet.livekit.io and choose the **Custom** tab. Safari may block the connection to `ws://127.0.0.1`.
2. On the simulator, sign in as `partner@example.com` and tap **Video**. It shows "Calling Adam…" and is already in the room.
3. Get a token for that room:

   ```sh
   ROOM=$(docker exec supabase_db_buttercup psql -U postgres -tAc \
     "select room_name from calls where status='ringing' order by created_at desc limit 1")
   lk token create --api-key devkey --api-secret secret --join --room "$ROOM" --identity web --valid-for 1h
   ```

4. Mark the call answered, so the simulator moves to the in-call screen instead of giving up after 45 s:

   ```sh
   docker exec supabase_db_buttercup psql -U postgres -c \
     "update calls set status='answered', answered_at=now() where room_name='$ROOM'"
   ```

5. In the browser, enter the server URL `ws://127.0.0.1:7880`, paste the token and connect.

The browser should show the simulator's video (a bundled test clip, since the simulator has no camera), and the simulator should show your webcam and play your mic. Mute and Camera off on the simulator should take effect in the browser.

## Testing with one iPhone and a simulator

Your iPhone is one side and a simulator on your Mac is the other. Both talk to the backend running on the Mac. This is the best way to test calls, because the phone sends a real camera and mic.

Your phone can't reach `127.0.0.1` (on the phone, that address means the phone itself), so everything has to use your Mac's local IP address. The simulator can reach that address as well, so one setting covers both devices.

1. **Put the phone on the same Wi-Fi as the Mac** and find the Mac's IP:

   ```sh
   ipconfig getifaddr en0
   ```

   The rest of these steps use `192.168.1.20` as the example. Use your own IP.

2. **Set up signing.** In Xcode, select the **Buttercup** target, open **Signing & Capabilities** and choose your team. If the bundle ID `com.adamfilchoir.buttercup` is taken, change it to one of your own. The first time, also turn on **Developer Mode** on the phone (Settings › Privacy & Security), and after the first install trust your developer profile (Settings › General › VPN & Device Management).

3. **Point the app at the Mac.** Copy the example config and put your IP in it:

   ```sh
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

   `Config/Local.xcconfig` is gitignored and overrides the Debug `SUPABASE_URL` from `Config/Debug.xcconfig`. Delete it to go back to `127.0.0.1`. Keep the `/$()/` in the URL, because a plain `//` starts a comment in `.xcconfig` files.

4. **Point calls at the Mac.** In `supabase/functions/.env`, set:

   ```sh
   LIVEKIT_URL=ws://192.168.1.20:7880
   ```

   This is the address the app gets for joining a call. Leave `LIVEKIT_API_URL` as it is, because the functions use it from inside Docker.

5. **Start the backend**, each command in its own terminal. LiveKit needs `--bind 0.0.0.0`, because in dev mode it otherwise only accepts connections from the Mac itself.

   ```sh
   supabase start
   ```

   ```sh
   livekit-server --dev --bind 0.0.0.0
   ```

   ```sh
   supabase functions serve --env-file supabase/functions/.env
   ```

   If `supabase functions serve` was already running, restart it so it reads the new `LIVEKIT_URL`.

6. **Run on both devices.** Plug in the phone (or pair it over Wi-Fi in Xcode under Window › Devices and Simulators), pick it as the run destination and press ⌘R. Then pick an iPhone simulator and press ⌘R again. When Xcode asks whether to stop the app on the phone, choose **Add** so both stay running.

7. **Allow local network access.** The first time the app runs on the phone, iOS asks to let buttercup find devices on your local network. Tap **Allow**. Without it the phone can't reach the Mac.

8. **Sign in.** Sign in on the phone as `adam@example.com` and on the simulator as `partner@example.com`. The codes for both arrive in Mailpit on the Mac at http://127.0.0.1:54324.

9. **Make a call** from either device and answer it on the other. Keep the app open on both, because ringing only works while the app is open. The phone shows the simulator's test clip, and the simulator shows the phone's camera and plays its mic.

To test pairing instead, sign in on one device as `stranger@example.com` and on the other with a new email, then follow [Try pairing](#try-pairing).

**If the phone can't connect:**

- Check that the phone and the Mac are on the same Wi-Fi. Guest networks often block devices from reaching each other.
- On the phone, turn on buttercup under Settings › Privacy & Security › Local Network.
- If macOS asks whether `livekit-server` or Docker can accept incoming connections, allow it. You can also check System Settings › Network › Firewall.
- Your Mac's IP can change, for example on a different Wi-Fi network. If it does, update the IP in both `Config/Local.xcconfig` and `supabase/functions/.env`, and restart `supabase functions serve`.
- If sign-in works but calls fail, `LIVEKIT_URL` or the `--bind` flag is the likely cause.

## Running the tests

The backend has two test suites. Run them with the local stack up:

```sh
supabase db reset   # rebuild the database from scratch
supabase test db    # database tests (pgTAP)
supabase db lint    # schema lint
```

The Edge Function tests also need LiveKit and the functions server, each in its own terminal:

```sh
livekit-server --dev
```

```sh
cp -n supabase/functions/.env.example supabase/functions/.env
supabase functions serve --env-file supabase/functions/.env
```

Then:

```sh
supabase status -o env > supabase/functions/tests/.env
deno test --allow-net --allow-env --allow-read --env-file=supabase/functions/tests/.env supabase/functions/tests/
```

If the first requests fail with 502 or 503, the functions server is still starting. Wait a few seconds and run the tests again.

## Local addresses

| What | URL |
| --- | --- |
| API | http://127.0.0.1:54321 |
| Postgres | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| Studio (database browser) | http://127.0.0.1:54323 |
| Mailpit (sign-in codes) | http://127.0.0.1:54324 |
| LiveKit | ws://127.0.0.1:7880 |

Stop everything with `supabase stop`.

## Project layout

| Path | What |
| --- | --- |
| `Buttercup/` | The iOS app |
| `ButtercupKit/` | Swift package with the Supabase client, models and session state |
| `supabase/migrations/` | Database schema, security rules and functions |
| `supabase/functions/` | Edge Functions (call start, answer and end) |
| `supabase/tests/database/` | Database tests |
| `supabase/seed.sql` | Local test data |
| `.claude/` | Product specs, designs and tickets |

Release builds and `supabase db push` target the owner's hosted Supabase project. To host your own copy, create a Supabase project, run `supabase link` and `supabase db push`, and put your project's URL and anon key in the Release build settings.
