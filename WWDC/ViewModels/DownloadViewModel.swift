//
//  DownloadViewModel.swift
//  WWDC
//
//  Created by Allen Humphreys on 10/21/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import Combine

final class DownloadViewModel {
    let download: MediaDownload
    let status: AnyPublisher<MediaDownloadState, Never>
    let session: Session

    init(download: MediaDownload, status: AnyPublisher<MediaDownloadState, Never>, session: Session) {
        self.download = download
        self.status = status
        self.session = session
    }
}
