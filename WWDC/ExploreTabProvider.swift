import Cocoa
import SwiftUI
import Combine
import ConfCore
import RealmSwift

final class ExploreTabProvider: ObservableObject {
    let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    @Published private(set) var content: ExploreTabContent?
    @Published var scrollOffset = CGPoint.zero

    private lazy var featuredSectionsObservable: some Publisher<Results<FeaturedSection>, Error> = {
        storage.featuredSections
    }()

    private lazy var continueWatchingSessionsObservable: some Publisher<[Session], Error> = {
        let cutoffDate = Calendar.current.date(byAdding: Constants.continueWatchingMaxLastProgressUpdateInterval, to: Date()) ?? Date.distantPast

        let videoPredicate = Session.videoPredicate
        let progressPredicate = NSPredicate(format: "SUBQUERY(progresses, $progress, $progress.updatedAt >= %@ AND $progress.relativePosition >= %f AND $progress.relativePosition < %f AND $progress.isDeleted = false).@count >= 1", cutoffDate as NSDate, Constants.continueWatchingMinRelativePosition, Constants.continueWatchingMaxRelativePosition)

        let sessions = storage.realm.objects(Session.self)
            .filter(NSCompoundPredicate(andPredicateWithSubpredicates: [videoPredicate, progressPredicate]))

        return sessions.collectionPublisher.map {
            Array($0.sorted(by: {
                guard let p1 = $0.progresses.first else { return false }
                guard let p2 = $1.progresses.first else { return false }
                return p1.updatedAt > p2.updatedAt
            })
            .prefix(Constants.maxContinueWatchingItems))
        }
    }()

    private lazy var recentFavoriteSessionsObservable: some Publisher<[Session], Error> = {
        let cutoffDate = Calendar.current.date(byAdding: Constants.recentFavoritesMaxDateInterval, to: Date()) ?? Date.distantPast

        let favoritePredicate = NSPredicate(format: "createdAt >= %@ AND isDeleted = false", cutoffDate as NSDate)

        let favorites = storage.realm.objects(Favorite.self)
            .filter(favoritePredicate)
            .sorted(byKeyPath: "createdAt", ascending: false)

        return favorites.collectionPublisher.map {
            Array($0.compactMap { $0.session.first }
                .prefix(Constants.maxRecentFavoritesItems))
        }
    }()

    private lazy var topicsObservable: some Publisher<[Track], Error> = {
        let tracks = storage.realm.objects(Track.self)
            .filter(NSPredicate(format: "sessions.@count >= 1 OR instances.@count >= 1"))
            .sorted(byKeyPath: "name")

        return tracks.collectionPublisher.map({ $0.toArray() })
    }()

    private lazy var liveEventObservable: some Publisher<Session?, Error> = {
        let liveInstances = storage.realm.objects(SessionInstance.self)
            .filter("rawSessionType == 'Special Event' AND isCurrentlyLive == true")
            .sorted(byKeyPath: "startTime", ascending: false)

        return liveInstances.collectionPublisher
            .map({ $0.toArray().first?.session })
    }()

    private var cancellables: Set<AnyCancellable> = []

    fileprivate struct SourceData {
        var featuredSections: Results<FeaturedSection>
        var continueWatching: [Session]
        var recentFavorites: [Session]
        var topics: [Track]
        var liveEventSession: Session?
    }

    func activate() {
        Publishers.CombineLatest4(
            featuredSectionsObservable,
            continueWatchingSessionsObservable,
            recentFavoriteSessionsObservable,
            topicsObservable
        ).combineLatest(liveEventObservable, { first, second in
            (first.0, first.1, first.2, first.3, second)
        })
        .replaceErrorWithEmpty()
        .filter { !$0.isEmpty || !$1.isEmpty || !$2.isEmpty || !$3.isEmpty || $4 != nil }
        .map(SourceData.init)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] data in
            self?.update(with: data)
        }
        .store(in: &cancellables)
    }

    func invalidate() {
        cancellables = []
    }

    private func update(with data: SourceData) {
        guard !data.shouldDisplayPlaceholderUI else { return }

        let continueWatchingSection = ExploreTabContent.Section(
            id: "continue-watching",
            title: "Continue Watching",
            icon: .symbol("list.bullet.below.rectangle"),
            items: data.continueWatching.compactMap { session in
                ExploreTabContent.Item(
                    session,
                    duration: session.mediaDuration - session.currentPosition()
                )
            }
        )

        let recentFavoritesSection = ExploreTabContent.Section(
            id: "recent-favorites",
            title: "Recent Favorites",
            icon: .symbol("star"),
            items: data.recentFavorites.compactMap { ExploreTabContent.Item($0) }
        )

        let topics = ExploreTabContent.Section(
            id: "topics",
            title: "Topics",
            layout: .pill,
            icon: .symbol("magnifyingglass"),
            items: data.topics.compactMap {
                ExploreTabContent.Item(
                    id: $0.identifier,
                    title: $0.name,
                    subtitle: nil,
                    overlayText: nil,
                    overlaySymbol: $0.symbolName,
                    imageURL: nil,
                    destination: .command(.filter(.topic($0))),
                    progress: nil
                )
            }
        )

        let remoteSections = data.featuredSections.compactMap(ExploreTabContent.Section.init)

        let contentSections = (
            [
                continueWatchingSection,
                recentFavoritesSection
            ]
            + remoteSections
            + [topics]
        ).filter({ !$0.items.isEmpty })

        guard !contentSections.isEmpty else {
            content = nil
            return
        }

        content = ExploreTabContent(
            id: "explore",
            sections: contentSections,
            liveEventItem: data.liveEventSession.flatMap { ExploreTabContent.Item($0) }
        )
    }
}

