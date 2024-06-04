//
//  DownloadsManagementViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 3/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import Combine
import SwiftUI

final class DownloadsManagementViewController: NSViewController, ObservableObject {

    struct Metrics {
        static let defaultWidth: CGFloat = 400
        static let defaultHeight: CGFloat = 200
    }

    private lazy var hostingView: NSView = NSHostingView(rootView: DownloadManagerView(controller: self).environmentObject(downloadManager))

    override func loadView() {
        view = DownloadManagementRootView(frame: NSRect(x: 0, y: 0, width: Metrics.defaultWidth, height: Metrics.defaultHeight))

        hostingView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    let downloadManager: MediaDownloadManager
    let storage: Storage
    private lazy var cancellables: Set<AnyCancellable> = []

    @Published private(set) var downloads = [MediaDownload]()

    override var preferredMaximumSize: NSSize {
        var mainSize = NSApp.windows.filter { $0.identifier == .mainWindow }.compactMap { $0 as? WWDCWindow }.first?.frame.size
        mainSize?.height -= 50

        return mainSize ?? NSSize(width: Metrics.defaultWidth, height: Metrics.defaultHeight)
    }

    init(downloadManager: MediaDownloadManager, storage: Storage) {
        self.downloadManager = downloadManager
        self.storage = storage

        super.init(nibName: nil, bundle: nil)

        downloadManager
            .$downloads
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .map({ $0.sorted(by: MediaDownload.sortingFunction) })
            .assign(to: &$downloads)

        $downloads.map(\.count).removeDuplicates().sink { [weak self] count in
            self?.updatePreferredSize(downloadCount: count)
        }
        .store(in: &cancellables)
    }

    private func updatePreferredSize(downloadCount: Int) {
        guard downloadCount > 0 else {
            dismiss(nil)
            return
        }

        /// Do a bit of introspection into the SwiftUI hierarchy to get the desired height for the scrollable contents.
        /// If this fails, then the popover/window will just use the default size.
        guard let scrollView = hostingView.subviews.first?.subviews.first as? NSScrollView,
              let documentView = scrollView.documentView
        else {
            self.preferredContentSize = NSSize(width: Metrics.defaultWidth, height: Metrics.defaultHeight)
            return
        }

        let height = min(documentView.fittingSize.height, preferredMaximumSize.height)

        self.preferredContentSize = NSSize(width: Metrics.defaultWidth, height: height)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DownloadsManagementViewController: NSPopoverDelegate {

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }
}

private final class DownloadManagementRootView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}
