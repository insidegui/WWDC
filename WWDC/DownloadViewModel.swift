//
//  DownloadViewModel.swift
//  WWDC
//
//  Created by Allen Humphreys on 10/21/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import RxSwift

final class DownloadViewModel {
    let download: DownloadManager.Download
    let status: Observable<DownloadStatus>
    let session: Session

    init(download: DownloadManager.Download, status: Observable<DownloadStatus>, session: Session) {
        self.download = download
        self.status = status
        self.session = session
    }
}
