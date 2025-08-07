//
//  NewTranscriptView.swift
//  WWDC
//
//  Created by luca on 03.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import ConfCore
import SwiftUI

@available(macOS 26.0, *)
struct NewTranscriptView: View {
//    @Environment(NewGlobalSearchCoordinator.self) var coordinator
    @State private var lines: [TranscriptLine] = []
    @State private var selectedLine: TranscriptLine?
    let viewModel: SessionViewModel
    @Binding var scrollPosition: ScrollPosition

    @State private var maskHeight: CGFloat?
    @State private var readyToPlay: Bool = false
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 5) {
            ForEach(lines) { line in
                Button("") {
                    seekVideoTo(line: line)
                }
                .buttonStyle(LineButtonStyle(line: line, selectedLine: selectedLine))
                .id(line)
                .scrollTransition { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.7)
                        .blur(radius: phase.isIdentity ? 0 : 0.5)
                }
            }
            .scrollTargetLayout()
        }
        .padding()
        .opacity(readyToPlay ? 1 : 0)
        .disabled(!readyToPlay)
        .transition(.blurReplace)
        .overlay(alignment: .top) {
            ProgressView().progressViewStyle(.circular)
                .opacity(readyToPlay ? 0 : 1)
                .transition(.blurReplace)
        }
        .onReceive(linesUpdate) { newValue in
            let filtered = newValue.filter { !$0.body.isEmpty }
            guard filtered != lines else {
                return
            }
            withAnimation {
                lines = filtered
            }
            updateCurrentLineIfNeeded()
        }
        .onReceive(highlightChange) { newValue in
            guard newValue != selectedLine else {
                return
            }
            withAnimation {
                selectedLine = newValue
                scrollPosition.scrollTo(id: newValue, anchor: .top)
            }
        }
        .task {
            updateCurrentLineIfNeeded()
        }
    }

    private var sessionID: String {
        viewModel.sessionIdentifier
    }

    private var highlightChange: AnyPublisher<TranscriptLine?, Never> {
        NotificationCenter.default.publisher(for: .HighlightTranscriptAtCurrentTimecode)
            .filter { ($0.userInfo?["session_id"] as? String) == sessionID }
            .compactMap { note in
                guard let timecode = note.object as? NSString else { return nil }

                guard let annotation = lines.findNearestLine(to: timecode.doubleValue, flipLastToFirst: false) else {
                    return nil
                }
                return annotation
            }
            .eraseToAnyPublisher()
    }

    private var linesUpdate: AnyPublisher<[TranscriptLine], Never> {
        viewModel.rxTranscriptAnnotations
            .replaceErrorWithEmpty()
            .map { list in
                list.map { TranscriptLine(timecode: $0.timecode, body: $0.body) }
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private func seekVideoTo(line: TranscriptLine) {
        withAnimation(.bouncy) {
            selectedLine = line
            scrollPosition.scrollTo(id: line, anchor: .top)
        }
        guard let transcript = viewModel.session.transcript() else { return }

        let annotation = TranscriptAnnotation()
        annotation.body = line.body
        annotation.timecode = line.timecode

        let notificationObject = (transcript, annotation)

        NotificationCenter.default.post(name: NSNotification.Name.TranscriptControllerDidSelectAnnotation, object: notificationObject)
    }

    private func updateCurrentLineIfNeeded() {
        let currentPosition = viewModel.session.progresses.first?.currentPosition ?? 0
        guard
            let line = lines.findNearestLine(to: currentPosition)
        else {
            return
        }
        withAnimation {
            selectedLine = line
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (readyToPlay ? 0 : 0.5)) {
            // wait until content fully appears
            scrollPosition.scrollTo(id: line, anchor: .top)
            withAnimation {
                readyToPlay = true
            }
        }
    }
}

struct TranscriptLine: Identifiable, Hashable {
    var id: String {
        "\(timecode)-\(body)"
    }

    /// The time this annotation occurs within the video
    let timecode: Double
    /// The annotation's text
    let body: String
}

private struct LineButtonStyle: ButtonStyle {
    let videoTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    @State private var isHovered = false
    let line: TranscriptLine
    let selectedLine: TranscriptLine?
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Text(line.body)
            .font(.title)
            .fontWeight(.medium)
            .lineLimit(nil)
            .transition(.blurReplace)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 5)) // clip first
            .overlay(alignment: .trailing, content: {
                Text(videoTimeFormatter.string(from: line.timecode) ?? "")
                    .font(.title2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .transition(.blurReplace.combined(with: .scale))
                    .shadow(radius: 10)
                    .opacity(isHovered ? 1 : 0)
            })
            .foregroundStyle(selectedLine == line ? .primary : .secondary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.bouncy, value: configuration.isPressed)
            .animation(.bouncy, value: isHovered)
            .contentShape(Rectangle()) // make the whole line hoverable
            .onHover { isHovering in
                isHovered = isHovering
            }
    }
}

private extension Array where Element == TranscriptLine {
    /// Assumes lines are sorted by timecode.
    ///
    /// - Parameters:
    ///   - timecode: The target timecode in seconds to search for.
    ///   - flipLastToFirst: If true, when playback has reached the end and restarts, the first line will be considered the closest for a smoother replay experience.
    /// - Returns: The transcript line closest to the given timecode, or `nil` if the array is empty.
    func findNearestLine(to timecode: Double, flipLastToFirst: Bool = true) -> TranscriptLine? {
        guard !isEmpty else { return nil }
        var low = 0
        var high = count - 1

        while low <= high {
            let mid = (low + high) / 2
            if self[mid].timecode == timecode {
                return self[mid]
            } else if self[mid].timecode < timecode {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        // Now low is the index of the smallest number >= target
        // high is the largest number < target
        let lowDiff = (low < count) ? abs(self[low].timecode - timecode) : .greatestFiniteMagnitude
        let highDiff = (high >= 0) ? abs(self[high].timecode - timecode) : .greatestFiniteMagnitude

        if lowDiff < highDiff {
            return self[low]
        } else {
            if high == count - 1 && flipLastToFirst {
                return self[0]
            } else {
                return self[high]
            }
        }
    }
}
