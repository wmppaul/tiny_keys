import Foundation

struct TuningEngine {
    let selection: TuningSelection

    func pitchClassOffsetsCents() -> [Float] {
        PitchClass.allCases.map { pitchClass in
            Float(offsetCents(for: pitchClass))
        }
    }

    func offsetCents(for midiNote: Int) -> Double {
        offsetCents(for: PitchClass(midiNote: midiNote))
    }

    func offsetCents(for pitchClass: PitchClass) -> Double {
        let degree = (pitchClass.rawValue - selection.keyCenter.rawValue + 12) % 12
        if selection.temperament == .custom {
            return selection.normalizedCustomOffsetsCents[degree]
        }

        return selection.temperament.tonicRelativeOffsetsCents[degree]
    }
}
