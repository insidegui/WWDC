//
//  NewSessionsTableViewController.swift
//  WWDC
//
//  Created by luca on 30.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Combine
import ConfCore
import Observation
import OSLog
import RealmSwift
import SwiftUI

// MARK: - Sessions Table View Controller

@available(macOS 26.0, *)
class NewSessionsTableViewController: NSViewController, NSMenuItemValidation, Logging {
    static var log = makeLogger()

    private lazy var cancellables: Set<AnyCancellable> = []

    weak var delegate: SessionsTableViewControllerDelegate?

    private let searchCoordinator: NewGlobalSearchCoordinator
    private let searchTarget: ReferenceWritableKeyPath<NewGlobalSearchCoordinator, GlobalSearchTabState>
    init(searchCoordinator: NewGlobalSearchCoordinator, searchTarget: ReferenceWritableKeyPath<NewGlobalSearchCoordinator, GlobalSearchTabState>, rowProvider: SessionRowProvider, initialSelection: SessionIdentifiable?) {
        self.searchCoordinator = searchCoordinator
        self.searchTarget = searchTarget
        var config = Self.defaultLoggerConfig()
        config.category += ": \(String(reflecting: type(of: rowProvider)))"
        Self.log = Self.makeLogger(config: config)
        self.sessionRowProvider = rowProvider
        self.stateRestorationSelection = initialSelection

        super.init(nibName: nil, bundle: nil)

        identifier = NSUserInterfaceItemIdentifier(rawValue: "videosList")

        rowProvider
            .rowsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateWith(rows: $0, animated: true)
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var filterItem: NSMenuToolbarItem? {
        viewIfLoaded?.window?.toolbar?.items.first(where: { $0.itemIdentifier == .filterItem }) as? NSMenuToolbarItem
    }

    private var header: NSView!
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: MainWindowController.defaultRect.height))

        scrollView.frame = view.bounds
        tableView.frame = view.bounds
        view.addSubview(scrollView)

        scrollView.contentView.automaticallyAdjustsContentInsets = true

        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true

        let header = NSHostingView(rootView: ListContentFilterHeaderView(stateKeyPath: searchTarget).environment(searchCoordinator))
        header.isHidden = true
        self.header = header
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.widthAnchor.constraint(lessThanOrEqualToConstant: 675)
        ])
        header.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self

        setupContextualMenu()
        if let rows = sessionRowProvider.rows {
            updateWith(rows: rows, animated: true)
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let additionalTopInset = header.isHidden ? 0 : header.bounds.height - header.safeAreaInsets.top
        guard additionalTopInset > 0 else { return }
        scrollView.additionalSafeAreaInsets.top = additionalTopInset
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // This allows using the arrow keys to navigate
        view.window?.makeFirstResponder(tableView)
        prepareForDisplayingFilterItem()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        prepareForHidingFilterItem()
    }

    override func viewWillLayout() {
        super.viewWillLayout()
        let count = searchCoordinator[keyPath: searchTarget].effectiveFilters.filter { !$0.isEmpty }.count
        filterItem?.badge = count > 0 ? .count(count) : nil
        filterItem?.showsIndicator = count > 0
    }

    @objc private func didTapSearchItem(_ item: NSToolbarItem) {
        let isHeaderHiddenNext = !header.isHidden
        let nextTopInset = isHeaderHiddenNext ? 0 : (header.bounds.height - header.safeAreaInsets.top)
        item.image = NSImage(systemSymbolName: isHeaderHiddenNext ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill", accessibilityDescription: isHeaderHiddenNext ? "Show Filter Options" : "Hide Filter Options")
        item.toolTip = item.image?.accessibilityDescription
        NSAnimationContext.runAnimationGroup { _ in
            header.animator().isHidden = isHeaderHiddenNext
            scrollView.animator().additionalSafeAreaInsets.top = nextTopInset
        }
    }

    @objc private func didTapClearItem(_ item: Any) {
        searchCoordinator.resetAction.send()
    }

    // MARK: - Selection

    @Published
    var selectedSession: SessionViewModel?
    /// The state restoration selection will be applied on 1st row display and then cleared
    private var stateRestorationSelection: SessionIdentifiable?
    /// The pending selection will be selected on the next update
    private var pendingSelection: SessionIdentifiable?

    private func selectSessionImmediately(with identifier: SessionIdentifiable) {
        guard let index = displayedRows.firstIndex(where: { $0.represents(session: identifier) }) else {
            log.debug("Can't select session \(identifier.sessionIdentifier)")
            return
        }

        tableView.scrollRowToCenter(index)
        tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
    }

    func select(session: SessionIdentifiable, removingFiltersIfNeeded: Bool = true) {
        let needsToClearSearchToAllowSelection = removingFiltersIfNeeded && !isSessionVisible(for: session) && canDisplay(session: session)

        if needsToClearSearchToAllowSelection {
            pendingSelection = session
        } else {
            selectSessionImmediately(with: session)
        }
    }

    /// Select and scroll to the session/get-together/lab that is "upcoming" and in your current filters
    /// We do not clear filters, so if your schedule view is just showing videos, it'll scroll to the video that will be released next
    func scrollToToday() {
        sessionRowProvider.sessionRowIdentifierForToday().flatMap { select(session: $0, removingFiltersIfNeeded: false) }
    }

    private func updateWith(rows: SessionRows, animated: Bool) {
        guard viewIfLoaded != nil else {
            return
        }
        let rowsToDisplay: [SessionRow]
        rowsToDisplay = rows.filtered

        guard performInitialRowDisplayIfNeeded(displaying: rowsToDisplay, allRows: rows.all) else {
            log.debug("Performed initial row display with [\(rowsToDisplay.count)] rows")
            return
        }

        setDisplayedRows(rowsToDisplay, animated: animated)
    }

    // MARK: - Updating the Displayed Rows

    let sessionRowProvider: SessionRowProvider

    private var displayedRows: [SessionRow] = []

    private lazy var displayedRowsLock = DispatchQueue(label: "io.wwdc.sessiontable.displayedrows.lock\(self.hashValue)", qos: .userInteractive)

    private func performInitialRowDisplayIfNeeded(displaying rows: [SessionRow], allRows: [SessionRow]) -> Bool {
        displayedRowsLock.suspend()

        displayedRows = rows

        tableView.reloadData()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0

            if let deferredSelection = self.stateRestorationSelection {
                self.stateRestorationSelection = nil
                self.selectSessionImmediately(with: deferredSelection)
            }

            // Ensure an initial selection
            if self.tableView.selectedRow == -1,
               let defaultIndex = rows.firstIndex(where: { $0.isSession })
            {
                self.tableView.selectRowIndexes(IndexSet(integer: defaultIndex), byExtendingSelection: false)
            }

            self.scrollView.alphaValue = 1
            self.tableView.allowsEmptySelection = false
        } completionHandler: {
            self.displayedRowsLock.resume()
        }

        return false
    }

    private func setDisplayedRows(_ newValue: [SessionRow], animated: Bool) {
        // Dismiss the menu when the displayed rows are about to change otherwise it will crash
        tableView.menu?.cancelTrackingWithoutAnimation()

        displayedRowsLock.async {
            let sessionToSelect = self.pendingSelection
            self.pendingSelection = nil
            let oldValue = self.displayedRows

            // Same elements, same order: https://github.com/apple/swift/blob/master/stdlib/public/core/Arrays.swift.gyb#L2203
            if oldValue == newValue { return }

            let oldRowsSet = Set(oldValue.enumerated().map { IndexedSessionRow(sessionRow: $1, index: $0) })
            let newRowsSet = Set(newValue.enumerated().map { IndexedSessionRow(sessionRow: $1, index: $0) })
            assert(newRowsSet.count == newValue.count)
            assert(oldRowsSet.count == oldValue.count)

            let removed = oldRowsSet.subtracting(newRowsSet)
            let added = newRowsSet.subtracting(oldRowsSet)

            let removedIndexes = IndexSet(removed.map { $0.index })
            let addedIndexes = IndexSet(added.map { $0.index })

            // Only reload rows if their relative positioning changes. This prevents
            // cell contents from flashing when cells are unnecessarily reloaded
            var needReloadedIndexes = IndexSet()

            let sortedOldRows = oldRowsSet.intersection(newRowsSet).sorted(by: { row1, row2 -> Bool in
                return row1.index < row2.index
            })

            let sortedNewRows = newRowsSet.intersection(oldRowsSet).sorted(by: { row1, row2 -> Bool in
                return row1.index < row2.index
            })

            for (oldSessionRowIndex, newSessionRowIndex) in zip(sortedOldRows, sortedNewRows) where oldSessionRowIndex.sessionRow != newSessionRowIndex.sessionRow {
                needReloadedIndexes.insert(newSessionRowIndex.index)
            }

            self.log.trace("setDisplayedRows: removed[\(removedIndexes.map { "\($0)" }.joined(separator: ",").count, privacy: .public)] added[\(addedIndexes.map { "\($0)" }.joined(separator: ",").count, privacy: .public)] reload[\(needReloadedIndexes.map { "\($0)" }.joined(separator: ",").count, privacy: .public)]")

            DispatchQueue.main.sync {
                var selectedIndexes = IndexSet()
                if let sessionToSelect,
                   let overrideIndex = newValue.firstIndex(where: { $0.sessionViewModel?.identifier == sessionToSelect.sessionIdentifier })
                {
                    selectedIndexes.insert(overrideIndex)
                } else {
                    // Preserve selected rows if possible
                    let previouslySelectedRows = self.tableView.selectedRowIndexes.compactMap { index -> IndexedSessionRow? in
                        guard index < oldValue.endIndex else { return nil }
                        return IndexedSessionRow(sessionRow: oldValue[index], index: index)
                    }

                    let newSelection = newRowsSet.intersection(previouslySelectedRows)
                    if let topOfPreviousSelection = previouslySelectedRows.first, newSelection.isEmpty {
                        // The update has removed the selected row(s).
                        // e.g. You have the unwatched filter active and then mark the selection as watched
                        stride(from: topOfPreviousSelection.index, to: -1, by: -1).lazy.compactMap {
                            IndexedSessionRow(sessionRow: oldValue[$0], index: $0)
                        }.first { (indexedRow: IndexedSessionRow) -> Bool in
                            newRowsSet.contains(indexedRow) && indexedRow.sessionRow.isSession
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

                if selectedIndexes.isEmpty, let defaultIndex = newValue.firstIndex(where: { $0.isSession }) {
                    selectedIndexes.insert(defaultIndex)
                }

                NSAnimationContext.beginGrouping()
                let context = NSAnimationContext.current
                context.duration = animated ? 0.35 : 0

                context.completionHandler = {
                    NSAnimationContext.runAnimationGroup({ context in
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

                self.log.debug("endUpdates: row count[\(self.displayedRows.count)]")
                self.tableView.endUpdates()
                NSAnimationContext.endGrouping()
            }
        }
    }

    func isSessionVisible(for session: SessionIdentifiable) -> Bool {
        return displayedRows.contains { row -> Bool in
            row.represents(session: session)
        }
    }

    func canDisplay(session: SessionIdentifiable) -> Bool {
        return sessionRowProvider.rows?.all.contains { row -> Bool in
            row.represents(session: session)
        } ?? false
    }

    // MARK: - UI

    lazy var tableView: WWDCTableView = {
        let v = WWDCTableView()

        // We control the initial selection during initialization
        v.allowsEmptySelection = true

        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .clear
        v.headerView = nil
        v.rowHeight = Metrics.sessionRowHeight
        v.autoresizingMask = [.width, .height]
        v.floatsGroupRows = true
        v.gridStyleMask = []
        v.style = .fullWidth

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "session"))
        v.addTableColumn(column)

        return v
    }()

    lazy var scrollView: NSScrollView = {
        let v = NSScrollView()

        v.focusRingType = .none
        v.drawsBackground = false
        v.borderType = .noBorder
        v.documentView = self.tableView
        v.hasVerticalScroller = true
        v.hasHorizontalScroller = false
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alphaValue = 0
        v.automaticallyAdjustsContentInsets = true

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
        case removeDownload = 1006
        case revealInFinder = 1007
        case clearFiler = 1008 // lives in tool bar
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

        let removeDownloadMenuItem = NSMenuItem(title: "Remove Download", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        contextualMenu.addItem(removeDownloadMenuItem)
        removeDownloadMenuItem.option = .removeDownload

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

        for row in selectedAndClickedRowIndexes() {
            guard case .session(let viewModel) = displayedRows[row].kind else { continue }

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
        case .removeDownload:
            delegate?.sessionTableViewContextMenuActionRemoveDownload(viewModels: viewModels)
        case .revealInFinder:
            delegate?.sessionTableViewContextMenuActionRevealInFinder(viewModels: viewModels)
        case .clearFiler:
            break
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        for row in selectedAndClickedRowIndexes() {
            let sessionRow = displayedRows[row]

            guard case .session(let viewModel) = sessionRow.kind else { break }

            if shouldEnableMenuItem(menuItem: menuItem, viewModel: viewModel) { return true }
        }

        return menuItem.option == .clearFiler
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
            return MediaDownloadManager.shared.canDownloadMedia(for: viewModel.session) &&
                !MediaDownloadManager.shared.isDownloadingMedia(for: viewModel.session) &&
                !MediaDownloadManager.shared.hasDownloadedMedia(for: viewModel.session)
        case .removeDownload:
            return viewModel.session.isDownloaded
        case .cancelDownload:
            return MediaDownloadManager.shared.canDownloadMedia(for: viewModel.session) && MediaDownloadManager.shared.isDownloadingMedia(for: viewModel.session)
        case .revealInFinder:
            return MediaDownloadManager.shared.hasDownloadedMedia(for: viewModel.session)
        case .clearFiler:
            return true
        default: ()
        }

        return false
    }
}

@available(macOS 26.0, *)
private extension NSMenuItem {
    var option: NewSessionsTableViewController.ContextualMenuOption {
        get {
            guard let value = NewSessionsTableViewController.ContextualMenuOption(rawValue: tag) else {
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

private extension NSUserInterfaceItemIdentifier {
    static let sessionRow = NSUserInterfaceItemIdentifier(rawValue: "sessionRow")
    static let headerRow = NSUserInterfaceItemIdentifier(rawValue: "headerRow")

    static let sessionCell = NSUserInterfaceItemIdentifier(rawValue: "sessionCell")
}

@available(macOS 26.0, *)
extension NewSessionsTableViewController: NSTableViewDataSource, NSTableViewDelegate {
    enum Metrics {
        static let headerRowHeight: CGFloat = 32
        static let sessionRowHeight: CGFloat = 64
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let numberOfRows = tableView.numberOfRows
        let selectedRow = tableView.selectedRow

        let row: Int? = (0..<numberOfRows).contains(selectedRow) ? selectedRow : nil

        if let row, let viewModel = displayedRows[row].sessionViewModel {
            selectedSession = viewModel
        } else {
            selectedSession = nil
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedRows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let sessionRow = displayedRows[row]

        switch sessionRow.kind {
        case .session(let viewModel):
            return cellForSessionViewModel(viewModel)
        case .sectionHeader:
            return nil
        }
    }

    private func rowView<T>(with id: NSUserInterfaceItemIdentifier) -> T? where T: NSTableRowView {
        var rowView = tableView.makeView(withIdentifier: id, owner: tableView) as? T
        if rowView == nil {
            rowView = T(frame: .zero)
            rowView?.identifier = id
        }
        return rowView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        switch displayedRows[row].kind {
        case .sectionHeader(let title, let symbol):
            let rowView: NewTopicHeaderRow? = rowView(with: .headerRow)
            rowView?.title = title
            rowView?.symbolName = symbol
            return rowView
        default:
            return rowView(with: .sessionRow)
        }
    }

    private func cellForSessionViewModel(_ viewModel: SessionViewModel) -> SessionTableCellView? {
        var cell = tableView.makeView(withIdentifier: .sessionCell, owner: tableView) as? SessionTableCellView

        if cell == nil {
            cell = SessionTableCellView(frame: .zero)
            cell?.identifier = .sessionCell
        }

        cell?.viewModel = viewModel

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

@available(macOS 26.0, *)
private extension NewSessionsTableViewController {
    func prepareForDisplayingFilterItem() {
        for item in [filterItem] {
            item?.target = self
            item?.isHidden = false
        }
        filterItem?.action = #selector(didTapSearchItem)
        filterItem?.menu.removeAllItems()
        filterItem?.menu.addItem(withTitle: "Clear All Filters", action: #selector(didTapClearItem), keyEquivalent: "").tag = ContextualMenuOption.clearFiler.rawValue
        filterItem?.image = NSImage(systemSymbolName: header.isHidden ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill", accessibilityDescription: header.isHidden ? "Show Filter Options" : "Hide Filter Options")
        filterItem?.toolTip = filterItem?.image?.accessibilityDescription
    }

    func prepareForHidingFilterItem() {
        for item in [filterItem] {
            item?.target = nil
            item?.isHidden = true
        }
    }
}
