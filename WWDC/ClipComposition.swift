//
//  ClipComposition.swift
//  WWDC
//
//  Created by Guilherme Rambo on 02/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import CoreMedia
import CoreImage.CIFilterBuiltins

final class ClipComposition: AVMutableComposition {

    private struct Constants {
        static let minBoxWidth: CGFloat = 325
        static let maxBoxWidth: CGFloat = 600
        static let boxPadding: CGFloat = 42
    }

    let title: String
    let subtitle: String
    let video: AVAsset
    let includeBanner: Bool

    var videoComposition: AVMutableVideoComposition?

    init(video: AVAsset, title: String, subtitle: String, includeBanner: Bool) throws {
        self.video = video
        self.title = title
        self.subtitle = subtitle
        self.includeBanner = includeBanner

        super.init()

        guard let newVideoTrack = addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            // Should this ever fail in real life? Who knows...
            preconditionFailure("Failed to add video track to composition")
        }

        if let videoTrack = video.tracks(withMediaType: .video).first {
            try newVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: video.duration), of: videoTrack, at: .zero)
        }

        if let newAudioTrack = addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            if let audioTrack = video.tracks(withMediaType: .audio).first {
                try newAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: video.duration), of: audioTrack, at: .zero)
            }
        }

        configureCompositionIfNeeded(videoTrack: newVideoTrack)
    }

    private func configureCompositionIfNeeded(videoTrack: AVMutableCompositionTrack) {
        guard includeBanner else { return }

        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: video.duration)

        let videolayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        mainInstruction.layerInstructions = [videolayerInstruction]

        videoComposition = AVMutableVideoComposition(propertiesOf: video)
        videoComposition?.instructions = [mainInstruction]

        composeTemplate(with: videoTrack.naturalSize)
    }

    private func composeTemplate(with renderSize: CGSize) {
        guard let asset = CALayer.load(assetNamed: "ClipTemplate") else {
            fatalError("Missing ClipTemplate asset")
        }
        guard let assetContainer = asset.sublayer(named: "container", of: CALayer.self) else {
            fatalError("Missing container layer")
        }
        guard let box = assetContainer.sublayer(named: "box", of: CALayer.self) else {
            fatalError("Missing box layer")
        }
        guard let titleLayer = box.sublayer(named: "sessionTitle", of: CATextLayer.self) else {
            fatalError("Missing sessionTitle layer")
        }
        guard let subtitleLayer = box.sublayer(named: "eventName", of: CATextLayer.self) else {
            fatalError("Missing sessionTitle layer")
        }
        guard let videoLayer = assetContainer.sublayer(named: "video", of: CALayer.self) else {
            fatalError("Missing video layer")
        }

        if let iconLayer = box.sublayer(named: "appicon", of: CALayer.self) {
            iconLayer.contents = NSApp.applicationIconImage
        }

        // Add a NSVisualEffectView-like blur to the box.

        let blur = CIFilter.gaussianBlur()
        blur.radius = 22

        let saturate = CIFilter.colorControls()
        saturate.setDefaults()
        saturate.saturation = 1.5

        box.backgroundFilters = [saturate, blur]
        box.masksToBounds = true

        // Set text on layers.

        titleLayer.string = attributedTitle
        subtitleLayer.string = attributedSubtitle

        // Compute final box/title layer widths based on title.

        let titleSize = attributedTitle.size()
        if titleSize.width > titleLayer.bounds.width {
            var boxFrame = box.frame
            boxFrame.size.width = titleSize.width + Constants.boxPadding * 3
            box.frame = boxFrame

            var titleFrame = titleLayer.frame
            titleFrame.size.width = titleSize.width
            titleLayer.frame = titleFrame
        }

        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: renderSize)
        container.addSublayer(assetContainer)
        container.resizeLayer(assetContainer)

        assetContainer.isGeometryFlipped = true

        videoComposition?.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: container)

        box.sublayers?.compactMap({ $0 as? CATextLayer }).forEach { layer in
            layer.minificationFilter = .trilinear

            /// Workaround rdar://32718905
            layer.display()
        }
    }

    private lazy var attributedTitle: NSAttributedString = {
        NSAttributedString.create(
            with: title,
            font: .wwdcRoundedSystemFont(ofSize: 16, weight: .medium),
            color: .white
        )
    }()

    private lazy var attributedSubtitle: NSAttributedString = {
        NSAttributedString.create(
            with: subtitle,
            font: .systemFont(ofSize: 13, weight: .medium),
            color: .white
        )
    }()

}
