//
//  VideoPlayerWindowController.swift
//  WWDCPlayer
//
//  Created by Guilherme Rambo on 04/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

public enum VideoPlayerWindowSizePreset: CGFloat {
    
    case Quarter = 0.25
    case Half = 0.50
    case Max = 1.0
    
}

public class VideoPlayerWindowController: NSWindowController, NSWindowDelegate {

    private let fullscreenOnly: Bool
    private let originalContainer: NSView!
    
    public var actionOnWindowClosed = {}
    
    public init(playerViewController: VideoPlayerViewController, fullscreenOnly: Bool = false, originalContainer: NSView? = nil) {
        self.fullscreenOnly = fullscreenOnly
        self.originalContainer = originalContainer
        
        let styleMask = NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask|NSFullSizeContentViewWindowMask
        
        var rect = VideoPlayerWindow.bestScreenRectFromDetachingContainer(playerViewController.view.superview)
        if rect == NSZeroRect { rect = VideoPlayerWindow.centerRectForProposedContentRect(playerViewController.view.bounds) }
        
        let window = VideoPlayerWindow(contentRect: rect, styleMask: styleMask, backing: .Buffered, defer: false)
        window.releasedWhenClosed = true
        
        if #available(OSX 10.11, *) {
            // ¯\_(ツ)_/¯
        } else {
            window.collectionBehavior = [.Default, .FullScreenPrimary]
        }
        
        super.init(window: window)
        
        window.delegate = self
        
        contentViewController = playerViewController
        window.title = playerViewController.title ?? ""
        
        if let aspect = playerViewController.player.currentItem?.presentationSize where aspect != NSZeroSize {
            window.aspectRatio = aspect
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("VideoPlayerWindowController can't be initialized with a coder")
    }
    
    public override func showWindow(sender: AnyObject?) {
        super.showWindow(sender)
        
        if !fullscreenOnly {
            (window as! VideoPlayerWindow).applySizePreset(.Half)
        } else {
            window?.toggleFullScreen(sender)
        }
    }
    
    // MARK: - Reattachment and fullscreen support
    
    public func windowWillClose(notification: NSNotification) {
        (contentViewController as? VideoPlayerViewController)?.player.cancelPendingPrerolls()
        (contentViewController as? VideoPlayerViewController)?.player.pause()
        
        actionOnWindowClosed()
        
        guard fullscreenOnly && contentViewController is VideoPlayerViewController else { return }
        
        reattachContentViewController()
    }
    
    public func windowWillExitFullScreen(notification: NSNotification) {
        guard fullscreenOnly && contentViewController is VideoPlayerViewController else { return }
        
        window?.resizeIncrements = NSSize(width: 1.0, height: 1.0)
    }
    
    public func windowDidExitFullScreen(notification: NSNotification) {
        guard fullscreenOnly && contentViewController is VideoPlayerViewController else { return }
        
        reattachContentViewController()
    }
    
    private func reattachContentViewController() {
        contentViewController!.view.frame = originalContainer.bounds
        originalContainer.addSubview(contentViewController!.view)
        contentViewController = nil
        close()
    }
    
    public func customWindowsToExitFullScreenForWindow(window: NSWindow) -> [NSWindow]? {
        guard fullscreenOnly else { return nil }
        
        return [window]
    }
    
    public func window(window: NSWindow, startCustomAnimationToExitFullScreenWithDuration duration: NSTimeInterval) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            let frame = VideoPlayerWindow.bestScreenRectFromDetachingContainer(self.originalContainer)
            window.animator().setFrame(frame, display: false)
            }, completionHandler: nil)
    }
    
    @IBAction public func sizeWindowToHalfSize(sender: AnyObject?) {
        (window as! VideoPlayerWindow).applySizePreset(.Half)
    }
    
    @IBAction public func sizeWindowToQuarterSize(sender: AnyObject?) {
        (window as! VideoPlayerWindow).applySizePreset(.Quarter)
    }
    
    @IBAction func sizeWindowToFill(sender: AnyObject?) {
        (window as! VideoPlayerWindow).applySizePreset(.Max)
    }
    
    @IBAction func floatOnTop(sender: NSMenuItem) {
        if sender.state == NSOnState {
            toggleFloatOnTop(false)
            sender.state = NSOffState
        } else {
            toggleFloatOnTop(true)
            sender.state = NSOnState
        }
    }
    
    private func toggleFloatOnTop(enable: Bool) {
        let level = enable ? Int(CGWindowLevelForKey(CGWindowLevelKey.FloatingWindowLevelKey)) : Int(CGWindowLevelForKey(CGWindowLevelKey.NormalWindowLevelKey))
        window?.level = level
    }
    
    deinit {
        #if DEBUG
        Swift.print("VideoPlayerWindowController is gone")
        #endif
    }

}

private extension VideoPlayerWindow {
    
    class func centerRectForProposedContentRect(rect: NSRect) -> NSRect {
        guard let screen = NSScreen.mainScreen() else { return NSZeroRect }
        
        return NSRect(x: screen.frame.width / 2.0 - rect.width / 2.0, y: screen.frame.height / 2.0 - rect.height / 2.0, width: rect.width, height: rect.height)
    }
    
    class func bestScreenRectFromDetachingContainer(containerView: NSView?) -> NSRect {
        guard let view = containerView else { return NSZeroRect }
        
        return view.window?.convertRectToScreen(view.frame) ?? NSZeroRect
    }
    
    func applySizePreset(preset: VideoPlayerWindowSizePreset, center: Bool = true, animated: Bool = true) {
        guard let screen = screen else { return }
        
        let proportion = frame.size.width / screen.visibleFrame.size.width
        let idealSize: NSSize
        if proportion != preset.rawValue {
            let rect = NSRect(origin: CGPointZero, size: NSSize(width: screen.frame.size.width * preset.rawValue, height: screen.frame.size.height * preset.rawValue))
            idealSize = constrainFrameRect(rect, toScreen: screen).size
        } else {
            idealSize = constrainFrameRect(frame, toScreen: screen).size
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