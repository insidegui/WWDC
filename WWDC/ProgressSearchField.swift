//
//  ProgressSearchField.swift
//  WWDC Data Layer Rewrite
//
//  Created by Guilherme Rambo on 10/2/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


class ProgressSearchField: NSSearchField {

    var progress: Progress? {
        didSet {
            DispatchQueue.main.async {
                oldValue?.removeObserver(self, forKeyPath: "fractionCompleted")
                
                guard self.progress != nil else {
                    self.showNormalState()
                    return
                }
                self.progress?.addObserver(self, forKeyPath: "fractionCompleted", options: [.initial, .new], context: nil)
                self.setNeedsDisplay()
            }
        }
    }
    @IBInspectable var progressColor: NSColor = Theme.WWDCTheme.fillColor
    
    override class func cellClass() -> AnyClass? {
        return ProgressSearchFieldCell.self
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "fractionCompleted" {
            DispatchQueue.main.async {
                if self.progress?.fractionCompleted < 1.0 {
                    self.showLoadingState()
                } else {
                    self.showNormalState()
                }
                self.setNeedsDisplay()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    @objc fileprivate func showLoadingState() {
        placeholderString = "Indexing..."
        isEnabled = false
    }
    
    @objc fileprivate func showNormalState() {
        placeholderString = nil
        isEnabled = true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        NotificationCenter.default.addObserver(self, selector: #selector(showLoadingState), name: NSNotification.Name(rawValue: TranscriptIndexingDidStartNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showNormalState), name: NSNotification.Name(rawValue: TranscriptIndexingDidStopNotification), object: nil)
        
        showNormalState()
    }
    
    var isFirstResponder: Bool {
        guard let window = self.window else { return false }
        guard let responder = window.firstResponder as? NSTextView else { return false }
        
        return window.firstResponder.isKind(of: NSTextView.self) && window.fieldEditor(false, for: self) != nil && self.isEqual(to: responder.delegate)
    }
    
    deinit {
        progress?.removeObserver(self, forKeyPath: "fractionCompleted")
    }
    
}

class ProgressSearchFieldCell: NSSearchFieldCell {
    
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: cellFrame, in: controlView)
        
        guard let searchField = controlView as? ProgressSearchField else { return }
        guard let progress = searchField.progress else { return }
        guard progress.fractionCompleted < 1.0 else { return }
        
        NSGraphicsContext.current()?.saveGraphicsState()

        let progressArea = NSInsetRect(cellFrame, 0, 1.0)
        let progressClipPath = NSBezierPath(roundedRect: progressArea, xRadius: 4.0, yRadius: 4.0)
        progressClipPath.addClip()
        
        let progressFill = NSMakeRect(0, progressArea.size.height-1.0, progressArea.size.width * CGFloat(progress.fractionCompleted), 4.0)
        searchField.progressColor.setFill()
        NSRectFill(progressFill)
        
        NSGraphicsContext.current()?.restoreGraphicsState()
    }
    
}
