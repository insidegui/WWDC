//
//  TrackColorView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import SwiftUI

struct TrackColorProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(.foreground, lineWidth: shouldShowBorder(for: configuration.fractionCompleted) ? 1 : 0)
            .overlay {
                GeometryReader { geometry in
                    VStack {
                        Rectangle()
                            .fill(.foreground)
                            .frame(height: geometry.size.height * (configuration.fractionCompleted ?? 1))
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(width: 4)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
    
    private func shouldShowBorder(for progress: Double?) -> Bool {
        guard let progress = progress else { return false }
        return progress < 1.0
    }
}

#Preview {
    VStack(spacing: 10) {
        Text("Track Color Progress View")
            .font(.headline)

        HStack(spacing: 30) {
            ProgressView(value: 0.0, total: 1.0)
                .foregroundStyle(.blue)

            ProgressView(value: 0.3, total: 1.0)
                .foregroundStyle(.green)

            ProgressView(value: 0.7, total: 1.0)
                .foregroundStyle(.orange)

            ProgressView(value: 0.98, total: 1.0)
                .foregroundStyle(.red)
        }
        .frame(height: 50)
        .padding()
    }
    .padding()
    .progressViewStyle(TrackColorProgressViewStyle())
}
