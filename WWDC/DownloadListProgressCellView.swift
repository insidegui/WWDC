//
//  DownloadListProgressCellView.swift
//  WWDC
//
//  Created by Ruslan Alikhamov on 26/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class DownloadListProgressCellView: NSTableCellView {

	var started: Bool = false
	weak var item: AnyObject?
	var statusBlock: ((AnyObject?, DownloadListProgressCellView) -> Void)?
	var cancelBlock: ((AnyObject?, DownloadListProgressCellView) -> Void)?
	
	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	@IBOutlet weak var statusBtn: NSButton!
	@IBOutlet weak var cancelBtn: NSButton!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.progressIndicator.indeterminate = true
		self.progressIndicator.usesThreadedAnimation = true
	}
	
	func startProgress() {
		if (self.started) {
			return
		}
		self.progressIndicator.indeterminate = false
		self.progressIndicator.startAnimation(nil)
		self.started = true
	}
	
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
	
}
