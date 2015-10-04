//
//  VideoTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ViewUtils
import KVOController

class VideoTableCellView: NSTableCellView {
    
    var session: Session! {
        willSet {
            KVOController.unobserve(session)
        }
        didSet {
            updateUI()
        }
    }
    
    @IBOutlet weak private var titleField: NSTextField!
    @IBOutlet weak private var detailsField: NSTextField!
    @IBOutlet weak private var progressView: SessionProgressView!
    @IBOutlet weak private var downloadedImage: GRMaskImageView!
    
    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            updateTint()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
        KVOController.unobserve(session)
    }

    private func updateUI() {
        KVOController.observe(session, keyPath: "favorite", options: .New, action: "updateSessionFlags")
        KVOController.observe(session, keyPath: "progress", options: .New, action: "updateSessionFlags")
        
        NSNotificationCenter.defaultCenter().addObserverForName(VideoStoreNotificationDownloadCancelled, object: nil, queue: NSOperationQueue.mainQueue()) { note in
            self.updateDownloadImage()
        }
        
        titleField.stringValue = session.title
        detailsField.stringValue = "\(session.year) - Session \(session.id) - \(session.track)"
        
        updateSessionFlags()
        updateTint()
        updateDownloadImage()
    }
    
    func updateDownloadImage() {
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
        } else {
            downloadedImage.hidden = true
        }
    }
    
    func updateSessionFlags() {
        progressView.progress = session.progress
        progressView.favorite = session.favorite
    }
    
    func updateTint() {
        if backgroundStyle == .Dark {
            downloadedImage.tintColor = Theme.WWDCTheme.backgroundColor
        } else {
            downloadedImage.tintColor = Theme.WWDCTheme.fillColor
        }
    }
    
}
