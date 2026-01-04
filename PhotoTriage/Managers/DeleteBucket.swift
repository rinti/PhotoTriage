//
//  DeleteBucket.swift
//  PhotoTriage
//

import Combine
import Photos
import SwiftUI

@MainActor
class DeleteBucket: ObservableObject {
    @Published private(set) var markedAssets: Set<String> = []  // localIdentifiers

    var count: Int { markedAssets.count }
    var isEmpty: Bool { markedAssets.isEmpty }

    func markForDeletion(_ asset: PHAsset) {
        markedAssets.insert(asset.localIdentifier)
    }

    func restore(_ asset: PHAsset) {
        markedAssets.remove(asset.localIdentifier)
    }

    func restoreByIdentifier(_ identifier: String) {
        markedAssets.remove(identifier)
    }

    func isMarked(_ asset: PHAsset) -> Bool {
        markedAssets.contains(asset.localIdentifier)
    }

    func isMarkedByIdentifier(_ identifier: String) -> Bool {
        markedAssets.contains(identifier)
    }

    func clear() {
        markedAssets.removeAll()
    }

    /// Restore bucket state from saved identifiers
    func restoreFromSession(_ identifiers: [String]) {
        markedAssets = Set(identifiers)
    }

    /// Calculate total storage size of marked assets in bytes
    func calculateTotalSize(from assets: PHFetchResult<PHAsset>) -> Int64 {
        var totalSize: Int64 = 0

        assets.enumerateObjects { asset, _, _ in
            if self.isMarked(asset) {
                // Get resources for this asset to calculate size
                let resources = PHAssetResource.assetResources(for: asset)
                for resource in resources {
                    if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                        totalSize += fileSize
                    }
                }
            }
        }

        return totalSize
    }

    /// Get all marked assets from a fetch result
    func getMarkedAssets(from assets: PHFetchResult<PHAsset>) -> [PHAsset] {
        var result: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            if self.isMarked(asset) {
                result.append(asset)
            }
        }
        return result
    }

    /// Get all marked assets from an array
    func getMarkedAssetsFromArray(_ assets: [PHAsset]) -> [PHAsset] {
        assets.filter { isMarked($0) }
    }

    /// Calculate total storage size of marked assets from an array
    func calculateTotalSizeFromArray(_ assets: [PHAsset]) -> Int64 {
        var totalSize: Int64 = 0

        for asset in assets {
            if isMarked(asset) {
                let resources = PHAssetResource.assetResources(for: asset)
                for resource in resources {
                    if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                        totalSize += fileSize
                    }
                }
            }
        }

        return totalSize
    }

    /// Commit deletions via PhotoKit - moves photos to Recently Deleted
    /// Returns the number of assets deleted
    func commitDeletions() async throws -> Int {
        let identifiers = Array(markedAssets)
        guard !identifiers.isEmpty else { return 0 }

        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete)
        }

        let deletedCount = markedAssets.count
        clear()
        return deletedCount
    }
}
