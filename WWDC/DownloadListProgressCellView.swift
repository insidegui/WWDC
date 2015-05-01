//
//  DownloadListProgressCellView.swift
//  WWDC
//
//  Created by Ruslan Alikhamov on 26/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class DownloadListCellView: NSTableCellView {
	
	weak var item: AnyObject?
	var statusBlock: ((AnyObject?, DownloadListCellView) -> Void)?
	var cancelBlock: ((AnyObject?, DownloadListCellView) -> Void)?
	var started: Bool = false
	
	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	@IBOutlet weak var statusBtn: NSButton!
	
	@IBAction func statusBtnPressed(sender: NSButton) {
		if let block = self.statusBlock {
			block(self.item, self)
		}
	}
	
	@IBAction func cancelBtnPressed(sender: NSButton) {
		if let block = self.cancelBlock {
			block(self.item, self)
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.progressIndicator.indeterminate = true
		self.progressIndicator.usesThreadedAnimation = true
		self.progressIndicator.startAnimation(nil)
	}
	
	func startProgress() {
		if (self.started) {
			return
		}
		self.progressIndicator.indeterminate = false
		self.started = true
	}
	
}
