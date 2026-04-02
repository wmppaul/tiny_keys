import SwiftUI
import UIKit

struct PianoKeyboardView: UIViewRepresentable {
    let layout: PianoKeyboardLayout
    let visibleWhiteStart: CGFloat
    let visibleWhiteCount: CGFloat
    let droneModeEnabled: Bool
    let clearDronesGeneration: Int
    let latchedNotesChanged: ([Int]) -> Void
    let noteOn: (Int, Int) -> Void
    let noteOff: (Int) -> Void

    func makeUIView(context: Context) -> PianoKeyboardUIView {
        let view = PianoKeyboardUIView()
        view.layoutModel = layout
        view.noteOn = noteOn
        view.noteOff = noteOff
        view.visibleWhiteStart = visibleWhiteStart
        view.visibleWhiteCount = visibleWhiteCount
        view.droneModeEnabled = droneModeEnabled
        view.clearDronesGeneration = clearDronesGeneration
        view.latchedNotesChanged = latchedNotesChanged
        return view
    }

    func updateUIView(_ uiView: PianoKeyboardUIView, context: Context) {
        uiView.layoutModel = layout
        uiView.noteOn = noteOn
        uiView.noteOff = noteOff
        uiView.visibleWhiteStart = visibleWhiteStart
        uiView.visibleWhiteCount = visibleWhiteCount
        uiView.droneModeEnabled = droneModeEnabled
        uiView.clearDronesGeneration = clearDronesGeneration
        uiView.latchedNotesChanged = latchedNotesChanged
    }
}

final class PianoKeyboardUIView: UIView {
    private struct CachedKey {
        let keyFrame: PianoKeyFrame
        let path: CGPath
    }

    private enum SwipeDirection {
        case towardTop
        case towardBottom
    }

    private struct TouchState {
        var token: Int? = nil
        var currentMIDINote: Int? = nil
        var beganMIDINote: Int? = nil
        var gestureMIDINote: Int? = nil
        var beganPoint: CGPoint = .zero
        var swipeProgress: CGFloat = 0
        var swipeDirection: SwipeDirection? = nil
        var controlledLatchedMIDINote: Int? = nil
        var gestureLocked = false
        var hasTraversedOtherNote = false
    }

    private struct SwipeVisualization {
        let progress: CGFloat
        let direction: SwipeDirection
    }

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

    var visibleWhiteCount: CGFloat = VisibleKeySpan.oneAndHalf.defaultWhiteKeyCount {
        didSet {
            if visibleWhiteCount != oldValue {
                updateFrames()
            }
        }
    }

    var droneModeEnabled = false

    var clearDronesGeneration = 0 {
        didSet {
            if clearDronesGeneration != oldValue {
                clearLatchedNotes()
            }
        }
    }

    var latchedNotesChanged: (([Int]) -> Void)?
    var noteOn: ((Int, Int) -> Void)?
    var noteOff: ((Int) -> Void)?

    private var currentFrames = PianoKeyboardFrameSet(whiteKeys: [], blackKeys: [])
    private var cachedWhiteKeys: [CachedKey] = []
    private var cachedBlackKeys: [CachedKey] = []
    private var touchStates: [ObjectIdentifier: TouchState] = [:]
    private var activeNoteCounts: [Int: Int] = [:]
    private var latchedNoteTokens: [Int: Int] = [:]
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

        for cachedKey in cachedWhiteKeys {
            let visualPath = activePath(for: cachedKey, swipe: swipeVisualization(for: cachedKey.keyFrame.key.midiNote))
            context.setFillColor(fillColor(for: cachedKey.keyFrame.key.midiNote, palette: palette, isBlack: false).cgColor)
            context.addPath(visualPath)
            context.fillPath()

            context.setStrokeColor(palette.whiteBorder.cgColor)
            context.setLineWidth(1)
            context.addPath(cachedKey.path)
            context.strokePath()
        }

