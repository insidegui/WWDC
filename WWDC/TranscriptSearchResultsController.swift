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

    var playCallback: ((_ startTime: Double) -> Void)?
    
    var lines: Results<TranscriptLine>? {
        didSet {
            guard let lines = lines, lines.count > 0 else {
                view.isHidden = true
                return
            }
            
            view.isHidden = false
            tableView.reloadData()
        }
    }
    
    @IBOutlet weak var tableView: NSTableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
        }
    }
    
    fileprivate struct Storyboard {
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
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return lines?.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.make(withIdentifier: Storyboard.transcriptLineCellIdentifier, owner: tableView) as! TranscriptLineTableCellView
        
        cell.line = lines![row]
        cell.playCallback = playCallback
        
        return cell
    }
    
}
