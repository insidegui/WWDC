//
//  WWDCProgressIndicator.swift
//  WWDC
//
//  Created by Guilherme Rambo on 24/10/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

struct WWDCProgressIndicator: View {
    var value: Double?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ProgressView("Click to cancel", value: value, total: 1.0)
                .foregroundStyle(Color(nsColor: .primary))
                .progressViewStyle(WWDCProgressViewStyle())
                .help("Click to cancel")
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct WWDCProgressViewStyle: ProgressViewStyle {
    @State private var isAnimating = false
    
    private struct Metrics {
        static let defaultSize: CGFloat = 24
        static let lineWidth: CGFloat = 2
        static let apparentProgressWhenIndeterminate: Double = 0.9
    }
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(.foreground.opacity(0.35), lineWidth: Metrics.lineWidth)
            
            Circle()
                .trim(from: 0, to: configuration.fractionCompleted ?? Metrics.apparentProgressWhenIndeterminate)
                .stroke(.foreground, style: StrokeStyle(lineWidth: Metrics.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .rotationEffect(.degrees(configuration.fractionCompleted == nil && isAnimating ? 360 : 0))
                .animation(
                    configuration.fractionCompleted == nil && isAnimating 
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .easeInOut(duration: 0.4),
                    value: configuration.fractionCompleted == nil && isAnimating ? 360 : 0
                )
                .animation(.easeInOut(duration: 0.4), value: configuration.fractionCompleted)
        }
        .frame(width: Metrics.defaultSize, height: Metrics.defaultSize)
        .onAppear {
            if configuration.fractionCompleted == nil {
                isAnimating = true
            }
        }
        .onChange(of: configuration.fractionCompleted) { _, newValue in
            isAnimating = newValue == nil
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressView(value: 0.7, total: 1.0)
        ProgressView()

        WWDCProgressIndicator(value: 0.2, action: {})
    }
    .progressViewStyle(WWDCProgressViewStyle())
    .foregroundStyle(Color(nsColor: .primary))
    .padding()
}
