import SwiftUI
import PlayerUI

struct LiveStreamOverlay: View {
    var item: ExploreTabContent.Item
    var onClose: () -> Void = { }

    @State private var playbackURL: URL?

    var body: some View {
        VStack(spacing: 22) {
            header

            video

            if item.canShowCountdown, let stream = item.liveStream {
                EventCountdown(stream: stream)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
        .overlay(alignment: .topLeading) { closeButton }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 8) {
            Text(item.title)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
    }

    @ViewBuilder
    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(.circular)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel(Text("Close"))
    }

    @ViewBuilder
    private var video: some View {
        ZStack {
            if let playbackURL {
                VideoPlayer(url: playbackURL)
                    .frame(maxWidth: 900, maxHeight: 500)
            } else if let url = item.imageURL {
                RemoteImage(url: url, size: .large) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .blendMode(item.liveStream?.url == nil ? .plusLighter : .normal)
                        .saturation(canStartPlayback ? 2 : 1)
                        .blur(radius: canStartPlayback ? 32 : 0)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .foregroundColor(.black)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if !isShowingVideoPlayer, let streamURL = item.liveStream?.url {
                Button {
                    playbackURL = streamURL
                } label: {
                    Image(systemName: "play")
                        .padding(18)
                }
                .symbolVariant(.fill)
                .font(.system(size: 50, weight: .semibold, design: .rounded))
                .buttonStyle(.circular)
            }
        }
        .overlay(alignment: .bottom) {
            if canStartPlayback, !isShowingVideoPlayer {
                Text("Live")
                    .textCase(.uppercase)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.8), in: Capsule(style: .continuous))
                    .blendMode(.plusLighter)
                    .padding(.bottom)
            }
        }
        .frame(maxWidth: 900, maxHeight: 500)
        .animation(.default, value: canStartPlayback)
        .animation(.default, value: isShowingVideoPlayer)
    }

    private var isShowingVideoPlayer: Bool { playbackURL != nil }
    private var canStartPlayback: Bool { item.liveStream?.url != nil }
}

private extension ExploreTabContent.Item {
    var canShowCountdown: Bool {
        guard let liveStream else { return false }
        let interval = liveStream.startTime.timeIntervalSince(today())
        // Hide countdown if less than a minute remaining
        guard interval >= 60 else { return false }
        // Hide countdown if more than 24 hours remaining
        guard interval < 24 * 60 * 60 else { return false }
        return true
    }
}

private struct EventCountdown: View {
    var stream: ExploreTabContent.Item.LiveStream

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let str = countdownString(for: stream.startTime, from: today())
            Text(str)
        }
    }

    func countdownString(for date: Date, from refDate: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar
            .dateComponents([.hour, .minute],
                            from: refDate,
                            to: date)

        var output = ""

        let prefix = "Event starts in"

        if let hour = components.hour, hour > 0 {
            if hour > 1 {
                output = "\(prefix) \(hour) hours"
            } else {
                output = "\(prefix) \(hour) hour"
            }
        } else {
            output = "\(prefix)"
        }

        if let minute = components.minute, minute > 0 {
            if minute > 1 {
                output += " \(minute) minutes"
            } else {
                output += " \(minute) minute"
            }
        }

        return output
    }
}

struct CircularButtonStyle: ButtonStyle {
    @Environment(\.font)
    private var font

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font ?? .system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(8)
            .background(Material.thin, in: Circle())
            .overlay {
                if configuration.isPressed {
                    Rectangle()
                        .foregroundStyle(.quaternary)
                        .clipShape(Circle())
                }
            }
            .padding()
    }
}

extension ButtonStyle where Self == CircularButtonStyle {
    static var circular: Self { CircularButtonStyle() }
}

#if DEBUG
struct LiveStreamOverlay_Previews: PreviewProvider {
    static var previews: some View {
        LiveStreamOverlay(item: ExploreTabContent.previewLiveCurrent.liveEventItem!)
    }
}
#endif
