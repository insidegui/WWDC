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
import Algorithms

final class SessionViewModel {
    static let updateQueue = DispatchQueue(label: "io.wwdc.session-view-model-updates", qos: .userInteractive)

    let style: SessionsListStyle

    // MARK: - Relayed Session Properties

    /*@MainActor */@Published private(set) var title: String
    @MainActor @Published private(set) var subtitle: String
    @MainActor @Published private(set) var summary: String
    @MainActor @Published private(set) var footer: String
    @MainActor @Published private(set) var color: NSColor?
    @MainActor @Published private(set) var darkColor: NSColor?
    @MainActor @Published private(set) var imageURL: URL?
    @MainActor @Published private(set) var webURL: URL?
    @MainActor @Published private(set) var isDownloaded: Bool
    @MainActor @Published private(set) var transcriptText: String

    // MARK: - More Complex Properties

    @MainActor @Published private(set) var isFavorite: Bool
    @MainActor @Published private(set) var hasBookmarks: Bool
    @MainActor @Published private(set) var progress: SessionProgress?
    @MainActor @Published private(set) var context: String
    @MainActor @Published private(set) var canBePlayed = false
    @MainActor @Published private(set) var relatedSessions: [Session] = []

    let session: Session
    let sessionInstance: SessionInstance
    private let track: Track
    let trackName: String
    let identifier: String

    @MainActor
    private var connections: Set<AnyCancellable> = []

    /// The implementation of this is a performance optimization and part of an effort to reduce
    /// the exposure of Realm directly to the view layer.
    @MainActor
    private lazy var rxSession: some Publisher<Session, Error> = {
        let rxSession = valuePublisher(session)
            .subscribe(on: Self.updateQueue)
            .freeze()
            .multicast(subject: CurrentValueSubject(session.freeze()))
            .autoconnect()

        rxSession
            .replaceErrorWithEmpty()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self else { return }

                MainActor.assumeIsolated {
                    self.title = session.title
                    self.subtitle = SessionViewModel.subtitle(from: session, at: session.event.first)
                    self.summary = session.summary
                    self.footer = SessionViewModel.footer(for: session, at: session.event.first)
                    self.color = SessionViewModel.trackColor(for: session)
                    self.darkColor = SessionViewModel.darkTrackColor(for: session)
                    self.imageURL = SessionViewModel.imageUrl(for: session)
                    self.webURL = SessionViewModel.webUrl(for: session)
                    self.isDownloaded = session.isDownloaded
                    self.transcriptText = session.transcriptText
                }
            }
            .store(in: &connections)

