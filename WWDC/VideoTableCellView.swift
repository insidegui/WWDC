//
//  VideoTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import WWDCAppKit
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
    
    var selected = false {
        didSet {
            updateTint()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        selected = false
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
        KVOController.unobserve(session)
    }

    private func updateUI() {
        KVOController.observe(session, keyPath: "favorite", options: .New, action: #selector(VideoTableCellView.updateSessionFlags))
        KVOController.observe(session, keyPath: "progress", options: .New, action: #selector(VideoTableCellView.updateSessionFlags))
        
        NSNotificationCenter.defaultCenter().addObserverForName(VideoStoreNotificationDownloadCancelled, object: nil, queue: NSOperationQueue.mainQueue()) { note in
            self.updateDownloadImage()
        }
        
        titleField.stringValue = session.title
        
        if session.isExtra {
            detailsField.stringValue = "\(session.event) \(session.year) - \(session.track)"
        } else {
            detailsField.stringValue = "\(session.year) - Session \(session.id) - \(session.track)"
        }
        
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
    
    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            titleField.cell?.backgroundStyle = .Light
            detailsField.cell?.backgroundStyle = .Light
        }
    }
    
    func updateTint() {
        if selected {
            titleField.textColor = NSColor.whiteColor()
            detailsField.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.70)
            downloadedImage.tintColor = Theme.WWDCTheme.backgroundColor
        } else {
            titleField.textColor = NSColor(calibratedWhite: 0.0, alpha: 0.95)
            detailsField.textColor = NSColor(calibratedWhite: 0.0, alpha: 0.70)
            downloadedImage.tintColor = Theme.WWDCTheme.fillColor
        }
    }
    
}
