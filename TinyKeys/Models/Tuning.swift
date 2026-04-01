import Foundation

enum PitchClass: Int, CaseIterable, Identifiable, Codable {
    case c = 0
    case db = 1
    case d = 2
    case eb = 3
    case e = 4
    case f = 5
    case gb = 6
    case g = 7
    case ab = 8
    case a = 9
    case bb = 10
    case b = 11

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .c: return "C"
        case .db: return "Db"
        case .d: return "D"
        case .eb: return "Eb"
        case .e: return "E"
        case .f: return "F"
        case .gb: return "Gb"
        case .g: return "G"
        case .ab: return "Ab"
        case .a: return "A"
        case .bb: return "Bb"
        case .b: return "B"
        }
    }

    init(midiNote: Int) {
        let normalized = ((midiNote % 12) + 12) % 12
        self = PitchClass(rawValue: normalized) ?? .c
    }
}

enum TemperamentPreset: String, CaseIterable, Identifiable, Codable {
    case equal
    case just
    case pythagorean
    case meantoneQuarterComma
    case werckmeisterIII
    case kirnbergerIII
    case vallotti
    case youngII

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equal:
            return "Equal"
        case .just:
            return "Just"
        case .pythagorean:
            return "Pythagorean"
        case .meantoneQuarterComma:
            return "Meantone"
        case .werckmeisterIII:
            return "Werckmeister III"
        case .kirnbergerIII:
            return "Kirnberger III"
        case .vallotti:
            return "Vallotti"
        case .youngII:
            return "Young II"
        }
    }

    var shortDescription: String {
        switch self {
        case .equal:
            return "Modern 12-tone equal temperament."
        case .just:
            return "5-limit just intonation relative to the chosen tonic."
        case .pythagorean:
            return "Pure fifth chain with bright, wide thirds."
        case .meantoneQuarterComma:
            return "Quarter-comma meantone with strong key color."
        case .werckmeisterIII:
            return "Baroque well temperament with stronger color contrast."
        case .kirnbergerIII:
            return "Circulating temperament with very pure nearby keys."
        case .vallotti:
            return "Balanced well temperament with gentle key color."
        case .youngII:
            return "Young 1799, a rotated Vallotti-style well temperament."
        }
    }

    var supportsPiano: Bool {
        self == .equal
    }

    // Offsets are normalized so the tonic is 0 cents relative to equal temperament.
    // Values are C-centered built-ins derived from published cent tables / ratios and
    // rotated by key center at runtime.
    var tonicRelativeOffsetsCents: [Double] {
        switch self {
        case .equal:
            return Array(repeating: 0, count: 12)
        case .just:
            return [
                0.000, 11.731, 3.910, 15.641, -13.686, -1.955,
                -9.776, 1.955, 13.686, -15.641, 17.596, -11.731,
            ]
        case .pythagorean:
            return [
                0.000, 13.720, 3.960, -5.860, 7.860, -1.940,
                11.760, 2.000, 15.670, 5.890, -3.880, 9.810,
            ]
        case .meantoneQuarterComma:
            return [
                0.000, -23.980, -6.850, 10.240, -13.700, 3.380,
                -20.540, -3.410, -27.380, -10.290, 6.830, -17.120,
            ]
        case .werckmeisterIII:
            return [
                0.000, -9.770, -7.820, 1.960, -13.690, -1.950,
                -11.730, -3.910, -7.820, -11.730, 0.000, -13.690,
            ]
        case .kirnbergerIII:
            return [
                0.000, -9.790, -6.850, 3.410, -13.700, 3.380,
                -9.320, -3.410, -6.390, -10.290, 0.000, -13.690,
            ]
        case .vallotti:
            return [
                0.000, -3.920, -3.890, 1.950, -7.800, 1.930,
                -5.870, -1.950, -1.970, -5.870, 0.000, -9.770,
            ]
        case .youngII:
            return [
                0.000, -5.860, -5.860, 1.960, -9.780, -1.950,
                -7.820, -1.950, -5.860, -7.820, 0.000, -9.780,
            ]
        }
    }
}

struct TuningSelection: Equatable, Codable {
    var temperament: TemperamentPreset = .equal
    var keyCenter: PitchClass = .c

    var title: String {
        if temperament == .equal {
            return temperament.title
        }

        return "\(temperament.title) · \(keyCenter.title)"
    }

    var supportsPiano: Bool {
        temperament.supportsPiano
    }

    var hasUnequalTemperament: Bool {
        temperament != .equal
    }
}
