//
//  ClipRenderer.swift
//  WWDC
//
//  Created by Guilherme Rambo on 02/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import ConfCore

final class ClipRenderer: NSObject, Logging {

    static let log = makeLogger()

    let playerItem: AVPlayerItem
    let fileNameHint: String?
    let title: String
    let subtitle: String

    init(playerItem: AVPlayerItem, title: String, subtitle: String, fileNameHint: String?) {
        self.playerItem = playerItem
        self.title = title
        self.subtitle = subtitle
        self.fileNameHint = fileNameHint

        super.init()
    }

    private func generateOutputURL() -> URL {
        var baseURL = Preferences.shared.localVideoStorageURL.appendingPathComponent("_Clips")

        if !FileManager.default.fileExists(atPath: baseURL.path) {
            do {
                try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
                log.error("Couldn't create clips directory: \(String(describing: error), privacy: .public)")
            }
        }

        let basename = fileNameHint ?? UUID().uuidString
        let filename = basename + "-" + String(Int(Date().timeIntervalSinceReferenceDate))

        return baseURL.appendingPathComponent(filename)
                      .appendingPathExtension("mp4")
    }

    private(set) lazy var outputURL: URL = {
        generateOutputURL()
    }()

    private func error(with message: String) -> Error {
        NSError(domain: "io.wwdc.ClipRenderer", code: 0, userInfo: [NSLocalizedRecoverySuggestionErrorKey: message])
    }

    typealias RenderProgressBlock = (Float) -> Void
    typealias RenderCompletionBlock = (Result<URL, Error>) -> Void

    private var progressHandler: RenderProgressBlock?
    private var completionHandler: RenderCompletionBlock?

    private var currentSession: AVAssetExportSession?

    func renderClip(progress: @escaping RenderProgressBlock, completion: @escaping RenderCompletionBlock) {
        log.debug("\(#function, privacy: .public)")

        progressHandler = progress
        completionHandler = completion

        let preset = AVAssetExportPreset1280x720

        do {
            let comp = try ClipComposition(
                video: playerItem.asset,
                title: title,
                subtitle: subtitle,
                includeBanner: Preferences.shared.includeAppBannerInSharedClips
            )

            guard let session = AVAssetExportSession(asset: comp, presetName: preset) else {
                completion(.failure(error(with: "The export session couldn't be initialized.")))
                return
            }

            session.videoComposition = comp.videoComposition

            currentSession = session

            startExport(with: session)

            startProgressReporting()
        } catch {
            log.error("Composition initialization failed: \(String(describing: error), privacy: .public)")

            reportCompletion(with: .failure(self.error(with: "Couldn't create video composition for clip.")))
        }
    }

    private func startExport(with session: AVAssetExportSession) {
        session.outputFileType = .mp4
        session.outputURL = outputURL

        log.debug("Will output to \(self.outputURL.path)")

        let startTime = playerItem.reversePlaybackEndTime
        let endTime = playerItem.forwardPlaybackEndTime
        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
        session.timeRange = timeRange

        session.exportAsynchronously { [weak session, weak self] in
            guard let self = self else { return }
            guard let session = session else { return }

            switch session.status {
            case .unknown:
                log.info("Export session received unknown status")
            case .waiting:
                log.info("Export session waiting")
            case .exporting:
                log.info("Export session started")
            case .completed:
                log.info("Export session finished")
                self.progressUpdateTimer?.invalidate()
                
                self.reportCompletion(with: .success(self.outputURL))
            case .failed:
                if let error = session.error {
                    log.error("Export session failed with error: \(String(describing: error), privacy: .public)")
                } else {
                    log.error("Export session failed with an unknown error")
                }

                self.reportCompletion(with: .failure(self.error(with: "The export failed.")))
            case .cancelled:
                self.progressUpdateTimer?.invalidate()
                log.debug("Cancelled")
                return
            @unknown default:
                fatalError("Unknown case")
            }
        }
    }

    private var progressUpdateTimer: Timer?

    private var currentProgress: Float = 0 {
        didSet {
            guard currentProgress != oldValue else { return }

            reportProgress(currentProgress)
        }
    }

    private func startProgressReporting() {
        let progressCheckInterval: TimeInterval = 0.1

        progressUpdateTimer = Timer.scheduledTimer(withTimeInterval: progressCheckInterval, repeats: true, block: { [weak self] timer in
            guard let self = self else { return }

            guard self.currentSession?.status == .exporting else {
                timer.invalidate()
                self.progressUpdateTimer = nil
                return
            }

            self.currentProgress = self.currentSession?.progress ?? 0
        })
    }

    func cancel() {
        currentSession?.cancelExport()
        currentSession = nil
    }

    private func reportProgress(_ value: Float) {
        DispatchQueue.main.async {
            self.progressHandler?(value)
        }
    }

    private func reportCompletion(with result: Result<URL, Error>) {
        DispatchQueue.main.async {
            self.completionHandler?(result)
        }
    }

}
