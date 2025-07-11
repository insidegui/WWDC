//
//  SessionViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import Combine
import RealmSwift
import PlayerUI

final class SessionViewModel {

    let style: SessionsListStyle
    var title: String
    let session: Session
    let sessionInstance: SessionInstance
    let track: Track
    let identifier: String
    lazy var webUrl: URL? = {
        SessionViewModel.webUrl(for: session)
    }()
    var imageUrl: URL?
    let trackName: String

    lazy var rxSession: some Publisher<Session, Error> = {
        return session.valuePublisher()
    }()

    lazy var rxTranscript: some Publisher<Transcript?, Error> = {
        return rxSession
            .map(\.transcriptIdentifier)
            .compacted()
            .removeDuplicates()
            .flatMap { [weak self] _ in
                guard let results = self?.session.transcripts() else {
                    return Just<Transcript?>(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
                }

                return results.collectionPublisher.map(\.first).eraseToAnyPublisher()
            }
    }()

    lazy var rxTranscriptAnnotations: some Publisher<List<TranscriptAnnotation>, Error> = {
        return rxSession
            .map(\.transcriptIdentifier)
            .compacted()
            .removeDuplicates()
            .flatMap { [weak self] _ in
                guard let annotations = self?.session.transcript()?.annotations else {
                    return Just(List<TranscriptAnnotation>()).setFailureType(to: Error.self).eraseToAnyPublisher()
                }

                return annotations.collectionPublisher.eraseToAnyPublisher()
            }
    }()

    lazy var rxSessionInstance: some Publisher<SessionInstance, Error> = {
        return sessionInstance.valuePublisher()
    }()

    lazy var rxTrack: some Publisher<Track, Error> = {
        return track.valuePublisher()
    }()

    lazy var rxTitle: some Publisher<String, Error> = {
        return rxSession.map { $0.title }
    }()

    lazy var rxSubtitle: some Publisher<String, Error> = {
        return rxSession.map { SessionViewModel.subtitle(from: $0, at: $0.event.first) }
    }()

    lazy var rxTrackName: some Publisher<String, Error> = {
        return rxTrack.map { $0.name }
    }()

    lazy var rxSummary: some Publisher<String, Error> = {
        return rxSession.map { $0.summary }
    }()

    lazy var rxActionPrompt: AnyPublisher<String?, Error> = {
        guard sessionInstance.startTime > today() else { return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher() }
        guard actionLinkURL != nil else { return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher() }

        return rxSessionInstance.map { $0.actionLinkPrompt }.eraseToAnyPublisher()
    }()

    var actionLinkURL: URL? {
        guard let candidateURL = sessionInstance.actionLinkURL else { return nil }

        return URL(string: candidateURL)
    }

    lazy var rxContext: AnyPublisher<String, Error> = {
        if self.style == .schedule {

            return Publishers.CombineLatest(rxSession, rxSessionInstance).map {
                SessionViewModel.context(for: $0.0, instance: $0.1)
            }.eraseToAnyPublisher()
        } else {
            return Publishers.CombineLatest(rxSession, rxTrack).map {
                SessionViewModel.context(for: $0.0, track: $0.1)
            }.eraseToAnyPublisher()
        }
    }()

    lazy var rxFooter: some Publisher<String, Error> = {
        return rxSession.map { SessionViewModel.footer(for: $0, at: $0.event.first) }
    }()

    lazy var rxColor: some Publisher<NSColor, Error> = {
        return rxSession.compactMap { SessionViewModel.trackColor(for: $0) }
    }()

    lazy var rxDarkColor: some Publisher<NSColor, Error> = {
        return rxSession.compactMap { SessionViewModel.darkTrackColor(for: $0) }
    }()

    lazy var rxImageUrl: some Publisher<URL?, Error> = {
        return rxSession.map { SessionViewModel.imageUrl(for: $0) }
    }()

    lazy var rxWebUrl: some Publisher<URL?, Error> = {
        return rxSession.map { SessionViewModel.webUrl(for: $0) }
    }()

    lazy var rxIsDownloaded: some Publisher<Bool, Error> = {
        return rxSession.map { $0.isDownloaded }
    }()

    lazy var rxIsFavorite: some Publisher<Bool, Error> = {
        // While scrolling the favorites publisher won't be able to fire
        // because the events are tracking. I'm guessing because it's using the main
        // runloop? Regardless, putting the subscription on a background queue fixes it
        return self.session.favorites.filter("isDeleted == false")
            .changesetPublisherShallow(keyPaths: ["identifier"])
            .subscribe(on: DispatchQueue(label: #function))
            .threadSafeReference()
            .receive(on: DispatchQueue.main)
            .map { $0.count > 0 }
    }()

    lazy var rxIsCurrentlyLive: some Publisher<Bool, Error> = {
        guard self.sessionInstance.realm != nil else {
            return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return rxSessionInstance.map { $0.isCurrentlyLive }.eraseToAnyPublisher()
    }()

    lazy var rxPlayableContent: some Publisher<Results<SessionAsset>, Error> = {
        let playableAssets = self.session.assets(matching: [.streamingVideo, .liveStreamVideo])

        return playableAssets.collectionPublisher
    }()

    lazy var rxCanBePlayed: some Publisher<Bool, Error> = {
        let validAssets = self.session.assets.filter("(rawAssetType == %@ AND remoteURL != '') OR (rawAssetType == %@ AND SUBQUERY(session.instances, $instance, $instance.isCurrentlyLive == true).@count > 0)", SessionAssetType.streamingVideo.rawValue, SessionAssetType.liveStreamVideo.rawValue)
        let validAssetsObservable = validAssets.collectionPublisher

        return validAssetsObservable.map { $0.count > 0 }
    }()

    lazy var rxProgresses: some Publisher<Results<SessionProgress>, Error> = {
        let progresses = self.session.progresses.filter(NSPredicate(value: true))

        return progresses.collectionPublisher
    }()

    lazy var rxRelatedSessions: some Publisher<Results<RelatedResource>, Error> = {
        // Return sessions with videos, or any session that hasn't yet occurred
        let predicateFormat = "type == %@ AND (ANY session.assets.rawAssetType == %@ OR ANY session.instances.startTime >= %@)"
        let relatedPredicate = NSPredicate(format: predicateFormat, RelatedResourceType.session.rawValue, SessionAssetType.streamingVideo.rawValue, today() as NSDate)
        let validRelatedSessions = self.session.related.filter(relatedPredicate)

        return validRelatedSessions.collectionPublisher
    }()

    convenience init?(session: Session) {
        self.init(session: session, instance: nil, track: nil, style: .videos)
    }

    convenience init?(session: Session, track: Track) {
        self.init(session: session, instance: nil, track: track, style: .videos)
    }

    init?(session: Session?, instance: SessionInstance?, track: Track?, style: SessionsListStyle) {
        self.style = style

        guard let session = session ?? instance?.session else { return nil }
        guard let track = track ?? session.track.first ?? instance?.track.first else { return nil }
        self.session = session
        self.track = track

        trackName = track.name
        sessionInstance = instance ?? session.instances.first ?? SessionInstance()
        title = session.title
        identifier = session.identifier
    }

    static func subtitle(from session: Session, at event: ConfCore.Event?) -> String {
        guard let event = event else { return "" }

        let year = Calendar.current.component(.year, from: event.startDate)
        var name = event.name

        /*
        We want to make sure that WWDC events show the year
        So we add it it not present.
        */
        if name == "WWDC" {
            name.append(" \(year)")
        }

        return "\(name) · Session \(session.number)"
    }

    static func focusesDescription(from focuses: [Focus], collapse: Bool) -> String {
        var result: String

        if focuses.count == 4 && collapse {
            result = "All Platforms"
        } else {
            let separator = ", "

            result = focuses.reduce("") { $0 + $1.name + separator }
            result = result.trimmingCharacters(in: CharacterSet(charactersIn: separator))
        }

        return result
    }

    static func context(for session: Session, instance: SessionInstance? = nil, track: Track? = nil) -> String {
        var components = [String]()

        if let instance {
            components = [timeFormatter.string(from: instance.startTime)]

            /// The end time is only relevant when the instance has a live component,
            /// and let's also ensure the start and end times are not the same just in case.
            if instance.hasLiveStream, instance.startTime != instance.endTime {
                components.append(timeFormatter.string(from: instance.endTime))
            }
        } else {
            components = []
        }

        /// Display either track or focuses, prioritizing track, since both won't fit.
        if let trackName = (track ?? session.track.first)?.name {
            components.append(trackName)
        } else {
            let focusesArray = session.focuses.toArray()
            if !focusesArray.isEmpty {
                let focuses = SessionViewModel.focusesDescription(from: focusesArray, collapse: true)
                components.append(focuses)
            }
        }

        return components.joined(separator: " · ")
    }

    static func footer(for session: Session, at event: ConfCore.Event?) -> String {
        guard let event = event else { return "" }

        let focusesArray = session.focuses.toArray()

        let allFocuses = SessionViewModel.focusesDescription(from: focusesArray, collapse: false)

        var result = "\(event.name) · Session \(session.number)"

        if (event.startDate...event.endDate).contains(today()), let date = session.instances.first?.startTime {
            result += " · " + standardFormatted(date: date, withTimeZoneName: false)
        }

        if session.mediaDuration > 0, let duration = String(timestamp: session.mediaDuration) {
            result += " · " + duration
        }

        if focusesArray.count > 0 {
            result += " · \(allFocuses)"
        }

        return result
    }

    static func imageUrl(for session: Session) -> URL? {
        let imageAsset = session.asset(ofType: .image)

        guard let thumbnail = imageAsset?.remoteURL, let thumbnailUrl = URL(string: thumbnail) else { return nil }

        return thumbnailUrl
    }

    static func webUrl(for session: Session) -> URL? {
        guard let url = session.asset(ofType: .webpage)?.remoteURL else { return nil }

        return URL(string: url)
    }

    static func trackColor(for session: Session) -> NSColor? {
        guard let code = session.track.first?.lightColor else { return nil }

        return NSColor.fromHexString(hexString: code)
    }

    static func darkTrackColor(for session: Session) -> NSColor? {
        guard let code = session.track.first?.darkColor else { return nil }

        return NSColor.fromHexString(hexString: code)
    }

    static let shortDayOfTheWeekFormatter: DateFormatter = {
        let df = DateFormatter()

        df.locale = Locale.current
        df.timeZone = TimeZone.current
        df.dateFormat = "E"

        return df
    }()

    static let dayOfTheWeekFormatter: DateFormatter = {
        let df = DateFormatter()

        df.locale = Locale.current
        df.timeZone = TimeZone.current
        df.dateFormat = "EEEE"

        return df
    }()

    static let timeFormatter: DateFormatter = {
        let tf = DateFormatter()

        tf.locale = Locale.current
        tf.timeZone = TimeZone.current
        tf.timeStyle = .short

        return tf
    }()

    static var timeZoneNameSuffix: String {
        if let name = TimeZone.current.localizedName(for: .shortGeneric, locale: Locale.current) {
            return " " + name
        } else {
            return ""
        }
    }

    static func standardFormatted(date: Date, withTimeZoneName: Bool) -> String {
        let result = dayOfTheWeekFormatter.string(from: date) + ", " + timeFormatter.string(from: date)

        return withTimeZoneName ? result + timeZoneNameSuffix : result
    }

}

extension SessionViewModel: UserActivityRepresentable { }

extension SessionViewModel {

    var isFavorite: Bool { session.isFavorite }

}

extension SessionViewModel {
    /// Challenges with previews
    ///
    /// 1. app boot up
    /// 2. realm needs objects to be managed
    ///
    /// I think we can build a preview helper that does a Boot().bootstrapDependencies(then:), but it's async
    /// so it's a bit of effort. For now, just brute force to get a session.
    static var preview: SessionViewModel {
        let delegate = (NSApplication.shared.delegate as! AppDelegate) // swiftlint:disable:this force_cast
        Thread.sleep(forTimeInterval: 0.5) // TODO: Get access to storage in a better way
        let coordinator = delegate.coordinator!

        return Self.init(
            session: coordinator.storage.sessions.first { $0.transcript() != nil }!
        )!
    }
}
