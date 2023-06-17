import SwiftUI

typealias HoverChangeBlock = (CGPoint?) -> Void

extension View {
    func onHoverWithPosition(perform block: @escaping HoverChangeBlock) -> some View {
        modifier(HoverPositionModifier(onHoverChange: block))
    }
}

private struct HoverPositionModifier: ViewModifier {
    var onHoverChange: HoverChangeBlock

    init(onHoverChange: @escaping HoverChangeBlock) {
        self.onHoverChange = onHoverChange
    }

    func body(content: Content) -> some View {
        content
            .background {
                _HoverPositionModifierView(onHoverChange: onHoverChange)
            }
    }
}

private struct _HoverPositionModifierView: NSViewRepresentable {
    typealias NSViewType = _HoverNSView

    var onHoverChange: HoverChangeBlock

    func makeNSView(context: Context) -> _HoverNSView {
        let v = _HoverNSView(frame: .zero)
        v.onHoverChange = onHoverChange
        return v
    }

    func updateNSView(_ nsView: _HoverNSView, context: Context) {

    }

    final class _HoverNSView: NSView {
        var onHoverChange: HoverChangeBlock = { _ in }

        private var hoverArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            if let hoverArea {
                removeTrackingArea(hoverArea)
                self.hoverArea = nil
            }

            let area = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
            addTrackingArea(area)
            self.hoverArea = area
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            window?.acceptsMouseMovedEvents = true
        }

        private var mouseInside = false {
            didSet {
                guard mouseInside != oldValue else { return }
                if !mouseInside { self.onHoverChange(nil) }
            }
        }

        override func mouseMoved(with event: NSEvent) {
            let p = convert(event.locationInWindow, from: nil)

            guard mouseInside, hitTest(p) == self else {
                self.onHoverChange(nil)
                return
            }

            let relativePoint = CGPoint(x: p.x / bounds.width, y: p.y / bounds.height)

            self.onHoverChange(relativePoint)
        }

        override func mouseEntered(with event: NSEvent) {
            mouseInside = true
        }

        override func mouseExited(with event: NSEvent) {
            mouseInside = false
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard NSApp.currentEvent?.type == .mouseMoved else { return nil }
            return super.hitTest(point)
        }
    }
}

#if DEBUG
struct HoverPositionModifier_Previews: PreviewProvider, View {
    static var previews: some View {
        Self()
    }

    @State private var hoverPoint: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .foregroundColor(.red)
                    .modifier(HoverPositionModifier(onHoverChange: { point in
                        hoverPoint = point
                    }))
                    .onTapGesture {
                        print("TAP")
                    }
                    .gesture(DragGesture(minimumDistance: 0).onChanged { _ in
                        print("DRAG")
                    })

                if let hoverPoint {
                    Rectangle()
                        .foregroundColor(.blue)
                        .frame(width: proxy.size.width * hoverPoint.x, alignment: .leading)
                        .transition(.opacity)
                }
            }
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .frame(width: 230, height: 22, alignment: .leading)
        .clipShape(Capsule())
        .padding()
        .frame(minWidth: 230, maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
    }
}
#endif
