import CoreGraphics
import Foundation

private enum PianoGeometry {
    // Based on measured piano-key proportions from the LilyPond reference the user provided.
    static let blackKeyWidthRatio: CGFloat = 15.0 / 23.5
    static let blackKeyHeightRatio: CGFloat = 95.0 / 150.0

    static let leftBlackCenterOffset: CGFloat = 20.5 / 23.5
    static let centeredBlackCenterOffset: CGFloat = 1.0
    static let rightBlackCenterOffset: CGFloat = 26.5 / 23.5
}

struct PianoKey: Identifiable, Hashable {
    enum Kind {
        case white
        case black
    }

    let midiNote: Int
    let kind: Kind
    let whiteIndex: Int
    let blackCenterOffset: CGFloat

    var id: Int { midiNote }
    var isBlack: Bool { kind == .black }
}

struct PianoKeyFrame: Identifiable {
    let key: PianoKey
    let frame: CGRect

    var id: Int { key.id }
}

struct PianoKeyboardFrameSet {
    let whiteKeys: [PianoKeyFrame]
    let blackKeys: [PianoKeyFrame]
}

struct PianoKeyboardLayout {
    let lowMIDINote: Int
    let highMIDINote: Int
    let keys: [PianoKey]
    let whiteKeys: [PianoKey]
    let blackKeys: [PianoKey]
    let whiteKeyCount: Int

    init(lowMIDINote: Int = 48, octaves: Int = 4) {
        self.lowMIDINote = lowMIDINote
        self.highMIDINote = lowMIDINote + (octaves * 12) - 1

        var builtKeys: [PianoKey] = []
        var whiteIndex = 0

        for midiNote in lowMIDINote...highMIDINote {
            let pitchClass = midiNote % 12
            switch pitchClass {
            case 0:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .white, whiteIndex: whiteIndex, blackCenterOffset: 0))
                whiteIndex += 1
            case 1:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .black, whiteIndex: whiteIndex - 1, blackCenterOffset: PianoGeometry.leftBlackCenterOffset))
            case 2:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .white, whiteIndex: whiteIndex, blackCenterOffset: 0))
                whiteIndex += 1
            case 3:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .black, whiteIndex: whiteIndex - 1, blackCenterOffset: PianoGeometry.rightBlackCenterOffset))
            case 4:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .white, whiteIndex: whiteIndex, blackCenterOffset: 0))
                whiteIndex += 1
            case 5:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .white, whiteIndex: whiteIndex, blackCenterOffset: 0))
                whiteIndex += 1
            case 6:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .black, whiteIndex: whiteIndex - 1, blackCenterOffset: PianoGeometry.leftBlackCenterOffset))
            case 7:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .white, whiteIndex: whiteIndex, blackCenterOffset: 0))
                whiteIndex += 1
            case 8:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .black, whiteIndex: whiteIndex - 1, blackCenterOffset: PianoGeometry.centeredBlackCenterOffset))
            case 9:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .white, whiteIndex: whiteIndex, blackCenterOffset: 0))
                whiteIndex += 1
            case 10:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .black, whiteIndex: whiteIndex - 1, blackCenterOffset: PianoGeometry.rightBlackCenterOffset))
            default:
                builtKeys.append(PianoKey(midiNote: midiNote, kind: .white, whiteIndex: whiteIndex, blackCenterOffset: 0))
                whiteIndex += 1
            }
        }

        self.keys = builtKeys
        self.whiteKeys = builtKeys.filter { !$0.isBlack }
        self.blackKeys = builtKeys.filter(\.isBlack)
        self.whiteKeyCount = whiteIndex
    }

    func whitePosition(for midiNote: Int) -> CGFloat? {
        guard let key = keys.first(where: { $0.midiNote == midiNote }) else {
            return nil
        }

        if key.isBlack {
            return CGFloat(key.whiteIndex) + key.blackCenterOffset
        }

        return CGFloat(key.whiteIndex)
    }

    func defaultVisibleStart(for span: VisibleKeySpan) -> CGFloat {
        defaultVisibleStart(visibleWhiteCount: span.defaultWhiteKeyCount)
    }

    func defaultVisibleStart(visibleWhiteCount: CGFloat) -> CGFloat {
        let middleCWhiteIndex = whitePosition(for: 60) ?? 7
        return clampVisibleStart(middleCWhiteIndex, visibleWhiteCount: visibleWhiteCount)
    }

    func clampVisibleStart(_ proposedStart: CGFloat, visibleWhiteCount: CGFloat) -> CGFloat {
        let maximumStart = max(CGFloat(whiteKeyCount) - visibleWhiteCount, 0)
        return min(max(proposedStart, 0), maximumStart)
    }

    func frames(in size: CGSize, visibleWhiteStart: CGFloat, visibleWhiteCount: CGFloat) -> PianoKeyboardFrameSet {
        guard size.width > 0, size.height > 0, visibleWhiteCount > 0 else {
            return PianoKeyboardFrameSet(whiteKeys: [], blackKeys: [])
        }

        let clampedStart = clampVisibleStart(visibleWhiteStart, visibleWhiteCount: visibleWhiteCount)
        let whiteKeyWidth = size.width / visibleWhiteCount
        let blackKeyWidth = whiteKeyWidth * PianoGeometry.blackKeyWidthRatio
        let blackKeyHeight = size.height * PianoGeometry.blackKeyHeightRatio

        var whiteFrames: [PianoKeyFrame] = []
        var blackFrames: [PianoKeyFrame] = []

        for key in whiteKeys {
            let xPosition = (CGFloat(key.whiteIndex) - clampedStart) * whiteKeyWidth
            let frame = CGRect(x: xPosition, y: 0, width: whiteKeyWidth, height: size.height).integral
            if frame.maxX >= 0, frame.minX <= size.width {
                whiteFrames.append(PianoKeyFrame(key: key, frame: frame))
            }
        }

        for key in blackKeys {
            let center = (CGFloat(key.whiteIndex) + key.blackCenterOffset - clampedStart) * whiteKeyWidth
            let frame = CGRect(
                x: center - (blackKeyWidth / 2),
                y: 0,
                width: blackKeyWidth,
                height: blackKeyHeight
            ).integral

            if frame.maxX >= 0, frame.minX <= size.width {
                blackFrames.append(PianoKeyFrame(key: key, frame: frame))
            }
        }

        return PianoKeyboardFrameSet(whiteKeys: whiteFrames, blackKeys: blackFrames)
    }
}
