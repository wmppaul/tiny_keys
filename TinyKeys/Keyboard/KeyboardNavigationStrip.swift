import SwiftUI

struct KeyboardNavigationStrip: View {
    let layout: PianoKeyboardLayout
    @Binding var visibleWhiteStart: CGFloat
    let visibleWhiteCount: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let totalWhiteCount = CGFloat(layout.whiteKeyCount)
            let whiteWidth = geometry.size.width / max(totalWhiteCount, 1)
            let windowWidth = max(geometry.size.width * (visibleWhiteCount / totalWhiteCount), 18)
            let clampedStart = layout.clampVisibleStart(visibleWhiteStart, visibleWhiteCount: visibleWhiteCount)
            let windowOffset = geometry.size.width * (clampedStart / totalWhiteCount)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(stripBackground)

                Canvas { context, size in
                    for key in layout.whiteKeys {
                        let x = CGFloat(key.whiteIndex) * whiteWidth
                        let frame = CGRect(x: x, y: 2, width: max(whiteWidth - 0.5, 0.5), height: size.height - 4)
                        context.fill(Path(frame), with: .color(whiteKeyColor))
                    }

                    for key in layout.blackKeys {
                        let center = (CGFloat(key.whiteIndex) + key.blackCenterOffset) * whiteWidth
                        let frame = CGRect(
                            x: center - ((whiteWidth * 0.46) / 2),
                            y: 2,
                            width: max(whiteWidth * 0.46, 1),
                            height: size.height * 0.56
                        )
                        context.fill(RoundedRectangle(cornerRadius: 2).path(in: frame), with: .color(blackKeyColor))
                    }
                }

                RoundedRectangle(cornerRadius: 7)
                    .fill(accentColor.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(accentColor.opacity(0.95), lineWidth: 1.25)
                    )
                    .frame(width: min(windowWidth, geometry.size.width))
                    .offset(x: min(max(0, windowOffset), max(geometry.size.width - windowWidth, 0)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let rawStart = ((value.location.x - (windowWidth / 2)) / max(geometry.size.width, 1)) * totalWhiteCount
                        visibleWhiteStart = layout.clampVisibleStart(rawStart, visibleWhiteCount: visibleWhiteCount)
                    }
            )
        }
    }

    private var stripBackground: Color {
        Color(uiColor: .secondarySystemFill)
    }

    private var whiteKeyColor: Color {
        Color(uiColor: .systemBackground)
    }

    private var blackKeyColor: Color {
        Color(uiColor: .label)
    }

    private var accentColor: Color {
        Color(red: 0.137, green: 0.431, blue: 0.773)
    }
}
