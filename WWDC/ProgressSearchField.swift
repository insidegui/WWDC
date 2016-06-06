//
//  ProgressSearchField.swift
//  WWDC Data Layer Rewrite
//
//  Created by Guilherme Rambo on 10/2/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class ProgressSearchField: NSSearchField {

    var progress: NSProgress? {
        didSet {
            dispatch_async(dispatch_get_main_queue()) {
                oldValue?.removeObserver(self, forKeyPath: "fractionCompleted")
                
                guard self.progress != nil else {
                    self.showNormalState()
                    return
                }
                self.progress?.addObserver(self, forKeyPath: "fractionCompleted", options: [.Initial, .New], context: nil)
                self.setNeedsDisplay()
            }
        }
    }
    @IBInspectable var progressColor: NSColor = Theme.WWDCTheme.fillColor
    
    override class func cellClass() -> AnyClass? {
        return ProgressSearchFieldCell.self
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "fractionCompleted" {
            dispatch_async(dispatch_get_main_queue()) {
                if self.progress?.fractionCompleted < 1.0 {
                    self.showLoadingState()
                } else {
                    self.showNormalState()
                }
                self.setNeedsDisplay()
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    @objc private func showLoadingState() {
        placeholderString = "Indexing..."
        enabled = false
    }
    
    @objc private func showNormalState() {
        placeholderString = nil
        enabled = true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(showLoadingState), name: TranscriptIndexingDidStartNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(showNormalState), name: TranscriptIndexingDidStopNotification, object: nil)
        
        showNormalState()
    }
    
    var isFirstResponder: Bool {
        guard let window = self.window else { return false }
        guard let responder = window.firstResponder as? NSTextView else { return false }
        
        return window.firstResponder.isKindOfClass(NSTextView.self) && window.fieldEditor(false, forObject: self) != nil && self.isEqualTo(responder.delegate)
    }
    
    deinit {
        progress?.removeObserver(self, forKeyPath: "fractionCompleted")
    }
    
}

class ProgressSearchFieldCell: NSSearchFieldCell {
    
    
    override func drawInteriorWithFrame(cellFrame: NSRect, inView controlView: NSView) {
        super.drawInteriorWithFrame(cellFrame, inView: controlView)
        
        guard let searchField = controlView as? ProgressSearchField else { return }
        guard let progress = searchField.progress else { return }
        guard progress.fractionCompleted < 1.0 else { return }
        
        NSGraphicsContext.currentContext()?.saveGraphicsState()

        let progressArea = NSInsetRect(cellFrame, 0, 1.0)
        let progressClipPath = NSBezierPath(roundedRect: progressArea, xRadius: 4.0, yRadius: 4.0)
        progressClipPath.addClip()
        
        let progressFill = NSMakeRect(0, progressArea.size.height-1.0, progressArea.size.width * CGFloat(progress.fractionCompleted), 4.0)
        searchField.progressColor.setFill()
        NSRectFill(progressFill)
        
        NSGraphicsContext.currentContext()?.restoreGraphicsState()
    }
    
}
