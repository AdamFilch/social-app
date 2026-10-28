# [14]: Note Photo mode

**Depends on:** [10] Note Draw tab merged ([11]–[13] are not required).

This ticket makes the camera side of the toggle work. The live camera fills the note square, and you pinch to zoom. Under it sit only flash, a big shutter and flip. Take the shot and the photo becomes the note's background: the camera controls fade out, the tab row fades in, and every drawing tool works on top of the photo. Retake, top left, is grey until a photo exists and then turns red. With anything drawn on the photo it asks before throwing it away. If camera access is off, the square explains why and offers Open Settings.

## Summary
Adds `CameraView` (`AVCaptureSession` + preview layer, square crop, 1–5× zoom, mirroring), `CameraRow`, `RetakeButton` and `CameraBlockedView`. The photo is stored in `NoteDraft.photo` and drawn under the strokes. Adds `NSCameraUsageDescription`. No backend changes.

## Scope
**MVP**
- Photo mode before capture: viewfinder in the canvas square, and flash / shutter / flip centred on y 692. No tab row, Retake grey, Send disabled (spec §4.7).
- Camera choice remembered with `@AppStorage`. The back camera the very first time (A5).
- Flash off by default. Disabled on the front camera.
- Capture: square centre crop, mirrored for the front camera. The camera row cross-fades to the tab row (0.15 s), and Retake turns red.
- Retake: only the photo → straight back to the viewfinder. Anything on the photo → discard alert first ([9]).
- Denied → "Camera is off for buttercup" + Open Settings, rechecked on return to the foreground. No camera → "No camera available" (spec §4.9).
- Interrupted session → last frame at 40% until it resumes.
- The `OnDanger` light value #FFFDF5 for the red Retake (spec §12.3)

**Out of scope**
- Camera roll (D24)
- Front screen-flash

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| N1 | Device-only checks | The Simulator shows "No camera available". Capture, zoom, flip and flash go on a manual on-device checklist, and the ticket is filed `partial` until Adam runs it | The Simulator has no camera (same as D36 in [6]) | Claude — straightforward |
| N2 | Camera code | Plain AVFoundation, no library | Tech spec dependencies list | Claude — straightforward |

## End-to-End Flows
```
Toggle → camera ─ (first time) iOS prompt ─ allow ─► back camera viewfinder
Pinch ─► zoom ─ shutter ─► photo is background, tab row in, Retake red
Draw a heart on it ─ Retake ─► discard alert ─ Discard ─► viewfinder
Deny access ─► "Camera is off for buttercup" ─ Open Settings ─► Settings app
```

## File Reference
| File | Role |
|---|---|
| `Buttercup/Notes/CameraView.swift` | **new** session, preview, capture, zoom |
| `Buttercup/Notes/CameraRow.swift` | **new** flash, shutter, flip |
| `Buttercup/Notes/RetakeButton.swift` | **new** |
| `Buttercup/Notes/CameraBlockedView.swift` | **new** |
| `Buttercup/Info.plist` | `NSCameraUsageDescription` |
| `Buttercup/Assets.xcassets/OnDanger.colorset` | light value |

---

## Acceptance Criteria
- [ ] AC1: Simulator: Photo mode shows "No camera available" in the square, with flash, shutter and flip at 40%. The toggle still switches back to Draw.
- [ ] AC2: Simulator: switching modes with progress shows the discard alert. Without progress it doesn't.
- [ ] AC3 (device): The first time, the back camera opens. Afterwards, the last-used camera opens.
- [ ] AC4 (device): Pinch zooms between 1× and 5×. Flash toggles on the back camera and is disabled on the front.
- [ ] AC5 (device): After capture, the photo (square, mirrored on the front camera) fills the canvas, the tab row replaces the camera row, Retake is red, and drawing works on top.
- [ ] AC6 (device): Retake with only a photo has no alert. With a stroke on it, the alert shows first.
- [ ] AC7 (device): With access denied, the panel and Open Settings show. Turning access on in Settings and returning starts the viewfinder.
- [ ] AC8: The build check passes.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The preview crop and the saved crop differ | Med | The photo shifts after capture | Crop the capture to the same square as the preview layer's visible rect (`metadataOutputRectConverted`) |
| Session start blocks the main thread | Med | Toggle stutters | Start and stop the session on a background queue |

---
*Status: READY — ticket [14]*
