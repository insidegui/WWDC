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
    
    fileprivate var titlebarAccessoryController: TitlebarButtonAccessory!
    
    var session: Session!
    var slidesDocument: PDFDocument? {
        didSet {
            guard slidesDocument != nil else { return }
            
            window?.titlebarAppearsTransparent = false
            window?.isMovableByWindowBackground = false
            pdfView.document = slidesDocument
            progressIndicator.stopAnimation(nil)
            pdfView.isHidden = false
            progressBgView.isHidden = true
            titlebarAccessoryController.view.isHidden = false
        }
    }
    
    convenience init(session: Session) {
        self.init(windowNibName: "PDFWindowController")
        self.session = session
    }
    
    var downloader: SlidesDownloader!
    override func windowDidLoad() {
        super.windowDidLoad()
        
        titlebarAccessoryController = TitlebarButtonAccessory(buttonTitle: "Open in Preview", buttonAction: openInPreview)
        
        window?.titlebarAppearsTransparent = true
        window?.isMovableByWindowBackground = true
        
        titlebarAccessoryController.layoutAttribute = .right
        window?.addTitlebarAccessoryViewController(titlebarAccessoryController)
        titlebarAccessoryController.view.isHidden = true
        
        progressIndicator.startAnimation(nil)
        
        guard session != nil else { return }
        
        window?.title = "WWDC \(session.year) | \(session.title) | Slides"

        downloader = SlidesDownloader(session: session)
        if session.slidesPDFData.count > 0 {
            self.slidesDocument = PDFDocument(data: session.slidesPDFData as Data)
        } else {
            let progressHandler: SlidesDownloader.ProgressHandler = { downloaded, total in
                if self.progressIndicator.isIndeterminate {
                    self.progressIndicator.minValue = 0
                    self.progressIndicator.maxValue = total
                    self.progressIndicator.isIndeterminate = false
                }
                
                self.progressIndicator.doubleValue = downloaded
            }
            downloader.downloadSlides({ success, data in
                if success == true {
                    guard let data = data else { return }
                    
                    self.slidesDocument = PDFDocument(data: data)
                } else {
                    print("Download failed")
                }
            }, progressHandler: progressHandler)
        }
    }
    
    fileprivate func openInPreview() {
        guard let slidesDocument = slidesDocument else { return }
        guard let downloadsPath = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first else { return }
        
        let filePath = NSString.path(withComponents: [downloadsPath, "\(session.title).pdf"])
        
        if slidesDocument.write(to: URL(fileURLWithPath: filePath)) {
            NSWorkspace.shared().openFile(filePath)
        } else {
            NSLog("Error writing slides document to file \(filePath)")
        }
    }
    
    func saveDocument(_ sender: AnyObject?) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["pdf"]
        panel.nameFieldStringValue = session!.title
        
        panel.beginSheetModal(for: window!){ result in
            if result != 1 {
                return
            }
            
            self.slidesDocument?.write(to: panel.url!)
        }
    }
    
    override func keyDown(with theEvent: NSEvent) {
        switch theEvent.keyCode {
        case 35: // p
            pdfView.goToPreviousPage(self)
        case 45: // n
            pdfView.goToNextPage(self)
        default:
            super.keyDown(with: theEvent)
            break
        }
    }

}
