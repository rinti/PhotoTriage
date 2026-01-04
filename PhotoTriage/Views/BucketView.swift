//
//  BucketView.swift
//  PhotoTriage
//

import SwiftUI
import Photos

struct BucketView: View {
    @ObservedObject var deleteBucket: DeleteBucket
    let assets: [PHAsset]
    let onDismiss: () -> Void

    @FocusState private var isFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 8)
    ]

    private var markedAssets: [PHAsset] {
        deleteBucket.getMarkedAssetsFromArray(assets)
    }

    private var totalSizeFormatted: String {
        let bytes = deleteBucket.calculateTotalSizeFromArray(assets)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(deleteBucket.count) items marked for deletion")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("\(totalSizeFormatted) will be freed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.white)

                    Spacer()

                    Text("Press B or Esc to return")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.black.opacity(0.8))

                // Grid of thumbnails
                if markedAssets.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Bucket is empty")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(markedAssets, id: \.localIdentifier) { asset in
                                ThumbnailView(asset: asset) {
                                    deleteBucket.restore(asset)
                                }
                            }
                        }
                        .padding()
                    }
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
            isFocused = true
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .escape:
            onDismiss()
            return .handled
        default:
            break
        }

        switch keyPress.characters.lowercased() {
        case "b":
            onDismiss()
            return .handled
        default:
            return .ignored
        }
    }
}

// MARK: - Thumbnail View

struct ThumbnailView: View {
    let asset: PHAsset
    let onTap: () -> Void

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 150, minHeight: 150)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(minWidth: 150, minHeight: 150)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
            }

            // Red overlay
            Rectangle()
                .stroke(.red, lineWidth: 4)

            // Trash icon overlay
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .padding(6)
                        .background(.red)
                        .clipShape(Circle())
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let targetSize = CGSize(width: 300, height: 300)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { result, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if let result = result {
                    Task { @MainActor in
                        self.image = result
                    }
                }
                // Only continue once we have the final image
                if !isDegraded {
                    continuation.resume()
                }
            }
        }
    }
}
