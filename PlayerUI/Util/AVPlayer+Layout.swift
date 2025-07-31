import Cocoa
import AVFoundation
import ConfUIFoundation

@MainActor
public extension AVPlayer {
    static let fallbackNaturalSize = CGSize(width: 1920, height: 1080)

    func fittingRect(with bounds: CGRect) -> CGRect {
        let videoSize = currentItem?.tracks.first(where: { $0.assetTrack?.mediaType == .video })?.assetTrack?.naturalSize ?? Self.fallbackNaturalSize

        let fittingRect = AVMakeRect(aspectRatio: videoSize, insideRect: bounds)

        UILog("📐 Video size: \(videoSize), fitting size: \(fittingRect.size)")

        return fittingRect
    }

    func updateLayout(guide: NSLayoutGuide, container: NSView, constraints: inout [NSLayoutConstraint]) {
        let videoRect = fittingRect(with: container.bounds)

        if guide.owningView == nil {
            container.addLayoutGuide(guide)
        }

        NSLayoutConstraint.deactivate(constraints)

        constraints = [
            guide.widthAnchor.constraint(equalToConstant: videoRect.width),
            guide.heightAnchor.constraint(equalToConstant: videoRect.height),
            guide.centerYAnchor.constraint(equalTo: container.safeAreaLayoutGuide.centerYAnchor),
            guide.centerXAnchor.constraint(equalTo: container.safeAreaLayoutGuide.centerXAnchor)
        ]

        NSLayoutConstraint.activate(constraints)
    }
}
