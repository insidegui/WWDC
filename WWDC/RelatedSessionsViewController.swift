//
//  RelatedSessionsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

private extension NSUserInterfaceItemIdentifier {
    static let sessionItem = NSUserInterfaceItemIdentifier("sessionCell")
}

protocol RelatedSessionsViewControllerDelegate: class {
    func relatedSessionsViewController(_ controller: RelatedSessionsViewController, didSelectSession viewModel: SessionViewModel)
}

final class RelatedSessionsViewController: NSViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Metrics {
        static let height: CGFloat = 96 + scrollerOffset
        static let itemHeight: CGFloat = 64
        static let scrollerOffset: CGFloat = 15
        static let scrollViewHeight: CGFloat = itemHeight + scrollerOffset
        static let itemWidth: CGFloat = 360
        static let padding: CGFloat = 24
    }

    private let disposeBag = DisposeBag()

    var sessions: [SessionViewModel] = [] {
        didSet {
            collectionView.reloadData()
            view.isHidden = sessions.count == 0
        }
    }

    weak var delegate: RelatedSessionsViewControllerDelegate?

    override var title: String? {
        didSet {
            titleLabel.stringValue = title ?? ""
        }
    }

    private lazy var titleLabel: WWDCTextField = {
        let l = WWDCTextField(labelWithString: "")
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        l.maximumNumberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = .secondaryText
        l.font = .wwdcRoundedSystemFont(ofSize: 20, weight: .semibold)

        return l
    }()

    private lazy var scrollView: NSScrollView = {
        let v = NSScrollView(frame: view.bounds)

        v.hasHorizontalScroller = true
        v.automaticallyAdjustsContentInsets = false
        v.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: Metrics.scrollerOffset, right: 0)
        v.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: -Metrics.scrollerOffset, right: 0)

        /// Force overlay style
        v.scrollerStyle = .overlay
        _ = NotificationCenter.default.addObserver(forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: nil) { [weak v] _ in
            v?.scrollerStyle = .overlay
        }

        v.backgroundColor = .darkWindowBackground

        return v
    }()

    private lazy var collectionView: NSCollectionView = {
        var rect = view.bounds
        rect.size.height = Metrics.scrollViewHeight

        let v = NSCollectionView(frame: rect)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: Metrics.itemWidth, height: Metrics.itemHeight)
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = Metrics.padding

        v.collectionViewLayout = layout
        v.dataSource = self
        v.delegate = self
        v.autoresizingMask = [.width, .minYMargin]

        v.backgroundColors = [.darkWindowBackground]

        return v
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: Metrics.height))
        view.wantsLayer = true

        scrollView.frame = NSRect(x: 0, y: 0, width: view.bounds.width, height: Metrics.scrollViewHeight)
        scrollView.autoresizingMask = [.width, .minYMargin]
        view.addSubview(scrollView)
        scrollView.documentView = collectionView

        view.addSubview(titleLabel)
        titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        titleLabel.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(SessionCollectionViewItem.self, forItemWithIdentifier: .sessionItem)
    }

    override func scrollToBeginningOfDocument(_ sender: Any?) {
        guard !sessions.isEmpty else { return }

        let beginningSet = Set([IndexPath(item: 0, section: 0)])
        collectionView.scrollToItems(at: beginningSet, scrollPosition: .leadingEdge)
    }

}

extension RelatedSessionsViewController: NSCollectionViewDelegate, NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return sessions.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let item = collectionView.makeItem(withIdentifier: .sessionItem, for: indexPath) as? SessionCollectionViewItem else {
            return NSCollectionViewItem()
        }

        item.viewModel = sessions[indexPath.item]
        item.onClicked = { [unowned self] viewModel in
            self.delegate?.relatedSessionsViewController(self, didSelectSession: viewModel)
        }

        return item
    }

    func collectionView(_ collectionView: NSCollectionView, shouldChangeItemsAt indexPaths: Set<IndexPath>, to highlightState: NSCollectionViewItem.HighlightState) -> Set<IndexPath> {
        return Set<IndexPath>()
    }

}
