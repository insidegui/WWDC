import SwiftUI
import AVFoundation

final class PUIPlaybackSpeedToggle: NSView, ObservableObject {

    @Published var speed: PUIPlaybackSpeed = .normal

    @Published var isEnabled = true

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setup() {
        wantsLayer = true

        let host = NSHostingView(rootView: PlaybackSpeedToggle().environmentObject(self))
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)

        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    fileprivate func toggleBinding(for option: PUIPlaybackSpeed) -> Binding<Bool> {
        .init { [weak self] in
            option == self?.speed
        } set: { [weak self] newValue in
            guard newValue else { return }
            self?.speed = option
        }
    }

}

private struct PlaybackSpeedToggle: View {
    @EnvironmentObject private var controller: PUIPlaybackSpeedToggle

    var body: some View {
        Button {
            if NSEvent.modifierFlags.contains(.shift) {
                controller.speed = controller.speed.previous
            } else {
                controller.speed = controller.speed.next
            }
        } label: {
            ZStack {
                shape
                    .stroke(.secondary, lineWidth: 1)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(controller.speed.buttonTitle)
                        .numericContentTransition(value: Double(controller.speed.rawValue))
                    Text("×")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .animation(.smooth, value: controller.speed)
            }
            .monospacedDigit()
            .frame(width: 40, height: 20)
        }
        .contentShape(Rectangle())
        .buttonStyle(.playerControlStatic)
        .contentShape(shape)
        .contextMenu {
            ForEach(PUIPlaybackSpeed.all) { option in
                Toggle(option.localizedDescription, isOn: controller.toggleBinding(for: option))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
        }
        .disabled(!controller.isEnabled)
    }

    private var shape: some InsettableShape {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }
}

private struct PUIControlButtonStyle: ButtonStyle {
    var animatePress = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                Rectangle()
                    .foregroundStyle(Color.black)
                    .blendMode(.plusDarker)
                    .mask(configuration.label)
                    .opacity(configuration.isPressed ? 0.2 : 0)
            }
            .scaleEffect(animatePress && configuration.isPressed ? 0.9 : 1)
            .animation(animatePress ? .spring() : .linear(duration: 0), value: configuration.isPressed)
    }
}

private extension ButtonStyle where Self == PUIControlButtonStyle {
    static var playerControl: Self { PUIControlButtonStyle() }
    static var playerControlStatic: Self { PUIControlButtonStyle(animatePress: false) }
}

#if DEBUG
struct PUIPlaybackSpeedToggle_Previews: PreviewProvider, View {
    @State var speed: PUIPlaybackSpeed = .normal

    static var previews: some View {
        Self()
    }

    var body: some View {
        PlaybackSpeedToggle()
            .padding()
            .environmentObject(PUIPlaybackSpeedToggle(frame: .zero))
    }
}
#endif
