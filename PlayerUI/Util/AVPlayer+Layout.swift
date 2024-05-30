import Cocoa
import AVFoundation

@MainActor
public extension AVPlayer {
    func layoutRect(with bounds: CGRect) -> CGRect? {
        guard let videoTrack = currentItem?.tracks.first(where: { $0.assetTrack?.mediaType == .video })?.assetTrack else { return nil }

        let videoRect = AVMakeRect(aspectRatio: videoTrack.naturalSize, insideRect: bounds)

        guard videoRect.width.isFinite, videoRect.height.isFinite else { return nil }

        return videoRect
    }

    func updateLayout(guide: NSLayoutGuide, container: NSView, constraints: inout [NSLayoutConstraint]) {
        guard let videoRect = layoutRect(with: container.bounds) else { return }

        if guide.owningView == nil {
            container.addLayoutGuide(guide)
        }

        NSLayoutConstraint.deactivate(constraints)

        constraints = [
            guide.widthAnchor.constraint(equalToConstant: videoRect.width),
            guide.heightAnchor.constraint(equalToConstant: videoRect.height),
            guide.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            guide.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ]

        NSLayoutConstraint.activate(constraints)
    }
}
