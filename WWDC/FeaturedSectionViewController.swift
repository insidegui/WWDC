//
//  FeaturedSectionViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

private extension NSUserInterfaceItemIdentifier {
    static let featuredContentItem = NSUserInterfaceItemIdentifier("featuredContentItem")
}

protocol FeaturedSectionViewControllerDelegate: class {
    func featuredSectionViewController(_ controller: FeaturedSectionViewController, didSelectContent viewModel: FeaturedContentViewModel)
}

final class FeaturedSectionViewController: NSViewController {

    init(viewModel: FeaturedSectionViewModel) {
        self.sectionViewModel = viewModel

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Metrics {
        static let height: CGFloat = 336
        static let padding: CGFloat = 24
    }

    private var disposeBag = DisposeBag()

    var sectionViewModel: FeaturedSectionViewModel {
        didSet {
            bindUI()
            collectionView.reloadData()
        }
    }

    var contents: [FeaturedContentViewModel] {
        return sectionViewModel.contents
    }

    weak var delegate: FeaturedSectionViewControllerDelegate?

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
        l.textColor = .primaryText
        l.font = .boldTitleFont

        return l
    }()

    private lazy var subtitleLabel: WWDCTextField = {
        let l = WWDCTextField(labelWithString: "")

        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        l.maximumNumberOfLines = 1
        l.textColor = .secondaryText
        l.font = .systemFont(ofSize: 16, weight: .medium)

        return l
    }()

    private lazy var titleContainer: NSView = {
        let v = NSView()

        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var titleStack: NSStackView = {
        let v = NSStackView(views: [self.titleLabel, self.subtitleLabel])

        v.orientation = .vertical
        v.spacing = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alignment = .leading

        return v
    }()

    private lazy var scrollView: WWDCHorizontalScrollView = {
        let v = WWDCHorizontalScrollView(frame: view.bounds)

        v.hasHorizontalScroller = true
        v.horizontalScroller?.alphaValue = 0
        v.scrollerStyle = .overlay
        v.backgroundColor = .clear

        _ = NotificationCenter.default.addObserver(forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: nil) { [weak v] _ in
            v?.scrollerStyle = .overlay
        }

        return v
    }()

    private lazy var collectionView: NSCollectionView = {
        var rect = view.bounds
        rect.size.height = FeaturedContentCollectionViewItem.Metrics.height

        let v = NSCollectionView(frame: rect)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: FeaturedContentCollectionViewItem.Metrics.width,
                                 height: FeaturedContentCollectionViewItem.Metrics.height)
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = Metrics.padding
        layout.sectionInset = NSEdgeInsets(top: 0, left: Metrics.padding, bottom: 0, right: Metrics.padding)

        v.collectionViewLayout = layout
        v.dataSource = self
        v.delegate = self
        v.autoresizingMask = [.width, .height]
        v.backgroundColors = [.clear]

        return v
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: Metrics.height))
        view.wantsLayer = true

        scrollView.frame = NSRect(x: 0, y: 0, width: view.bounds.width, height: FeaturedContentCollectionViewItem.Metrics.height)
        scrollView.autoresizingMask = [.width, .minYMargin]
        view.addSubview(scrollView)
        scrollView.documentView = collectionView

        view.addSubview(titleContainer)
        titleContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.padding).isActive = true
        titleContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.padding).isActive = true
        titleContainer.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        titleContainer.bottomAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true

        titleContainer.addSubview(titleStack)
        titleStack.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor).isActive = true
        titleStack.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(FeaturedContentCollectionViewItem.self, forItemWithIdentifier: .featuredContentItem)
        bindUI()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // https://stackoverflow.com/questions/46433652/nscollectionview-does-not-scroll-items-past-initial-visible-rect
        collectionView.setFrameSize(collectionView.collectionViewLayout!.collectionViewContentSize)
    }

    override func scrollToBeginningOfDocument(_ sender: Any?) {
        guard !contents.isEmpty else { return }

        let beginningSet = Set([IndexPath(item: 0, section: 0)])
        collectionView.scrollToItems(at: beginningSet, scrollPosition: .leadingEdge)
    }

    private func bindUI() {
        disposeBag = DisposeBag()

        sectionViewModel.rxTitle.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(titleLabel.rx.text).disposed(by: disposeBag)
        sectionViewModel.rxSubtitle.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(subtitleLabel.rx.text).disposed(by: disposeBag)
        sectionViewModel.rxSubtitle.map({ $0.isEmpty }).asDriver(onErrorJustReturn: true).drive(subtitleLabel.rx.isHidden).disposed(by: disposeBag)
    }

}

extension FeaturedSectionViewController: NSCollectionViewDelegate, NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return contents.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let item = collectionView.makeItem(withIdentifier: .featuredContentItem, for: indexPath) as? FeaturedContentCollectionViewItem else {
            return NSCollectionViewItem()
        }

        item.viewModel = contents[indexPath.item]
        item.onClicked = { [unowned self] viewModel in
            self.delegate?.featuredSectionViewController(self, didSelectContent: viewModel)
        }

        return item
    }

    func collectionView(_ collectionView: NSCollectionView, shouldChangeItemsAt indexPaths: Set<IndexPath>, to highlightState: NSCollectionViewItem.HighlightState) -> Set<IndexPath> {
        return Set<IndexPath>()
    }

}
