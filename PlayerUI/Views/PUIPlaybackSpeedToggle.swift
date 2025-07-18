import SwiftUI
import AVFoundation

final class PUIPlaybackSpeedToggle: NSView, ObservableObject {

    @Published var speed: PUIPlaybackSpeed = .normal

    @Published var isEnabled = true

    @Published var isEditingCustomSpeed = false

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

    fileprivate func customizeSpeed(with rate: Float) {
        if let standardSpeed = PUIPlaybackSpeed.all.first(where: { $0.rawValue == rate }) {
            self.speed = standardSpeed
        } else {
            self.speed = .custom(rate: rate)
        }
    }

}

private struct PlaybackSpeedToggle: View {
    @EnvironmentObject private var controller: PUIPlaybackSpeedToggle

    @State private var customSpeedValue: Double = 1

    @State private var customSpeedInvalid = false

    @FocusState private var speedFieldFocused: Bool

    @Namespace private var transition

    /// Transition for custom speed UI doesn't work well in older OS versions.
    private var customSpeedTransitionEnabled: Bool {
        guard #available(macOS 14.0, *) else { return false }
        return true
    }

    var body: some View {
        ZStack {
            shape
                .fill(.tertiary)
                .opacity(controller.isEditingCustomSpeed ? 1 : 0)

            shape
                .strokeBorder(controller.isEditingCustomSpeed ? .primary : .secondary, lineWidth: 1)

            if controller.isEditingCustomSpeed {
                customSpeedEditor
            } else {
                toggleButton
            }
        }
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        .frame(width: 40, height: 20)
        .buttonStyle(.playerControlStatic)
        .contentShape(shape)
        .overlay {
            if controller.isEditingCustomSpeed, customSpeedInvalid {
                Color.red
                    .blendMode(.plusDarker)
                    .opacity(0.5)
            }
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(controller.isEditingCustomSpeed ? 0.1 : 0), radius: 2)
        .scaleEffect(customSpeedTransitionEnabled && controller.isEditingCustomSpeed ? 1.4 : 1)
        .animation(controller.isEditingCustomSpeed ? .bouncy : .smooth, value: customSpeedTransitionEnabled ? controller.isEditingCustomSpeed : false)
        .animation(.linear, value: customSpeedInvalid)
        .contextMenu {
            Group {
                menuContents
            }
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
        }
        .disabled(!controller.isEnabled)
        .onChange(of: speedFieldFocused) { _, fieldFocused in
            if !fieldFocused {
                controller.isEditingCustomSpeed = false
            }
        }
    }

    @ViewBuilder
    private var toggleButton: some View {
        Button {
            if NSEvent.modifierFlags.contains(.shift) {
                controller.speed = controller.speed.previous
            } else {
                controller.speed = controller.speed.next
            }
        } label: {
            ZStack {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(controller.speed.buttonTitle)
                        .numericContentTransition(value: Double(controller.speed.rawValue))
                    Text("×")
                }
                .matchedGeometryEffect(id: "text", in: transition)
                .foregroundStyle(.primary)
                .animation(.smooth, value: controller.speed)
            }
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var menuContents: some View {
        ForEach(PUIPlaybackSpeed.all) { option in
            Toggle(option.localizedDescription, isOn: controller.toggleBinding(for: option))
        }

        Divider()

        if controller.speed.isCustom {
            Toggle(controller.speed.localizedDescription, isOn: controller.toggleBinding(for: controller.speed))
        }

        Button {
            customSpeedValue = Double(controller.speed.rawValue)
            controller.isEditingCustomSpeed = true
            speedFieldFocused = true
        } label: {
            Text(controller.speed.isCustom ? "Edit…" : "Custom…")
        }
    }

    @ViewBuilder
    private var customSpeedEditor: some View {
        TextField("Speed", value: $customSpeedValue, formatter: PUIPlaybackSpeed.buttonTitleFormatter)
            .matchedGeometryEffect(id: "text", in: transition)
            .textFieldStyle(.plain)
            .onEscapePressed { speedFieldFocused = false }
            .multilineTextAlignment(.center)
            .focused($speedFieldFocused)
            .onSubmit {
                let value = Float(customSpeedValue)

                guard PUIPlaybackSpeed.validateCustomSpeed(value) else {
                    customSpeedInvalid = true
                    return
                }

                controller.customizeSpeed(with: value)

                speedFieldFocused = false
                controller.isEditingCustomSpeed = false
            }
            .onChange(of: customSpeedValue) {
                customSpeedInvalid = false
            }
    }

    private var shape: some InsettableShape {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }
}

private extension View {
    @ViewBuilder
    func onEscapePressed(perform action: @escaping () -> Void) -> some View {
        /// This ugly hack was the only way I could find to get the escape key event
        ///  so that the custom speed field can be dismissed by pressing escape.
        background {
            Button {
                action()
            } label: {
                Text("")
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .accessibilityHidden(true)
        }
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
struct PUIPlaybackSpeedToggle_Previews: PreviewProvider {
    static var previews: some View { PUIPlayerView_Previews.previews }
}
#endif
