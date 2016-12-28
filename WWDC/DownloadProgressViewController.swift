//
//  DownloadProgressViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import WWDCAppKit

enum DownloadProgressViewButtonState : Int {
    case invalid
	case noDownload
	case downloaded
	case downloading
	case paused
}

class DownloadProgressViewController: NSViewController {
	
	var session: Session! {
		didSet {
			updateUI()
		}
	}
	
	@IBOutlet var downloadButton: NSButton!
	@IBOutlet var progressIndicator: GRActionableProgressIndicator?
	
	fileprivate var downloadStartedHndl: AnyObject?
	fileprivate var downloadFinishedHndl: AnyObject?
	fileprivate var downloadChangedHndl: AnyObject?
	fileprivate var downloadCancelledHndl: AnyObject?
	fileprivate var downloadPausedHndl: AnyObject?
	fileprivate var downloadResumedHndl: AnyObject?
	fileprivate var subscribed: Bool = false
	
	var downloadFinishedCallback: () -> () = {}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		updateUI()
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self.downloadStartedHndl!)
		NotificationCenter.default.removeObserver(self.downloadFinishedHndl!)
		NotificationCenter.default.removeObserver(self.downloadChangedHndl!)
		NotificationCenter.default.removeObserver(self.downloadCancelledHndl!)
		NotificationCenter.default.removeObserver(self.downloadPausedHndl!)
		NotificationCenter.default.removeObserver(self.downloadResumedHndl!)
	}
	
	fileprivate func updateUI()
	{
        guard session != nil else {
            updateButtonVisibility(.invalid)
            return
        }
        
        progressIndicator?.action = #selector(AppDelegate.showDownloadsWindow(_:))

        if session.hd_url != nil {
            view.isHidden = false
            updateDownloadStatus()
        } else {
            view.isHidden = true
        }
	}
	
	fileprivate func updateButtonVisibility(_ visibility: DownloadProgressViewButtonState) {
		switch (visibility) {
        case .invalid:
            self.progressIndicator?.isHidden = true
            self.downloadButton.isHidden = true
		case .noDownload:
			self.progressIndicator?.isHidden = true
			self.downloadButton.isHidden = false
		case .downloaded:
			self.progressIndicator?.isHidden = true
			self.downloadButton.isHidden = true
		case .downloading:
			self.progressIndicator?.isHidden = false
			self.downloadButton.isHidden = true
		case .paused:
            self.progressIndicator?.isHidden = false
			self.downloadButton.isHidden = true
		}
	}
	
	fileprivate func subscribeForNotifications() {
		let nc = NotificationCenter.default
		self.downloadStartedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadStarted), object: nil, queue: OperationQueue.main) { note in
			if !self.isThisNotificationForMe(note) {
				return
			}
			self.updateButtonVisibility(.downloading)
		}
		self.downloadFinishedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadFinished), object: nil, queue: OperationQueue.main) { note in
			if !self.isThisNotificationForMe(note) {
				return
			}
			self.updateButtonVisibility(.downloaded)
			self.downloadFinishedCallback()
		}
		self.downloadChangedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadProgressChanged), object: nil, queue: OperationQueue.main) { note in
			if !self.isThisNotificationForMe(note) {
				return
			}
			self.updateButtonVisibility(.downloading)
			if let info = note.userInfo {
				if let totalBytesExpectedToWrite = info["totalBytesExpectedToWrite"] as? Int {
					self.progressIndicator?.maxValue = Double(totalBytesExpectedToWrite)
				}
				if let totalBytesWritten = info["totalBytesWritten"] as? Int {
					self.progressIndicator?.doubleValue = Double(totalBytesWritten)
				}
			}
		}
		self.downloadCancelledHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadCancelled), object: nil, queue: OperationQueue.main) { note in
			self.updateButtonVisibility(.noDownload)
		}
		self.downloadPausedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadPaused), object: nil, queue: OperationQueue.main) { note in
			self.updateButtonVisibility(.paused)
		}
		self.downloadResumedHndl = nc.addObserver(forName: NSNotification.Name(rawValue: VideoStoreNotificationDownloadResumed), object: nil, queue: OperationQueue.main) { note in
			self.updateButtonVisibility(.downloading)
		}
		self.subscribed = true
	}
	
	fileprivate func updateDownloadStatus()
	{
		if self.subscribed == false {
			self.subscribeForNotifications()
		}
		if VideoStore.SharedStore().isDownloading(session.hd_url!) {
			self.updateButtonVisibility(.downloading)
		} else {
			if VideoStore.SharedStore().hasVideo(session.hd_url!) {
				self.updateButtonVisibility(.downloaded)
			} else {
				self.updateButtonVisibility(.noDownload)
			}
		}
	}
	
	fileprivate func isThisNotificationForMe(_ note: Notification!) -> Bool {
		// we don't have a downloadable session, so this is clearly not for us
        if session == nil {
            return false
        }
		if session.hd_url == nil {
			return false
		}
		
		if let url = note.object as? String {
			if url != session.hd_url! {
				// notification's URL doesn't match our session's URL
				return false
			}
		} else {
			// notification's object is not a valid string
			return false
		}
		
		// this is for us
		return true
	}
	
	@IBAction func download(_ sender: NSButton) {
        if session == nil {
            return
        }
        
		if let url = session.hd_url {
			VideoStore.SharedStore().download(url)
		}
	}
}
