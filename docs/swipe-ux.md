# Swipe UX Notes

This note captures the touch-handling decisions behind Tiny Keys' swipe-to-latch drone interaction. The goal was not just to "make the gesture work," but to make it feel stable when multiple hit regions overlap and when the same surface supports both continuous play and state-changing swipes.

## Problem shape

Tiny Keys has a few constraints that make touch handling more subtle than a plain button grid:

- white and black key hit regions overlap
- the keyboard supports glissando, so lateral movement across keys must remain fluid
- the drone gesture uses movement on the same key surface that also plays notes
- a gesture that toggles state should not keep manipulating the key after it has already succeeded

The resulting UX problems were:

- a swipe started on a white key could get "stolen" by an overlapping black key
- pinning the touch too early fixed that, but broke glissando by preventing normal cross-key movement
- once a latch or unlatch threshold was crossed, continuing to drag still visually pulled on the key again
- tapping a latched key should still produce a temporary note without breaking the drone

## The approach

### 1. Separate note playback state from gesture ownership

Tiny Keys keeps per-touch state that distinguishes:

- the note currently sounding for that touch
- the note the gesture began on
- the note currently owned by a drone swipe gesture
- whether the touch has already completed a toggle and should ignore further movement

That separation matters because "what note is sounding right now" and "what note this gesture should keep controlling" are not always the same thing.

### 2. Delay gesture ownership until intent is clear

The key fix for overlapping white/black key hit boxes was to *not* lock a touch to its starting note immediately.

Instead:

- normal movement keeps using fresh hit-testing
- once movement looks like a deliberate along-the-key swipe, ownership locks to the note where that swipe began

In practice this means:

- vertical-dominant movement along the key starts drone-gesture tracking
- horizontal or diagonal movement still behaves like normal glissando

This preserves both behaviors:

- stable swipe-to-latch on the intended key
- natural lateral glissando across adjacent keys

### 3. Use key-local gesture intent, not global screen intent

The drone gesture is determined from the touch translation relative to the note where the gesture started. That keeps the behavior correct even when the keyboard surface is rotated independently from the overall app orientation.

The practical rule is:

- decide gesture semantics in the controlled surface's local coordinate space
- do not rely on the current topmost hit target once the gesture is clearly in progress

### 4. Lock the touch after a successful toggle

Once a swipe crosses the latch or unlatch threshold, the gesture is done.

At that point the touch becomes inert until finger-up:

- no new pull animation
- no repeated toggles
- no accidental re-engagement while the user is still moving

This was important for making the threshold feel decisive instead of squishy.

### 5. Let latched keys support temporary notes on top

A latched drone key should not become "dead." Tiny Keys allows a normal temporary note to sound on top of a latched drone when the user taps that key again.

That means:

- touch-down on a latched key starts a normal note
- the existing drone continues underneath
- if the gesture turns into an unlatch swipe, the temporary note is explicitly released before the drone is toggled off

This preserves both use cases:

- retouching the same pitch for a fresh attack
- deliberately unlatching with a swipe

## UX heuristics worth reusing

These are the general lessons that seem portable to other projects:

- When a surface supports both continuous motion and a mode-changing swipe, do not commit to the mode-changing gesture too early.
- If overlapping hit targets exist, preserve ownership only after gesture intent is clear.
- A successful threshold gesture should usually consume the rest of that touch.
- When one interaction layer is "persistent" and another is "temporary," model them as separate states instead of trying to fake one with the other.
- Gesture rules should be based on user intent and surface geometry, not just whatever view is topmost under the finger at that instant.

## Tiny Keys implementation references

- Main keyboard touch handling: [`TinyKeys/Keyboard/PianoKeyboardView.swift`](../TinyKeys/Keyboard/PianoKeyboardView.swift)
- Main screen drone controls: [`TinyKeys/App/MainKeyboardScreen.swift`](../TinyKeys/App/MainKeyboardScreen.swift)
- View-model state for drone mode: [`TinyKeys/App/TinyKeysViewModel.swift`](../TinyKeys/App/TinyKeysViewModel.swift)
- Settings toggle: [`TinyKeys/Settings/SettingsSheetView.swift`](../TinyKeys/Settings/SettingsSheetView.swift)
