//
//  DownloadsManagementTableCellView.swift
//  WWDC
//
//  Created by Allen Humphreys on 10/17/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import RxSwift

final class DownloadsManagementTableCellView: NSTableCellView {

    static var byteCounterFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.zeroPadsFractionDigits = true
        return formatter
    }()

    static func statusString(for info: DownloadManager.DownloadInfo, download: DownloadManager.Download) -> String {
        var status = ""

        if download.state == .suspended {
            status = "Paused"
        } else if info.totalBytesExpectedToWrite == 0 {
            status = "Waiting..."
        } else {
            let formatter = DownloadsManagementTableCellView.byteCounterFormatter

            status += "\(formatter.string(fromByteCount: info.totalBytesWritten))"
            status += " of "
            status += "\(formatter.string(fromByteCount: info.totalBytesExpectedToWrite))"
        }

        return status
    }

    var disposeBag = DisposeBag()

    var viewModel: DownloadViewModel? {
        didSet {
            guard viewModel !== oldValue else { return }
            bindUI()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    required init?(coder decoder: NSCoder) {
        fatalError()
    }

    func bindUI() {
        disposeBag = DisposeBag()

        sessionTitleLabel.stringValue = viewModel?.session.title ?? "No ViewModel"

        guard let viewModel = viewModel else { return }
        let status = viewModel.status
        let download = viewModel.download

        let throttledStatus = status.throttle(.milliseconds(100), latest: true, scheduler: MainScheduler.instance)

        throttledStatus
            .subscribe(onNext: { [weak self] status in
                guard let self = self else { return }

                switch status {
                case .downloading(let info), .paused(let info):
                    if info.totalBytesExpectedToWrite > 0 {
                        self.progressIndicator.isIndeterminate = false
                        self.progressIndicator.doubleValue = info.progress
                    } else {
                        self.progressIndicator.isIndeterminate = true
                        self.progressIndicator.startAnimation(nil)
                    }
                    self.downloadStatusLabel.stringValue = DownloadsManagementTableCellView.statusString(for: info, download: download)
                case .finished, .cancelled, .none, .failed: ()
                }
            }).disposed(by: disposeBag)

        status
            .map { status -> NSControl.StateValue in
                if case .downloading = status {
                    return NSControl.StateValue.off
                }
                return NSControl.StateValue.on
            }
            .distinctUntilChanged()
            .bind(to: suspendResumeButton.rx.state)
            .disposed(by: disposeBag)
    }

    private lazy var sessionTitleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 13)
        l.textColor = .labelColor
        l.isSelectable = true
        l.translatesAutoresizingMaskIntoConstraints = false
        l.allowsDefaultTighteningForTruncation = true
        l.lineBreakMode = .byTruncatingTail

        return l
    }()

    private lazy var downloadStatusLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = .labelColor
        l.isSelectable = true
        l.translatesAutoresizingMaskIntoConstraints = false
        l.allowsDefaultTighteningForTruncation = true
        l.lineBreakMode = .byTruncatingTail

        return l
    }()

    static let pauseImage = NSImage(named: "NSPauseTemplate")!.makeFreestandingTemplate(outputSize: NSSize(width: 14, height: 14))
    static let resumeImage = NSImage(named: "NSPlayTemplate")!.resized(to: 13)

    private lazy var suspendResumeButton: NSButton = {
        let v = NSButton(image: DownloadsManagementTableCellView.pauseImage, target: self, action: #selector(togglePause))
        v.alternateImage = DownloadsManagementTableCellView.resumeImage
        v.alternateImage?.isTemplate = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isBordered = false
        v.imagePosition = .imageOnly
        v.setButtonType(.toggle)
        return v
    }()

    private lazy var cancelButton: NSButton = {
        let v = NSButton(image: NSImage(named: "NSStopProgressFreestandingTemplate")!, target: self, action: #selector(cancel))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isBordered = false
        v.imagePosition = .imageOnly
        return v
    }()

    private lazy var progressIndicator: NSProgressIndicator = {
        let v = NSProgressIndicator(frame: .zero)
        v.minValue = 0
        v.maxValue = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 12).isActive = true
        return v
    }()

    @objc
    private func togglePause() {
        if viewModel?.download.state == .suspended {
            viewModel?.download.resume()
        } else if viewModel?.download.state == .running {
            viewModel?.download.pause()
        }
    }

    @objc
    private func cancel() {
        viewModel?.download.cancel()
    }

    private func setup() {

        addSubview(progressIndicator)
        addSubview(cancelButton)
        addSubview(sessionTitleLabel)
        addSubview(downloadStatusLabel)
        addSubview(suspendResumeButton)

        // Horizontal layout
        let gap: CGFloat = -5
        progressIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20).isActive = true
        progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 3).isActive = true
        progressIndicator.trailingAnchor.constraint(equalTo: suspendResumeButton.leadingAnchor, constant: gap - 2).isActive = true

        suspendResumeButton.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: gap/2 + 2).isActive = true
        suspendResumeButton.widthAnchor.constraint(equalToConstant: 25).isActive = true
        suspendResumeButton.centerYAnchor.constraint(equalTo: progressIndicator.centerYAnchor).isActive = true

        cancelButton.centerYAnchor.constraint(equalTo: progressIndicator.centerYAnchor).isActive = true
        cancelButton.widthAnchor.constraint(equalToConstant: 25).isActive = true
        cancelButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: gap).isActive = true

        // Vertical layout
        sessionTitleLabel.bottomAnchor.constraint(equalTo: progressIndicator.topAnchor, constant: -4).isActive = true
        sessionTitleLabel.leadingAnchor.constraint(equalTo: progressIndicator.leadingAnchor).isActive = true
        sessionTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: cancelButton.leadingAnchor).isActive = true
        downloadStatusLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor).isActive = true
        downloadStatusLabel.leadingAnchor.constraint(equalTo: progressIndicator.leadingAnchor).isActive = true
        downloadStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: cancelButton.leadingAnchor).isActive = true
    }
}
