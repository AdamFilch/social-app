# buttercup: face tracking, how heavy it is and what else exists

Written 2026-10-19. Answers Adam's question: will ARKit/Vision face tracking be heavy on the phone during a call, and are there better options? Items marked *(inferred)* come from general knowledge and weren't confirmed against a current source.

## Short answer

**Keep ARKit on iPhone and Vision on Mac.** Nothing else is faster on an iPhone, and the alternatives either cost money, add watermarks, or come with strings attached. Face tracking is not the expensive part of a video call; the camera, video encoding and network are. Done carefully, tracking plus stickers should add a modest slice on top of what any video call already costs *(inferred)*.

One adjustment to tech-stack.md: ARKit can't keep running when the app is in Picture-in-Picture, so the app should switch to a plain camera (with Vision 2D stickers or no stickers) while in the background. Details below.

## 1. How heavy is ARKit face tracking?

**Where the cost actually goes in a call** *(inferred, typical for any iPhone video app)*:

| Part | Cost |
|---|---|
| Front camera running | Moderate, same for every option |
| H.264/HEVC encode and decode | Done by dedicated hardware, cheap |
| Network (Wi-Fi or cellular radio) | Significant, especially on cellular |
| Screen on at brightness | Significant |
| Face tracking (ARKit) | Runs on the Neural Engine and TrueDepth sensor, built for this. Small to moderate |
| Drawing stickers | 2D: tiny. 3D hats/masks with RealityKit: moderate, depends on the model |

So a buttercup call will drain roughly like a FaceTime call, plus some extra for tracking and 3D rendering. FaceTime itself uses the same face tracking for Memoji, which is a fair sign Apple tuned it for calls.

**Speed and latency.** ARKit delivers the camera image and the face position in the same `ARFrame`, so the sticker is drawn on the exact frame it was measured from. There's no visible lag between your face and the sticker. Tracking adds a few milliseconds per frame, which is invisible next to the 100 to 300 ms of normal network delay in any call *(inferred)*.

**Heat.** Long video calls warm every iPhone, with or without effects. The risk is that after 20 to 40 minutes iOS throttles the chip and the frame rate drops *(inferred)*. Mitigations that are easy to build in from day one:

- **Run ARKit at 30 fps, not 60.** Apple's own engineer says the video format is the biggest battery lever ([Apple Developer Forums](https://developer.apple.com/forums/thread/704304)). 30 fps is normal for calls anyway.
- **Turn off what you don't use:** light estimation, world tracking, person segmentation ([same thread](https://developer.apple.com/forums/thread/704304)).
- **Send 720p, not 1080p.** Matches the LiveKit free-plan math in tech-stack.md.
- **Watch `ProcessInfo.thermalState`.** At `.serious`, drop 3D items to 2D or lower the frame rate; at `.critical`, turn effects off. Users rarely notice, and the call stays smooth.
- **Pause tracking when no sticker is on.** Use the plain camera when effects are off.

**Vision on its own** is lighter than ARKit only if you run it on fewer frames (say every 2nd or 3rd frame and smooth in between). It gives 2D points and head angles, not a 3D mesh, so it's the fallback, not the main path. Old reports of 3 to 16 fps ([Apple forums, 2017](https://developer.apple.com/forums/thread/92048)) were on iPhone 6-era hardware and don't apply to current chips.

## 2. The PiP catch

iOS 18+ lets video-calling apps keep the camera on in Picture-in-Picture, but that switch (`isMultitaskingCameraAccessEnabled`) lives on `AVCaptureSession`, not on ARKit's session. ARKit's session is interrupted when the app leaves the foreground *(inferred)*. So:

- **Foreground:** ARKit owns the camera, full 2D and 3D effects.
- **Background / PiP:** switch to an `AVCaptureSession`, keep sending video, and either run Vision for 2D stickers at a low rate or send plain video. ios-limits.md §4 already expects effects to be reduced in PiP.

