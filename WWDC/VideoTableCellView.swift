//
//  VideoTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VideoTableCellView: NSTableCellView {
    
    var session: Session! {
        didSet {
            updateUI()
        }
    }
    
    @IBOutlet weak private var titleField: NSTextField!
    @IBOutlet weak private var detailsField: NSTextField!
    @IBOutlet weak private var progressView: SessionProgressView!
    @IBOutlet weak private var downloadedImage: NSImageView!
    
    func updateUI() {
        titleField.stringValue = session.title
        detailsField.stringValue = "\(session.year) - Session \(session.id) - \(session.track)"
        progressView.progress = session.progress
        progressView.favorite = session.favorite
        
        if let url = session.hd_url {
            let videoStore = VideoStore.SharedStore()
            
            if videoStore.hasVideo(url) {
                downloadedImage.hidden = false
                downloadedImage.image = NSImage(named: "downloaded")
            } else if videoStore.isDownloading(url) {
                downloadedImage.hidden = false
                downloadedImage.image = NSImage(named: "downloading")
            } else {
                downloadedImage.hidden = true
            }
        }
    }
    
}
