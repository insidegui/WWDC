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

class SessionsTableViewController: NSViewController {
    
    fileprivate struct Metrics {
        static let headerRowHeight: CGFloat = 20
        static let sessionRowHeight: CGFloat = 64
    }
    
    private let disposeBag = DisposeBag()
    
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
    
    private var searchRows: [SessionRow] = []
    private var allRows: [SessionRow] = []
    
    var displayedRows: [SessionRow] = [] {
        didSet {
            tableView.reloadPreservingSelection()
        }
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
        self.displayedRows = allRows
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
        self.displayedRows = allRows
    }
    
    private func updateWithSearchResults() {
        guard let results = searchResults else {
            if !allRows.isEmpty {
                self.displayedRows = allRows
            } else {
                switch style {
                case .schedule:
                    updateScheduleList()
                case .videos:
                    updateVideosList()
                }
            }
            
            self.searchRows = []
            
            return
        }
        
        let sortingFunction = (style == .schedule) ? Session.standardSortForSchedule : Session.standardSort
        
        let sessionRows: [SessionRow] = results.sorted(by: sortingFunction).flatMap { session in
            guard let viewModel = SessionViewModel(session: session) else { return nil }
            
            return SessionRow(viewModel: viewModel)
        }
        
        self.searchRows = sessionRows
        self.displayedRows = searchRows
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
        
        tableView.rx.selectedRow.map { index -> SessionViewModel? in
            guard let index = index else { return nil }
            guard case .session(let viewModel) = self.displayedRows[index].kind else { return nil }
            
            return viewModel
        }.bind(to: selectedSession).addDisposableTo(self.disposeBag)
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
