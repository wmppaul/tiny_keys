# Tiny Keys App Store Draft

This file collects draft App Store materials for Tiny Keys.

## App Information

- Name: `Tiny Keys`
- Subtitle: `Pocket Piano Keyboard`
- Bundle ID: `com.will.tinykeys`
- SKU suggestion: `tinykeys-ios-001`
- Primary category: `Music`
- Secondary category: `Utilities` (optional)

## App Icon

The current app icon has already been generated and added to the project.

- Source image currently used to generate the icon set: `/Users/will/Downloads/iconimage.png`
- Project icon assets:
  - `TinyKeys/Resources/AppIcons`
  - `TinyKeys/Assets.xcassets/AppIcon.appiconset`

## Screenshot Plan

Apple currently allows 1 to 10 screenshots per device size and says that if the UI is the same across device sizes, you can upload only the highest required iPhone size and let App Store Connect scale down. Draft the screenshots as landscape iPhone shots so the keyboard reads clearly.

Recommended set:

1. Default keyboard view
   - Show the app open directly on the keyboard.
   - Caption idea: `Check melodies fast`
2. Multi-touch chord playback
   - Show several pressed keys.
   - Caption idea: `Play chords and glissandos`
3. Navigation strip
   - Show the thin range control above the keys.
   - Caption idea: `Move across a wider range`
4. Settings sheet
   - Show `Visible Octaves`, `Volume`, and `Sound`.
   - Caption idea: `Minimal controls only`
5. Portrait app orientation with rotated keyboard
   - Show the one-handed use case.
   - Caption idea: `Portrait app, wide keyboard`

Recommended capture target:

- iPhone 6.9" landscape screenshots if available in Simulator
- Otherwise 6.5" landscape screenshots are acceptable and App Store Connect will scale them where needed

## Description

Tiny Keys is a minimal iPhone piano utility for checking notes and melodies by ear.

It opens straight to a playable keyboard, keeps the interface almost entirely focused on the keys, and mixes its sound with Apple Music, Spotify, and other audio already playing on the device.

Features:
- Play notes without interrupting background music from apps like Apple Music and Spotify
- Multi-touch chords and glissando-style playing
- Thin navigation strip for moving across a larger keyboard range
- Adjustable visible width: 1, 1.5, or 2 octaves
- Piano, sine, triangle, and square sounds
- Independent app orientation and keyboard direction settings
- No login, no ads, no subscriptions

Tiny Keys is intentionally small and direct: a quick musical utility, not a full workstation.

## Keywords

Use a comma-separated keyword string under 100 bytes and avoid repeating words already used in the app name.

Suggested keywords:

`melody,notes,practice,pitch,scales,chords,intervals,ear training,play by ear,music tool`

## Privacy Policy URL

Apple requires a public privacy policy URL for iOS apps.

Draft policy text is in:

- `AppStore/PRIVACY_POLICY.md`

Once you host that text publicly, use the final URL here. Example format:

- `https://your-domain.example/tiny-keys/privacy`

## Age Rating

Expected result: `4+`

Draft questionnaire answers:

- Unrestricted Web Access: `No`
- User-Generated Content: `No`
- Advertising: `No`
- Gambling / Contests: `No`
- Medical / Wellness treatment claims: `No`
- Violent, sexual, horror, drugs, alcohol, tobacco, profanity, mature themes: `None`

Apple assigns the final age rating based on the questionnaire, but this app should land at the minimum rating.

## Build Uploaded From Xcode

This is a manual step once your paid Apple Developer account is active.

1. Open [`/Users/will/Documents/git/tiny_keys/TinyKeys.xcodeproj`](/Users/will/Documents/git/tiny_keys/TinyKeys.xcodeproj) in Xcode.
2. Select the `Tiny Keys` target.
3. In `Signing & Capabilities`, choose your paid developer team.
4. Set the bundle identifier to match the app record in App Store Connect.
5. Choose `Any iOS Device (arm64)` or the generic iPhone destination.
6. Use `Product > Archive`.
7. In Organizer, choose `Distribute App`.
8. Select `App Store Connect`.
9. Upload the build and wait for processing in App Store Connect.

## App Privacy Answers

Based on the current app behavior, answer:

- `No, we do not collect data from this app`

Why this answer fits the current build:

- no account creation
- no analytics SDK
- no ads
- no remote content
- no user tracking
- no personal data collection

If any analytics, crash reporting, cloud sync, account system, or support form is added later, this answer must be revisited.

## Export Compliance Answers

Draft answer:

- The app does not use non-exempt encryption.
- No additional export compliance documentation should be required.

Reasoning:

- the app is a local audio utility
- it does not implement custom cryptography
- Apple states that if encryption is limited to that within the Apple operating system, no App Store Connect documentation is required

## Review Notes

Suggested App Review notes:

Tiny Keys is a minimal iPhone piano keyboard utility.

There is no login, no account setup, no subscription, and no external content.

The main feature to verify is audio mixing. The app configures `AVAudioSession` with category `.playback` and option `.mixWithOthers`, so it can play notes while other audio is already playing on the device, including apps like Apple Music and Spotify.

Suggested review flow:

1. Launch the app.
2. Tap piano keys on the main screen to hear notes.
3. Open Settings from the gear button to change visible octaves, volume, sound, app orientation, and keyboard direction.
4. Confirm the app remains usable in portrait and landscape.

If desired, the reviewer can also start Apple Music, Spotify, or another audio app first, then return to Tiny Keys and confirm that tapping notes does not interrupt the background audio.

## Also Required In App Store Connect

These are not in the original checklist above, but App Store Connect will also ask for them:

- Support URL
- App privacy policy URL
- Version-specific screenshots

Recommended support URL approach:

- host a simple support page with a contact email and the privacy policy link
- draft support page text is in `AppStore/SUPPORT.md`
