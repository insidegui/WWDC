//
//  TranscriptViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/12/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class TranscriptViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    var session: Session!
    var jumpToTimeCallback: (time: Double) -> () = { _ in }
    
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

    @IBOutlet weak private var tableView: NSTableView!
    
    private struct Storyboard {
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

        tableView.setDelegate(self)
        tableView.setDataSource(self)
        
        tableView.target = self
        tableView.doubleAction = Selector("doubleClickedLine:")
    }
    
    func highlightLineAt(roundedTimecode: String) {
        guard let lines = session.transcript?.lines else { return }
        
        let result = lines.filter { Transcript.roundedStringFromTimecode($0.timecode) == roundedTimecode }
        
        guard let row = lines.indexOf(result[0]) where result.count > 0 else { return }

        tableView.selectRowIndexes(NSIndexSet(index: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }
    
    // MARK: - TableView
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return session.transcript!.lines.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeViewWithIdentifier(Storyboard.cellIdentifier, owner: tableView) as! TranscriptLineTableCellView
        
        cell.foregroundColor = textColor
        cell.font = font
        cell.line = session.transcript!.lines[row]
        
        return cell
    }
    
    func tableView(tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.makeViewWithIdentifier(Storyboard.rowIdentifier, owner: tableView) as? NSTableRowView
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let font = font else { return 17.0 }
        
        return font.pointSize * 2
    }
    
    func doubleClickedLine(sender: AnyObject?) {
        let line = session.transcript!.lines[tableView.clickedRow]
        jumpToTimeCallback(time: line.timecode)
    }
    
}