        for cachedKey in cachedBlackKeys {
            let visualPath = activePath(for: cachedKey, swipe: swipeVisualization(for: cachedKey.keyFrame.key.midiNote))
            context.setFillColor(fillColor(for: cachedKey.keyFrame.key.midiNote, palette: palette, isBlack: true).cgColor)
            context.addPath(visualPath)
            context.fillPath()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = event
        beginTouches(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = event
        moveTouches(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = event
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        _ = event
        endTouches(touches)
    }

    private func updateFrames() {
        currentFrames = layoutModel.frames(
            in: bounds.size,
            visibleWhiteStart: visibleWhiteStart,
            visibleWhiteCount: visibleWhiteCount
        )
        cachedWhiteKeys = currentFrames.whiteKeys.map(Self.cachedKey(for:))
        cachedBlackKeys = currentFrames.blackKeys.map(Self.cachedKey(for:))
        setNeedsDisplay()
    }

    private func beginTouches(_ touches: Set<UITouch>) {
        var didChangeVisibleState = false

        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            let point = touch.location(in: self)
            let hitMIDINote = midiNote(at: point)

            var state = TouchState(
                token: nil,
                currentMIDINote: nil,
                beganMIDINote: hitMIDINote,
                beganPoint: point
            )

            if let hitMIDINote, isNoteLatched(hitMIDINote) {
                let token = allocateToken()
                state.token = token
                state.currentMIDINote = hitMIDINote
                state.controlledLatchedMIDINote = hitMIDINote
                state.gestureMIDINote = hitMIDINote
                activateNote(hitMIDINote)
                noteOn?(token, hitMIDINote)
                didChangeVisibleState = true
            } else if let hitMIDINote {
                let token = allocateToken()
                state.token = token
                state.currentMIDINote = hitMIDINote
                activateNote(hitMIDINote)
                noteOn?(token, hitMIDINote)
                didChangeVisibleState = true
            }

            touchStates[identifier] = state
        }

        if didChangeVisibleState {
            setNeedsDisplay()
        }
    }

    private func moveTouches(_ touches: Set<UITouch>) {
        var didChangeVisibleState = false

        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            guard var state = touchStates[identifier] else {
                continue
            }

            let point = touch.location(in: self)

            if state.gestureLocked {
                touchStates[identifier] = state
                continue
            }

            if let controlledLatchedMIDINote = state.controlledLatchedMIDINote {
                let gestureNote = state.gestureMIDINote ?? controlledLatchedMIDINote
                let gesture = droneGesture(for: point, state: state, midiNote: gestureNote)
                state.swipeProgress = gesture?.progress ?? 0
                state.swipeDirection = gesture?.direction

                if let gesture, gesture.progress >= 1 {
                    if let activeMIDINote = state.currentMIDINote, let token = state.token {
                        deactivateNote(activeMIDINote)
                        noteOff?(token)
                    }
                    unlatchNote(gestureNote)
                    state.controlledLatchedMIDINote = nil
                    state.currentMIDINote = nil
                    state.token = nil
                    state.beganMIDINote = nil
                    state.gestureMIDINote = nil
                    state.swipeProgress = 0
                    state.swipeDirection = nil
                    state.gestureLocked = true
                    didChangeVisibleState = true
                }

                touchStates[identifier] = state
                continue
            }

            let activeMIDINote = state.currentMIDINote
            if state.gestureMIDINote == nil,
               droneModeEnabled,
               let activeMIDINote,
               isDroneGestureTracking(point: point, state: state, midiNote: activeMIDINote) {
                state.gestureMIDINote = activeMIDINote
            }

            let hitMIDINote = state.gestureMIDINote ?? midiNote(at: point)

            if hitMIDINote != activeMIDINote {
                if activeMIDINote != nil, hitMIDINote != nil {
                    state.hasTraversedOtherNote = true
                }
                state.swipeProgress = 0
                state.swipeDirection = nil

                if let activeMIDINote, let token = state.token {
                    deactivateNote(activeMIDINote)
                    noteOff?(token)
                    didChangeVisibleState = true
                }

                if let hitMIDINote, isNoteLatched(hitMIDINote) {
                    state.currentMIDINote = nil
                    state.controlledLatchedMIDINote = hitMIDINote
                    state.beganMIDINote = hitMIDINote
                    state.gestureMIDINote = hitMIDINote
                    state.beganPoint = point
                } else if let hitMIDINote {
                    let token = state.token ?? allocateToken()
                    state.token = token
                    state.currentMIDINote = hitMIDINote
                    state.beganMIDINote = hitMIDINote
                    state.gestureMIDINote = nil
                    state.beganPoint = point
                    activateNote(hitMIDINote)
                    noteOn?(token, hitMIDINote)
                    didChangeVisibleState = true
                } else {
                    state.currentMIDINote = nil
                    state.beganMIDINote = nil
                    state.gestureMIDINote = nil
                }

                touchStates[identifier] = state
                continue
            }

            guard droneModeEnabled, let activeMIDINote else {
                touchStates[identifier] = state
                continue
            }

            let gesture = droneGesture(for: point, state: state, midiNote: activeMIDINote)
            state.swipeProgress = gesture?.progress ?? 0
            state.swipeDirection = gesture?.direction

            if let gesture, gesture.progress >= 1 {
                latchNote(activeMIDINote, using: &state)
                didChangeVisibleState = true
            }

            touchStates[identifier] = state
        }

        if didChangeVisibleState || touchStates.values.contains(where: { $0.swipeProgress > 0 }) {
            setNeedsDisplay()
        }
    }

