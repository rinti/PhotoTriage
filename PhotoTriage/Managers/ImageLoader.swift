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
    @Published var videoAsset: AVAsset?  // Changed from AVPlayerItem to AVAsset

    private let imageManager = PHImageManager.default()
    private var currentRequestID: PHImageRequestID?
    private var currentVideoTask: Task<Void, Never>?

    /// Target size for image loading (medium resolution for performance)
    private let targetSize = CGSize(width: 1600, height: 1600)

    // Preloading
    private var preloadCache: [String: NSImage] = [:]  // localIdentifier -> image
    private var preloadRequests: [String: PHImageRequestID] = [:]

    func loadImage(from asset: PHAsset) {
        // Cancel any pending request
        cancelLoad()

        // Clear current state
        image = nil
        error = nil
        mediaType = asset.mediaType
        videoAsset = nil

        // Check preload cache first (photos only)
        if asset.mediaType == .image, let cached = preloadCache[asset.localIdentifier] {
            self.image = cached
            self.isLoading = false
            preloadCache.removeValue(forKey: asset.localIdentifier)
            return
        }

        // Show loading state
        isLoading = true

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
                // Get AVAsset from Photos library
                let avAsset = try await requestAVAsset(for: asset)

                guard !Task.isCancelled else { return }

                // Store the AVAsset so VideoPlayerView can create its own AVPlayerItem
                self.videoAsset = avAsset

                // Try to extract first frame (non-critical)
                do {
                    let firstFrame = try await extractFirstFrame(from: avAsset)
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

    private func requestAVAsset(for asset: PHAsset) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                if let avAsset = avAsset {
                    continuation.resume(returning: avAsset)
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

    // MARK: - Preloading

    /// Preload images for the given assets (photos only, not videos)
    func preloadAssets(_ assets: [PHAsset]) {
        // Cancel requests for assets no longer in preload window
        let newIdentifiers = Set(assets.map { $0.localIdentifier })
        for (id, requestID) in preloadRequests where !newIdentifiers.contains(id) {
            imageManager.cancelImageRequest(requestID)
            preloadRequests.removeValue(forKey: id)
            preloadCache.removeValue(forKey: id)
        }

        // Request new assets not already cached or being loaded
        for asset in assets {
            let id = asset.localIdentifier
            guard preloadCache[id] == nil, preloadRequests[id] == nil else { continue }
            guard asset.mediaType == .image else { continue }  // Only preload photos

            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { [weak self] image, info in
                Task { @MainActor in
                    guard let self = self, let image = image else { return }

                    // Check if request was cancelled
                    if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                        return
                    }

                    // Only cache high quality (non-degraded) images
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !isDegraded {
                        self.preloadCache[id] = image
                        self.preloadRequests.removeValue(forKey: id)
                    }
                }
            }
            preloadRequests[id] = requestID
        }
    }

    /// Clear all preloaded images and cancel pending preload requests
    func clearPreloadCache() {
        for (_, requestID) in preloadRequests {
            imageManager.cancelImageRequest(requestID)
        }
        preloadRequests.removeAll()
        preloadCache.removeAll()
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
