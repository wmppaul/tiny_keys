# Tuning Reference

This page documents the built-in tuning offsets exactly as they are implemented in Tiny Keys.

All values below are cents offsets from 12-tone equal temperament, not absolute cents-above-tonic positions. The tonic is normalized to `0.000`, so these rows match the interval labels used in the custom editor (`Tonic` through `M7`) rather than fixed note names.

The literal built-in tables live in [`TinyKeys/Models/Tuning.swift`](../TinyKeys/Models/Tuning.swift). The editor uses the same interval ordering in [`TinyKeys/Settings/CustomTuningEditorView.swift`](../TinyKeys/Settings/CustomTuningEditorView.swift).

## Built-In Offsets

| Degree | Equal | Just | Pythagorean | Meantone | Werckmeister III | Kirnberger III | Vallotti | Young II |
|---|---|---|---|---|---|---|---|---|
| Tonic | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| m2 | 0.000 | +11.731 | +13.720 | -23.980 | -9.770 | -9.790 | -3.920 | -5.860 |
| M2 | 0.000 | +3.910 | +3.960 | -6.850 | -7.820 | -6.850 | -3.890 | -5.860 |
| m3 | 0.000 | +15.641 | -5.860 | +10.240 | +1.960 | +3.410 | +1.950 | +1.960 |
| M3 | 0.000 | -13.686 | +7.860 | -13.700 | -13.690 | -13.700 | -7.800 | -9.780 |
| P4 | 0.000 | -1.955 | -1.940 | +3.380 | -1.950 | +3.380 | +1.930 | -1.950 |
| TT | 0.000 | -9.776 | +11.760 | -20.540 | -11.730 | -9.320 | -5.870 | -7.820 |
| P5 | 0.000 | +1.955 | +2.000 | -3.410 | -3.910 | -3.410 | -1.950 | -1.950 |
| m6 | 0.000 | +13.686 | +15.670 | -27.380 | -7.820 | -6.390 | -1.970 | -5.860 |
| M6 | 0.000 | -15.641 | +5.890 | -10.290 | -11.730 | -10.290 | -5.870 | -7.820 |
| m7 | 0.000 | +17.596 | -3.880 | +6.830 | 0.000 | 0.000 | 0.000 | 0.000 |
| M7 | 0.000 | -11.731 | +9.810 | -17.120 | -13.690 | -13.690 | -9.770 | -9.780 |

## How Tiny Keys Implements This

- Built-in presets are stored as C-centered `tonicRelativeOffsetsCents` arrays in [`TinyKeys/Models/Tuning.swift`](../TinyKeys/Models/Tuning.swift). The code comment there explicitly says the offsets are normalized so the tonic is `0` and rotated by key center at runtime.
- Runtime lookup happens in [`TinyKeys/Audio/TuningEngine.swift`](../TinyKeys/Audio/TuningEngine.swift). For each pitch class, the engine computes `degree = (pitchClass.rawValue - selection.keyCenter.rawValue + 12) % 12` and uses that degree to read either the built-in table or the custom table.
- The 12 computed pitch-class offsets are pushed from [`TinyKeys/App/TinyKeysViewModel.swift`](../TinyKeys/App/TinyKeysViewModel.swift) into [`TinyKeys/Audio/SynthEngine.swift`](../TinyKeys/Audio/SynthEngine.swift) via `setPitchClassOffsets(_:)`.
- `SynthEngine` applies the updated pitch-class offsets by retuning active waveform voices when it processes `updatePitchClassOffsets`.
- The current implementation is still 12-pitch-class only. The UI exposes combined enharmonic slots such as `C#/Db`, `F#/Gb`, `G#/Ab`, and `A#/Bb`, so the unequal temperaments are implemented as one value per semitone slot rather than split enharmonic pitches.
- Unequal temperaments currently affect the waveform synth path. `Piano` remains equal-only until per-note sampler retuning is added.

## External Cross-Check

