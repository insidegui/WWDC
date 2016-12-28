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
    
    fileprivate func updateUI() {
        guard isViewLoaded else { return }
        guard session != nil else { return }
        guard !session.isInvalidated else { return }
        
        
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
    
    fileprivate func noSession() {
        setSessionCanBeWatched(false)
        setSessionCanBeWatchedInHD(false)
        setSessionHasSlides(false)
        hideProgressButton()
    }
    
    fileprivate func setSessionCanBeWatched(_ can: Bool) {
        if can {
            stackView.addView(watchButton, in: .top)
        } else {
            if watchButton.superview != nil {
                watchButton.removeFromSuperviewWithoutNeedingDisplay()
            }
        }
    }
    fileprivate func setSessionCanBeWatchedInHD(_ can: Bool) {
        if can {
            stackView.addView(watchHDButton, in: .top)
        } else {
            if watchHDButton.superview != nil {
                watchHDButton.removeFromSuperviewWithoutNeedingDisplay()
            }
        }
    }
    fileprivate func setSessionHasSlides(_ has: Bool) {
        if has {
            stackView.addView(slidesButton, in: .top)
        } else {
            if slidesButton.superview != nil {
                slidesButton.removeFromSuperviewWithoutNeedingDisplay()
            }
        }
    }
    fileprivate func hideProgressButton() {
        if progressButton.superview != nil {
            progressButton.removeFromSuperviewWithoutNeedingDisplay()
        }
    }
    
    fileprivate struct ProgressButtonTitles {
        static let MarkAsWatched = NSLocalizedString("Mark as Watched", comment: "mark as watched button title")
        static let MarkAsUnwatched = NSLocalizedString("Mark as Unwatched", comment: "mark as unwatched button title")
    }
    
    fileprivate func reflectSessionProgress() {
        if session.progress < 100 {
            progressButton.title = ProgressButtonTitles.MarkAsWatched
            if progressButton.superview == nil {
                stackView.addView(progressButton, in: .top)
            }
        } else {
            progressButton.title = ProgressButtonTitles.MarkAsUnwatched
            if progressButton.superview == nil {
                stackView.addView(progressButton, in: .top)
            }
        }
    }
    
    @IBAction func watchHD(_ sender: NSButton) {
        watchHDVideoCallback()
        afterCallback()
    }
    @IBAction func watch(_ sender: NSButton) {
        watchVideoCallback()
        afterCallback()
    }
    @IBAction func watchSlides(_ sender: NSButton) {
        showSlidesCallback()
        afterCallback()
    }
    @IBAction func toggleWatched(_ sender: NSButton) {
        toggleWatchedCallback()
        afterCallback()
    }
}
