//
//  SessionItemView.swift
//  WWDC
//
//  Created by luca on 07.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//
import SwiftUI

struct SessionItemView: View {
    @Environment(SessionItemViewModel.self) var viewModel
    var horizontalPadding: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            ProgressView(value: viewModel.progress, total: 1.0)
                .progressViewStyle(TrackColorProgressViewStyle())
                .foregroundStyle(.primary)
                .opacity(viewModel.isWatched ? 0 : 1)

            SessionCoverView(isThumbnail: true) { newImg, isPlaceHolder in
                newImg
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 85, height: 48)
                    .clipped()
                    .padding(.horizontal, 8)
            }

            informationLabels
        }
        .task(id: viewModel.coverImageURL) {
            await viewModel.downloadSmallCoverIfNeeded()
        }
        .overlay(alignment: .trailing) {
            statusIcons
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
        .frame(height: 64) // Metrics.itemHeight
        .task {
            viewModel.prepareForDisplay()
        }
        .contentShape(Rectangle()) // quick hover
        .help([viewModel.title, viewModel.subtitle, viewModel.context].joined(separator: "\n"))
    }

    /// Discover Apple-Hosted Background Assets
    /// WWDC25 • Session 325
    /// System Services
    private var informationLabels: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            Text(viewModel.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
            Text(viewModel.context)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private var statusIcons: some View {
        // Icons
        VStack(alignment: .trailing, spacing: 0) {
            if viewModel.isFavorite {
                Image(systemName: "star.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14)
                    .padding(3)
                    .blurBackground()
                    .transition(.scale)
            }

            Spacer()

            if viewModel.isDownloaded {
                Image(systemName: "arrowshape.down.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 11)
                    .padding(3)
                    .blurBackground()
                    .transition(.scale)
            }
        }
        .animation(.bouncy, value: viewModel.isFavorite)
        .animation(.bouncy, value: viewModel.isDownloaded)
    }
}

struct SessionItemButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.isSelected) var isSelected
    let style: SessionCellView.Style
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1) // scale content only
            .contentShape(Rectangle())
            .background(background, in: .rect)
            .animation(.bouncy, value: configuration.isPressed)
            .animation(.smooth, value: isHovered)
            .animation(.smooth, value: isSelected)
            .transition(.blurReplace)
            .clipShape(RoundedRectangle(cornerRadius: style == .rounded ? 6 : 0))
            .onHover { isHovering in
                withAnimation {
                    isHovered = isHovering
                }
            }
    }

    private var background: Color {
        if isSelected {
            return Color(.selection)
        } else if isHovered {
            return .secondary.opacity(0.3)
        } else {
            return .clear
        }
    }
}

extension View {
    func blurBackground(opacity: Double = 0.5) -> some View {
        background {
            Rectangle().fill(.background.opacity(opacity))
                .blur(radius: 5)
        }
    }
}
