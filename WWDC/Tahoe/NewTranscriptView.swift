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
    @State private var scrollPosition = ScrollPosition(idType: TranscriptLine.self)
    let viewModel: SessionViewModel
    let videoTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    @State private var maskHeight: CGFloat?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(lines) { line in
                    Button {
                        seekVideoTo(line: line)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(videoTimeFormatter.string(from: line.timecode) ?? "")
                                .font(.caption2)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.tertiary)
                            Text(line.body)
                                .font(.title)
                                .fontWeight(.medium)
                                .lineLimit(nil)
                                .foregroundStyle(selectedLine == line ? .primary : .secondary)
                                .scaleEffect(selectedLine == line ? 1 : 0.95)
                                .transition(.blurReplace)
                        }
                    }
                    .buttonStyle(LineButtonStyle())
                    .id(line)
                    .scrollTransition { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.95)
                            .opacity(phase.isIdentity ? 1 : 0.7)
                            .blur(radius: phase.isIdentity ? 0 : 0.5)
                    }
                }
                .scrollTargetLayout()
            }
        }
        .scrollPosition($scrollPosition, anchor: .center)
        .safeAreaPadding([.top, .bottom], 100)
        .onReceive(linesUpdate) { newValue in
            guard newValue != lines else {
                return
            }
            withAnimation {
                lines = newValue
            }
        }
        .onReceive(highlightChange) { newValue in
            guard newValue != selectedLine else {
                return
            }
            withAnimation {
                selectedLine = newValue
                scrollPosition.scrollTo(id: newValue, anchor: .center)
            }
        }
    }

    private var sessionID: String {
        viewModel.sessionIdentifier
    }

    private var highlightChange: AnyPublisher<TranscriptLine?, Never> {
        NotificationCenter.default.publisher(for: .HighlightTranscriptAtCurrentTimecode)
            .filter { ($0.userInfo?["session_id"] as? String) == sessionID }
            .compactMap { note in
                guard let timecode = note.object as? String else { return nil }

                guard let annotation = lines.first(where: { Transcript.roundedStringFromTimecode($0.timecode) == timecode }) else {
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
            scrollPosition.scrollTo(id: line, anchor: .center)
        }
        guard let transcript = viewModel.session.transcript() else { return }

        let annotation = TranscriptAnnotation()
        annotation.body = line.body
        annotation.timecode = line.timecode

        let notificationObject = (transcript, annotation)

        NotificationCenter.default.post(name: NSNotification.Name.TranscriptControllerDidSelectAnnotation, object: notificationObject)
    }
}

private struct TranscriptLine: Identifiable, Hashable {
    var id: String {
        "\(timecode)-\(body)"
    }

    /// The time this annotation occurs within the video
    let timecode: Double
    /// The annotation's text
    let body: String
}

private struct LineButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.bouncy, value: configuration.isPressed)
    }
}
