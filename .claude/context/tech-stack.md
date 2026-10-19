# buttercup: recommended tech stack

Written 2026-10-18. Scope: v1 is a private 1:1 app for Adam and his partner, installed with TestFlight or Xcode on a paid Apple Developer account. Group calls and other users come later, so nothing here should block them. Items marked *(inferred)* come from general knowledge and weren't re-checked against a current source.

## The pick in one table

| Layer | Pick | Why |
|---|---|---|
| Face tracking (iPhone) | **ARKit face tracking**, with Vision as a fallback | 3D head pose, face mesh and 52 expression blendshapes, which hats and masks need |
| Face tracking (Mac) | **Vision** face landmarks | ARKit face tracking doesn't exist on macOS |
| Rendering effects | **RealityKit offscreen** for 3D, **Core Image / Metal** for 2D stickers | SceneKit is deprecated as of WWDC25 *(inferred)* |
| App | **Swift 6 + SwiftUI**, one multiplatform Xcode project, shared Swift package | One codebase for iPhone and Mac |
| Ringing | **CallKit + PushKit (VoIP push)** on iPhone | Required for a real incoming-call screen |
| Call media | **LiveKit** (Swift SDK), on **LiveKit Cloud's free plan** to start | No TURN or media server to run, group calls work later, open source so you can self-host |
| Backend | **Supabase**: Auth, Postgres, Edge Functions, Realtime | Mints call tokens, sends VoIP pushes, stores device tokens. Free |
| Cost | **$99/yr** Apple Developer, everything else $0 at two people | |

## 1. Face tracking: ARKit on iPhone, Vision on Mac

**iPhone: ARKit (`ARFaceTrackingConfiguration`).** It gives a face anchor with a full 3D transform, a 1,220-vertex face mesh and expression blendshapes (blink, smile, jaw open). That's what makes a hat sit on the head when you turn, or a mask wrap the face. It runs on the front camera of A12 chips and newer; Face ID iPhones get better depth from TrueDepth *(inferred)*. Any iPhone that runs iOS 18 qualifies.

**The key design choice:** let ARKit own the front camera. Don't run a separate `AVCaptureSession`. Each `ARFrame` gives you the camera image (`capturedImage`) plus the face anchor. You draw the effects on top of that image and send the result as the outgoing video. The other person sees the stickers because they're baked into the pixels, and their app needs no effect code at all.

**Pipeline per frame:**
1. `ARSession` delivers `ARFrame` (camera image + face anchor), 30 or 60 fps.
2. Render the camera image plus effects offscreen into a `CVPixelBuffer`:
   - 2D stickers: project anchor points to screen space, composite PNGs with Core Image or Metal. Start here.
   - 3D hats and masks: RealityKit's offscreen `RealityRenderer`, with the virtual camera matched to ARKit's camera intrinsics *(inferred: confirm the API on iOS 18+)*. Metal by hand is the fallback.
3. Show the same buffer as your own preview, and push it into the call (LiveKit `BufferCapturer.capture(pixelBuffer, timeStampNs:, rotation:)`).

**Vision as the fallback.** Vision's face landmarks (`DetectFaceLandmarksRequest`, the Swift-native API since iOS 18) work on any camera frame on iPhone and Mac. It gives 2D landmarks plus roll, yaw and pitch. That's plenty for 2D stickers that follow the face, but not for a mask that wraps the face in 3D.

**Mac reality check.**
- No ARKit face tracking on macOS. Use Vision on frames from an `AVCaptureSession` (built-in camera or Continuity Camera). 2D stickers work well. 3D hats can be approximated from head angles; full masks won't look as good as on iPhone.
- CallKit and VoIP push don't give a Mac a phone-style ringing screen *(inferred)*. Ring the Mac with an ordinary notification, or treat the Mac as "join from here" only.
- **Recommendation:** build iPhone first. Add the Mac target once calls and stickers work on iPhone. The shared Swift package keeps that cheap.

## 2. App: Swift + SwiftUI, one project

- **Swift 6, SwiftUI**, one multiplatform Xcode project with an iOS target and (later) a macOS target.
- A local Swift package, say `ButtercupKit`, holds the call logic, backend client and 2D effect code shared by both.
- Platform-specific pieces live in the targets: ARKit, CallKit and PushKit in iOS; Vision camera pipeline in macOS.
- **Minimum iOS 26** (decided 2026-10-19). Both phones run it, WidgetKit push needs it, and it covers everything iOS 18 brought (camera in Picture-in-Picture, the Swift Vision API). See technical-spec.md.
- Install: TestFlight internal testing (up to 100 people on your team, no App Review) or straight from Xcode. The paid account is required anyway for PushKit and CallKit.

