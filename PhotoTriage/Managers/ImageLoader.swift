//
//  ImageLoader.swift
//  PhotoTriage
//

import Foundation
import Photos
import AppKit
import Combine

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let imageManager = PHImageManager.default()
    private var currentRequestID: PHImageRequestID?

    /// Target size for image loading (medium resolution for performance)
    private let targetSize = CGSize(width: 1600, height: 1600)

    func loadImage(from asset: PHAsset) {
        // Cancel any pending request
        cancelLoad()

        // Clear current image and show loading state immediately
        image = nil
        isLoading = true
        error = nil

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

    func cancelLoad() {
        if let requestID = currentRequestID {
            imageManager.cancelImageRequest(requestID)
            currentRequestID = nil
        }
        isLoading = false
    }
}
