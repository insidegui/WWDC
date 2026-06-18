//
//  VideoPlayerWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 04/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa
import PlayerUI

public enum PUIPlayerWindowSizePreset: CGFloat {

    case quarter = 0.25
    case half = 0.50
    case max = 1.0

}

final class VideoPlayerWindowController: NSWindowController, NSWindowDelegate {

    fileprivate let fullscreenOnly: Bool
    fileprivate let originalContainer: NSView!

    var actionOnWindowClosed = {}
    var actionOnWindowWillExitFullScreen = {}

    var playerWindow: PUIPlayerWindow? {
        let playerWindow = window as? PUIPlayerWindow
        assert(playerWindow != nil, "Expected a valid window and found none")

        return playerWindow
    }

    init(playerViewController: VideoPlayerViewController, fullscreenOnly: Bool = false, originalContainer: NSView? = nil) {
        self.fullscreenOnly = fullscreenOnly
        self.originalContainer = originalContainer

        originalContainer?.layer?.backgroundColor = .black

        var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]

        if fullscreenOnly {
            // fullscreen_transition: Remove these so we can make the window appear without any noticeable transition
            styleMask.remove(.titled)
            styleMask.insert(.borderless)
        }

        var rect = PUIPlayerWindow.bestScreenRectFromDetachingContainer(playerViewController.view, layoutGuide: playerViewController.playerView.videoLayoutGuide)
        if rect == NSRect.zero { rect = PUIPlayerWindow.centerRectForProposedContentRect(playerViewController.view.bounds) }

        let window = PUIPlayerWindow(contentRect: rect, styleMask: styleMask, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = true

        if fullscreenOnly {
            // We must insert this behavior because `styleMask.remove(.titled)` above disables it
            window.collectionBehavior.insert(.fullScreenPrimary)
            // fullscreen_transition: So we can make the window appear without any noticeable transition
            // calling showWindow() has a default animation that makes it scale slightly
            window.animationBehavior = .none
            window.hasShadow = false
        }

        super.init(window: window)

        window.delegate = self

        contentViewController = playerViewController
        window.title = playerViewController.title ?? ""

        if let aspect = playerViewController.player.currentItem?.presentationSize, aspect != NSSize.zero {
            window.aspectRatio = aspect
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("VideoPlayerWindowController can't be initialized with a coder")
    }

    /// `fullscreen_transition`: This exists because `showWindow(_:)` returns well before the window is actually visible on screen.
    /// Which means when we want to enter fullscreen right away, the animation starts at screen (0,0) and looks bad.
    ///
    /// So we use ``windowDidChangeOcclusionState`` to detect when the window is actually visible and only then enter fullscreen.
    ///
    /// This API behavior may be OS version dependent. Currently confirmed on 26.0
    weak var deferredEnterFullScreenSender: AnyObject?
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)

        if !fullscreenOnly {
            playerWindow?.applySizePreset(.half)
        } else if let sender = sender as? AnyObject {
            deferredEnterFullScreenSender = sender
        } else {
            window?.toggleFullScreen(sender)
        }
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let window else { return }

        if let deferredEnterFullScreenSender, fullscreenOnly && window.occlusionState.contains(.visible) {
            self.deferredEnterFullScreenSender = nil
            window.toggleFullScreen(deferredEnterFullScreenSender)
        }
    }

    // MARK: - Reattachment and fullscreen support

    var windowWasAskedToClose = false
    func windowShouldClose(_ sender: NSWindow) -> Bool {

        windowWasAskedToClose = true

        if fullscreenOnly {
            defer { window?.toggleFullScreen(nil) }
            return false
        } else {
            defer { reallyCloseWindow() }
            return true
        }
    }

    private func windowWasAskedToCloseCleanup() {
        actionOnWindowClosed()
        (contentViewController as? VideoPlayerViewController)?.player.cancelPendingPrerolls()
        (contentViewController as? VideoPlayerViewController)?.player.pause()
    }

    /// When not in `fullscreenOnly` mode, call this to clean up the window
    private func reallyCloseWindow() {
        windowWasAskedToCloseCleanup()

        if fullscreenOnly && contentViewController is VideoPlayerViewController {
            reattachContentViewController()
        }

        contentViewController?.view.removeFromSuperview()
        window = nil
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        originalContainer?.layer?.backgroundColor = .clear

        if windowWasAskedToClose {
            windowWasAskedToCloseCleanup()
        } else {
            actionOnWindowWillExitFullScreen()
        }

        window?.resizeIncrements = NSSize(width: 1.0, height: 1.0)
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard fullscreenOnly && contentViewController is VideoPlayerViewController else { return }

        reattachContentViewController()
    }

    fileprivate func reattachContentViewController() {
        close()
        contentViewController!.view.frame = originalContainer.bounds
        let view = contentViewController!.view

        originalContainer.addSubview(view)

        originalContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": view]))
        originalContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(0)-[playerView]-(0)-|", options: [], metrics: nil, views: ["playerView": view]))
    }

    func customWindowsToExitFullScreen(for window: NSWindow) -> [NSWindow]? {
        guard fullscreenOnly else { return nil }

        return [window]
    }

    func window(_ window: NSWindow, startCustomAnimationToExitFullScreenWithDuration duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            let frame = PUIPlayerWindow.bestScreenRectFromDetachingContainer(originalContainer, layoutGuide: nil)
            window.animator().setFrame(frame, display: false)
        }, completionHandler: nil)
    }

    @IBAction func sizeWindowToHalfSize(_ sender: AnyObject?) {
        playerWindow?.applySizePreset(.half)
    }

    @IBAction func sizeWindowToQuarterSize(_ sender: AnyObject?) {
        playerWindow?.applySizePreset(.quarter)
    }

    @IBAction func sizeWindowToFill(_ sender: AnyObject?) {
        playerWindow?.applySizePreset(.max)
    }

    @IBAction func floatOnTop(_ sender: NSMenuItem) {
        if sender.state == .on {
            toggleFloatOnTop(false)
            sender.state = .off
        } else {
            toggleFloatOnTop(true)
            sender.state = .on
        }
    }

    fileprivate func toggleFloatOnTop(_ enable: Bool) {
        let level = enable ? Int(CGWindowLevelForKey(CGWindowLevelKey.floatingWindow)) : Int(CGWindowLevelForKey(CGWindowLevelKey.normalWindow))
        window?.level = NSWindow.Level(rawValue: level)
    }

}

private extension PUIPlayerWindow {

    class func centerRectForProposedContentRect(_ rect: NSRect) -> NSRect {
        guard let screen = NSScreen.main else { return NSRect.zero }

        return NSRect(x: screen.frame.width / 2.0 - rect.width / 2.0, y: screen.frame.height / 2.0 - rect.height / 2.0, width: rect.width, height: rect.height)
    }

    class func bestScreenRectFromDetachingContainer(_ containerView: NSView?, layoutGuide: NSLayoutGuide?) -> NSRect {
        guard let view = containerView, let superview = view.superview else { return NSRect.zero }

        let targetFrame = layoutGuide?.frame ?? view.frame

        return view.window?.convertToScreen(superview.convert(targetFrame, to: nil)) ?? NSRect.zero
    }

    func applySizePreset(_ preset: PUIPlayerWindowSizePreset, center: Bool = true, animated: Bool = true) {
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
