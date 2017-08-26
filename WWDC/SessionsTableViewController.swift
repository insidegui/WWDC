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

protocol SessionsTableViewControllerDelegate: class {
    
    func sessionTableViewContextMenuActionWatch(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionUnWatch(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionFavorite(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionRemoveFavorite(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionDownload(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionCancelDownload(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionRevealInFinder(viewModels: [SessionViewModel])
}

class SessionsTableViewController: NSViewController {
    
    fileprivate struct Metrics {
        static let headerRowHeight: CGFloat = 20
        static let sessionRowHeight: CGFloat = 64
    }
    
    private let disposeBag = DisposeBag()
    
    weak var delegate: SessionsTableViewControllerDelegate?
    
    var selectedSession = Variable<SessionViewModel?>(nil)
    
    let style: SessionsListStyle
    
    var searchResults: Results<Session>? {
        didSet {
            updateWithSearchResults()
        }
    }
    
    var tracks: Results<Track>? {
        didSet {
            updateVideosList()
        }
    }
    
    var scheduleSections: Results<ScheduleSection>? {
        didSet {
            updateScheduleList()
        }
    }

    private var allRows: [SessionRow] = []
    
    var displayedRows: [SessionRow] = [] {
        didSet {
            if displayedRows.count == 0 {
                print("What")
            }
        }
    }

    func setDisplayedRows(_ newValue: [SessionRow], animated: Bool) {
        guard animated else {
            displayedRows = newValue
            self.tableView.reloadData()
            return
        }

        let oldValue = displayedRows

        let oldRowsSet = Set<SessionRow>.init(oldValue)
        let newRowsSet = Set<SessionRow>.init(newValue)
        let removed = oldRowsSet.subtracting(newRowsSet)
        let added = newRowsSet.subtracting(oldRowsSet)

        var removedIndexes = IndexSet()
        var addedIndexes = IndexSet()

        for row in removed {
            guard let index = oldValue.index(of: row) else { continue }
            removedIndexes.insert(index)
        }

        for row in added {
            guard let index = newValue.index(of: row) else { continue }
            addedIndexes.insert(index)
        }

        self.tableView.beginUpdates()

        self.tableView.removeRows(at: removedIndexes, withAnimation: [.slideLeft])
        self.tableView.insertRows(at: addedIndexes, withAnimation: [.slideDown])

        // insertRows(::) and removeRows(::) will query the delegate for the row count at the beginning
        // so we delay updating the data model until after those methods have done their thing
        displayedRows = newValue

        self.tableView.endUpdates()
    }

    init(style: SessionsListStyle) {
        self.style = style
        
        super.init(nibName: nil, bundle: nil)!
        
        identifier = "videosList"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func selectSession(with identifier: String, scrollOnly: Bool = false) {
        guard let index = displayedRows.index(where: { row in
            guard case .session(let viewModel) = row.kind else { return false }
            
            return viewModel.identifier == identifier
        }) else {
            return
        }
        
        if !scrollOnly {
            tableView.selectRowIndexes(IndexSet([index]), byExtendingSelection: false)
        }
        
        tableView.scrollRowToVisible(index)
    }
    
    func scrollToToday() {
        guard let sections = scheduleSections else { return }
        
        guard let section = sections.filter("representedDate >= %@", Today()).first else { return }
        
        guard let identifier = section.instances.first?.session?.identifier else { return }
        
        selectSession(with: identifier, scrollOnly: true)
    }
    
    private var setupDone = false
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        performFirstUpdateIfNeeded()
        
        searchController.searchField.isEnabled = false
        view.window?.makeFirstResponder(tableView)
        searchController.searchField.isEnabled = true
    }
    
    private func performFirstUpdateIfNeeded() {
        switch style {
        case .schedule:
            updateScheduleList()
            setupDone = true
        case .videos:
            guard !setupDone else { return }
            setupDone = true
            
            updateVideosList()
        }
    }
    
    private func updateVideosList() {
        guard searchResults == nil else { return }
        guard view.window != nil else { return }
        
        guard let tracks = tracks else { return }
        
        let rows: [SessionRow] = tracks.flatMap { track -> [SessionRow] in
            let titleRow = SessionRow(title: track.name)
            
            let sessionRows: [SessionRow] = track.sessions.filter(Session.videoPredicate).sorted(by: Session.standardSort).flatMap { session in
                guard let viewModel = SessionViewModel(session: session) else { return nil }
                
                return SessionRow(viewModel: viewModel)
            }
            
            return [titleRow] + sessionRows
        }
        
        self.allRows = rows

        setDisplayedRows(allRows, animated: false)
    }
    
    private func updateScheduleList() {
        guard searchResults == nil else { return }
        guard let sections = scheduleSections else { return }
        
        var shownTimeZone = false
        
        let rows: [SessionRow] = sections.flatMap { section -> [SessionRow] in
            let titleRow = SessionRow(date: section.representedDate, showTimeZone: !shownTimeZone)
            
            shownTimeZone = true
            
            let instanceRows: [SessionRow] = section.instances.sorted(by: SessionInstance.standardSort).flatMap { instance in
                guard let viewModel = SessionViewModel(session: instance.session, instance: instance, style: .schedule) else { return nil }
                
                return SessionRow(viewModel: viewModel)
            }
            
            return [titleRow] + instanceRows
        }
        
        self.allRows = rows

        setDisplayedRows(allRows, animated: false)
    }
    
    private func updateWithSearchResults() {
        guard let results = searchResults else {
            if !allRows.isEmpty {
                setDisplayedRows(allRows, animated: true)
            } else {
                switch style {
                case .schedule:
                    updateScheduleList()
                case .videos:
                    updateVideosList()
                }
            }
            
            return
        }

        if allRows.isEmpty {
            switch style {
            case .schedule:
                updateScheduleList()
            case .videos:
                updateVideosList()
            }
        }

        let sortingFunction = (style == .schedule) ? Session.standardSortForSchedule : Session.standardSort
        
        let sessionRows: [SessionRow] = results.sorted(by: sortingFunction).flatMap { session in
            guard let viewModel = SessionViewModel(session: session) else { return nil }

            for row in self.allRows {
                if case .session(let sessionViewModel) = row.kind {
                    if sessionViewModel.session.identifier == session.identifier {
                        return row
                    }
                }
            }
            
            return SessionRow(viewModel: viewModel)
        }

        setDisplayedRows(sessionRows, animated: true)
    }
    
    lazy var searchController: SearchFiltersViewController = {
        return SearchFiltersViewController.loadFromStoryboard()
    }()
    
    lazy var tableView: WWDCTableView = {
        let v = WWDCTableView()
        
        v.wantsLayer = true
        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .listBackground
        v.headerView = nil
        v.rowHeight = Metrics.sessionRowHeight
        v.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        v.floatsGroupRows = true
        v.gridStyleMask = .solidHorizontalGridLineMask
        v.gridColor = .darkGridColor
        
        let column = NSTableColumn(identifier: "session")
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
        
        return v
    }()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.darkWindowBackground.cgColor
        view.widthAnchor.constraint(lessThanOrEqualToConstant: 675).isActive = true
        
        scrollView.frame = view.bounds
        tableView.frame = view.bounds
        
        scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        
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
        }.bind(to: selectedSession).addDisposableTo(self.disposeBag)
    }
    
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
    
    private func selectedRowIndexes() -> IndexSet {
        let clickedRow = self.tableView.clickedRow
        let selectedRowIndexes = self.tableView.selectedRowIndexes
        
        if clickedRow < 0 || selectedRowIndexes.contains(clickedRow) {
            return selectedRowIndexes
        } else {
            return IndexSet(integer: clickedRow)
        }
    }

    @objc private func tableViewMenuItemClicked(_ menuItem: NSMenuItem) {
        var viewModels = [SessionViewModel]()
        
        selectedRowIndexes().forEach { row in
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
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        for row in selectedRowIndexes() {
            let sessionRow = displayedRows[row]
            
            guard case .session(let viewModel) = sessionRow.kind else { break }
            
            if shouldEnableMenuItem(menuItem: menuItem, viewModel: viewModel) { return true }
        }
        
        return false
    }
    
    private func shouldEnableMenuItem(menuItem: NSMenuItem, viewModel: SessionViewModel) -> Bool {
        switch menuItem.option {
        case .watched:
            if viewModel.session.progresses.first == nil || viewModel.session.progresses.first?.relativePosition != 1 {
                return true
            }
        case .unwatched:
            if viewModel.session.progresses.first?.relativePosition == 1 { return true }
        case .favorite:
            if !viewModel.isFavorite { return true }
        case .removeFavorite:
            if viewModel.isFavorite { return true }
        case .download:
            if let sessionAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first {
                if !DownloadManager.shared.isDownloading(sessionAsset.remoteURL) {
                    if DownloadManager.shared.localFileURL(for: viewModel.session) == nil { return true }
                }
            }
        case .cancelDownload:
            if let sessionAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first {
               if DownloadManager.shared.isDownloading(sessionAsset.remoteURL) { return true }
            }
        case .revealInFinder:
            if let sessionAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first {
                if DownloadManager.shared.hasVideo(sessionAsset.remoteURL) { return true }
            }
        }
        
        return false
    }
}

extension SessionsTableViewController: NSTableViewDataSource, NSTableViewDelegate {
    
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
        var rowView = tableView.make(withIdentifier: Constants.rowIdentifier, owner: tableView) as? WWDCTableRowView
        
        if rowView == nil {
            rowView = WWDCTableRowView(frame: .zero)
            rowView?.identifier = Constants.rowIdentifier
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
        var cell = tableView.make(withIdentifier: Constants.sessionCellIdentifier, owner: tableView) as? SessionTableCellView
        
        if cell == nil {
            cell = SessionTableCellView(frame: .zero)
            cell?.identifier = Constants.sessionCellIdentifier
        }
        
        cell?.viewModel = viewModel
        
        return cell
    }
    
    private func cellForSectionTitle(_ title: String) -> TitleTableCellView? {
        var cell = tableView.make(withIdentifier: Constants.titleCellIdentifier, owner: tableView) as? TitleTableCellView
        
        if cell == nil {
            cell = TitleTableCellView(frame: .zero)
            cell?.identifier = Constants.titleCellIdentifier
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

private extension NSMenuItem {
    
    var option: SessionsTableViewController.ContextualMenuOption {
        get {
            guard let value = SessionsTableViewController.ContextualMenuOption(rawValue: self.tag) else {
                fatalError("Invalid ContextualMenuOption: \(self.tag)")
            }
            
            return value
        }
        set {
            self.tag = newValue.rawValue
        }
    }
    
}
