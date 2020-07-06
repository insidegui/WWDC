//
//  SessionsTableViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import RealmSwift
import ConfCore
import os.log

// MARK: - Sessions Table View Controller

class SessionsTableViewController: NSViewController, NSMenuItemValidation {

    private let disposeBag = DisposeBag()

    weak var delegate: SessionsTableViewControllerDelegate?

    var selectedSession = BehaviorRelay<SessionViewModel?>(value: nil)

    let style: SessionsListStyle

    init(style: SessionsListStyle) {
        self.style = style

        super.init(nibName: nil, bundle: nil)

        identifier = NSUserInterfaceItemIdentifier(rawValue: "videosList")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.darkWindowBackground.cgColor
        view.widthAnchor.constraint(lessThanOrEqualToConstant: 675).isActive = true

        scrollView.frame = view.bounds
        tableView.frame = view.bounds

        scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true

        view.addSubview(scrollView)
        view.addSubview(searchController.view)

        searchController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        scrollView.topAnchor.constraint(equalTo: searchController.view.bottomAnchor).isActive = true

        searchController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        searchController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        searchController.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self

        setupContextualMenu()

        tableView.rx.selectedRow.map { index -> SessionViewModel? in
            guard let index = index else { return nil }
            guard case .session(let viewModel) = self.displayedRows[index].kind else { return nil }

            return viewModel
        }.bind(to: selectedSession).disposed(by: disposeBag)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        view.window?.makeFirstResponder(tableView)

        performFirstUpdateIfNeeded()
    }

    // MARK: - Selection

    private var initialSelection: SessionIdentifiable?

    private func selectSessionImmediately(with identifier: SessionIdentifiable) {

        guard let index = displayedRows.firstIndex(where: { row in
            row.represents(session: identifier)
        }) else {
            return
        }

        tableView.scrollRowToCenter(index)
        tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
    }

    func select(session: SessionIdentifiable) {

        // If we haven't yet displayed our rows, likely because we haven't come on screen
        // yet. We defer scrolling to the requested identifier until that time.
        guard hasPerformedInitialRowDisplay else {
            initialSelection = session
            return
        }

        let needsToClearSearchToAllowSelection = !isSessionVisible(for: session) && canDisplay(session: session)

        if needsToClearSearchToAllowSelection {
            searchController.resetFilters()
            setFilterResults(.empty, animated: view.window != nil, selecting: session)
        } else {
            selectSessionImmediately(with: session)
        }
    }

    func scrollToToday() {

        sessionRowProvider?.sessionRowIdentifierForToday().flatMap { select(session: $0) }
    }

    var hasPerformedFirstUpdate = false

    /// This function is meant to ensure the table view gets populated
    /// even if its data model gets added while it is offscreen. Specifically,
    /// when this table view is not the initial active tab.
    private func performFirstUpdateIfNeeded() {
        guard !hasPerformedFirstUpdate && sessionRowProvider != nil && view.window != nil else { return }
        hasPerformedFirstUpdate = true

        updateWith(searchResults: filterResults.latestSearchResults, animated: false, selecting: nil)
    }

    private func updateWith(searchResults: Results<Session>?, animated: Bool, selecting session: SessionIdentifiable?) {
        guard hasPerformedFirstUpdate else { return }

        guard let results = searchResults else {
            setDisplayedRows(sessionRowProvider?.allRows ?? [], animated: animated, overridingSelectionWith: session)
            return
        }

        guard let sessionRowProvider = sessionRowProvider else { return }

        let sessionRows = sessionRowProvider.filteredRows(onlyIncludingRowsFor: results)

        setDisplayedRows(sessionRows, animated: animated, overridingSelectionWith: session)
    }

    // MARK: - Updating the Displayed Rows

    var sessionRowProvider: SessionRowProvider? {
        didSet {
            performFirstUpdateIfNeeded()
        }
    }

    private(set) var displayedRows: [SessionRow] = []

