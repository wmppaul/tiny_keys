import SwiftUI
import UIKit

struct PianoKeyboardView: UIViewRepresentable {
    let layout: PianoKeyboardLayout
    let visibleWhiteStart: CGFloat
    let visibleWhiteCount: CGFloat
    let noteOn: (Int, Int) -> Void
    let noteOff: (Int) -> Void

    func makeUIView(context: Context) -> PianoKeyboardUIView {
        let view = PianoKeyboardUIView()
        view.layoutModel = layout
        view.noteOn = noteOn
        view.noteOff = noteOff
        view.visibleWhiteStart = visibleWhiteStart
        view.visibleWhiteCount = visibleWhiteCount
        return view
    }

    func updateUIView(_ uiView: PianoKeyboardUIView, context: Context) {
        uiView.layoutModel = layout
        uiView.noteOn = noteOn
        uiView.noteOff = noteOff
        uiView.visibleWhiteStart = visibleWhiteStart
        uiView.visibleWhiteCount = visibleWhiteCount
    }
}

final class PianoKeyboardUIView: UIView {
    var layoutModel = PianoKeyboardLayout() {
        didSet {
            updateFrames()
        }
    }

    var visibleWhiteStart: CGFloat = 0 {
        didSet {
            if visibleWhiteStart != oldValue {
                updateFrames()
            }
        }
    }

    var visibleWhiteCount: CGFloat = VisibleKeySpan.oneAndHalf.whiteKeyCount {
        didSet {
            if visibleWhiteCount != oldValue {
                updateFrames()
            }
        }
    }

    var noteOn: ((Int, Int) -> Void)?
    var noteOff: ((Int) -> Void)?

    private var currentFrames = PianoKeyboardFrameSet(whiteKeys: [], blackKeys: [])
    private var touchTokens: [ObjectIdentifier: Int] = [:]
    private var touchNotes: [ObjectIdentifier: Int] = [:]
    private var nextToken = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        contentMode = .redraw
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (keyboardView: Self, _) in
            keyboardView.setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateFrames()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let palette = KeyboardPalette(traits: traitCollection)
        context.setFillColor(palette.background.cgColor)
        context.fill(bounds)

        for keyFrame in currentFrames.whiteKeys {
            let isPressed = activeMIDINotes.contains(keyFrame.key.midiNote)
            let insetFrame = keyFrame.frame.insetBy(dx: 0.5, dy: 0.5)
            let path = UIBezierPath(roundedRect: insetFrame, cornerRadius: 4)
            context.setFillColor((isPressed ? palette.whitePressed : palette.whiteKey).cgColor)
            context.addPath(path.cgPath)
            context.fillPath()

            context.setStrokeColor(palette.whiteBorder.cgColor)
            context.setLineWidth(1)
            context.addPath(path.cgPath)
            context.strokePath()
        }

        for keyFrame in currentFrames.blackKeys {
            let isPressed = activeMIDINotes.contains(keyFrame.key.midiNote)
            let insetFrame = keyFrame.frame.insetBy(dx: 0.5, dy: 0.5)
            let path = UIBezierPath(roundedRect: insetFrame, cornerRadius: 4)
            context.setFillColor((isPressed ? palette.blackPressed : palette.blackKey).cgColor)
            context.addPath(path.cgPath)
            context.fillPath()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = event
        handleTouches(touches, shouldEndMissingNotes: false)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = event
        handleTouches(touches, shouldEndMissingNotes: false)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = event
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = event
        endTouches(touches)
    }

    private var activeMIDINotes: Set<Int> {
        Set(touchNotes.values)
    }

    private func updateFrames() {
        currentFrames = layoutModel.frames(
            in: bounds.size,
            visibleWhiteStart: visibleWhiteStart,
            visibleWhiteCount: visibleWhiteCount
        )
        setNeedsDisplay()
    }

    private func handleTouches(_ touches: Set<UITouch>, shouldEndMissingNotes: Bool) {
        _ = shouldEndMissingNotes

        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            let token = touchTokens[identifier] ?? allocateToken(for: identifier)
            let point = touch.location(in: self)
            let hitMIDINote = midiNote(at: point)
            let activeMIDINote = touchNotes[identifier]

            guard hitMIDINote != activeMIDINote else {
                continue
            }

            if activeMIDINote != nil {
                noteOff?(token)
                touchNotes[identifier] = nil
            }

            if let hitMIDINote {
                noteOn?(token, hitMIDINote)
                touchNotes[identifier] = hitMIDINote
            }
        }

        setNeedsDisplay()
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)

            if let token = touchTokens[identifier], touchNotes[identifier] != nil {
                noteOff?(token)
            }

            touchTokens.removeValue(forKey: identifier)
            touchNotes.removeValue(forKey: identifier)
        }

        setNeedsDisplay()
    }

    private func allocateToken(for identifier: ObjectIdentifier) -> Int {
        let token = nextToken
        nextToken += 1
        touchTokens[identifier] = token
        return token
    }

    private func midiNote(at point: CGPoint) -> Int? {
        for keyFrame in currentFrames.blackKeys.reversed() where keyFrame.frame.contains(point) {
            return keyFrame.key.midiNote
        }

        for keyFrame in currentFrames.whiteKeys where keyFrame.frame.contains(point) {
            return keyFrame.key.midiNote
        }

        return nil
    }
}

private struct KeyboardPalette {
    let background: UIColor
    let whiteKey: UIColor
    let whitePressed: UIColor
    let whiteBorder: UIColor
    let blackKey: UIColor
    let blackPressed: UIColor

    init(traits: UITraitCollection) {
        if traits.userInterfaceStyle == .dark {
            background = UIColor(white: 0.10, alpha: 1)
            whiteKey = UIColor(white: 0.92, alpha: 1)
            whitePressed = UIColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 1)
            whiteBorder = UIColor(white: 0.18, alpha: 1)
            blackKey = UIColor(white: 0.04, alpha: 1)
            blackPressed = UIColor(red: 0.14, green: 0.37, blue: 0.68, alpha: 1)
        } else {
            background = UIColor(white: 0.84, alpha: 1)
            whiteKey = .white
            whitePressed = UIColor(red: 0.76, green: 0.88, blue: 1.0, alpha: 1)
            whiteBorder = UIColor(white: 0.20, alpha: 1)
            blackKey = UIColor(white: 0.08, alpha: 1)
            blackPressed = UIColor(red: 0.19, green: 0.40, blue: 0.74, alpha: 1)
        }
    }
}
