//
//  LiveSessionsListViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

class LiveSessionsListViewController: NSViewController {

    init() {
        super.init(nibName: "LiveSessionsListViewController", bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBOutlet weak var tableView: NSTableView!
    
    var playbackHandler: (session: LiveSession) -> Void = { _ in }
    
    var liveSessions = [LiveSession]() {
        didSet {
            updateUI()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.setDataSource(self)
        tableView.setDelegate(self)
        
        updateUI()
    }
    
    private func updateUI() {
        guard tableView != nil else { return }
        
        tableView.reloadData()
    }
    
}

// MARK: - Table view

extension LiveSessionsListViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return liveSessions.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeViewWithIdentifier("Live Session", owner: tableView) as? LiveSessionTableCellView else { return nil }
        
        cell.delegate = self
        cell.session = liveSessions[row]
        
        return cell
    }
    
    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
    
}

// MARK: - Playback

extension LiveSessionsListViewController: LiveSessionTableCellViewDelegate {
    
    func playLiveSession(session: LiveSession) {
        playbackHandler(session: session)
    }
    
}