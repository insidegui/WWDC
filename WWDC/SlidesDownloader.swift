//
//  SlidesDownloader.swift
//  WWDC
//
//  Created by Guilherme Rambo on 10/3/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Alamofire

class SlidesDownloader {
    
    private let maxPDFLength = 16*1024*1024
    
    typealias ProgressHandler = (downloaded: Double, total: Double) -> Void
    typealias CompletionHandler = (success: Bool, data: NSData?) -> Void
    
    var session: Session

    init(session: Session) {
        self.session = session
    }
    
    func downloadSlides(completionHandler: CompletionHandler, progressHandler: ProgressHandler?) {
        guard session.slidesURL != "" else { return completionHandler(success: false, data: nil) }
        guard let slidesURL = NSURL(string: session.slidesURL) else { return completionHandler(success: false, data: nil) }
        
        Alamofire.download(Method.GET, slidesURL.absoluteString) { tempURL, response in
            if let data = NSData(contentsOfURL: tempURL) {
                mainQ {
                    // this operation can fail if the PDF file is too big, Realm currently supports blobs of up to 16MB
                    if data.length < self.maxPDFLength {
                        WWDCDatabase.sharedDatabase.doChanges {
                            self.session.slidesPDFData = data
                        }
                    } else {
                        print("Error saving slides data to database, the file is too big to be saved")
                    }
                    
                    completionHandler(success: true, data: data)
                }
            } else {
                completionHandler(success: false, data: nil)
            }

            do {
                try NSFileManager.defaultManager().removeItemAtURL(tempURL)
            } catch {
                print("Error removing temporary PDF file")
            }
            
            return tempURL
        }.progress { _, totalBytesRead, totalBytesExpected in
            mainQ { progressHandler?(downloaded: Double(totalBytesRead), total: Double(totalBytesExpected)) }
        }
    }
    
}