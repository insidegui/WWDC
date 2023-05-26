import Cocoa
import RealmSwift
import RxSwift
import RxCocoa
import SwiftUI
import ConfCore

final class ExploreTabContentProvider: ObservableObject {
    @Published private(set) var content: ExploreTabContent?

    func update(with sections: Results<FeaturedSection>) {
        let contentSections = sections.compactMap(ExploreTabContent.Section.init)

        guard !contentSections.isEmpty else {
            content = nil
            return
        }

        content = ExploreTabContent(
            id: "explore",
            sections: Array(contentSections)
        )
    }
}

final class ExploreViewController: NSViewController, ObservableObject {

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    private let contentProvider = ExploreTabContentProvider()

    override func loadView() {
        let backgroundView = NSVisualEffectView()
        backgroundView.blendingMode = .behindWindow
        backgroundView.material = .menu
        backgroundView.state = .active
        backgroundView.appearance = NSAppearance(named: .darkAqua)
        view = backgroundView
        view.wantsLayer = true
    }

    private lazy var rootView: NSView = {
        let host = NSHostingView(rootView: ExploreTabRootView().environmentObject(contentProvider))
        host.translatesAutoresizingMaskIntoConstraints = false
        return host
    }()

    private func installRootViewIfNeeded() {
        guard rootView.superview == nil else { return }

        view.addSubview(rootView)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: view.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func update(with sections: Results<FeaturedSection>) {
        guard isViewLoaded else { return }
        
        DispatchQueue.main.async {
            self.contentProvider.update(with: sections)

            self.installRootViewIfNeeded()
        }
    }

}

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
        guard let event = session.event.first else { return nil }

        self.init(
            id: session.identifier,
            title: event.name,
            subtitle: session.title,
            overlayText: session.mediaDuration > 0 ? String(timestamp: session.mediaDuration) : nil,
            overlaySymbol: session.mediaDuration > 0 ? "play" : nil,
            imageURL: session.imageURL,
            deepLink: WWDCAppCommand.revealVideo(session.identifier).url
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
