import SwiftUI
import AVFoundation
import Combine

struct PUIPlayerViewControls: View {
    @EnvironmentObject private var controller: PUIPlayerView

    var body: some View {
        PUIPlayerViewControlsContent(state: $controller.state)
    }
}

private extension PUIPlayerView.State {
    var durationInSeconds: Double { Double(CMTimeGetSeconds(duration)) }
    var currentTimeInSeconds: Double { Double(CMTimeGetSeconds(currentTime)) }

    func startFraction(for segment: PUIBufferSegment) -> Double {
        guard durationInSeconds > 0 else { return 0 }
        return segment.start / durationInSeconds
    }

    func durationFraction(for segment: PUIBufferSegment) -> Double {
        guard durationInSeconds > 0 else { return 0 }
        return (segment.duration - segment.start) / durationInSeconds
    }

    var volumeSymbolName: String {
        switch volume {
        case 0:
            return "speaker"
        case 0...0.3:
            return "speaker.wave.1.fill"
        case 0.3...0.7:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }

    var canChangePlaybackState: Bool { [.playing, .paused].contains(playbackState) }

    mutating func togglePlaying() {
        guard canChangePlaybackState else { return }

        if playbackState == .playing {
            playbackState = .paused
        } else {
            playbackState = .playing
        }
    }
}

private struct PUIPlayerViewControlsContent: View {
    @Binding var state: PUIPlayerView.State

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                HStack {
                    timeLabel(for: \.formattedCurrentTime)

                    timeline

                    timeLabel(for: \.formattedTimeRemaining)
                }

                centerButtons
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) { audioControls }
            }
            .padding()
            .frame(minWidth: 360, maxWidth: 500)
            .background(Material.thin, in: shape)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private func timeLabel(for value: KeyPath<PUIPlayerView.State, String>) -> some View {
        Text(state[keyPath: value])
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var timeline: some View {
        GeometryReader { proxy in
            ZStack {
                Capsule(style: .continuous)
                    .foregroundStyle(.quaternary)
                let segments = Array(state.bufferedSegments)
                ForEach(segments.indices, id: \.self) { i in
                    let segment = segments[i]
                    Capsule(style: .continuous)
                        .foregroundStyle(.tertiary)
                        .frame(width: proxy.size.width * state.durationFraction(for: segment))
                        .offset(x: proxy.size.width * state.startFraction(for: segment))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Capsule(style: .continuous)
                    .foregroundStyle(Color.white)
                    .frame(width: proxy.size.width * state.playbackProgress)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
    }

    @ViewBuilder
    private var centerButtons: some View {
        HStack(spacing: 12) {
            if state.has(.back) {
                Button {

                } label: {
                    Image(systemName: "gobackward.\(state.backForwardSkipInterval)")
                        .imageScale(.large)
                }
                .buttonStyle(.playerControl)
            }

            Button {
                state.togglePlaying()
            } label: {
                ZStack {
                    switch state.playbackState {
                    case .idle, .paused:
                        Image(systemName: "play")
                            .transition(.scale.combined(with: .opacity))
                    case .stalled:
                        ProgressView()
                            .controlSize(.small)
                    case .playing:
                        Image(systemName: "pause")
                            .transition(.scale.combined(with: .opacity))
                    }

                }
                    .imageScale(.large)
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.5), value: state.playbackState)
            }
            .buttonStyle(.playerControl)
            .frame(width: 32, height: 32)

            if state.has(.forward) {
                Button {

                } label: {
                    Image(systemName: "goforward.\(state.backForwardSkipInterval)")
                        .imageScale(.large)
                }
                .buttonStyle(.playerControl)
            }
        }
        .symbolVariant(.fill)
        .disabled(!state.canChangePlaybackState)
    }

    @ViewBuilder
    private var audioControls: some View {
        HStack {
            Image(systemName: state.volumeSymbolName)
                .symbolVariant(.fill)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .frame(width: 22, alignment: .leading)
                .foregroundStyle(.secondary)

            Slider(value: $state.volume, in: 0...1)
                .controlSize(.mini)
                .frame(maxWidth: 80)
        }
    }

    private var shape: some InsettableShape {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }
}

extension PUIPlaybackSpeed: View {
    public var body: some View {
        switch self {
        case .slow:
            <#code#>
        case .normal:
            <#code#>
        case .midFast:
            <#code#>
        case .fast:
            <#code#>
        case .faster:
            <#code#>
        case .fastest:
            <#code#>
        }
    }
}

struct PUIControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                Rectangle()
                    .foregroundStyle(Color.black)
                    .blendMode(.plusDarker)
                    .mask(configuration.label)
                    .opacity(configuration.isPressed ? 0.2 : 0)
            }
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PUIControlButtonStyle {
    static var playerControl: Self { PUIControlButtonStyle() }
}

#if DEBUG
struct PUIPlayerViewControlsContent_Previews: PreviewProvider, View {
    static var previews: some View { Self() }

    @State private var playerState = PUIPlayerView.State(
        currentTime: CMTimeMakeWithSeconds(300, preferredTimescale: 9000),
        duration: CMTimeMakeWithSeconds(900, preferredTimescale: 9000),
        formattedCurrentTime: "05:00",
        formattedTimeRemaining: "-10:00",
        playbackProgress: 0.3,
        isPiPAvailable: true,
        playbackState: .paused,
        speed: .normal,
        volume: 0.6,
        subtitles: nil,
        bufferedSegments: [.init(start: 60, duration: 360)],
        features: Set(PUIPlayerView.State.Feature.allCases),
        backForwardSkipInterval: 15)

    var body: some View {
        ZStack {
            Image("PreviewFrame", bundle: .playerUI)
                .resizable()
                .aspectRatio(contentMode: .fill)

            PUIPlayerViewControlsContent(state: $playerState)
        }
        .frame(width: 640, height: 360)
    }
}
#endif