import Cocoa
import SwiftUI
import Combine
import ConfCore

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

    public lazy var continueWatchingSessionsObservable: Observable<Results<Session>> = {
        let cutoffDate = Calendar.current.date(byAdding: Constants.continueWatchingMaxLastProgressUpdateInterval, to: Date()) ?? Date.distantPast

        let videoPredicate = Session.videoPredicate
        let progressPredicate = NSPredicate(format: "SUBQUERY(progresses, $progress, $progress.updatedAt >= %@ AND $progress.relativePosition >= %f AND $progress.relativePosition < %f AND $progress.isDeleted = false).@count >= 1", cutoffDate as NSDate, Constants.continueWatchingMinRelativePosition, Constants.continueWatchingMaxRelativePosition)

        let sessions = storage.realm.objects(Session.self)
            .filter(NSCompoundPredicate(andPredicateWithSubpredicates: [videoPredicate, progressPredicate]))

        return Observable.collection(from: sessions)
    }()

    private var disposeBag = DisposeBag()

    func activate() {
        Observable.combineLatest(
            featuredSectionsObservable,
            continueWatchingSessionsObservable
        )
        .filter { !$0.isEmpty || !$1.isEmpty }
        .subscribe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] sections, continueWatchingSessions in
            guard let self = self else { return }
            self.update(with: sections, continueWatchingSessions: continueWatchingSessions)
        })
        .disposed(by: disposeBag)
    }

    func invalidate() {
        disposeBag = DisposeBag()
    }

    func update(with sections: Results<FeaturedSection>, continueWatchingSessions: Results<Session>) {
        let sortedContinueWatchingSessions = continueWatchingSessions.sorted(by: {
            guard let p1 = $0.progresses.first else { return false }
            guard let p2 = $1.progresses.first else { return false }
            return p1.updatedAt > p2.updatedAt
        })
        let continueWatchingSection = ExploreTabContent.Section(
            id: "continue-watching",
            title: "Continue Watching",
            icon: .symbol("list.bullet.below.rectangle"),
            items: sortedContinueWatchingSessions.prefix(Constants.maxContinueWatchingItems).compactMap { session in
                ExploreTabContent.Item(
                    session,
                    duration: session.mediaDuration - session.currentPosition()
                )
            }
        )

        let remoteSections = sections.compactMap(ExploreTabContent.Section.init)

        let contentSections = ([continueWatchingSection] + remoteSections).filter({ !$0.items.isEmpty })

        guard !contentSections.isEmpty else {
            content = nil
            return
        }

        content = ExploreTabContent(
            id: "explore",
            sections: contentSections
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

        self.init(
            id: session.identifier,
            title: event.name,
            subtitle: session.title,
            overlayText: effectiveDuration > 0 ? String(timestamp: effectiveDuration) : nil,
            overlaySymbol: session.mediaDuration > 0 ? "play" : nil,
            imageURL: session.imageURL,
            deepLink: WWDCAppCommand.revealVideo(session.identifier).url,
            progress: progress
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
