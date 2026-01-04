//
//  ImageLoader.swift
//  PhotoTriage
//

import Foundation
import Photos
import AppKit
import Combine
import AVFoundation

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var mediaType: PHAssetMediaType?
    @Published var playerItem: AVPlayerItem?

    private let imageManager = PHImageManager.default()
    private var currentRequestID: PHImageRequestID?
    private var currentVideoTask: Task<Void, Never>?

    /// Target size for image loading (medium resolution for performance)
    private let targetSize = CGSize(width: 1600, height: 1600)

    func loadImage(from asset: PHAsset) {
        // Cancel any pending request
        cancelLoad()

        // Clear current state and show loading
        image = nil
        isLoading = true
        error = nil
        mediaType = asset.mediaType
        playerItem = nil

        if asset.mediaType == .video {
            loadVideo(from: asset)
        } else {
            loadPhoto(from: asset)
        }
    }

    private func loadPhoto(from asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true // Allow downloading from iCloud
        options.isSynchronous = false

        currentRequestID = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, info in
            Task { @MainActor in
                guard let self = self else { return }

                // Check if request was cancelled
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    return
                }

                // Check for errors
                if let error = info?[PHImageErrorKey] as? Error {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    return
                }

                // Check if this is a degraded (low quality) image - wait for high quality
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                    // Show degraded image while waiting for full quality
                    if let image = image {
                        self.image = image
                    }
                    return
                }

                self.isLoading = false

                if let image = image {
                    self.image = image
                } else {
                    self.error = "Failed to load image"
                }
            }
        }
    }

    private func loadVideo(from asset: PHAsset) {
        currentVideoTask = Task {
            do {
                // Get AVPlayerItem from Photos library (more reliable than URL)
                let item = try await requestPlayerItem(for: asset)

                guard !Task.isCancelled else { return }

                // Store the player item immediately so video can play
                self.playerItem = item

                // Try to extract first frame (non-critical)
                do {
                    let firstFrame = try await extractFirstFrame(from: item.asset)
                    guard !Task.isCancelled else { return }
                    self.image = firstFrame
                } catch {
                    // First frame extraction failed, but video can still play
                    print("First frame extraction failed: \(error)")
                }

                self.isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func requestPlayerItem(for asset: PHAsset) async throws -> AVPlayerItem {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            imageManager.requestPlayerItem(forVideo: asset, options: options) { playerItem, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                if let playerItem = playerItem {
                    continuation.resume(returning: playerItem)
                } else {
                    continuation.resume(throwing: VideoLoadError.unsupportedFormat)
                }
            }
        }
    }

    private func extractFirstFrame(from avAsset: AVAsset) async throws -> NSImage {
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let cgImage = try await generator.image(at: .zero).image
        return NSImage(cgImage: cgImage, size: .zero)
    }

    func cancelLoad() {
        if let requestID = currentRequestID {
            imageManager.cancelImageRequest(requestID)
            currentRequestID = nil
        }
        currentVideoTask?.cancel()
        currentVideoTask = nil
        isLoading = false
    }
}

enum VideoLoadError: LocalizedError {
    case unsupportedFormat
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Video format not supported"
        case .extractionFailed:
            return "Failed to extract video frame"
        }
    }
}
