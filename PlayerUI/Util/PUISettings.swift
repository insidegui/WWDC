import SwiftUI

final class PUISettings: ObservableObject {
    @AppStorage("trailingLabelDisplaysDuration")
    var trailingLabelDisplaysDuration = false

    @AppStorage("playerVolume")
    var playerVolume: Double = 1

    @AppStorage("playbackRate")
    var playbackRate: Double = Double(PUIPlaybackSpeed.normal.rawValue)
}
