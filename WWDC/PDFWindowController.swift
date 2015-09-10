//
//  PDFWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Quartz

class PDFWindowController: NSWindowController {

    @IBOutlet weak var pdfView: PDFView!
    
    @IBOutlet weak var progressIndicator: NSProgressIndicator! {
        didSet {
            progressIndicator.displayedWhenStopped = false
        }
    }
    var session: Session!
    var slidesDocument: PDFDocument? {
        didSet {
            if slidesDocument != nil {
                pdfView.setDocument(slidesDocument)
                progressIndicator.stopAnimation(nil)
                if let bgView = progressIndicator.superview {
                    bgView.hidden = true
                }
            }
        }
    }
    
    convenience init(session: Session) {
        self.init(windowNibName: "PDFWindowController")
        self.session = session
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        progressIndicator.startAnimation(nil)
        
        if session != nil {
            window?.title = "WWDC \(session.year) | \(session.title) | Slides"

            DataStore.SharedStore.downloadSessionSlides(session) { success, data in
                dispatch_async(dispatch_get_main_queue()) {
                    if success == true {
                        self.slidesDocument = PDFDocument(data: data)
                    } else {
                        print("Download failed")
                    }
                }
            }
        }
    }
    
    func saveDocument(sender: AnyObject?) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["pdf"]
        panel.nameFieldStringValue = session!.title
        
        panel.beginSheetModalForWindow(window!){ result in
            if result != 1 {
                return
            }
            
            self.slidesDocument?.writeToURL(panel.URL)
        }
    }
    
}
