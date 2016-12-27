//
//  TranscriptViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/12/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

class TranscriptViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    var session: Session!
    var jumpToTimeCallback: (_ time: Double) -> () = { _ in }
    
    @IBOutlet weak var searchContainer: NSVisualEffectView!
    @IBOutlet weak var searchField: NSSearchField!
    
    var filteredLines: Results<TranscriptLine> {
        return session.transcript!.lines.filter("text CONTAINS[c] %@", searchField.stringValue)
    }

    var font: NSFont? {
        didSet {
            tableView.reloadData()
        }
    }
    var textColor: NSColor? {
        didSet {
            tableView.reloadData()
        }
    }
    var backgroundColor: NSColor? {
        didSet {
            guard let backgroundColor = backgroundColor else { return }
            tableView.backgroundColor = backgroundColor
        }
    }
    
    var enableScrolling = true

    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak fileprivate var tableView: NSTableView!
    
    fileprivate struct Storyboard {
        static let cellIdentifier = "transcriptCell"
        static let rowIdentifier = "rowView"
    }
    
    init(session: Session) {
        self.session = session
        super.init(nibName: "TranscriptViewController", bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        self.session = nil
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.target = self
        tableView.doubleAction = #selector(TranscriptViewController.doubleClickedLine(_:))
        
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = EdgeInsets(top: 22.0, left: 0.0, bottom: NSHeight(searchContainer.bounds), right: 0.0)
    }
    
    func highlightLineAt(_ roundedTimecode: String) {
        guard enableScrolling else { return }
        
        guard let lines = session.transcript?.lines else { return }
        
        let result = lines.filter { Transcript.roundedStringFromTimecode($0.timecode) == roundedTimecode }
        
        guard result.count > 0 else { return }
        
        guard let row = lines.indexOf(result[0]) else { return }

        tableView.selectRowIndexes(IndexSet(index: row), byExtendingSelection: false)
        
        tableView.scrollRowToVisible(row)
    }
    
    // MARK: - TableView
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredLines.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredLines.count else { return nil }
        
        let cell = tableView.make(withIdentifier: Storyboard.cellIdentifier, owner: tableView) as! TranscriptLineTableCellView
        
        cell.foregroundColor = textColor
        cell.font = font
        cell.line = filteredLines[row]
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.make(withIdentifier: Storyboard.rowIdentifier, owner: tableView) as? NSTableRowView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let font = font else { return 17.0 }
        
        return font.pointSize * 2
    }
    
    func doubleClickedLine(_ sender: AnyObject?) {
        guard tableView.clickedRow < filteredLines.count else { return }
        
        let line = filteredLines[tableView.clickedRow]
        jumpToTimeCallback(time: line.timecode)
    }
    
    // MARK: - Search
    
    @IBAction func search(_ sender: NSSearchField) {
        // disables scrolling during search
        enableScrolling = sender.stringValue.isEmpty
        
        tableView.reloadData()
    }
}
