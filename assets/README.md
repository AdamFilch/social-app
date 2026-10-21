# buttercup assets

Drop face-effect assets here. The app bundles everything in this folder.

| Folder | What goes in it | Format |
|---|---|---|
| stickers/ | Emoji, stickers, any flat image you pin to your face | PNG with transparent background, about 512 px |
| glasses/ | Flat glasses, front view | PNG, transparent, about 1024 px wide |
| hats/ | Flat hats, front view (dunce cap, party hat, crown) | PNG, transparent, about 1024 px |
| signs/ | Signs or banners that show text you type | PNG, transparent, about 1024 px |
| face-paint/ | Paint, freckles, blush drawn onto the face | PNG drawn on the ARKit face texture template (added later) |

For a hat or sign with editable text, add a file next to the image with the same name ending in `.txt` that says where the text goes, for example `dunce-cap.txt`:

```
text area: middle of the cone
default text: DUNCE
```

A rough description is fine; the exact box gets set when it's built.

Keep a note of where each asset came from and its licence in `sources.md` (free for personal use is fine for now; it matters only if the app goes public).
