import CoreGraphics
import Foundation

enum VisibleKeySpan: CGFloat, CaseIterable, Identifiable {
    case one = 7.0
    case oneAndHalf = 10.5
    case two = 14.0

    var id: CGFloat { rawValue }
    var whiteKeyCount: CGFloat { rawValue }

    var title: String {
        switch self {
        case .one:
            return "1"
        case .oneAndHalf:
            return "1.5"
        case .two:
            return "2"
        }
    }
}

enum SoundPreset: String, CaseIterable, Identifiable {
    case piano = "Piano"
    case electricPiano = "E-Piano"
    case sine = "Sine"

    var id: String { rawValue }
}
