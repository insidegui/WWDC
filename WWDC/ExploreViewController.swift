import Cocoa
import SwiftUI
import Combine
import ConfCore

final class ExploreViewController: NSViewController, ObservableObject {

    private let provider: ExploreTabProvider

    init(provider: ExploreTabProvider) {
        self.provider = provider

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

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

    private lazy var titleBarFadeView: TitleBarBlurFadeView = {
        let v = TitleBarBlurFadeView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private func installRootViewIfNeeded() {
        guard rootView.superview == nil else { return }

        view.addSubview(rootView)
        view.addSubview(titleBarFadeView)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: view.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

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

    override func viewWillAppear() {
        super.viewWillAppear()

        provider.activate()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        installRootViewIfNeeded()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        provider.invalidate()
    }

}

extension NSWindow {
    var titleBarHeight: CGFloat { contentRect(forFrameRect: frame).height - contentLayoutRect.height }
}
