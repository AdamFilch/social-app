# Video calls with face effects spec

Oct 19, 2026 · @Adam

buttercup calls ring like a real phone call, and stickers, hats and masks follow your face and are baked into the video your partner sees. FaceTime removed its effects in iOS 26, so nothing built into the iPhone does this anymore. The face effects and call features below were settled with Adam on 19 October 2026 (see [decisions.md](decisions.md)).

## Calls

- **1:1 audio and video calls** between the two of you in v1. Group calls come later on the same setup.
- **Two call buttons:** audio and video. You can turn your camera on or off during any call; turning it on starts ARKit and the face effects, and turning it off drops back to audio.
- **Missed calls:** the caller gets a missed-call notification, and the app keeps a simple call history for both of you. No voicemail. CallKit also adds calls to the iPhone's Recents.
- **Ringing:** the native incoming-call screen, even on the lock screen, using CallKit and VoIP push. It shows in Recents and works with Bluetooth, CarPlay and Focus modes.
- **Picture-in-Picture:** the call keeps going with your camera on when you switch apps (iOS 18+).
- **Phone number:** used as an identity, not a phone line. Calls only go between buttercup apps over the internet. v1 signs in with Apple; phone-number sign-in comes when the app opens to others.

## Face effects

- **Pinned to one point:** everything you add sticks to the spot you drop it on (forehead, cheek, nose) and moves and tilts with your head.
- **Stickers, emoji and text:** pick one from a tray or type text, then drag it onto your face in your own preview.
- **Drawing on a pad:** you draw on a still pad, and the drawing becomes a sticker you drag onto your face. Drawing live on your moving face was dropped because it's hard to aim and hard to make sit right. Drawing itself is cheap for the phone.
- **Flat glasses and hats:** flat images that follow your head's position and turn, not full 3D models. Real 3D items can come later.
- **Editable text on items:** hats and signs have a text area you can change, like a dunce cap that says whatever you type. Every item, signs included, always follows your face; nothing tracks your hands.
- **Filters:** colour looks over the whole video, and face-only changes such as face paint or blush drawn onto the face.
- **One face in v1:** effects go on one face. Supporting two people in front of one phone is more work, not less, because every item has to know whose face it belongs to.
- **Cleared after every call:** nothing is saved between calls.
- **Baked into the video:** effects are drawn onto your outgoing video, so your partner sees them without needing any effect code.
- **In Picture-in-Picture:** effects drop to 2D stickers, or turn off, because the face tracker can't run in the background.
- **When the phone gets hot:** filters and extra items step down first, and at critical heat effects switch off so the call stays smooth.

**Removing a sticker:** tap any sticker on your face, yours or your partner's, and a trash button appears at the bottom middle of the screen to remove it.

## Stickers from your partner (later)

Your partner can put stickers on your face, and it's a moderate add-on that reuses the sticker system. They tap a spot on your face in their view of the call. Their app sends the sticker and its position relative to your face over the call's data channel, and your phone draws it like one of your own, so it's baked into your video too. A setting decides whether your partner's stickers appear straight away or wait for your approval. It comes after your own stickers and flat items work.

## Voice changer (later)

Voice effects on your outgoing audio come after v1, once calls and face effects work and heat has been tested on the iPhone 11.

## Assets

Adam collects stickers, glasses, hats, signs and filters from free libraries in the **assets** folder inside the buttercup project folder on his Mac. Its README lists the formats: transparent PNGs for stickers and flat items, an optional note per hat or sign saying where the editable text goes, and a sources.md recording where each asset came from.

## Phones

You both have an iPhone 11 (A13 chip, TrueDepth camera, 2019). It runs ARKit face tracking, but it's the oldest phone that gets iOS 26 and the most likely to heat up. Flat items help here: they're far lighter than 3D models. Calls run at 30 fps and 720p, and a 30-minute test call on both phones comes before building hats and filters.

## Mac, later

- A Mac app with 2D stickers. Masks won't look as good there because the Mac has no ARKit face tracking.
- The Mac can't show a phone-style ringing screen, so it rings with a normal notification or just joins calls.

## How it's built

| Part | Choice |
| --- | --- |
| Face tracking (iPhone) | ARKit at 30 fps, 720p; Vision in Picture-in-Picture |
| Face tracking (Mac) | Vision face landmarks |
| Drawing effects | Core Image or Metal for stickers, text, flat hats and filters; RealityKit only if real 3D items come later |
| Call media | LiveKit Swift SDK on LiveKit Cloud's free plan, about 35 to 40 hours of 720p calls a month |
| Ringing | CallKit + PushKit, pushes sent by a Supabase Edge Function |
| Backend | Supabase: Sign in with Apple, call tokens, device tokens |

If calls go past the free plan, self-host LiveKit on a small server for about €5 a month. Full reasoning is in tech-stack.md, face-tracking-options.md and ios-limits.md in the project files.

## Build order

1. Audio and video call between the two phones, joined from a button, with the camera switchable during the call.
2. ARKit camera feeding the call, plain video first.
3. Emoji, text and image stickers first, then the drawing pad, pinned to your face and baked into the video.
4. A 30-minute test call on both iPhone 11s to check heat.
5. Ringing with CallKit and VoIP push.
6. Flat glasses and hats, with editable text on hats and signs.
7. Filters: whole-video colour looks, then face paint.
8. Stickers from your partner.
9. Picture-in-Picture with the camera on.
10. Mac app with 2D stickers.
11. Voice changer.

## Open questions

None right now. Calls and face effects are settled.