This is the one real change to the plan, and it's cheap because the sticker drawing code is shared.

## 3. Alternatives, judged

| Option | Speed on iPhone | Cost for 2 people | 3D hats/masks | Mac | Fit with stack | Verdict |
|---|---|---|---|---|---|---|
| **ARKit** (current pick) | Best; uses TrueDepth + Neural Engine | Free | Yes: 3D pose, 1,220-point mesh, 52 blendshapes | No | Native Swift, frames straight into LiveKit | **Keep for iPhone** |
| **Vision** (current Mac pick) | Good | Free | 2D only, head angles for fake 3D | Yes | Native | **Keep for Mac and PiP** |
| **Google MediaPipe Face Landmarker** | Good, GPU-accelerated, but plain camera only (no depth) | Free, open source (Apache 2.0) | Yes: 478 3D points, 52 blendshapes, face transform matrix ([Google docs](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/ios)) | iOS package doesn't list macOS ([docs](https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/ios)) | Swift Package, works on any `AVCaptureSession` frame | **Best backup.** Use if Vision isn't good enough for hats on Mac or in PiP |
| **Snap Camera Kit** | Very good, polished tracking | Snap says it doesn't plan to charge ([Snap community](https://community.snap.com/snapar/discussion/comment/4020)) | Yes, best-looking; you design in Lens Studio | No; iOS, Android, Web ([Snap docs](https://developers.snap.com/camera-kit/home)) | Heavy SDK; replaces your effect code | **Skip.** Needs Snap app approval, Snap branding, users must accept Snap's terms, and you must publish most of your Lenses on Snapchat too ([Camera Kit terms](https://www.snap.com/terms/snap-camera-kit?lang=da-DK)). Too many strings for a private app |
| **DeepAR** | Good | Free up to 10 users but **watermarked**; $25/month to remove it ([DeepAR pricing](https://docs.deepar.ai/deepar-sdk/pricing)) | Yes, with its own effect editor | Has a macOS SDK *(inferred)* | Ready-made effects, less control | **Skip** unless you'd rather buy effects than build them |
| **Banuba Face AR** | Good | Custom quote, yearly billing, 14-day trial only ([Banuba pricing](https://www.banuba.com/banuba-pricing-face-ar-sdk)) | Yes | Yes | Enterprise-oriented | **Skip.** Priced for companies |
| **TikTok Effect House** | n/a | n/a | n/a | n/a | Only makes effects for TikTok, not an SDK | **Not an option** |
| **LiveKit video processing** | n/a | Free | n/a | Yes | A hook to modify frames, not a face tracker *(inferred: Swift SDK has a `VideoProcessor` hook)* | **Use alongside**, not instead. The `BufferCapturer` path in tech-stack.md already covers it |

## 4. Why ARKit still wins on iPhone

- **It's the only option that uses the TrueDepth depth sensor.** MediaPipe, DeepAR and Banuba guess depth from a flat image. Masks sit more firmly with real depth *(inferred)*.
- **It's free, has no watermark, no approval, and no third-party terms.**
- **It's what Apple uses for Memoji in FaceTime,** so it's tuned for exactly this situation.
- **No extra SDK** bloating the app or adding its own camera handling to fight with LiveKit.

When to reconsider: if you later want Android partners, or want identical 3D quality on Mac, swap in **MediaPipe** behind the same "face tracker" interface. Keep the sticker renderer independent of the tracker so this swap stays cheap.

## 5. Practical checklist for the build

1. Wrap tracking in a small `FaceTracker` protocol (ARKit implementation on iPhone, Vision on Mac and PiP).
2. ARKit at 30 fps, 720p, light estimation off.
3. React to `thermalState` and Low Power Mode by stepping effects down.
4. Switch to `AVCaptureSession` + Vision when entering PiP.
5. Test a 30-minute call on both phones early, before building 3D items, to see real heat.
