//
//  TranscriptSearchResultsController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

class TranscriptSearchResultsController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    var playCallback: ((startTime: Double) -> Void)?
    
    var lines: Results<TranscriptLine>? {
        didSet {
            guard lines != nil && lines?.count > 0 else {
                view.hidden = true
                return
            }
            
            view.hidden = false
            tableView.reloadData()
        }
    }
    
    @IBOutlet weak var tableView: NSTableView! {
        didSet {
            tableView.setDelegate(self)
            tableView.setDataSource(self)
        }
    }
    
    private struct Storyboard {
        static let transcriptLineCellIdentifier = "transcriptLine"
    }
    
    init() {
        super.init(nibName: "TranscriptSearchResultsController", bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    // MARK: Table View
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return lines?.count ?? 0
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeViewWithIdentifier(Storyboard.transcriptLineCellIdentifier, owner: tableView) as! TranscriptLineTableCellView
        
        cell.line = lines![row]
        cell.playCallback = playCallback
        
        return cell
    }
    
}
