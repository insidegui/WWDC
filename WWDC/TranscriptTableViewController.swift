//
//  TranscriptTableViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RealmSwift

extension Notification.Name {
    static let TranscriptControllerDidSelectAnnotation = Notification.Name("TranscriptControllerDidSelectAnnotation")
}

class TranscriptTableViewController: NSViewController {

    var viewModel: SessionViewModel? {
        didSet {
            guard viewModel?.identifier != oldValue?.identifier else { return }
            
            updateUI()
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)!
        
        identifier = "transcriptList"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: WWDCTableView = {
        let v = WWDCTableView()
        
        v.wantsLayer = true
        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .clear
        v.headerView = nil
        v.rowHeight = 36
        v.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        v.floatsGroupRows = true
        
        let column = NSTableColumn(identifier: "transcript")
        v.addTableColumn(column)
        
        return v
    }()
    
    lazy var scrollView: NSScrollView = {
        let v = NSScrollView()
        
        v.focusRingType = .none
        v.backgroundColor = .clear
        v.drawsBackground = false
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
        
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        
        view.addSubview(scrollView)
        
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    fileprivate var transcript: Transcript?
    
    private func updateUI() {
        guard let transcript = viewModel?.session.transcript() else { return }
        
        self.transcript = transcript
        
        tableView.reloadData()
    }
    
}

extension TranscriptTableViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    private struct Constants {
        static let cellIdentifier = "annotation"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return transcript?.annotations.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let annotations = transcript?.annotations else { return nil }
        
        var cell = tableView.make(withIdentifier: Constants.cellIdentifier, owner: tableView) as? TranscriptTableCellView
        
        if cell == nil {
            cell = TranscriptTableCellView(frame: .zero)
            cell?.identifier = Constants.cellIdentifier
        }
        
        cell?.annotation = annotations[row]
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let transcript = transcript else { return }
        guard tableView.selectedRow >= 0 && tableView.selectedRow < transcript.annotations.count else { return }
        
        let row = tableView.selectedRow
        
        let notificationObject = (transcript, transcript.annotations[row])
        
        NotificationCenter.default.post(name: NSNotification.Name.TranscriptControllerDidSelectAnnotation, object: notificationObject)
    }
    
}
