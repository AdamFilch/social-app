# buttercup: what iOS won't let you do

Researched 2026-10-18 against iOS 26. Items marked *(inferred)* are from general knowledge of Apple's rules and weren't re-checked against a current source.

## The short version

Your app can be a full WhatsApp-style calling app. It can ring like a real phone call, find friends by phone number, and add face stickers to **its own** calls. Here's what it can't do:

1. **It can't use your carrier line.** Calls go over the internet (VoIP). The phone number only works as a username you prove you own.
2. **It can't touch FaceTime, Phone, WhatsApp or Zoom calls.** No API on iOS lets you put stickers into another app's video.
3. **It can only call people who also have buttercup**, unless you pay for a phone-network gateway.
4. **It has to obey strict rules for incoming calls** (CallKit + VoIP push), and CallKit isn't allowed in China.
5. **The camera only keeps running in the background under certain conditions**, and the app gets limited processing power there.
6. **Contacts are opt-in and can be partial.** Uploading address books brings privacy and App Store obligations.

## 1. Phone numbers: identity, not a phone line

- **You can't read the phone's own number.** iOS has no API for it. `CTCarrier` is deprecated and has returned placeholder values since iOS 16 *(inferred)*. The user types their number and you verify it by SMS code. That's what WhatsApp, Signal and Telegram do.
- **SMS verification is a cost and a fraud risk.** You pay a provider such as Twilio Verify, Firebase Phone Auth or Vonage for each code. "SMS pumping" fraud can run up big bills, so add rate limits and fraud checks from day one.
- **Calls don't go out over the cellular network**, and the caller ID isn't your carrier number. buttercup calls are internet calls between two buttercup apps.
- **Calling people who don't have the app** requires a PSTN gateway (Twilio Voice, Vonage, etc.). You'd pay per minute, it's audio only, and showing the user's own number as caller ID needs separate verification. Leave this out of v1.
- **Emergency calls** stay with the system dialer. A VoIP app can't be relied on for 911/112 and shouldn't try *(inferred)*.

## 2. FaceTime and other apps' calls are off-limits

