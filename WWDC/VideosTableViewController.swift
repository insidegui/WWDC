//
//  VideosTableViewController.swift
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

class VideosTableViewController: NSViewController {
    
    private let disposeBag = DisposeBag()
    
    var sessions = Variable<Results<Session>?>(nil)
    
    var viewModels: [SessionViewModel] = [] {
        didSet {
            tableView.reload(withOldValue: oldValue, newValue: viewModels)
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: NSTableView = {
        let v = NSTableView()
        
        v.wantsLayer = true
        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .listBackground
        v.headerView = nil
        v.rowHeight = 64
        v.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        
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
        
        sessions.asObservable().subscribe(onNext: { [weak self] results in
            guard let results = results else { return }
            
            self?.viewModels = results.flatMap({ SessionViewModel(session: $0) })
        }).addDisposableTo(self.disposeBag)
    }
    
}

extension VideosTableViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModels.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cell = tableView.make(withIdentifier: "cell", owner: tableView) as? SessionTableCellView
        
        if cell == nil {
            cell = SessionTableCellView(frame: .zero)
            cell?.identifier = "cell"
        }
        
        cell?.viewModel = viewModels[row]
        
        return cell
    }
    
}
