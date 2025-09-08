import SwiftUI
import AVFoundation
import AVKit

struct VideoPlayer: NSViewRepresentable {
    var url: URL
    private var player: AVPlayer

    init(url: URL) {
        self.url = url
        self.player = AVPlayer(url: url)
    }

    typealias NSViewType = AVPlayerView

    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.allowsPictureInPicturePlayback = true
        v.showsFullScreenToggleButton = true
        v.controlsStyle = .floating
        player.play()
        return v
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {

    }
}

#if DEBUG
struct VideoPlayer_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayer(url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!)
    }
}
#endif
