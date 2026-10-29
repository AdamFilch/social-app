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
- [x] AC1: Simulator: Photo mode shows "No camera available" in the square, with flash, shutter and flip at 40%. The toggle still switches back to Draw.
- [x] AC2: Simulator: switching modes with progress shows the discard alert. Without progress it doesn't.
- [ ] AC3 (device): The first time, the back camera opens. Afterwards, the last-used camera opens.
- [ ] AC4 (device): Pinch zooms between 1× and 5×. Flash toggles on the back camera and is disabled on the front.
- [ ] AC5 (device): After capture, the photo (square, mirrored on the front camera) fills the canvas, the tab row replaces the camera row, Retake is red, and drawing works on top.
- [ ] AC6 (device): Retake with only a photo has no alert. With a stroke on it, the alert shows first.
- [ ] AC7 (device): With access denied, the panel and Open Settings show. Turning access on in Settings and returning starts the viewfinder.
- [x] AC8: The build check passes.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The preview crop and the saved crop differ | Med | The photo shifts after capture | Crop the capture to the same square as the preview layer's visible rect (`metadataOutputRectConverted`) |
| Session start blocks the main thread | Med | Toggle stutters | Start and stop the session on a background queue |

---
*Status: PARTIAL — PR #12*

## Implementation Status
| AC | Status | Evidence / notes |
|---|---|---|
| AC1 | ✅ done | iPhone 17 simulator, light and dark: the square shows "No camera available"; flash, shutter and flip are at 40% and disabled; the toggle switches back to Draw at once |
| AC2 | ✅ done | A stroke in Draw, then the camera side: the discard alert shows; Keep editing keeps it; Discard opens Photo blank. With no progress the switch happens at once both ways |
| AC3 | ⚠️ unverified | The front/back choice is kept in `@AppStorage("noteCameraFront")` and survives a relaunch (checked on the simulator with the Debug stand-in). That the right lens opens needs a device |
| AC4 | ⚠️ unverified | Flash toggles Off/On on the back camera and is disabled (40%, "Off") on the front, checked on the simulator. Pinch zoom 1–5× needs a device |
| AC5 | ⚠️ unverified | With the Debug stand-in (`-notePhotoStub YES`, the test clip's first frame) the captured photo fills the canvas, the tab row replaces the camera row, Retake turns red and strokes draw on top, in light and dark. The real square crop and front-camera mirroring need a device |
| AC6 | ✅ done | With the stand-in: Retake with only a photo goes straight back to the viewfinder; with strokes on it the discard alert shows first and Discard returns to the viewfinder |
| AC7 | ⚠️ unverified | With access revoked (`simctl privacy revoke camera`), "Camera is off for buttercup", the line and Open Settings show in light and dark, and Open Settings opens Settings. Turning access on and returning can't be checked on the simulator: changing the permission ends the app |
| AC8 | ✅ done | `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeds with no new warnings |

### Needs attention
- Run the device checklist in the PR on an iPhone 11: the lens opened first and afterwards, pinch zoom, flash on the back camera, capture crop matching the preview, front-camera mirroring, Retake, the return from Settings, an interrupted session (a call or Siri) dimming the viewfinder to 40% until it resumes, and no haptic on the shutter.