    private func endTouches(_ touches: Set<UITouch>) {
        var didChangeVisibleState = false

        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            guard let state = touchStates.removeValue(forKey: identifier) else {
                continue
            }

            if let activeMIDINote = state.currentMIDINote, let token = state.token {
                deactivateNote(activeMIDINote)
                noteOff?(token)
                didChangeVisibleState = true
            }
        }

        if didChangeVisibleState || !touches.isEmpty {
            setNeedsDisplay()
        }
    }

    private func allocateToken() -> Int {
        let token = nextToken
        nextToken += 1
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

    private func keyFrame(for midiNote: Int) -> PianoKeyFrame? {
        currentFrames.blackKeys.first(where: { $0.key.midiNote == midiNote }) ??
            currentFrames.whiteKeys.first(where: { $0.key.midiNote == midiNote })
    }

    private func activateNote(_ midiNote: Int) {
        activeNoteCounts[midiNote, default: 0] += 1
    }

    private func deactivateNote(_ midiNote: Int) {
        let remainingCount = (activeNoteCounts[midiNote] ?? 1) - 1
        if remainingCount <= 0 {
            activeNoteCounts.removeValue(forKey: midiNote)
        } else {
            activeNoteCounts[midiNote] = remainingCount
        }
    }

    private func latchNote(_ midiNote: Int, using state: inout TouchState) {
        guard let token = state.token else {
            return
        }

        deactivateNote(midiNote)
        latchedNoteTokens[midiNote] = token
        state.token = nil
        state.currentMIDINote = nil
        state.controlledLatchedMIDINote = midiNote
        state.beganMIDINote = nil
        state.gestureMIDINote = midiNote
        state.swipeProgress = 0
        state.swipeDirection = nil
        state.gestureLocked = true
        notifyLatchedNotesChanged()
    }

    private func unlatchNote(_ midiNote: Int) {
        guard let token = latchedNoteTokens.removeValue(forKey: midiNote) else {
            return
        }

        noteOff?(token)
        notifyLatchedNotesChanged()
    }

    private func clearLatchedNotes() {
        let tokens = Array(latchedNoteTokens.values)
        latchedNoteTokens.removeAll(keepingCapacity: true)

        for token in tokens {
            noteOff?(token)
        }

        for identifier in touchStates.keys {
            var state = touchStates[identifier] ?? TouchState()
            state.controlledLatchedMIDINote = nil
            state.gestureLocked = false
            state.gestureMIDINote = nil
            state.swipeProgress = 0
            state.swipeDirection = nil
            touchStates[identifier] = state
        }

        notifyLatchedNotesChanged()
        setNeedsDisplay()
    }

    private func notifyLatchedNotesChanged() {
        latchedNotesChanged?(latchedNoteTokens.keys.sorted())
    }

    private func isNoteLatched(_ midiNote: Int) -> Bool {
        latchedNoteTokens[midiNote] != nil
    }

    private func swipeVisualization(for midiNote: Int) -> SwipeVisualization? {
        touchStates.values
            .compactMap { state -> SwipeVisualization? in
                guard state.swipeProgress > 0 else {
                    return nil
                }

                let matchesActiveNote = state.currentMIDINote == midiNote
                let matchesControlledLatchedNote = state.controlledLatchedMIDINote == midiNote

                guard matchesActiveNote || matchesControlledLatchedNote, let direction = state.swipeDirection else {
                    return nil
                }

                return SwipeVisualization(progress: state.swipeProgress, direction: direction)
            }
            .max(by: { $0.progress < $1.progress })
    }

    private func droneGesture(for point: CGPoint, state: TouchState, midiNote: Int) -> SwipeVisualization? {
        guard isDroneGestureTracking(point: point, state: state, midiNote: midiNote),
              let keyFrame = keyFrame(for: midiNote) else {
            return nil
        }

        let translation = CGPoint(x: point.x - state.beganPoint.x, y: point.y - state.beganPoint.y)
        let verticalDistance = abs(translation.y)
        let horizontalDistance = abs(translation.x)

        guard verticalDistance > 6, verticalDistance > (horizontalDistance * 1.15) else {
            return nil
        }

        let threshold = min(max(keyFrame.frame.height * 0.22, 28), 64)
        let progress = min(verticalDistance / threshold, 1)
        let direction: SwipeDirection = translation.y < 0 ? .towardTop : .towardBottom
        return SwipeVisualization(progress: progress, direction: direction)
    }

    private func isDroneGestureTracking(point: CGPoint, state: TouchState, midiNote: Int) -> Bool {
        guard state.beganMIDINote == midiNote, !state.hasTraversedOtherNote else {
            return false
        }

        let translation = CGPoint(x: point.x - state.beganPoint.x, y: point.y - state.beganPoint.y)
        let verticalDistance = abs(translation.y)
        let horizontalDistance = abs(translation.x)
        return verticalDistance > 6 && verticalDistance > (horizontalDistance * 1.15)
    }

    private func activePath(for cachedKey: CachedKey, swipe: SwipeVisualization?) -> CGPath {
        guard let swipe else {
            return cachedKey.path
        }

        let frame = visualFrame(for: cachedKey.keyFrame.frame, swipe: swipe)
        return CGPath(
            roundedRect: frame.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: 4,
            cornerHeight: 4,
            transform: nil
        )
    }

    private func visualFrame(for frame: CGRect, swipe: SwipeVisualization) -> CGRect {
        let retraction = frame.height * 0.28 * swipe.progress
        let adjustedHeight = max(frame.height - retraction, frame.height * 0.62)

        switch swipe.direction {
        case .towardTop:
            return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: adjustedHeight)
        case .towardBottom:
            return CGRect(x: frame.minX, y: frame.maxY - adjustedHeight, width: frame.width, height: adjustedHeight)
        }
    }

    private func fillColor(for midiNote: Int, palette: KeyboardPalette, isBlack: Bool) -> UIColor {
        if isNoteLatched(midiNote) {
            return isBlack ? palette.blackLatched : palette.whiteLatched
        }

        if activeNoteCounts[midiNote] != nil {
            return isBlack ? palette.blackPressed : palette.whitePressed
        }

        return isBlack ? palette.blackKey : palette.whiteKey
    }

    private static func cachedKey(for keyFrame: PianoKeyFrame) -> CachedKey {
        let insetFrame = keyFrame.frame.insetBy(dx: 0.5, dy: 0.5)
        let path = CGPath(
            roundedRect: insetFrame,
            cornerWidth: 4,
            cornerHeight: 4,
            transform: nil
        )

        return CachedKey(keyFrame: keyFrame, path: path)
    }
}

