//
//  TranscriptIndexer.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import SwiftyJSON

extension Notification.Name {
    public static let TranscriptIndexingDidStart = Notification.Name("io.wwdc.app.TranscriptIndexingDidStartNotification")
    public static let TranscriptIndexingDidStop = Notification.Name("io.wwdc.app.TranscriptIndexingDidStopNotification")
}

struct MediaSelectionGroup {
    enum MediumType: String {
        case subtitles = "SUBTITLES"
        case audio = "AUDIO"
        case video = "VIDEO"
    }

    let type: MediumType
    let groupID: String
    let name: String
    let isDefault: Bool
    let shouldAutoselect: Bool
    let shouldForce: Bool
    let language: String
    let url: URL

}

enum PlaylistError: Error {
    case unknown
}

struct MasterPlaylist {

    private(set) var selectionGroups = [MediaSelectionGroup]()
    let version: Int
//    let streams: [Stream]

    let baseURL: URL

    init(string: String, baseURL: URL) throws {

        self.baseURL = baseURL

        let capturedStrings = string.captureGroups(for: "#EXT-X-VERSION:(\\d)").flatMap { $0 }
        guard capturedStrings.count == 1, let version = Int(capturedStrings[0]) else {
            throw PlaylistError.unknown
        }

        self.version = version

        let matches = string.matches(for: "^#EXT-X-MEDIA:[^\\n]+")

        for mediumSpecifier in matches {

            let mediaCSV = mediumSpecifier.replacingOccurrences(of: "#EXT-X-MEDIA:", with: "")

            var mediaDictionary = [String: String]()
            for subsection in mediaCSV.split(separator: ",") {
                let keyAndValue = subsection.split(separator: "=")
                if keyAndValue.count == 2 {
                    mediaDictionary[String(keyAndValue[0])] = String(keyAndValue[1])
                } else {
                    print("Unexpected error when parsing media definition")
                }
            }

            guard let mediumTypeString = mediaDictionary["TYPE"],
                let mediumType = MediaSelectionGroup.MediumType(rawValue: mediumTypeString) else {
                    throw PlaylistError.unknown
            }
            guard let groupID = mediaDictionary["GROUP-ID"]?.replacingOccurrences(of: "\"", with: "") else {
                throw PlaylistError.unknown
            }
            guard let name = mediaDictionary["NAME"]?.replacingOccurrences(of: "\"", with: "") else {
                throw PlaylistError.unknown
            }
            guard let isDefaultString = mediaDictionary["DEFAULT"]?.replacingOccurrences(of: "\"", with: "") else {
                throw PlaylistError.unknown
            }
            let isDefault = isDefaultString == "YES" ? true : false

            guard let shouldAutoSelectString = mediaDictionary["AUTOSELECT"]?.replacingOccurrences(of: "\"", with: "") else {
                throw PlaylistError.unknown
            }
            let shouldAutoSelect = shouldAutoSelectString == "YES" ? true : false

            guard let shouldForceString = mediaDictionary["FORCED"]?.replacingOccurrences(of: "\"", with: "") else {
                throw PlaylistError.unknown
            }
            let shouldForce = shouldForceString == "YES" ? true : false

            guard let language = mediaDictionary["LANGUAGE"]?.replacingOccurrences(of: "\"", with: "") else {
                throw PlaylistError.unknown
            }

            guard let uri = mediaDictionary["URI"]?.replacingOccurrences(of: "\"", with: "") else {
                throw PlaylistError.unknown
            }

            selectionGroups.append(MediaSelectionGroup(type: mediumType,
                                groupID: groupID,
                                name: name, isDefault: isDefault,
                                shouldAutoselect: shouldAutoSelect,
                                shouldForce: shouldForce,
                                language: language,
                                url: baseURL.appendingPathComponent(uri)))
        }
    }
}

//#EXTM3U
//#EXT-X-TARGETDURATION:60
//#EXT-X-VERSION:3
//#EXT-X-MEDIA-SEQUENCE:0
//#EXT-X-PLAYLIST-TYPE:VOD
//#EXTINF:60.00000,
//fileSequence0.webvtt
//#EXTINF:60.00000,
//fileSequence1.webvtt
//#EXTINF:60.00000,
//fileSequence2.webvtt
//#EXTINF:60.00000,
//fileSequence3.webvtt
//#EXTINF:60.00000,
//fileSequence4.webvtt
//#EXTINF:52.11800,
//fileSequence5.webvtt
//#EXT-X-ENDLIST

struct Medium: Hashable {
    var hashValue: Int {
        return url.hashValue ^ title.hashValue ^ sequence.hashValue ^ duration.hashValue
    }

    static func == (lhs: Medium, rhs: Medium) -> Bool {
        return lhs.sequence == rhs.sequence
            && lhs.url == rhs.url
            && lhs.title == rhs.title
            && lhs.duration == rhs.duration
    }

    let sequence: Int
    let url: URL
    let title: String
    let duration: Float
}

struct MediaPlaylist {
    enum PlaylistType: String {
        case vod = "VOD"
    }
    let version: Int
    let targetDuration: Int
    private(set) var media = [Medium]()

