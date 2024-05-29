import SwiftUI

final class PUISettings: ObservableObject {
    @AppStorage("trailingLabelDisplaysDuration")
    var trailingLabelDisplaysDuration = false

    @AppStorage("playerVolume")
    var playerVolume: Double = 1
}
