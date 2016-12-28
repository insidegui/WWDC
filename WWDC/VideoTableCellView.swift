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
            kvoController.unobserve(session)
        }
        didSet {
            updateUI()
        }
    }
    
    @IBOutlet weak fileprivate var titleField: NSTextField!
    @IBOutlet weak fileprivate var detailsField: NSTextField!
    @IBOutlet weak fileprivate var progressView: SessionProgressView!
    @IBOutlet weak fileprivate var downloadedImage: GRMaskImageView!
    
    var selected = false {
        didSet {
            updateTint()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        selected = false
        
        NotificationCenter.default.removeObserver(self)
        kvoController.unobserve(session)
    }

    fileprivate func updateUI() {
        kvoController.observe(session, keyPath: "favorite", options: .new, action: #selector(VideoTableCellView.updateSessionFlags))
        kvoController.observe(session, keyPath: "progress", options: .new, action: #selector(VideoTableCellView.updateSessionFlags))
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadCancelled), object: nil, queue: OperationQueue.main) { note in
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
                downloadedImage.isHidden = false
                downloadedImage.image = NSImage(named: "downloaded")
            } else if videoStore.isDownloading(url) {
                downloadedImage.isHidden = false
                downloadedImage.image = NSImage(named: "downloading")
            } else {
                downloadedImage.isHidden = true
            }
        } else {
            downloadedImage.isHidden = true
        }
    }
    
    func updateSessionFlags() {
        progressView.progress = session.progress
        progressView.favorite = session.favorite
    }
    
    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            titleField.cell?.backgroundStyle = .light
            detailsField.cell?.backgroundStyle = .light
        }
    }
    
    func updateTint() {
        if selected {
            titleField.textColor = NSColor.white
            detailsField.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.70)
            downloadedImage.tintColor = Theme.WWDCTheme.backgroundColor
        } else {
            titleField.textColor = NSColor(calibratedWhite: 0.0, alpha: 0.95)
            detailsField.textColor = NSColor(calibratedWhite: 0.0, alpha: 0.70)
            downloadedImage.tintColor = Theme.WWDCTheme.fillColor
        }
    }
    
}
