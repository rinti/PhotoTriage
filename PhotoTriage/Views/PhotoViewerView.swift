//
//  PhotoViewerView.swift
//  PhotoTriage
//

import SwiftUI
import Photos

struct PhotoViewerView: View {
    let assets: PHFetchResult<PHAsset>
    let onDismiss: () -> Void

    @StateObject private var imageLoader = ImageLoader()
    @State private var currentIndex: Int = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Photo display
            if let image = imageLoader.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if imageLoader.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            } else if let error = imageLoader.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress counter overlay
            VStack {
                HStack {
                    Spacer()
                    Text("\(currentIndex + 1)/\(assets.count)")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                        .padding()
                }
                Spacer()
            }

            // End of photos message
            if currentIndex >= assets.count {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("You've reached the end!")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("Press Q to quit")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .focusable()
        .focused($isFocused)
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
        .task {
            loadCurrentPhoto()
            isFocused = true
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.characters.lowercased() {
        case "s":
            // Keep photo, advance to next
            Task { @MainActor in
                advanceToNext()
            }
            return .handled
        case "q":
            // Quit session
            Task { @MainActor in
                onDismiss()
            }
            return .handled
        default:
            return .ignored
        }
    }

    private func advanceToNext() {
        guard currentIndex < assets.count - 1 else {
            // Already at the last photo
            currentIndex = assets.count // Trigger "end" state
            return
        }
        currentIndex += 1
        loadCurrentPhoto()
    }

    private func loadCurrentPhoto() {
        guard currentIndex < assets.count else { return }
        let asset = assets.object(at: currentIndex)
        imageLoader.loadImage(from: asset)
    }
}
