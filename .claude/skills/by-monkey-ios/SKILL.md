---
name: by-monkey-ios
description: Conventions for by_monkey's character assets (portrait + frames folders) and the build-only verification workflow after Swift code changes. Use whenever adding/reading character art in Assets.xcassets or after editing Swift code in this project.
---

# by_monkey iOS conventions

## Character asset layout (Assets.xcassets)

Each character is a top-level folder (e.g. `player`, `boss`, `yuki`) that can contain:

- **`<name>.imageset`** — the character's static portrait (立繪), used as the default/idle image. Every character has at least this.
- **`frames/<action>/`** — optional. Holds a numbered image sequence for an animated action, e.g. `frames/talk/talk_0` … `talk_3`, `frames/walk_left/left_0` … `left_7`. Frame count per action is typically 1–8 but is **not fixed** — enumerate the actual `.imageset` entries under `frames/<action>/` instead of hardcoding a count.

Not every character currently has a `frames` folder (`boss` and `yuki` only have static imagesets today). When adding animation for one of them, follow the same pattern: `frames/<action>/<action>_<n>.imageset`.

When writing animation code (e.g. building a `UIImage` array for `UIImageView.animationImages`), derive the frame list from what's actually in `Assets.xcassets/<character>/frames/<action>/` rather than assuming 8 frames always exist.

## Build-only verification after code changes

After modifying Swift code, verify it compiles. Do **not** boot/launch the iOS Simulator app or run the app — just build:

```
xcodebuild -project by_monkey.xcodeproj -scheme by_monkey -destination 'generic/platform=iOS Simulator' build
```

This compiles the `by_monkey` scheme for the simulator SDK without booting any simulator device.
