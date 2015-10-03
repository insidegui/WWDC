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
    
    @IBOutlet weak var progressBgView: ContentBackgroundView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    var session: Session!
    var slidesDocument: PDFDocument? {
        didSet {
            guard slidesDocument != nil else { return }
            
            window?.titlebarAppearsTransparent = false
            window?.movableByWindowBackground = false
            pdfView.setDocument(slidesDocument)
            progressIndicator.stopAnimation(nil)
            pdfView.hidden = false
            progressBgView.hidden = true
        }
    }
    
    convenience init(session: Session) {
        self.init(windowNibName: "PDFWindowController")
        self.session = session
    }
    
    var downloader: SlidesDownloader!
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.titlebarAppearsTransparent = true
        window?.movableByWindowBackground = true
        
        progressIndicator.startAnimation(nil)
        
        guard session != nil else { return }
        
        window?.title = "WWDC \(session.year) | \(session.title) | Slides"

        downloader = SlidesDownloader(session: session)
        if session.slidesPDFData.length > 0 {
            self.slidesDocument = PDFDocument(data: session.slidesPDFData)
        } else {
            let progressHandler: SlidesDownloader.ProgressHandler = { downloaded, total in
                if self.progressIndicator.indeterminate {
                    self.progressIndicator.minValue = 0
                    self.progressIndicator.maxValue = total
                    self.progressIndicator.indeterminate = false
                }
                
                self.progressIndicator.doubleValue = downloaded
            }
            downloader.downloadSlides({ success, data in
                if success == true {
                    self.slidesDocument = PDFDocument(data: data)
                } else {
                    print("Download failed")
                }
            }, progressHandler: progressHandler)
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
