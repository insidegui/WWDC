import Cocoa
import SwiftUI
import Combine
import ConfCore
import RxSwift

final class ExploreTabProvider: ObservableObject {
    let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    @Published private(set) var content: ExploreTabContent?
    @Published var scrollOffset = CGPoint.zero

    private lazy var featuredSectionsObservable: Observable<Results<FeaturedSection>> = {
        storage.featuredSectionsObservable
    }()

    private lazy var continueWatchingSessionsObservable: Observable<[Session]> = {
        let cutoffDate = Calendar.current.date(byAdding: Constants.continueWatchingMaxLastProgressUpdateInterval, to: Date()) ?? Date.distantPast

        let videoPredicate = Session.videoPredicate
        let progressPredicate = NSPredicate(format: "SUBQUERY(progresses, $progress, $progress.updatedAt >= %@ AND $progress.relativePosition >= %f AND $progress.relativePosition < %f AND $progress.isDeleted = false).@count >= 1", cutoffDate as NSDate, Constants.continueWatchingMinRelativePosition, Constants.continueWatchingMaxRelativePosition)

        let sessions = storage.realm.objects(Session.self)
            .filter(NSCompoundPredicate(andPredicateWithSubpredicates: [videoPredicate, progressPredicate]))

        return Observable.collection(from: sessions).map {
            Array($0.sorted(by: {
                guard let p1 = $0.progresses.first else { return false }
                guard let p2 = $1.progresses.first else { return false }
                return p1.updatedAt > p2.updatedAt
            })
            .prefix(Constants.maxContinueWatchingItems))
        }
    }()

    private lazy var recentFavoriteSessionsObservable: Observable<[Session]> = {
        let cutoffDate = Calendar.current.date(byAdding: Constants.recentFavoritesMaxDateInterval, to: Date()) ?? Date.distantPast

        let favoritePredicate = NSPredicate(format: "createdAt >= %@ AND isDeleted = false", cutoffDate as NSDate)

        let favorites = storage.realm.objects(Favorite.self)
            .filter(favoritePredicate)
            .sorted(byKeyPath: "createdAt", ascending: false)

        return Observable.collection(from: favorites).map {
            Array($0.compactMap { $0.session.first }
                .prefix(Constants.maxRecentFavoritesItems))
        }
    }()

    private lazy var topicsObservable: Observable<[Track]> = {
        let tracks = storage.realm.objects(Track.self)
            .filter(NSPredicate(format: "sessions.@count >= 1 OR instances.@count >= 1"))
            .sorted(byKeyPath: "name")

        return Observable.collection(from: tracks).map({ $0.toArray() })
    }()

    private lazy var liveEventObservable: Observable<Session?> = {
        let liveInstances = storage.realm.objects(SessionInstance.self)
            .filter("rawSessionType == 'Special Event' AND isCurrentlyLive == true")
            .sorted(byKeyPath: "startTime", ascending: false)

        return Observable.collection(from: liveInstances)
            .map({ $0.toArray().first?.session })
    }()

    private var disposeBag = DisposeBag()

    private struct SourceData {
        var featuredSections: Results<FeaturedSection>
        var continueWatching: [Session]
        var recentFavorites: [Session]
        var topics: [Track]
        var liveEventSession: Session?
    }

    func activate() {
        Observable.combineLatest(
            featuredSectionsObservable,
            continueWatchingSessionsObservable,
            recentFavoriteSessionsObservable,
            topicsObservable,
            liveEventObservable
        )
        .filter { !$0.isEmpty || !$1.isEmpty || !$2.isEmpty || !$3.isEmpty || $4 != nil }
        .subscribe(on: MainScheduler.instance)
        .map(SourceData.init)
        .subscribe(onNext: { [weak self] data in
            self?.update(with: data)
        })
        .disposed(by: disposeBag)
    }

    func invalidate() {
        disposeBag = DisposeBag()
    }

    private func update(with data: SourceData) {
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