    init(string: String, baseURL: URL) throws {
        var capturedStrings = string.captureGroups(for: "#EXT-X-VERSION:(\\d+)").flatMap { $0 }
        guard capturedStrings.count == 1, let version = Int(capturedStrings[0]) else {
            throw PlaylistError.unknown
        }

        self.version = version

        capturedStrings = string.captureGroups(for: "#EXT-X-TARGETDURATION:(\\d+)").flatMap { $0 }
        guard capturedStrings.count == 1, let targetDuration = Int(capturedStrings[0]) else {
            throw PlaylistError.unknown
        }
        self.targetDuration = targetDuration

        capturedStrings = string.captureGroups(for: "#EXT-X-MEDIA-SEQUENCE:(\\d+)").flatMap { $0 }
        guard capturedStrings.count == 1, let playlistSequence = Int(capturedStrings[0]) else {
            throw PlaylistError.unknown
        }

        let media = string.captureGroups(for: "^#EXTINF:([\\d]+.[\\d]+),(.*)\\n([^\\n]+)")
        var sequence = playlistSequence
        for medium in media {
            guard medium.count == 3 else {
                throw PlaylistError.unknown
            }

            let durationString = medium[0]
            guard let duration = Float(durationString) else {
                throw PlaylistError.unknown
            }

            self.media.append(Medium(sequence: sequence,
                                     url: baseURL.appendingPathComponent(medium[2]),
                                     title: medium[1],
                                     duration: duration))
            sequence += 1
        }
    }
}

public final class TranscriptIndexer {

    private let storage: Storage

    public init(_ storage: Storage) {
        self.storage = storage
    }

    /// The progress when the transcripts are being downloaded/indexed
    public var transcriptIndexingProgress: Progress?

    private let asciiWWDCURL = "http://asciiwwdc.com/"

    fileprivate let bgThread = DispatchQueue.global(qos: .utility)

    fileprivate lazy var backgroundOperationQueue: OperationQueue = {
        let q = OperationQueue()

        q.underlyingQueue = self.bgThread
        q.name = "Transcript Indexing"

        return q
    }()

    public static let minTranscriptableSessionLimit: Int = 20
    // TODO: increase 2017 to 2018 when transcripts for 2017 become available
    public static let transcriptableSessionsPredicate: NSPredicate = NSPredicate(format: "year > 2012 AND year < 2013 AND SUBQUERY(assets, $asset, $asset.rawAssetType == %@).@count > 0", SessionAssetType.streamingVideo.rawValue)

    public static func needsUpdate(in storage: Storage) -> Bool {
        let transcriptedSessions = storage.realm.objects(Session.self)//.filter(TranscriptIndexer.transcriptableSessionsPredicate)

        return true
        return transcriptedSessions.count > minTranscriptableSessionLimit
    }

    /// Try to download transcripts for sessions that don't have transcripts yet
    public func downloadTranscriptsIfNeeded() {
        let transcriptedSessions = storage.realm.objects(Session.self)//.filter(TranscriptIndexer.transcriptableSessionsPredicate)

        for session in transcriptedSessions {
            indexTranscript(for: session)
            break
        }
//        let sessionKeys: [String] = transcriptedSessions.map({ $0.identifier })
//
//        indexTranscriptsForSessionsWithKeys(sessionKeys)
    }

    let subtitleFetcherQueue = DispatchQueue(label: "subtitleFetcherQueue")

    func downloadMasterPlaylist(url: URL, _ completion: @escaping (MasterPlaylist?) -> Void) {

        var request = URLRequest(url: url)
        request.setValue("application/vnd.apple.mpegurl", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            var result: MasterPlaylist?

            defer {
                completion(result)
            }

            guard let data = data else {
                NSLog("Playlist returned no data for \(url)")

                return
            }

            guard let playlistString = String(data: data, encoding: .utf8) else {
                NSLog("Playlist is not utf8 for \(url)")
                return
            }

            let playlist = try! MasterPlaylist(string: playlistString, baseURL: url.deletingLastPathComponent())

            result = playlist
        }

        task.resume()
    }

    func downloadMediaPlaylist(url: URL, _ completion: @escaping (MediaPlaylist?) -> Void) {

        var request = URLRequest(url: url)
        request.setValue("application/vnd.apple.mpegurl", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            var result: MediaPlaylist?

            defer {
                completion(result)
            }

            guard let data = data else {
                NSLog("Playlist returned no data for \(url)")

                return
            }

            guard let playlistString = String(data: data, encoding: .utf8) else {
                NSLog("Playlist is not utf8 for \(url)")
                return
            }

            let playlist = try! MediaPlaylist(string: playlistString, baseURL: url.deletingLastPathComponent())

            result = playlist
        }

        task.resume()
    }

