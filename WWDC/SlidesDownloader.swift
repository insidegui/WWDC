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
    
    fileprivate let maxPDFLength = 16*1024*1024
    
    typealias ProgressHandler = (_ downloaded: Double, _ total: Double) -> Void
    typealias CompletionHandler = (_ success: Bool, _ data: Data?) -> Void
    
    var session: Session

    init(session: Session) {
        self.session = session
    }
    
    func downloadSlides(_ completionHandler: @escaping CompletionHandler, progressHandler: ProgressHandler?) {
        guard session.slidesURL != "" else { return completionHandler(false, nil) }
        guard let slidesURL = URL(string: session.slidesURL) else { return completionHandler(false, nil) }
        
        Alamofire.request(slidesURL).responseData { response in
            guard let data = response.result.value else {
                completionHandler(false, nil)
                return
            }
            
            mainQ {
                // this operation can fail if the PDF file is too big, Realm currently supports blobs of up to 16MB
                if data.count < self.maxPDFLength {
                    WWDCDatabase.sharedDatabase.doChanges {
                        self.session.slidesPDFData = data as Data
                    }
                } else {
                    print("Error saving slides data to database, the file is too big to be saved")
                }
                
                completionHandler(true, data)
            }
        }.downloadProgress { progress in
            mainQ { progressHandler?(Double(progress.completedUnitCount), Double(progress.totalUnitCount)) }
        }
    }
    
}
