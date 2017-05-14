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
    
    var sessionRows: [SessionRow] = [] {
        didSet {
            tableView.reloadData()
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
    
    private func updateVideosList() {
        guard let tracks = tracks else { return }
        
        self.sessionRows = tracks.flatMap { track -> [SessionRow] in
            let titleRow = SessionRow(title: track.name)
            
            let sessionRows: [SessionRow] = track.sessions.filter("assets.@count > 0").sorted(by: Session.standardSort).flatMap { session in
                guard let viewModel = SessionViewModel(session: session) else { return nil }
                
                return SessionRow(viewModel: viewModel)
            }
            
            return [titleRow] + sessionRows
        }
    }
    
    private func updateScheduleList() {
        guard let sections = scheduleSections else { return }
        
        var shownTimeZone = false
        
        self.sessionRows = sections.flatMap { section -> [SessionRow] in
            let titleRow = SessionRow(date: section.representedDate, showTimeZone: !shownTimeZone)
            
            shownTimeZone = true
            
            let instanceRows: [SessionRow] = section.instances.flatMap { instance in
                guard let viewModel = SessionViewModel(session: instance.session, instance: instance, style: .schedule) else { return nil }
                
                return SessionRow(viewModel: viewModel)
            }
            
            return [titleRow] + instanceRows
        }
    }
    
    lazy var tableView: NSTableView = {
        let v = NSTableView()
        
        v.wantsLayer = true
        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .listBackground
        v.headerView = nil
        v.rowHeight = Metrics.sessionRowHeight
        v.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        v.floatsGroupRows = true
        
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
        v.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        
        return v
    }()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: MainWindowController.defaultRect.height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.blue.cgColor
        
        scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        
        scrollView.frame = view.bounds
        tableView.frame = view.bounds
        
        view.addSubview(scrollView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.rx.selectedRow.map { index -> SessionViewModel? in
            guard let index = index else { return nil }
            guard case .session(let viewModel) = self.sessionRows[index].kind else { return nil }
            
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
        return sessionRows.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let sessionRow = sessionRows[row]
        
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
        
        switch sessionRows[row].kind {
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
        switch sessionRows[row].kind {
        case .session:
            return Metrics.sessionRowHeight
        case .sectionHeader:
            return Metrics.headerRowHeight
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        switch sessionRows[row].kind {
        case .sectionHeader:
            return false
        case .session:
            return true
        }
    }
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        switch sessionRows[row].kind {
        case .sectionHeader:
            return true
        case .session:
            return false
        }
    }
    
}