## 3. Calls: LiveKit

**Recommendation: LiveKit Swift SDK, LiveKit Cloud free plan to start.**

Why not raw WebRTC peer to peer? It's free per minute, but you'd write signaling, ICE handling, reconnection, network switching (Wi-Fi to cellular) and run a TURN server for networks that block direct connections. That's a lot of plumbing before the first sticker works, and it all has to be redone for group calls.

Why not Agora? Proprietary, priced per minute with video tiers, and you can't self-host. Nothing it does beats LiveKit for this app.

What LiveKit gives you:
- Media server, TURN and reconnection handled.
- Custom video frames: `LocalVideoTrack.createBufferTrack` + `BufferCapturer` takes your rendered `CVPixelBuffer`s, which is exactly the pipeline above ([docs](https://mintlify.wiki/livekit/client-sdk-swift/api/capturers/custom-capturer)).
- Group calls later with no redesign; it's an SFU already.
- Open source server, so you can leave the cloud for your own.

**Free plan limits, and the honest math** ([LiveKit pricing](https://livekit.com/pricing.md)): 5,000 participant minutes and 50 GB downstream per month, no card required.
- A 1:1 call uses 2 participant minutes per minute, so 5,000 is about 41 hours of calls a month.
- Bandwidth is the tighter limit. At 720p (~1.5 Mbps per stream) each call minute downloads about 22 MB across both of you, so 50 GB is roughly **35 to 40 hours of 720p calls a month** *(inferred estimate)*.
- That's about an hour a day. If you call longer than that, two cheap ways out: drop to 540p, or **self-host LiveKit on a small VPS** (around €5/month) for unlimited minutes. The app only changes its server URL. The paid cloud plan starts at $50/month, which is poor value for two people.

## 4. Backend: Supabase

**What the backend has to do for v1:**
1. Know who's who and store each phone's VoIP push token.
2. Mint a LiveKit access token for each person (needs the LiveKit API secret, so it can't live in the app).
3. Send the VoIP push that makes the other phone ring (needs your APNs `.p8` key).
4. Pass "declined / cancelled / ended" while the call is ringing.

**Supabase covers all four on the free plan:**
- **Auth:** Sign in with Apple for now. Supabase supports phone-number OTP via Twilio when you open up to others, which matches the phone-number identity plan.
- **Pairing:** after signing in, one of you shares a one-time invite link and the other opens it to pair the two accounts as partners. The same flow works for adding friends later.
- **Postgres:** `profiles` (user id, phone number, display name) and `devices` (user id, VoIP token, APNs environment). Row-level security keeps it locked down.
- **Edge Functions** (TypeScript/Deno):
  - `start-call`: creates a room name, mints LiveKit tokens for both people, sends the VoIP push straight to APNs with the room and caller in the payload.
  - `end-call`: sends a cancel so the other phone stops ringing.
  - Hobby lookups: proxy TMDB (TV shows) and IGDB (games, via a Twitch developer account) so their keys and secrets never ship in the app. See hobby-tracker-spec.md.
- **Realtime:** a broadcast channel per call for ringing / declined / ended while both apps are open.

**One catch:** free Supabase projects pause after about 7 days with little activity, with an email warning first ([Supabase docs](https://supabase.com/docs/guides/platform/free-project-pausing.md)). Calling each other most days keeps it awake. If it pauses, you resume it in the dashboard with data intact. A scheduled ping or the $25/month Pro plan removes the risk.

**Why not Firebase:** Firebase Cloud Messaging can't send PushKit VoIP pushes, so you'd call APNs directly anyway, and Cloud Functions need the pay-as-you-go Blaze plan with a card on file *(inferred)*. Its main advantage disappears.

**Why not a hand-written server:** it works, but you'd host it, secure it and keep it running. Supabase is the same three endpoints with auth and a database already attached.

## 5. Build order

1. Xcode project, Supabase project, LiveKit Cloud project, APNs key.
2. Video call between the two phones with LiveKit, joined from a button (no ringing yet).
3. ARKit camera feeding LiveKit through `BufferCapturer`, plain video first.
4. 2D face stickers burned into the frames.
5. Ringing: PushKit + CallKit + `start-call` / `end-call` functions.
6. 3D hats and masks with RealityKit.
7. Picture-in-Picture with camera in the background.
8. Mac app with Vision stickers.

## 6. What changes when you go public

- Swap Sign in with Apple for phone OTP (Supabase + Twilio Verify), add rate limits against SMS fraud.
- Contact discovery, report/block, account deletion, App Review (see ios-limits.md §5 and §6).
- Group calls: same LiveKit rooms with more people. Expect to move to self-hosted LiveKit or a paid plan.

## 7. Extra features: daily photo widget and shared reading

Added 2026-10-18 after Adam asked about a Locket-style photo widget and sharing reading progress from Apple Books or Goodreads.

### Daily photo widget: fully doable with the same stack

- **Sending:** take or pick a photo in buttercup, downscale it (around 1000 px on the long side), upload to **Supabase Storage** (1 GB free is years of daily photos at that size), and write a row with the sender and timestamp.
- **Receiving:** a **WidgetKit** widget on the home and lock screen shows the partner's latest photo. Its timeline provider fetches the newest photo from Supabase and caches it in an App Group container.
- **Making it update right away:** the `send-photo` Edge Function sends a **WidgetKit push** (`apns-push-type: widgets`, iOS 26+), which tells iOS to reload the widget ([Apple docs](https://developer.apple.com/tutorials/data/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications.md)). iOS budgets these and delivers them "opportunistically", so a photo a day is fine but a burst of ten might lag. Also send a normal notification with the photo attached so it's never missed.
- **Watch out:** widgets have a small memory limit, so always store and show the downscaled image, never the original *(inferred)*.

### Reading progress: no API from Apple Books or Goodreads

- **Goodreads:** closed its API to new developers in December 2020 and disabled existing keys ([Infodocket](https://www.infodocket.com/2020/12/13/report-goodreads-plans-to-retire-api-access-disables-existing-api-keys/)). Not an option.
- **Apple Books on iPhone:** no public API for the current book, chapter, progress or reading goals. Its Shortcuts actions open books and turn pages but don't report progress ([Matthew Cassinelli's list](https://matthewcassinelli.com/apps/books/)). No other app on iPhone can read Books' data.
- **Apple Books on Mac:** Books keeps its library and reading progress in local SQLite files, which tools like [apple-books-mcp](https://www.producthunt.com/products/apple-books-mcp) read directly. A small Mac helper (outside the App Store sandbox) could read the current book and percentage and post it to Supabase. It's undocumented, so a macOS update can break it, it only works if your phone's progress syncs to the Mac through iCloud, and it likely gives a percentage rather than a chapter name *(inferred)*.

**Recommendation:** make logging a one-tap thing inside buttercup instead of scraping Books.
- An **interactive widget** with "I read today" and a chapter +1 button, plus each other's current book and chapter.
- **App Intents** so "Log progress" works from Siri, Shortcuts and the Action button.
- **A Shortcuts automation** on each phone: "When Books is closed, run buttercup's Log progress". You finish reading, close Books, and buttercup asks "Read today? Which chapter?" with one tap to confirm. That's the closest thing to automatic iOS allows.
- **Book details** (cover, title, chapter count) from a free book database such as Open Library, so you only search the book once.
- The Mac Books helper can come later as a bonus if you read on a Mac.

## Sources
- [LiveKit Cloud pricing](https://livekit.com/pricing.md)
- [LiveKit quotas and limits](https://docs.livekit.io/home/cloud/quotas-and-limits/)
- [LiveKit Swift SDK: custom capturer](https://mintlify.wiki/livekit/client-sdk-swift/api/capturers/custom-capturer)
- [Supabase: free project pausing](https://supabase.com/docs/guides/platform/free-project-pausing.md)
- [Apple: WidgetKit push notifications](https://developer.apple.com/tutorials/data/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications.md)
- [Infodocket: Goodreads retires its API](https://www.infodocket.com/2020/12/13/report-goodreads-plans-to-retire-api-access-disables-existing-api-keys/)
- [Apple Books shortcuts](https://matthewcassinelli.com/apps/books/)
- Earlier findings: [ios-limits.md](ios-limits.md)
