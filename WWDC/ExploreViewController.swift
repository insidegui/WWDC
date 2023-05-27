import Cocoa
import SwiftUI
import Combine
import ConfCore

final class ExploreTabProvider: ObservableObject {
    @Published private(set) var content: ExploreTabContent?
    @Published var scrollOffset = CGPoint.zero

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

    private let provider = ExploreTabProvider()

    @Published private var scrollOffset = CGPoint.zero

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
        let host = NSHostingView(rootView: ExploreTabRootView().environmentObject(provider))
        host.translatesAutoresizingMaskIntoConstraints = false
        host.wantsLayer = true
        return host
    }()

    private lazy var cancellables = Set<AnyCancellable>()

    private lazy var titleBarFadeView = TitleBarBlurFadeView()

    private func installRootViewIfNeeded() {
        guard rootView.superview == nil else { return }

        view.addSubview(rootView)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: view.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        titleBarFadeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleBarFadeView)
        NSLayoutConstraint.activate([
            titleBarFadeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleBarFadeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleBarFadeView.topAnchor.constraint(equalTo: view.topAnchor)
        ])

        rootView.layer?.mask = contentMask

        provider.$scrollOffset.sink { [weak self] offset in
            guard let self = self else { return }
            self.updateTitleBarFadeVisibility(with: offset)
        }.store(in: &cancellables)
    }

    private func updateTitleBarFadeVisibility(with offset: CGPoint) {
        let visible = offset.y >= 9

        titleBarFadeView.isHidden = !visible
    }

    private lazy var contentMask: CALayer = {
        let l = CALayer()

        l.autoresizingMask = []
        l.addSublayer(contentMaskArea)
        l.addSublayer(contentFadeLayer)

        return l
    }()

    private lazy var contentMaskArea: CALayer = {
        let l = CALayer()

        l.backgroundColor = NSColor.cyan.cgColor
        l.autoresizingMask = []

        return l
    }()

    private lazy var contentFadeLayer: CAGradientLayer = {
        let l = CAGradientLayer()
        l.colors = [NSColor.red.withAlphaComponent(0).cgColor, NSColor.red.withAlphaComponent(0.4).cgColor, NSColor.red.cgColor]
        l.locations = [NSNumber(value: 0), NSNumber(value: 0.7), NSNumber(value: 1)]
        l.startPoint = CGPoint(x: 0, y: 0)
        l.endPoint = CGPoint(x: 0, y: 1)
        l.autoresizingMask = []
        return l
    }()

    override func viewDidLayout() {
        super.viewDidLayout()

        guard let window = rootView.window else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        contentMask.frame = rootView.bounds
        contentMaskArea.frame = CGRect(x: 0, y: window.titleBarHeight, width: rootView.bounds.width, height: rootView.bounds.height - window.titleBarHeight)
        contentFadeLayer.frame = CGRect(x: 0, y: 0, width: rootView.bounds.width, height: window.titleBarHeight)
        CATransaction.commit()
    }

    func update(with sections: Results<FeaturedSection>) {
        guard isViewLoaded else { return }
        
        DispatchQueue.main.async {
            self.provider.update(with: sections)

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

extension NSWindow {
    var titleBarHeight: CGFloat { contentRect(forFrameRect: frame).height - contentLayoutRect.height }
}
