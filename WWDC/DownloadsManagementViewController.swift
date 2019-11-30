//
//  DownloadsManagementViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 3/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import RxSwift

class DownloadsManagementViewController: NSViewController {

    fileprivate struct Metrics {
        static let topPadding: CGFloat = 0
        static let tableGridLineHeight: CGFloat = 2
        static let rowHeight: CGFloat = 64
        static let popOverDesiredWidth: CGFloat = 400
        static let popOverDesiredHeight: CGFloat = 500
    }

    lazy var tableView: DownloadsManagementTableView = {
        let v = DownloadsManagementTableView()

        v.wantsLayer = true
        v.focusRingType = .none
        v.allowsEmptySelection = true
        v.allowsMultipleSelection = false
        v.backgroundColor = .clear
        v.headerView = nil
        v.rowHeight = Metrics.rowHeight
        v.autoresizingMask = [.width, .height]
        v.floatsGroupRows = true
        v.gridStyleMask = .solidHorizontalGridLineMask
        v.gridColor = NSColor.gridColor
        v.selectionHighlightStyle = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "download"))
        v.addTableColumn(column)

        return v
    }()

    lazy var scrollView: NSScrollView = {
        let v = NSScrollView()

        v.focusRingType = .none
        v.drawsBackground = false
        v.borderType = .noBorder
        v.documentView = self.tableView
        v.hasVerticalScroller = true
        v.autohidesScrollers = true
        v.hasHorizontalScroller = false
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    override func loadView() {
        tableView.delegate = self
        tableView.dataSource = self

        view = NSView(frame: NSRect(x: 0, y: 0, width: Metrics.popOverDesiredWidth, height: Metrics.popOverDesiredHeight))

        view.addSubview(scrollView)
        scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: Metrics.topPadding).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Metrics.topPadding).isActive = true
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        view.window?.title = "Downloads"
    }

    let downloadManager: DownloadManager
    let storage: Storage
    var disposeBag = DisposeBag()

    var downloads = [DownloadManager.Download]() {
        didSet {
            if downloads.count == 0 {
                dismiss(nil)
            } else if downloads != oldValue {
                tableView.reloadData()
                let height = min((Metrics.rowHeight + Metrics.tableGridLineHeight) * CGFloat(downloads.count) + Metrics.topPadding * 2, preferredMaximumSize.height)
                self.preferredContentSize = NSSize(width: Metrics.popOverDesiredWidth, height: height)
            }
        }
    }

    override var preferredMaximumSize: NSSize {
        var mainSize = NSApp.windows.filter { $0.identifier == .mainWindow }.compactMap { $0 as? WWDCWindow }.first?.frame.size
        mainSize?.height -= 50

        return mainSize ?? NSSize(width: Metrics.popOverDesiredWidth, height: Metrics.popOverDesiredHeight)
    }

    init(downloadManager: DownloadManager, storage: Storage) {
        self.downloadManager = downloadManager
        self.storage = storage

        super.init(nibName: nil, bundle: nil)

        downloadManager
            .downloadsObservable
            .throttle(.milliseconds(200), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in

                self?.downloads = $0.sorted(by: DownloadManager.Download.sortingFunction)
            }).disposed(by: disposeBag)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DownloadsManagementViewController: NSTableViewDataSource, NSTableViewDelegate {

    private struct Constants {
        static let downloadStatusCellIdentifier = "downloadStatusCellIdentifier"
        static let rowIdentifier = "row"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return downloads.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let download = downloads[row]
        guard let session = storage.session(with: download.session.sessionIdentifier) else { return nil }

        var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.downloadStatusCellIdentifier), owner: tableView) as? DownloadsManagementTableCellView

        if cell == nil {
            cell = DownloadsManagementTableCellView(frame: .zero)
            cell?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.downloadStatusCellIdentifier)
        }

        if let status = downloadManager.downloadStatusObservable(for: download) {
            cell?.viewModel = DownloadViewModel(download: download, status: status, session: session)
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        var rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier), owner: tableView) as? DownloadsManagementTableRowView

        if rowView == nil {
            rowView = DownloadsManagementTableRowView(frame: .zero)
            rowView?.identifier = NSUserInterfaceItemIdentifier(rawValue: Constants.rowIdentifier)
        }

        rowView?.isLastRow = row == downloads.index(before: downloads.endIndex)

        return rowView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return Metrics.rowHeight
    }
}

extension DownloadsManagementViewController: NSPopoverDelegate {

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }
}
