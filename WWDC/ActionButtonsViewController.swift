//
//  ActionButtonsController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class ActionButtonsViewController: NSViewController {
    
    var session: Session! {
        didSet {
            updateUI()
        }
    }
    
    var stackView: NSStackView {
        return view as! NSStackView
    }
    
    var watchHDVideoCallback: () -> () = {}
    var watchVideoCallback: () -> () = {}
    var showSlidesCallback: () -> () = {}
    var toggleWatchedCallback: () -> () = {}
    var afterCallback: () -> () = {}
    
    /* these outlets are not weak because we will be removing the buttons from the view
       but we have to keep our reference to put them back later */
    @IBOutlet var watchHDButton: NSButton!
    @IBOutlet var watchButton: NSButton!
    @IBOutlet var slidesButton: NSButton!
    @IBOutlet var progressButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }
    
    private func updateUI() {
        if !self.viewLoaded {
            return
        }
        
        noSession()
        
        if let session = session {
            setSessionCanBeWatched(true)
            setSessionCanBeWatchedInHD((session.hdVideoURL != ""))
            setSessionHasSlides((session.slidesURL != ""))
            reflectSessionProgress()
        } else {
            noSession()
        }
    }
    
    private func noSession() {
        setSessionCanBeWatched(false)
        setSessionCanBeWatchedInHD(false)
        setSessionHasSlides(false)
        hideProgressButton()
    }
    
    private func setSessionCanBeWatched(can: Bool) {
        if can {
            stackView.addView(watchButton, inGravity: .Top)
        } else {
            if watchButton.superview != nil {
                watchButton.removeFromSuperviewWithoutNeedingDisplay()
            }
        }
    }
    private func setSessionCanBeWatchedInHD(can: Bool) {
        if can {
            stackView.addView(watchHDButton, inGravity: .Top)
        } else {
            if watchHDButton.superview != nil {
                watchHDButton.removeFromSuperviewWithoutNeedingDisplay()
            }
        }
    }
    private func setSessionHasSlides(has: Bool) {
        if has {
            stackView.addView(slidesButton, inGravity: .Top)
        } else {
            if slidesButton.superview != nil {
                slidesButton.removeFromSuperviewWithoutNeedingDisplay()
            }
        }
    }
    private func hideProgressButton() {
        if progressButton.superview != nil {
            progressButton.removeFromSuperviewWithoutNeedingDisplay()
        }
    }
    
    private struct ProgressButtonTitles {
        static let MarkAsWatched = NSLocalizedString("Mark as Watched", comment: "mark as watched button title")
        static let MarkAsUnwatched = NSLocalizedString("Mark as Unwatched", comment: "mark as unwatched button title")
    }
    
    private func reflectSessionProgress() {
        if session.progress < 100 {
            progressButton.title = ProgressButtonTitles.MarkAsWatched
            if progressButton.superview == nil {
                stackView.addView(progressButton, inGravity: .Top)
            }
        } else {
            progressButton.title = ProgressButtonTitles.MarkAsUnwatched
            if progressButton.superview == nil {
                stackView.addView(progressButton, inGravity: .Top)
            }
        }
    }
    
    @IBAction func watchHD(sender: NSButton) {
        watchHDVideoCallback()
        afterCallback()
    }
    @IBAction func watch(sender: NSButton) {
        watchVideoCallback()
        afterCallback()
    }
    @IBAction func watchSlides(sender: NSButton) {
        showSlidesCallback()
        afterCallback()
    }
    @IBAction func toggleWatched(sender: NSButton) {
        toggleWatchedCallback()
        afterCallback()
    }
}