// MARK: - Model Extensions

private extension ExploreTabContent.Section {
    init?(_ section: FeaturedSection) {
        guard let format = section.format else {
            assertionFailure("Featured section is missing format: \(section)")
            return nil
        }

        let items = Array(section.content.compactMap(ExploreTabContent.Item.init))

        guard !items.isEmpty else { return nil }

        let icon: ExploreTabContent.Section.Icon

        if let symbolName = format.symbolName {
            icon = .symbol(symbolName)
        } else if let glyphURLStr = section.content.compactMap({ $0.session?.event.first?.glyphURL }).first,
                  let glyphURL = URL(string: glyphURLStr)
        {
            icon = .remoteGlyph(glyphURL)
        } else {
            icon = .symbol("play")
        }

        self.init(
            id: section.identifier,
            title: section.title,
            icon: icon,
            items: items
        )
    }
}

private extension ExploreTabContent.Item {
    init?(_ content: FeaturedContent) {
        guard let session = content.session else { return nil }

        self.init(session)
    }

    init?(_ session: Session, duration: Double? = nil) {
        guard let event = session.event.first else { return nil }

        let effectiveDuration = duration ?? session.mediaDuration
        let progress: Double?

        if duration != nil, let progressItem = session.progresses.first {
            progress = progressItem.relativePosition
        } else {
            progress = nil
        }

        let overlayText: String?
        let overlaySymbol: String?
        let stream: LiveStream?

        if let instance = session.instances.first, instance.startTime <= today(), instance.endTime >= today()  {
            stream = LiveStream(
                startTime: instance.startTime,
                endTime: instance.endTime,
                url: session.asset(ofType: .liveStreamVideo).flatMap({ URL(string: $0.remoteURL) })
            )
            overlayText = "Live"
            overlaySymbol = "record.circle"
        } else {
            stream = nil
            overlayText = effectiveDuration > 0 ? String(timestamp: effectiveDuration) : nil
            overlaySymbol = session.mediaDuration > 0 ? "play" : nil
        }

        self.init(
            id: session.identifier,
            title: event.name,
            subtitle: session.title,
            overlayText: overlayText,
            overlaySymbol: overlaySymbol,
            imageURL: session.imageURL,
            destination: .command(.revealVideo(session.identifier)),
            progress: progress,
            liveStream: stream
        )
    }
}

private extension FeaturedSectionFormat {
    var symbolName: String? {
        switch self {
        case .largeGrid, .smallGrid:
            return nil
        case .curated:
            return "pencil"
        case .history:
            return "list.bullet.below.rectangle"
        case .favorites:
            return "star"
        case .live:
            return "record.circle"
        case .upNext:
            return "sparkles"
        }
    }
}

private extension Session {
    var imageURL: URL? {
        guard let asset = asset(ofType: .image) else { return nil }
        return URL(string: asset.remoteURL)
    }
}

extension WWDCFiltersState {
    static func topic(_ topic: Track) -> WWDCFiltersState {
        WWDCFiltersState(
            scheduleTab: .init(filters: []),
            videosTab: .init(
                focus: nil,
                event: nil,
                track: .init(selectedOptions: [
                    .init(title: topic.name, value: topic.name)
                ]),
                isDownloaded: nil,
                isFavorite: nil,
                hasBookmarks: nil,
                isUnwatched: nil,
                text: nil
            )
        )
    }
}

private extension ExploreTabProvider.SourceData {
    /// `true` when all sections except for "Topics" are empty.
    /// This addresses migration from previous versions without an Explore tab,
    /// where the local database has topics but no other data relevant to the explore tab.
    var shouldDisplayPlaceholderUI: Bool {
        featuredSections.isEmpty
        && continueWatching.isEmpty
        && recentFavorites.isEmpty
        && liveEventSession == nil
    }
}
