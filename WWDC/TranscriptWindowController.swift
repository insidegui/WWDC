//
//  TranscriptWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class TranscriptWindowController: NSWindowController {

    var jumpToTimeCallback: (time: Double) -> () = { _ in }
    {
        didSet {
            guard let transcriptController = transcriptController else { return }
            transcriptController.jumpToTimeCallback = jumpToTimeCallback
        }
    }

    var session: Session!
    private var transcriptController: TranscriptViewController!
    
    convenience init (session: Session) {
        self.init(windowNibName: "TranscriptWindowController")
        self.session = session
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // initialize transcript controller with current session and add It's view to our window
        transcriptController = TranscriptViewController(session: session)
        transcriptController.view.frame = NSMakeRect(0, 0, NSWidth(self.window!.contentView!.frame), NSHeight(self.window!.contentView!.frame))
        transcriptController.view.autoresizingMask = [.ViewHeightSizable, .ViewWidthSizable]
        self.window!.contentView!.addSubview(transcriptController.view)

        // configure transcript controller with preferences
        transcriptController.font = Preferences.SharedPreferences().transcriptFont
        transcriptController.textColor = Preferences.SharedPreferences().transcriptTextColor
        transcriptController.backgroundColor = Preferences.SharedPreferences().transcriptBgColor

        // set notification observers to keep transcript controller in sync with preferences
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserverForName(TranscriptPreferencesChangedNotification, object: nil, queue: nil) { _ in
            self.transcriptController.font = Preferences.SharedPreferences().transcriptFont
            self.transcriptController.textColor = Preferences.SharedPreferences().transcriptTextColor
            self.transcriptController.backgroundColor = Preferences.SharedPreferences().transcriptBgColor
        }
    }
    
    func highlightLineAt(roundedTimecode: String) {
        transcriptController.highlightLineAt(roundedTimecode)
    }
    
}