        return rxSession
    }()

    // TODO: Can this be moved to an @Published relay?
    @MainActor
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

    @MainActor
    private lazy var rxSessionInstance: some Publisher<SessionInstance, Error> = {
        let rxSessionInstance = valuePublisher(sessionInstance)
            .subscribe(on: Self.updateQueue)
            .freeze()
            .multicast(subject: CurrentValueSubject(sessionInstance.freeze()))
            .autoconnect()

        return rxSessionInstance
    }()

    @MainActor
    lazy var rxActionPrompt: AnyPublisher<String?, Error> = {
        guard sessionInstance.startTime > today() else { return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher() }
        guard actionLinkURL != nil else { return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher() }

        return rxSessionInstance.map { $0.actionLinkPrompt }.eraseToAnyPublisher()
    }()

    /// Depends on ``rxSession``, ``rxSessionInstance``, and ``rxTrack``
    @MainActor
    private lazy var rxContext: AnyPublisher<String, Error> = {
        var rxContext = if self.style == .schedule {
            Publishers.CombineLatest(rxSession, rxSessionInstance).map { @Sendable in
                SessionViewModel.context(for: $0.0, instance: $0.1)
            }.eraseToAnyPublisher()
        } else {
            Publishers.CombineLatest(rxSession, rxTrack).map { @Sendable in
                SessionViewModel.context(for: $0.0, track: $0.1)
            }.eraseToAnyPublisher()
        }

        rxContext
            .replaceError(with: "")
            .receive(on: DispatchQueue.main)
            .sink { [weak self] context in
                MainActor.assumeIsolated {
                    self?.context = context
                }
            }
            .store(in: &connections)

        return rxContext
    }()

    @MainActor
    private lazy var rxTrack: some Publisher<Track, Error> = {
        let rxTrack = valuePublisher(track)
            .subscribe(on: Self.updateQueue)
            .freeze()
            .multicast(subject: CurrentValueSubject(track.freeze()))
            .autoconnect()

        return rxTrack
    }()

    var actionLinkURL: URL? {
        guard let candidateURL = sessionInstance.actionLinkURL else { return nil }

        return URL(string: candidateURL)
    }

    @MainActor
    private lazy var rxIsFavorite: some Publisher<Bool, Error> = {
        let favorites = session.favorites.filter("isDeleted == false")

        let rxIsFavorite = favorites
            .collectionPublisher
            .subscribe(on: Self.updateQueue)
            .map(\.isEmpty)
            .toggled()

        rxIsFavorite
            .replaceError(with: false)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFavorite in
                MainActor.assumeIsolated {
                    self?.isFavorite = isFavorite
                }
            }
            .store(in: &connections)

        return rxIsFavorite
    }()

    @MainActor
    private lazy var rxHasBookmarks: some Publisher<Bool, Error> = {
        let bookmarks = session.bookmarks.filter("isDeleted == false")

        let rxHasBookmarks = bookmarks
            .collectionPublisher
            .subscribe(on: Self.updateQueue)
            .map(\.isEmpty)
            .toggled()

        rxHasBookmarks
            .replaceError(with: false)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasBookmarks in
                MainActor.assumeIsolated {
                    self?.hasBookmarks = hasBookmarks
                }
            }
            .store(in: &connections)

        return rxHasBookmarks
    }()

    @MainActor
    private lazy var rxCanBePlayed: some Publisher<Bool, Error> = {
        let validAssets = self.session.assets.filter("(rawAssetType == %@ AND remoteURL != '') OR (rawAssetType == %@ AND SUBQUERY(session.instances, $instance, $instance.isCurrentlyLive == true).@count > 0)", SessionAssetType.streamingVideo.rawValue, SessionAssetType.liveStreamVideo.rawValue)
        let rxCanBePlayed = validAssets.collectionPublisher.map(\.isEmpty).toggled()

        rxCanBePlayed
            .replaceError(with: false)
            .sink { [weak self] canBePlayed in
                DispatchQueue.main.async {
                    self?.canBePlayed = canBePlayed
                }
            }
            .store(in: &connections)

        return rxCanBePlayed
    }()

    @MainActor
    private lazy var rxProgresses: some Publisher<Results<SessionProgress>, Error> = {
        let progresses = self.session.progresses.filter(NSPredicate(value: true))

        let rxProgresses = progresses
            .collectionPublisher
            .subscribe(on: Self.updateQueue)
            .freeze()
            .multicast(subject: CurrentValueSubject(progresses.freeze()))
            .autoconnect()

        rxProgresses
            .replaceErrorWithEmpty()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progresses in
                MainActor.assumeIsolated {
                    self?.progress = progresses.first
                }
            }
            .store(in: &connections)

        return rxProgresses
    }()

    @MainActor
    private lazy var rxRelatedSessions: some Publisher<Array<Session>, Error> = {
        // Return sessions with videos, or any session that hasn't yet occurred
        let predicateFormat = "type == %@ AND (ANY session.assets.rawAssetType == %@ OR ANY session.instances.startTime >= %@)"
        let relatedPredicate = NSPredicate(format: predicateFormat, RelatedResourceType.session.rawValue, SessionAssetType.streamingVideo.rawValue, today() as NSDate)
        let validRelatedSessions = self.session.related.filter(relatedPredicate)
        let initialValue = Array(validRelatedSessions.compactMap(\.session).uniqued(on: \.identifier))

        let relatedSessions = validRelatedSessions
            .collectionPublisher
            .subscribe(on: Self.updateQueue)
            .freeze()
            .map { @Sendable in
                Array($0.compactMap(\.session).uniqued(on: \.identifier))
            }
            .removeDuplicates { @Sendable previous, new in
                previous.map(\.identifier) == new.map(\.identifier)
            }
            .multicast(subject: CurrentValueSubject(initialValue))
            .autoconnect()

        relatedSessions
            .replaceErrorWithEmpty()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] relatedSessions in
                MainActor.assumeIsolated {
                    self?.relatedSessions = relatedSessions
                }
            }
            .store(in: &connections)

        return relatedSessions
    }()

    convenience init?(session: Session) {
        self.init(session: session, instance: nil, track: nil, style: .videos)
    }

    convenience init?(session: Session, track: Track) {
        self.init(session: session, instance: nil, track: track, style: .videos)
    }

    init?(session: Session?, instance: SessionInstance?, track: Track?, style: SessionsListStyle) {
        self.style = style

        guard let session = session?.thaw() ?? session ?? instance?.session else { return nil }
        guard let track = track ?? session.track.first ?? instance?.track.first else { return nil }
        self.session = session
        self.track = track

        trackName = track.name
        sessionInstance = instance ?? session.instances.first ?? SessionInstance()
        identifier = session.identifier

        _title = Published(initialValue: session.title)
        _subtitle = Published(initialValue: SessionViewModel.subtitle(from: session, at: session.event.first))
        _summary = Published(initialValue: session.summary)
        _footer = Published(initialValue: SessionViewModel.footer(for: session, at: session.event.first))
        _color = Published(initialValue: SessionViewModel.trackColor(for: session))
        _darkColor = Published(initialValue: SessionViewModel.darkTrackColor(for: session))
        _imageURL = Published(initialValue: SessionViewModel.imageUrl(for: session))
        _webURL = Published(initialValue: SessionViewModel.webUrl(for: session))
        _isDownloaded = Published(initialValue: session.isDownloaded)
        _transcriptText = Published(initialValue: session.transcriptText)

        _isFavorite = Published(initialValue: session.isFavorite)
        _hasBookmarks = Published(initialValue: !session.bookmarks.filter("isDeleted == false").isEmpty)
        _progress = Published(initialValue: session.progresses.filter(NSPredicate(value: true)).first)
        _context = if self.style == .schedule {
            Published(initialValue: SessionViewModel.context(for: session, instance: sessionInstance))
        } else {
            Published(initialValue: SessionViewModel.context(for: session, track: track))
        }
    }

    /// Establishes a reactive connection from Realm to the view model's properties so they can be consumed via @Published.
    ///
    /// This needs to happen lazily, because when doing from inside the initializer, it causes too much work to be done
    /// during app launch.
    ///
    /// The reason we want this is so that we can move toward isolating Realm from the view layer, hopefully assisting in
    /// one day switching away from Realm as our storage solution.
    @MainActor
    func connect() {
        guard connections.isEmpty else { return }

        _ = rxSession
        _ = rxIsFavorite
        _ = rxHasBookmarks
        _ = rxProgresses
        _ = rxCanBePlayed
        _ = rxContext
        _ = rxRelatedSessions
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