- `Just`: [Kyle Gann, "Just Intonation Explained"](https://www.kylegann.com/tuning.html) gives the same 12-note 5-limit ratio set `1/1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8`. Verdict: agrees. Tiny Keys is using those ratios converted to cents, then expressed as deviations from equal temperament and rounded to three decimals.
- `Pythagorean`: [Tunable, "A0 in Pythagorean Tuning"](https://tunableapp.com/notes/a0/pythagorean/) and [Kyle Gann, "An Introduction to Historical Tunings"](<https://www.kylegann.com/histune.html>) both support the implemented pure-fifths structure. Verdict: agrees after normalization. Source tables usually publish absolute cents or A-referenced deviations, while Tiny Keys stores tonic-normalized deviations from equal temperament.
- `Quarter-comma meantone`: [Kyle Gann, "An Introduction to Historical Tunings"](<https://www.kylegann.com/histune.html>) and [HMT `pietro_aaron_1523`](https://hackage.haskell.org/package/hmt-0.16/docs/Music-Theory-Tuning-DB-Gann.html) both match the code's Pietro Aaron style quarter-comma meantone pattern. Verdict: agrees. The remaining differences are rounding and representation as deviations-from-equal instead of absolute cents.
- `Werckmeister III`: [Kyle Gann, "An Introduction to Historical Tunings"](<https://www.kylegann.com/histune.html>), [HMT `werckmeister_iii`](https://hackage.haskell.org/package/hmt-0.16/docs/Music-Theory-Tuning-DB-Werckmeister.html), and [Tunable, "E0 in Werckmeister III"](https://tunableapp.com/notes/e0/werckmeister-iii/) all line up with the implementation. Verdict: agrees. The code appears to be a directly normalized-and-rounded version of the usual C-based cent table.
- `Kirnberger III`: [Ableton Tuning, "12 WT (Kirnberger III)"](https://tuning.ableton.com/european-historical/12-wt-kirnberger-iii/) and [Tunable, "A#2 in Kirnberger III"](https://tunableapp.com/notes/a-sharp-2/kirnberger-iii/) support the same circulating-temperament construction and published deviations. Verdict: agrees after normalization. The code values differ from the rounded web tables only by a few hundredths of a cent.
- `Vallotti`: [Tunable, "G#7 in Vallotti"](https://tunableapp.com/notes/g-sharp-7/vallotti/) matches the implemented Vallotti pattern once C's own deviation is normalized back to `0.000`. Verdict: agrees. The Tiny Keys table is the same temperament expressed in tonic-relative form.
- `Young II`: [Tunable, "G#5 in Young (1799)"](https://tunableapp.com/notes/g-sharp-5/young/) agrees with the code's "rotated Vallotti-style" pattern. Verdict: agrees with Tunable, but not with every Young-labeled source. [Kyle Gann/HMT `thomas_young_1799` and `young2.scl`](https://hackage.haskell.org/package/hmt-0.16/docs/Music-Theory-Tuning-DB-Gann.html) document a different Young 1799 table than the one Tiny Keys ships. Tiny Keys therefore appears to implement the Vallotti-Young / Young-second style reading of the name rather than Gann's first-Young table.

## Potential Discrepancies

- Many references do not publish "pitch shift from equal temperament with tonic normalized to zero." They usually publish either absolute cents above the tonic or equal-temperament deviations with some fixed pitch like `A` as the reference. Direct numeric comparison requires converting into the same representation first.
- Several historical temperaments distinguish enharmonic spellings that a 12-note keyboard collapses. Tiny Keys currently has one slot for each semitone, so comparisons should be made by interval degree or semitone slot, not by assuming a split `C#` vs `Db` keyboard.
- Source tables often round to one or two decimals. Tiny Keys stores two or three decimals in code, so tiny mismatches are expected even when the temperament itself agrees.
- The main naming ambiguity is `Young II`. The implementation matches rotated-Vallotti / Vallotti-Young style sources, but some references use `Young 1799` for a different Young temperament.