private struct KeyboardPalette {
    let background: UIColor
    let whiteKey: UIColor
    let whitePressed: UIColor
    let whiteLatched: UIColor
    let whiteBorder: UIColor
    let blackKey: UIColor
    let blackPressed: UIColor
    let blackLatched: UIColor

    init(traits: UITraitCollection) {
        if traits.userInterfaceStyle == .dark {
            background = UIColor(white: 0.10, alpha: 1)
            whiteKey = UIColor(white: 0.92, alpha: 1)
            whitePressed = UIColor(red: 0.78, green: 0.88, blue: 1.0, alpha: 1)
            whiteLatched = UIColor(red: 0.60, green: 0.79, blue: 1.0, alpha: 1)
            whiteBorder = UIColor(white: 0.18, alpha: 1)
            blackKey = UIColor(white: 0.04, alpha: 1)
            blackPressed = UIColor(red: 0.14, green: 0.37, blue: 0.68, alpha: 1)
            blackLatched = UIColor(red: 0.19, green: 0.48, blue: 0.86, alpha: 1)
        } else {
            background = UIColor(white: 0.84, alpha: 1)
            whiteKey = .white
            whitePressed = UIColor(red: 0.76, green: 0.88, blue: 1.0, alpha: 1)
            whiteLatched = UIColor(red: 0.62, green: 0.82, blue: 1.0, alpha: 1)
            whiteBorder = UIColor(white: 0.20, alpha: 1)
            blackKey = UIColor(white: 0.08, alpha: 1)
            blackPressed = UIColor(red: 0.19, green: 0.40, blue: 0.74, alpha: 1)
            blackLatched = UIColor(red: 0.16, green: 0.45, blue: 0.84, alpha: 1)
        }
    }
}