- **You can't add effects to FaceTime, WhatsApp, Zoom or Phone calls.** iOS has no system virtual camera and no way to inject video into another app's capture. On the Mac, "camera extensions" (CoreMediaIO) can do this, which is how Snap Camera worked. Nothing like that exists on iOS. Stickers only work inside buttercup's own calls.
- **There's still an opening.** Apple removed the whole FaceTime Effects menu in iOS 26: Memoji swaps, filters, stickers, captions and shapes are all gone, and Apple hasn't said why ([SlashGear](https://www.slashgear.com/1982974/apple-got-rid-of-facetime-camera-effects-ios-26)). Nothing on iOS fills that gap, so it's a real selling point for buttercup.
- **You can't use Apple's Memoji avatars** in your app. There's no public API for them *(inferred)*. Build your own sticker and avatar assets.
- **You can't replace FaceTime, but you can sit next to it.** Since iOS 18.2, users anywhere can pick a **default calling app**. Tapping a phone number in Contacts or Safari then opens buttercup instead of Phone. You need the `com.apple.developer.calling-app` entitlement, the `voip` background mode, and CallKit or LiveCommunicationKit. If the other person doesn't have buttercup, you can hand the call back to the system with the `telephony:` URL ([Apple docs](https://developer.apple.com/documentation/callkit/preparing-your-app-to-be-the-default-calling-app), [Apple support](https://support.apple.com/en-asia/121430)).
- **You can't intercept, record or read ordinary phone calls or the carrier call history.** Recording buttercup's own calls is technically possible but brings consent laws into play.

## 3. Ringing like a real call: CallKit + PushKit rules

- **Incoming calls arrive as a VoIP push (PushKit)**, which wakes the app even when it's closed. Every VoIP push must be reported to CallKit as an incoming call right away. If you don't, iOS kills the app and, after repeated misses, stops delivering your VoIP pushes. VoIP pushes can't be used for chat messages or anything else.
- **You get the native call screen** on the lock screen, plus Recents integration, Bluetooth/CarPlay, and Do Not Disturb/Focus behavior. LiveCommunicationKit is Apple's newer alternative.
- **China:** apps that use CallKit have been refused on the China App Store since 2018, under regulator rules. Shipping there would mean removing CallKit for that region *(inferred: confirm before launching there)*.
- **You need your own servers no matter what:** signaling, push delivery, TURN relays for networks that block direct connections, and an SFU media server for group calls. Peer-to-peer only works well for 1:1 calls. None of this is an iOS limit, but it's the biggest running cost.

## 4. Camera, mic and the background

- **By default iOS cuts the camera when the app goes to the background.** The other person sees a frozen picture or nothing.
- **Exception:** apps built for iOS 18+ that declare the `voip` background mode as video-conferencing apps can keep the camera running while in Picture-in-Picture (`isMultitaskingCameraAccessSupported`). Apple can also grant the `multitasking-camera-access` entitlement on request ([Stream docs](https://getstream.io/video/docs/ios/advanced/background-modes/)). So you'll need to support PiP properly.
- **Audio stays alive in the background** with the right background modes. Without them, iOS mutes the call.
- **Face tracking and stickers in the background** are allowed in principle, but heat and battery limits will hurt. Expect to lower the frame rate or drop effects while in PiP *(inferred)*.
- **The green and orange camera/mic dots always show.** You can't hide them or record without the user knowing.

## 5. Contacts and "who's on buttercup"

- **Users can share only some contacts.** iOS 18 added *limited* contacts access, and many users will pick a few or none. Apple's `ContactAccessButton` lets them add people one at a time ([Apple docs](https://developer.apple.com/documentation/contactsui/contactaccessbutton), [WWDC24](https://developer.apple.com/videos/play/wwdc2024/10121/)). Plan for typing a number manually and for invite links.
- **Contact discovery means sending phone numbers to your server.** Hashing doesn't really protect them, since all phone numbers can be brute-forced. Say clearly in your privacy policy and App Privacy label what you upload. Consider Signal-style private matching later.
- **You can't use contacts for spam.** You can't text or invite contacts automatically, and you can't keep or sell other people's data (App Review 5.1.1/5.1.2) *(inferred section numbers)*.

## 6. App Store review checklist

- **Account deletion inside the app** is required for any app with accounts.
- **Calls and stickers count as user-generated content.** Users must be able to report and block, and you need moderation of abuse (Guideline 1.2) *(inferred)*.
- **Privacy labels plus purpose strings** for camera, microphone, contacts and notifications. A permission request without a clear reason gets rejected.
- **Don't use Apple names or look-alike branding** ("FaceTime", Memoji style, Apple icons).
- **Encryption export compliance:** standard WebRTC/TLS encryption is usually covered by the exemption, but you still answer the questions.
- **Age rating:** a video app that lets you call strangers by number likely rates 13+ or higher under Apple's newer age-rating tiers *(inferred)*.

## 7. Notes for the face-sticker thread

- Apple's **Vision** framework (face landmarks) runs on every supported iPhone. ARKit face tracking needs an A12 chip or newer and gives full 3D head pose. Either one works with your own WebRTC camera pipeline, but the stickers have to be drawn into the video frames before they're encoded so the other side sees them.
- Running ARKit and a separate `AVCaptureSession` on the same front camera at the same time is awkward. Take ARKit's frames, or use Vision on your own capture frames.

## Sources
- [Apple: Preparing your app to be the default calling app](https://developer.apple.com/documentation/callkit/preparing-your-app-to-be-the-default-calling-app)
- [Apple Support: Change your default apps](https://support.apple.com/en-asia/121430)
- [SlashGear: Apple removed FaceTime effects in iOS 26](https://www.slashgear.com/1982974/apple-got-rid-of-facetime-camera-effects-ios-26)
- [Stream: iOS background modes and multitasking camera](https://getstream.io/video/docs/ios/advanced/background-modes/)
- [Apple: ContactAccessButton](https://developer.apple.com/documentation/contactsui/contactaccessbutton)
- [WWDC24: Meet the Contact Access Button](https://developer.apple.com/videos/play/wwdc2024/10121/)
- [Apple Developer Forums: PushKit](https://developer.apple.com/forums/tags/pushkit)
