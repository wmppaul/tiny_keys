import CoreGraphics
import Foundation
import UIKit

enum VisibleKeySpan: String, CaseIterable, Identifiable {
    case one
    case oneAndHalf
    case two
    case zoom

    var id: String { rawValue }

    var fixedWhiteKeyCount: CGFloat? {
        switch self {
        case .one:
            return 7.0
        case .oneAndHalf:
            return 10.5
        case .two:
            return 14.0
        case .zoom:
            return nil
        }
    }

    var defaultWhiteKeyCount: CGFloat {
        fixedWhiteKeyCount ?? 10.5
    }

    var title: String {
        switch self {
        case .one:
            return "1"
        case .oneAndHalf:
            return "1.5"
        case .two:
            return "2"
        case .zoom:
            return "Zoom"
        }
    }
}

enum SoundPreset: String, CaseIterable, Identifiable {
    case piano = "Piano"
    case sine = "Sine"
    case triangle = "Triangle"
    case square = "Square"

    var id: String { rawValue }
}

enum SettingsNavigationDestination: Hashable {
    case tuning
}

enum AppOrientationMode: String, CaseIterable, Identifiable {
    case portrait
    case landscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portrait:
            return "Portrait"
        case .landscape:
            return "Landscape"
        }
    }

    var supportedMask: UIInterfaceOrientationMask {
        switch self {
        case .portrait:
            return .portrait
        case .landscape:
            return .landscape
        }
    }

    var defaultInterfaceOrientation: UIInterfaceOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .landscape:
            return .landscapeRight
        }
    }
}

enum KeyboardOrientationMode: String, CaseIterable, Identifiable {
    case landscapeLeft
    case portrait
    case landscapeRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .landscapeLeft:
            return "Left"
        case .portrait:
            return "Down"
        case .landscapeRight:
            return "Right"
        }
    }

    var quarterTurnsClockwiseFromPortrait: Int {
        switch self {
        case .portrait:
            return 0
        case .landscapeLeft:
            return 1
        case .landscapeRight:
            return -1
        }
    }

    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait:
            self = .portrait
        case .landscapeLeft:
            self = .landscapeRight
        case .landscapeRight:
            self = .landscapeLeft
        default:
            return nil
        }
    }

    func relativeQuarterTurns(from interfaceOrientation: UIInterfaceOrientation) -> Int {
        _ = interfaceOrientation
        var relativeQuarterTurns = quarterTurnsClockwiseFromPortrait

        while relativeQuarterTurns > 2 {
            relativeQuarterTurns -= 4
        }

        while relativeQuarterTurns < -2 {
            relativeQuarterTurns += 4
        }

        return relativeQuarterTurns
    }

    func rotationDegrees(from interfaceOrientation: UIInterfaceOrientation) -> Double {
        Double(relativeQuarterTurns(from: interfaceOrientation) * 90)
    }

    func swapsAxes(from interfaceOrientation: UIInterfaceOrientation) -> Bool {
        abs(relativeQuarterTurns(from: interfaceOrientation)).isMultiple(of: 2) == false
    }
}

extension UIInterfaceOrientation {
    var quarterTurnsClockwiseFromPortrait: Int? {
        switch self {
        case .portrait:
            return 0
        case .landscapeRight:
            return 1
        case .landscapeLeft:
            return -1
        default:
            return nil
        }
    }

    var tinyKeysDebugName: String {
        switch self {
        case .portrait:
            return "portrait"
        case .portraitUpsideDown:
            return "portraitUpsideDown"
        case .landscapeLeft:
            return "landscapeLeft"
        case .landscapeRight:
            return "landscapeRight"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }
}
