//
//  DownloadProgressViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

enum DownloadProgressViewButtonState : Int {
	case NoDownload
	case Downloaded
	case Downloading
}

class DownloadProgressViewController: NSViewController {
	
	var session: Session! {
		didSet {
			updateUI()
		}
	}
	
	@IBOutlet var downloadButton: NSButton!
	@IBOutlet var progressIndicator: NSProgressIndicator!
	@IBOutlet var statusButton: NSButton!
	@IBOutlet var cancelButton: NSButton!
	
	private var downloadStartedHndl: AnyObject?
	private var downloadFinishedHndl: AnyObject?
	private var downloadChangedHndl: AnyObject?
	private var subscribed: Bool = false
	
	var downloadFinishedCallback: () -> () = {}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		updateUI()
	}
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self.downloadStartedHndl!)
		NSNotificationCenter.defaultCenter().removeObserver(self.downloadFinishedHndl!)
		NSNotificationCenter.defaultCenter().removeObserver(self.downloadChangedHndl!)
	}
	
	private func updateUI()
	{
		if let session = session {
			if session.hd_url != nil {
				view.hidden = false
				updateDownloadStatus()
			} else {
				view.hidden = true
			}
		} else {
			view.hidden = true
		}
	}
	
	private func updateButtonVisibility(visibility: DownloadProgressViewButtonState) {
		switch (visibility) {
		case .NoDownload:
			self.progressIndicator.hidden = true
			self.downloadButton.hidden = false
			self.statusButton.hidden = true
			self.cancelButton.hidden = true
		case .Downloaded:
			self.progressIndicator.hidden = true
			self.downloadButton.hidden = true
			self.statusButton.hidden = true
			self.cancelButton.hidden = true
		case .Downloading:
			self.progressIndicator.hidden = false
			self.downloadButton.hidden = true
			self.statusButton.hidden = false
			self.cancelButton.hidden = false
		}
	}
	
	private func subscribeForNotifications() {
		let nc = NSNotificationCenter.defaultCenter()
		self.downloadStartedHndl = nc.addObserverForName(VideoStoreNotificationDownloadStarted, object: nil, queue: NSOperationQueue.mainQueue()) { note in
			if !self.isThisNotificationForMe(note) {
				return
			}
			self.updateButtonVisibility(.Downloading)
		}
		self.downloadFinishedHndl = nc.addObserverForName(VideoStoreNotificationDownloadFinished, object: nil, queue: NSOperationQueue.mainQueue()) { note in
			if !self.isThisNotificationForMe(note) {
				return
			}
			self.updateButtonVisibility(.Downloaded)
			self.downloadFinishedCallback()
		}
		self.downloadChangedHndl = nc.addObserverForName(VideoStoreNotificationDownloadProgressChanged, object: nil, queue: NSOperationQueue.mainQueue()) { note in
			if !self.isThisNotificationForMe(note) {
				return
			}
			self.updateButtonVisibility(.Downloading)
			if let info = note.userInfo {
				if let totalBytesExpectedToWrite = info["totalBytesExpectedToWrite"] as? Int {
					self.progressIndicator.maxValue = Double(totalBytesExpectedToWrite)
				}
				if let totalBytesWritten = info["totalBytesWritten"] as? Int {
					self.progressIndicator.doubleValue = Double(totalBytesWritten)
				}
			}
		}
		self.subscribed = true
	}
	
	private func updateDownloadStatus()
	{
		if self.subscribed == false {
			self.subscribeForNotifications()
		}
		if VideoStore.SharedStore().isDownloading(session.hd_url!) {
			self.updateButtonVisibility(.Downloading)
		} else {
			if VideoStore.SharedStore().hasVideo(session.hd_url!) {
				self.updateButtonVisibility(.Downloaded)
			} else {
				self.updateButtonVisibility(.NoDownload)
			}
		}
	}
	
	private func isThisNotificationForMe(note: NSNotification!) -> Bool {
		// we don't have a downloadable session, so this is clearly not for us
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
	
	@IBAction func download(sender: NSButton) {
		if let url = session.hd_url {
			VideoStore.SharedStore().download(url)
			self.statusButton.target = self
			self.statusButton.action = "pauseDownload:"
		}
	}
	
	func pauseDownload(sender: NSButton) {
		if let url = session.hd_url {
			if VideoStore.SharedStore().pauseDownload(url) {
				sender.title = NSLocalizedString("Resume", comment: "resume title in video download view")
				sender.action = "resumeDownload:"
			}
		}
	}
	
	func resumeDownload(sender: NSButton) {
		if let url = session.hd_url {
			if VideoStore.SharedStore().resumeDownload(url) {
				sender.title = NSLocalizedString("Pause", comment: "pause title in video download view")
				sender.action = "pauseDownload:"
			}
		}
	}
	
	@IBAction func cancelDownload(sender: NSButton) {
		if let url = session.hd_url {
			if VideoStore.SharedStore().cancelDownload(url) {
				self.updateDownloadStatus()
			}
		}
	}
}
