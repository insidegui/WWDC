//
//  VideoPlayerWindowController.swift
//  WWDCPlayer
//
//  Created by Guilherme Rambo on 04/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

public enum VideoPlayerWindowSizePreset: CGFloat {
    
    case quarter = 0.25
    case half = 0.50
    case max = 1.0
    
}

open class VideoPlayerWindowController: NSWindowController, NSWindowDelegate {

    fileprivate let fullscreenOnly: Bool
    fileprivate let originalContainer: NSView!
    
    open var actionOnWindowClosed = {}
    
    public init(playerViewController: VideoPlayerViewController, fullscreenOnly: Bool = false, originalContainer: NSView? = nil) {
        self.fullscreenOnly = fullscreenOnly
        self.originalContainer = originalContainer
        
        let styleMask: NSWindowStyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        
        var rect = VideoPlayerWindow.bestScreenRectFromDetachingContainer(playerViewController.view.superview)
        if rect == NSZeroRect { rect = VideoPlayerWindow.centerRectForProposedContentRect(playerViewController.view.bounds) }
        
        let window = VideoPlayerWindow(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = true
        
        if #available(OSX 10.11, *) {
            // ¯\_(ツ)_/¯
        } else {
            window.collectionBehavior = .fullScreenPrimary
        }
        
        super.init(window: window)
        
        window.delegate = self
        
        contentViewController = playerViewController
        window.title = playerViewController.title ?? ""
        
        if let aspect = playerViewController.player.currentItem?.presentationSize, aspect != NSZeroSize {
            window.aspectRatio = aspect
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("VideoPlayerWindowController can't be initialized with a coder")
    }
    
    open override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        if !fullscreenOnly {
            (window as! VideoPlayerWindow).applySizePreset(.half)
        } else {
            window?.toggleFullScreen(sender)
        }
    }
    
    // MARK: - Reattachment and fullscreen support
    
    open func windowWillClose(_ notification: Notification) {
        (contentViewController as? VideoPlayerViewController)?.player.cancelPendingPrerolls()
        (contentViewController as? VideoPlayerViewController)?.player.pause()
        
        actionOnWindowClosed()
        
        guard fullscreenOnly && contentViewController is VideoPlayerViewController else { return }
        
        reattachContentViewController()
    }
    
    open func windowWillExitFullScreen(_ notification: Notification) {
        guard fullscreenOnly && contentViewController is VideoPlayerViewController else { return }
        
        window?.resizeIncrements = NSSize(width: 1.0, height: 1.0)
    }
    
    open func windowDidExitFullScreen(_ notification: Notification) {
        guard fullscreenOnly && contentViewController is VideoPlayerViewController else { return }
        
        reattachContentViewController()
    }
    
    fileprivate func reattachContentViewController() {
        contentViewController!.view.frame = originalContainer.bounds
        originalContainer.addSubview(contentViewController!.view)
        contentViewController = nil
        close()
    }
    
    open func customWindowsToExitFullScreen(for window: NSWindow) -> [NSWindow]? {
        guard fullscreenOnly else { return nil }
        
        return [window]
    }
    
    open func window(_ window: NSWindow, startCustomAnimationToExitFullScreenWithDuration duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            let frame = VideoPlayerWindow.bestScreenRectFromDetachingContainer(self.originalContainer)
            window.animator().setFrame(frame, display: false)
            }, completionHandler: nil)
    }
    
    @IBAction open func sizeWindowToHalfSize(_ sender: AnyObject?) {
        (window as! VideoPlayerWindow).applySizePreset(.half)
    }
    
    @IBAction open func sizeWindowToQuarterSize(_ sender: AnyObject?) {
        (window as! VideoPlayerWindow).applySizePreset(.quarter)
    }
    
    @IBAction func sizeWindowToFill(_ sender: AnyObject?) {
        (window as! VideoPlayerWindow).applySizePreset(.max)
    }
    
    @IBAction func floatOnTop(_ sender: NSMenuItem) {
        if sender.state == NSOnState {
            toggleFloatOnTop(false)
            sender.state = NSOffState
        } else {
            toggleFloatOnTop(true)
            sender.state = NSOnState
        }
    }
    
    fileprivate func toggleFloatOnTop(_ enable: Bool) {
        let level = enable ? Int(CGWindowLevelForKey(CGWindowLevelKey.floatingWindow)) : Int(CGWindowLevelForKey(CGWindowLevelKey.normalWindow))
        window?.level = level
    }
    
    deinit {
        #if DEBUG
        Swift.print("VideoPlayerWindowController is gone")
        #endif
    }

}

private extension VideoPlayerWindow {
    
    class func centerRectForProposedContentRect(_ rect: NSRect) -> NSRect {
        guard let screen = NSScreen.main() else { return NSZeroRect }
        
        return NSRect(x: screen.frame.width / 2.0 - rect.width / 2.0, y: screen.frame.height / 2.0 - rect.height / 2.0, width: rect.width, height: rect.height)
    }
    
    class func bestScreenRectFromDetachingContainer(_ containerView: NSView?) -> NSRect {
        guard let view = containerView else { return NSZeroRect }
        
        return view.window?.convertToScreen(view.frame) ?? NSZeroRect
    }
    
    func applySizePreset(_ preset: VideoPlayerWindowSizePreset, center: Bool = true, animated: Bool = true) {
        guard let screen = screen else { return }
        
        let proportion = frame.size.width / screen.visibleFrame.size.width
        let idealSize: NSSize
        if proportion != preset.rawValue {
            let rect = NSRect(origin: CGPoint.zero, size: NSSize(width: screen.frame.size.width * preset.rawValue, height: screen.frame.size.height * preset.rawValue))
            idealSize = constrainFrameRect(rect, to: screen).size
        } else {
            idealSize = constrainFrameRect(frame, to: screen).size
        }
        
        let origin: NSPoint
        
        if center {
            origin = NSPoint(x: screen.frame.width / 2.0 - idealSize.width / 2.0, y: screen.frame.height / 2.0 - idealSize.height / 2.0)
        } else {
            origin = frame.origin
        }
        
        setFrame(NSRect(origin: origin, size: idealSize), display: true, animate: animated)
    }
    
}
