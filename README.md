# Tiny Keys

Tiny Keys is a minimal iPhone piano utility for quickly checking melodies by ear while Apple Music or another audio app keeps playing in the background.

## What it does

- launches straight into a minimal piano interface optimized for quick note checking
- keeps the main screen almost entirely dedicated to touchable keys
- supports multitouch chords and glissando-style dragging across keys
- uses a thin navigation strip above the keyboard to move the visible window across a larger note range
- lets the app orientation and keyboard orientation be configured independently in settings

## Audio mixing

Audio mixing is configured in [`TinyKeys/Audio/AudioSessionManager.swift`](./TinyKeys/Audio/AudioSessionManager.swift).

The app uses:

- `AVAudioSession` category `.playback`
- option `.mixWithOthers`
- `setActive(true)` during setup and re-activation

This is the key behavior that allows Tiny Keys to play on top of Apple Music instead of interrupting it.

## Where audio is configured

- Session setup: [`TinyKeys/Audio/AudioSessionManager.swift`](./TinyKeys/Audio/AudioSessionManager.swift)
- Audio engine and synth playback: [`TinyKeys/Audio/SynthEngine.swift`](./TinyKeys/Audio/SynthEngine.swift)

## Keyboard navigation

The keyboard itself is not a scroll view. Dragging on keys plays notes. Horizontal navigation happens only through the thin strip above the keyboard, implemented in [`TinyKeys/Keyboard/KeyboardNavigationStrip.swift`](./TinyKeys/Keyboard/KeyboardNavigationStrip.swift).

The visible keyboard width can be set with a `Visible Octaves` control at 1, 1.5, or 2 octaves. The default is 1.5 octaves.

## Orientation controls

Tiny Keys now separates the system app orientation from the keyboard’s own layout direction:

- `App Orientation`: portrait or landscape for the overall app chrome, safe areas, and home-indicator relationship
- `Keyboard Direction`: left landscape, portrait, or right landscape for the playable keyboard surface

The app-level orientation is managed in [`TinyKeys/App/OrientationController.swift`](./TinyKeys/App/OrientationController.swift) and wired into [`TinyKeys/App/TinyKeysAppDelegate.swift`](./TinyKeys/App/TinyKeysAppDelegate.swift). The keyboard’s independent rotation is applied in [`TinyKeys/App/MainKeyboardScreen.swift`](./TinyKeys/App/MainKeyboardScreen.swift).

## Build and run

1. Open [`TinyKeys.xcodeproj`](./TinyKeys.xcodeproj) in Xcode.
2. Select an iPhone simulator or a connected iPhone.
3. If running on your own iPhone, choose your Personal Team in Signing and Capabilities and use a unique bundle identifier.
4. Build and run.

Command-line simulator build:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project TinyKeys.xcodeproj \
  -scheme "Tiny Keys" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  build
```

Command-line device-SDK build without signing:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project TinyKeys.xcodeproj \
  -scheme "Tiny Keys" \
  -configuration Debug \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

## Real-device checks

These behaviors must be validated on a real iPhone:

- Apple Music keeps playing while Tiny Keys plays notes
- audio route changes and interruptions recover cleanly
- touch feel, latency, and glissando response are satisfactory on hardware
- app-orientation switching from settings behaves reliably on device
- rotated keyboard layouts feel correct in portrait and landscape app modes

The simulator can build and launch the app on a normal Xcode setup, but it is not a reliable way to validate real background audio mixing against Apple Music.

## Manual step that still requires you

If you want to run on a physical iPhone or submit to the App Store, you need to sign the app in Xcode. A paid Apple Developer Program account is only required for App Store distribution; a free Personal Team is enough to run the app on your own device for local testing.