    func indexTranscript(for session: Session) {
        guard let urlString = session.assets.first(where: { $0.assetType == .streamingVideo} )?.remoteURL, let url = URL(string: urlString) else { return }
        if url.pathExtension == "mov" {
            print("We'll need to parse the movie atom")
            return
        }

        // moov
        //  |
        //   - rmra
        //      |
        //       - rmda
        //          |
        //           - rdrf # reference file
        //           - rmdr # data rate
        //           -
        //           -
        //       - rmda
        //       - rmda
        let primaryKey = session.value(forKey: Session.primaryKey()!) as! String

//        guard let url = URL(string: "\(asciiWWDCURL)\(session.year)//sessions/\(session.number)") else { return }

        var request = URLRequest(url: url)

        self.downloadMasterPlaylist(url: url) { masterPlaylist in
            guard let masterPlaylist = masterPlaylist else { return }

            guard let subtitleMedium = masterPlaylist.selectionGroups.first(where: { $0.type == .subtitles }) else { return }

            self.downloadMediaPlaylist(url: subtitleMedium.url) { subtitleMediaPlaylist in
                guard let subtitleMediaPlaylist = subtitleMediaPlaylist else { return }

                var subtitles = [Medium: String]()

                let dispatchGroup = DispatchGroup()

                for medium in subtitleMediaPlaylist.media {

                    let subtitleRequest = URLRequest(url: medium.url)

                    dispatchGroup.enter()
                    let subtitleTask = URLSession.shared.dataTask(with: subtitleRequest) { data, response, error in
                        defer {
                            dispatchGroup.leave()
                        }
                        guard let data = data else { return }
                        subtitles[medium] = String(data: data, encoding: .utf8)!
                    }
                    subtitleTask.resume()
                }

                dispatchGroup.notify(queue: .main, execute: {
                    print(subtitles)
                })
            }

            self.storage.storageQueue.waitUntilAllOperationsAreFinished()
        }
    }

    func indexTranscriptsForSessionsWithKeys(_ sessionKeys: [String]) {
        // ignore very low session counts
        guard sessionKeys.count > TranscriptIndexer.minTranscriptableSessionLimit else {
            waitAndExit()
            return
        }

        transcriptIndexingProgress = Progress(totalUnitCount: Int64(sessionKeys.count))

        for key in sessionKeys {
            guard let session = storage.realm.object(ofType: Session.self, forPrimaryKey: key) else { return }

            guard session.transcriptIdentifier.isEmpty else { continue }

            indexTranscript(for: session.number, in: session.year, primaryKey: key)
        }
    }

    fileprivate var batch: [Transcript] = [] {
        didSet {
            if batch.count >= 20 {
                store(batch)
                storage.storageQueue.waitUntilAllOperationsAreFinished()
                batch.removeAll()
            }
        }
    }

    fileprivate func store(_ transcripts: [Transcript]) {
        storage.backgroundUpdate { backgroundRealm in
            transcripts.forEach { transcript in
                guard let session = backgroundRealm.object(ofType: Session.self, forPrimaryKey: transcript.identifier) else {
                    NSLog("Session not found for \(transcript.identifier)")
                    return
                }

                session.transcriptIdentifier = transcript.identifier
                session.transcriptText = transcript.fullText

                backgroundRealm.add(transcript, update: true)
            }
        }
    }

    fileprivate func indexTranscript(for sessionNumber: String, in year: Int, primaryKey: String) {
        guard let url = URL(string: "\(asciiWWDCURL)\(year)//sessions/\(sessionNumber)") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { [unowned self] data, response, error in
            defer {
                self.transcriptIndexingProgress?.completedUnitCount += 1

                self.checkForCompletion()
            }

            guard let jsonData = data else {
                NSLog("No data returned from ASCIIWWDC for \(primaryKey)")

                return
            }

            var json: JSON

            do {
                json = try JSON(data: jsonData)
            } catch {
                NSLog("Error parsing JSON data for \(primaryKey)")
                return
            }

            let result = TranscriptsJSONAdapter().adapt(json)

            guard case .success(let transcript) = result else {
                NSLog("Error parsing transcript for \(primaryKey)")
                return
            }

            self.storage.storageQueue.waitUntilAllOperationsAreFinished()

            self.batch.append(transcript)
        }

        task.resume()
    }

    private func checkForCompletion() {
        guard let progress = transcriptIndexingProgress else { return }

        #if DEBUG
            NSLog("Completed: \(progress.completedUnitCount) Total: \(progress.totalUnitCount)")
        #endif

        if progress.completedUnitCount >= progress.totalUnitCount {
            DispatchQueue.main.async {
                #if DEBUG
                    NSLog("Transcript indexing finished")
                #endif

                self.storage.storageQueue.waitUntilAllOperationsAreFinished()
                self.waitAndExit()
            }
        }
    }

    fileprivate func waitAndExit() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            exit(0)
        }
    }

}

extension String {

    func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex, options: [.anchorsMatchLines])
            let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }

    func captureGroups(for regex: String) -> [[String]] {
        do {
            let regex = try NSRegularExpression(pattern: regex, options: [.anchorsMatchLines])
            let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
            return results.map { match in
                var groupMatches = [String]()
                for i in 1..<match.numberOfRanges {
                    groupMatches.append(String(self[Range(match.range(at: i), in: self)!]))
                }
                return groupMatches
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}