    lazy var displayedRowsLock = DispatchQueue(label: "io.wwdc.sessiontable.displayedrows.lock\(self.hashValue)", qos: .userInteractive)

    private var hasPerformedInitialRowDisplay = false

    private func performInitialRowDisplayIfNeeded(displaying rows: [SessionRow]) -> Bool {

        guard !hasPerformedInitialRowDisplay else { return true }
        hasPerformedInitialRowDisplay = true

        displayedRowsLock.suspend()

        displayedRows = rows

        // Clear filters if there is an initial selection that we can display that isn't gonna be visible
        if let initialSelection = self.initialSelection,
            !isSessionVisible(for: initialSelection) && canDisplay(session: initialSelection) {

            searchController.resetFilters()
            _filterResults = .empty
            displayedRows = sessionRowProvider?.allRows ?? []
        }

        tableView.reloadData()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0

            if let deferredSelection = self.initialSelection {
                self.initialSelection = nil
                self.selectSessionImmediately(with: deferredSelection)
            }

            // Ensure an initial selection
            if self.tableView.selectedRow == -1,
                let defaultIndex = rows.firstSessionRowIndex() {

                self.tableView.selectRowIndexes(IndexSet(integer: defaultIndex), byExtendingSelection: false)
            }

            self.scrollView.alphaValue = 1
            self.tableView.allowsEmptySelection = false
        }, completionHandler: {
            self.displayedRowsLock.resume()
        })

        return false
    }

    func setDisplayedRows(_ newValue: [SessionRow], animated: Bool, overridingSelectionWith session: SessionIdentifiable?) {

        guard performInitialRowDisplayIfNeeded(displaying: newValue) else { return }

        // Dismiss the menu when the displayed rows are about to change otherwise it will crash
        tableView.menu?.cancelTrackingWithoutAnimation()

        displayedRowsLock.async {

            let oldValue = self.displayedRows

            // Same elements, same order: https://github.com/apple/swift/blob/master/stdlib/public/core/Arrays.swift.gyb#L2203
            if oldValue == newValue { return }

            let oldRowsSet = Set(oldValue.enumerated().map { IndexedSessionRow(sessionRow: $1, index: $0) })
            let newRowsSet = Set(newValue.enumerated().map { IndexedSessionRow(sessionRow: $1, index: $0) })

            let removed = oldRowsSet.subtracting(newRowsSet)
            let added = newRowsSet.subtracting(oldRowsSet)

            let removedIndexes = IndexSet(removed.map { $0.index })
            let addedIndexes = IndexSet(added.map { $0.index })

            // Only reload rows if their relative positioning changes. This prevents
            // cell contents from flashing when cells are unnecessarily reloaded
            var needReloadedIndexes = IndexSet()

            let sortedOldRows = oldRowsSet.intersection(newRowsSet).sorted(by: { (row1, row2) -> Bool in
                return row1.index < row2.index
            })

            let sortedNewRows = newRowsSet.intersection(oldRowsSet).sorted(by: { (row1, row2) -> Bool in
                return row1.index < row2.index
            })

            for (oldSessionRowIndex, newSessionRowIndex) in zip(sortedOldRows, sortedNewRows) where oldSessionRowIndex.sessionRow != newSessionRowIndex.sessionRow {
                needReloadedIndexes.insert(newSessionRowIndex.index)
            }

            DispatchQueue.main.sync {

                var selectedIndexes = IndexSet()
                if let session = session,
                    let overrideIndex = newValue.index(of: session) {

                    selectedIndexes.insert(overrideIndex)
                } else {
                    // Preserve selected rows if possible
                    let previouslySelectedRows = self.tableView.selectedRowIndexes.compactMap { (index) -> IndexedSessionRow? in
                        guard index < oldValue.endIndex else { return nil }
                        return IndexedSessionRow(sessionRow: oldValue[index], index: index)
                    }

                    let newSelection = newRowsSet.intersection(previouslySelectedRows)
                    if let topOfPreviousSelection = previouslySelectedRows.first, newSelection.isEmpty {
                        // The update has removed the selected row(s).
                        // e.g. You have the unwatched filter active and then mark the selection as watched
                        stride(from: topOfPreviousSelection.index, to: -1, by: -1).lazy.compactMap {
                            return IndexedSessionRow(sessionRow: oldValue[$0], index: $0)
                        }.first { (indexedRow: IndexedSessionRow) -> Bool in
                            newRowsSet.contains(indexedRow)
                        }.flatMap {
                            newRowsSet.firstIndex(of: $0)
                        }.map {
                            newRowsSet[$0].index
                        }.map {
                            selectedIndexes = IndexSet(integer: $0)
                        }
                    } else {
                        selectedIndexes = IndexSet(newSelection.map { $0.index })
                    }
                }

                if selectedIndexes.isEmpty, let defaultIndex = newValue.firstSessionRowIndex() {
                    selectedIndexes.insert(defaultIndex)
                }

                NSAnimationContext.beginGrouping()
                let context = NSAnimationContext.current
                context.duration = animated ? 0.35 : 0

                context.completionHandler = {
                    NSAnimationContext.runAnimationGroup({ (context) in
                        context.allowsImplicitAnimation = animated
                        self.tableView.scrollRowToCenter(selectedIndexes.first ?? 0)
                    }, completionHandler: nil)
                }

                self.tableView.beginUpdates()

                self.tableView.removeRows(at: removedIndexes, withAnimation: [.slideLeft])

                self.tableView.insertRows(at: addedIndexes, withAnimation: [.slideDown])

                // insertRows(::) and removeRows(::) will query the delegate for the row count at the beginning
                // so we delay updating the data model until after those methods have done their thing
                self.displayedRows = newValue

                // This must be after you update the backing model
                self.tableView.reloadData(forRowIndexes: needReloadedIndexes, columnIndexes: IndexSet(integersIn: 0..<1))

                self.tableView.selectRowIndexes(selectedIndexes, byExtendingSelection: false)

                self.tableView.endUpdates()
                NSAnimationContext.endGrouping()
            }
        }
    }

    func isSessionVisible(for session: SessionIdentifiable) -> Bool {
        assert(hasPerformedInitialRowDisplay, "Rows must be displayed before checking this value")

        return displayedRows.contains { row -> Bool in
            row.represents(session: session)
        }
    }

    func canDisplay(session: SessionIdentifiable) -> Bool {
        return sessionRowProvider?.allRows.contains { row -> Bool in
            row.represents(session: session)
        } ?? false
    }

    // MARK: - Search

    /// Provide a session identifier if you'd like to override the default selection behavior. Provide
    /// nil to let the table figure out what selection to apply after the update.
    func setFilterResults(_ filterResults: FilterResults, animated: Bool, selecting: SessionIdentifiable?) {
        _filterResults = filterResults
        filterResults.observe { [weak self] in
            self?.updateWith(searchResults: $0, animated: animated, selecting: selecting)
        }
    }

    var _filterResults = FilterResults.empty
    private var filterResults: FilterResults {
        get {
            return _filterResults
        }
        set {
            _filterResults = newValue
            filterResults.observe { [weak self] in
                self?.updateWith(searchResults: $0, animated: false, selecting: nil)
            }
        }
    }

    // MARK: - UI

    lazy var searchController = SearchFiltersViewController.loadFromStoryboard()

    lazy var tableView: WWDCTableView = {
        let v = WWDCTableView()

        // We control the intial selection during initialization
        v.allowsEmptySelection = true

        v.wantsLayer = true
        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .listBackground
        v.headerView = nil
        v.rowHeight = Metrics.sessionRowHeight
        v.autoresizingMask = [.width, .height]
        v.floatsGroupRows = true
        v.gridStyleMask = .solidHorizontalGridLineMask
        v.gridColor = .darkGridColor

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "session"))
        v.addTableColumn(column)

        return v
    }()

    lazy var scrollView: NSScrollView = {
        let v = NSScrollView()

        v.focusRingType = .none
        v.backgroundColor = .listBackground
        v.borderType = .noBorder
        v.documentView = self.tableView
        v.hasVerticalScroller = true
        v.hasHorizontalScroller = false
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alphaValue = 0

        return v
    }()

    // MARK: - Contextual menu

    fileprivate enum ContextualMenuOption: Int {
        case watched = 1000
        case unwatched = 1001
        case favorite = 1002
        case removeFavorite = 1003
        case download = 1004
        case cancelDownload = 1005
        case revealInFinder = 1006
    }

    private func setupContextualMenu() {
        let contextualMenu = NSMenu(title: "TableView Menu")

        let watchedMenuItem = NSMenuItem(title: "Mark as Watched", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        watchedMenuItem.option = .watched
        contextualMenu.addItem(watchedMenuItem)

        let unwatchedMenuItem = NSMenuItem(title: "Mark as Unwatched", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        unwatchedMenuItem.option = .unwatched
        contextualMenu.addItem(unwatchedMenuItem)

        contextualMenu.addItem(.separator())

        let favoriteMenuItem = NSMenuItem(title: "Add to Favorites", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        favoriteMenuItem.option = .favorite
        contextualMenu.addItem(favoriteMenuItem)

        let removeFavoriteMenuItem = NSMenuItem(title: "Remove From Favorites", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        removeFavoriteMenuItem.option = .removeFavorite
        contextualMenu.addItem(removeFavoriteMenuItem)

        contextualMenu.addItem(.separator())

        let downloadMenuItem = NSMenuItem(title: "Download", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        downloadMenuItem.option = .download
        contextualMenu.addItem(downloadMenuItem)

        let cancelDownloadMenuItem = NSMenuItem(title: "Cancel Download", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        contextualMenu.addItem(cancelDownloadMenuItem)
        cancelDownloadMenuItem.option = .cancelDownload

        let revealInFinderMenuItem = NSMenuItem(title: "Reveal in Finder", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        contextualMenu.addItem(revealInFinderMenuItem)
        revealInFinderMenuItem.option = .revealInFinder

        tableView.menu = contextualMenu
    }

    private func selectedAndClickedRowIndexes() -> IndexSet {
        let clickedRow = tableView.clickedRow
        let selectedRowIndexes = tableView.selectedRowIndexes

        if clickedRow < 0 || selectedRowIndexes.contains(clickedRow) {
            return selectedRowIndexes
        } else {
            return IndexSet(integer: clickedRow)
        }
    }

    @objc private func tableViewMenuItemClicked(_ menuItem: NSMenuItem) {
        var viewModels = [SessionViewModel]()

        selectedAndClickedRowIndexes().forEach { row in
            guard case .session(let viewModel) = displayedRows[row].kind else { return }

            viewModels.append(viewModel)
        }

        guard !viewModels.isEmpty else { return }

        switch menuItem.option {
        case .watched:
            delegate?.sessionTableViewContextMenuActionWatch(viewModels: viewModels)
        case .unwatched:
            delegate?.sessionTableViewContextMenuActionUnWatch(viewModels: viewModels)
        case .favorite:
            delegate?.sessionTableViewContextMenuActionFavorite(viewModels: viewModels)
        case .removeFavorite:
            delegate?.sessionTableViewContextMenuActionRemoveFavorite(viewModels: viewModels)
        case .download:
            delegate?.sessionTableViewContextMenuActionDownload(viewModels: viewModels)
        case .cancelDownload:
            delegate?.sessionTableViewContextMenuActionCancelDownload(viewModels: viewModels)
        case .revealInFinder:
            delegate?.sessionTableViewContextMenuActionRevealInFinder(viewModels: viewModels)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        for row in selectedAndClickedRowIndexes() {
            let sessionRow = displayedRows[row]

            guard case .session(let viewModel) = sessionRow.kind else { break }

            if shouldEnableMenuItem(menuItem: menuItem, viewModel: viewModel) { return true }
        }

        return false
    }

    private func shouldEnableMenuItem(menuItem: NSMenuItem, viewModel: SessionViewModel) -> Bool {

        switch menuItem.option {
        case .watched:
            let canMarkAsWatched = !viewModel.session.isWatched
                && viewModel.session.instances.first?.isCurrentlyLive != true
                && viewModel.session.asset(ofType: .streamingVideo) != nil

            return canMarkAsWatched
        case .unwatched:
            return viewModel.session.isWatched || viewModel.session.progresses.count > 0
        case .favorite:
            return !viewModel.isFavorite
        case .removeFavorite:
            return viewModel.isFavorite
        default: ()
        }

        switch menuItem.option {
        case .download:
            return DownloadManager.shared.isDownloadable(viewModel.session) &&
                !DownloadManager.shared.isDownloading(viewModel.session) &&
                !DownloadManager.shared.hasDownloadedVideo(session: viewModel.session)
        case .cancelDownload:
            return DownloadManager.shared.isDownloadable(viewModel.session) && DownloadManager.shared.isDownloading(viewModel.session)
        case .revealInFinder:
            return DownloadManager.shared.hasDownloadedVideo(session: viewModel.session)
        default: ()
        }

        return false
    }
}

private extension NSMenuItem {

    var option: SessionsTableViewController.ContextualMenuOption {
        get {
            guard let value = SessionsTableViewController.ContextualMenuOption(rawValue: tag) else {
                fatalError("Invalid ContextualMenuOption: \(tag)")
            }

            return value
        }
        set {
            tag = newValue.rawValue
        }
    }

}

// MARK: - Datasource / Delegate

extension SessionsTableViewController: NSTableViewDataSource, NSTableViewDelegate {

    fileprivate struct Metrics {
        static let headerRowHeight: CGFloat = 20
        static let sessionRowHeight: CGFloat = 64
    }

    private struct Constants {
        static let sessionCellIdentifier = "sessionCell"
        static let titleCellIdentifier = "titleCell"
        static let rowIdentifier = "row"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedRows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let sessionRow = displayedRows[row]

        switch sessionRow.kind {
        case .session(let viewModel):
            return cellForSessionViewModel(viewModel)
        case .sectionHeader(let title):
            return cellForSectionTitle(title)
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        var rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier), owner: tableView) as? WWDCTableRowView

        if rowView == nil {
            rowView = WWDCTableRowView(frame: .zero)
            rowView?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier)
        }

        switch displayedRows[row].kind {
        case .sectionHeader:
            rowView?.isGroupRowStyle = true
        default:
            rowView?.isGroupRowStyle = false
        }

        return rowView
    }

    private func cellForSessionViewModel(_ viewModel: SessionViewModel) -> SessionTableCellView? {
        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.sessionCellIdentifier), owner: tableView) as? SessionTableCellView

        if cell == nil {
            cell = SessionTableCellView(frame: .zero)
            cell?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.sessionCellIdentifier)
        }

        cell?.viewModel = viewModel

        return cell
    }

    private func cellForSectionTitle(_ title: String) -> TitleTableCellView? {
        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.titleCellIdentifier), owner: tableView) as? TitleTableCellView

        if cell == nil {
            cell = TitleTableCellView(frame: .zero)
            cell?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.titleCellIdentifier)
        }

        cell?.title = title

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch displayedRows[row].kind {
        case .session:
            return Metrics.sessionRowHeight
        case .sectionHeader:
            return Metrics.headerRowHeight
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        switch displayedRows[row].kind {
        case .sectionHeader:
            return false
        case .session:
            return true
        }
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        switch displayedRows[row].kind {
        case .sectionHeader:
            return true
        case .session:
            return false
        }
    }

}
