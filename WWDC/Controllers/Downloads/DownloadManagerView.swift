import SwiftUI
import ConfCore
import PlayerUI

private typealias Metrics = DownloadsManagementViewController.Metrics

struct DownloadManagerView: View {
    @EnvironmentObject private var manager: MediaDownloadManager
    @ObservedObject var controller: DownloadsManagementViewController

    var body: some View {
        List {
            ForEach(manager.downloads) { download in
                DownloadItemView(download: download)
                    .tag(download)
            }
        }
        .frame(minWidth: Metrics.defaultWidth, maxWidth: .infinity, minHeight: Metrics.defaultHeight, maxHeight: .infinity)
        .animation(.smooth, value: manager.downloads.count)
    }
}

struct DownloadItemView: View {
    @EnvironmentObject private var manager: MediaDownloadManager
    @ObservedObject var download: MediaDownload

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(download.title)
                    .font(.headline)

                Spacer()

                DownloadActionsView(download: download)
            }

            DownloadProgressView(download: download)
        }
        .wwdc_listRowSeparatorHidden()
        .contentShape(Rectangle())
        .padding(8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { contextActions }
        .contextMenu { contextActions }
    }

    @ViewBuilder
    private var contextActions: some View {
        if download.isCompleted {
            Button("Clear") {
                manager.clear(download)
            }
        } else if download.isPaused {
            Button("Resume") {
                catchingErrors {
                    try manager.resume(download)
                }
            }
        } else if download.isFailed {
            Button("Try Again") {
                retry(download)
            }
        } else {
            Button("Pause") {
                catchingErrors {
                    try manager.pause(download)
                }
            }

            Button("Cancel", role: .destructive) {
                catchingErrors {
                    try manager.cancel(download)
                }
            }
        }
    }

    private func catchingErrors(perform action: () throws -> Void) {
        do {
            try action()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func retry(_ download: MediaDownload) {
        Task {
            do {
                try await manager.retry(download)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}

struct DownloadProgressView: View {
    @EnvironmentObject private var manager: MediaDownloadManager
    @ObservedObject var download: MediaDownload

    var body: some View {
        Group {
            switch download.state {
            case .waiting:
                progressState(message: "Starting…")
            case .downloading:
                progressState()
            case .paused:
                progressState(message: "Paused")
            case .failed(let message):
                progressState(message: message)
                    .foregroundStyle(.red)
            case .completed:
                progressState(message: "Finished!")
            case .cancelled:
                progressState(message: "Canceled")
            }
        }
    }

    @ViewBuilder
    private func progressState(message: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if let progress = download.progress {
                ProgressView(value: min(1, max(0, progress)))
                    .opacity(download.isPaused ? 0.5 : 1)
                    .opacity(progress >= 1 ? 0.2 : 1)
            } else {
                ProgressView(value: download.isCompleted ? 1 : nil, total: 1)
                    .opacity(0.5)
            }

            progressDetail(message: message)
        }
    }

    @ViewBuilder
    private func progressDetail(message: String?) -> some View {
        HStack {
            progressIndicator(message: message)

            Spacer()

            if !download.isPaused, let stats = download.stats, let formattedETA = stats.formattedETA, let eta = stats.eta, eta > 0 {
                Text("\(formattedETA)")
                    .numericContentTransition(value: eta, countsDown: true)
            } else if download.isCompleted {
                clearButton
            }
        }
        .progressViewStyle(.linear)
        .monospacedDigit()
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .animation(.smooth, value: download.stats?.eta)
    }

    @ViewBuilder
    private func progressIndicator(message: String?) -> some View {
        if let progress = download.progress, progress < 1 {
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.subheadline.weight(.medium))
                .numericContentTransition(value: progress)
        } else if let message {
            Text(message)
        }
    }

    @ViewBuilder
    private var clearButton: some View {
        Button {
            manager.clear(download)
        } label: {
            Image(systemName: "xmark.circle.fill")
        }
        .buttonStyle(.borderless)
    }
}

struct DownloadActionsView: View {
    @EnvironmentObject private var manager: MediaDownloadManager
    @ObservedObject var download: MediaDownload

    var body: some View {
        Group {
            switch download.state {
            case .waiting:
                pauseButton
            case .downloading:
                pauseButton
            case .paused:
                resumeButton
            case .failed(let message):
                errorButton(with: message)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .progressViewStyle(.circular)
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var pauseButton: some View {
        Button {
            handlingErrors {
                try manager.pause(download)
            }
        } label: {
            Image(systemName: "pause.circle.fill")
        }
    }

    @ViewBuilder
    private var resumeButton: some View {
        Button {
            handlingErrors {
                try manager.resume(download)
            }
        } label: {
            Image(systemName: "play.circle.fill")
        }
    }

    @ViewBuilder
    private func errorButton(with message: String) -> some View {
        Button {
            NSAlert(error: message).runModal()
        } label: {
            Image(systemName: "exclamationmark.circle.fill")
        }
        .foregroundStyle(.red)
    }

    private func handlingErrors(perform action: () throws -> Void) {
        do {
            try action()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

extension View {
    @ViewBuilder
    func wwdc_listRowSeparatorHidden(_ hidden: Bool = true) -> some View {
        if #available(macOS 13.0, *) {
            listRowSeparator(hidden ? .hidden : .automatic)
        } else {
            self
        }
    }
}
