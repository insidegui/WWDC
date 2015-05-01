//
//  TranscriptWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ASCIIwwdc

class TranscriptWindowController: NSWindowController {

    var jumpToTimeCallback: (time: Double) -> () = { _ in } {
        didSet {
            if transcriptController != nil {
                transcriptController.jumpToTimecodeCallback = jumpToTimeCallback
            }
        }
    }
    
    var transcriptReadyCallback: (transcript: WWDCSessionTranscript!) -> () = { _ in } {
        didSet {
            if transcriptController != nil {
                transcriptController.transcriptAvailableCallback = transcriptReadyCallback
            }
        }
    }
    
    var session: Session!
    var transcriptController: WWDCTranscriptViewController!
    
    convenience init (session: Session) {
        self.init(windowNibName: "TranscriptWindowController")
        self.session = session
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()

        transcriptController = WWDCTranscriptViewController(year: session.year, session: session.id)
        transcriptController.view.frame = NSMakeRect(0, 0, NSWidth(self.window!.contentView.frame), NSHeight(self.window!.contentView.frame))
        transcriptController.view.autoresizingMask = .ViewHeightSizable | .ViewWidthSizable

        self.window!.contentView.addSubview(transcriptController.view)
    }
    
    func highlightLineAt(roundedTimecode: String) {
        transcriptController.highlightLineAt(roundedTimecode)
    }
    
}
