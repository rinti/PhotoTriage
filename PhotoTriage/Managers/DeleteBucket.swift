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
}
