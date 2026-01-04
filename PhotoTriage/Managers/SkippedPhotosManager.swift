//
//  SkippedPhotosManager.swift
//  PhotoTriage
//

import Combine
import Foundation
import Photos

/// Manages permanently skipped photos that should not appear in future sessions
@MainActor
final class SkippedPhotosManager: ObservableObject {
    static let shared = SkippedPhotosManager()

    private static let storageKey = "com.phototriage.skippedPhotos"

    @Published private(set) var skippedIds: Set<String> = []

    var count: Int { skippedIds.count }

    init() {
        loadFromStorage()
    }

    /// Mark a photo as permanently skipped
    func skip(_ asset: PHAsset) {
        skippedIds.insert(asset.localIdentifier)
        saveToStorage()
    }

    /// Check if a photo is permanently skipped
    func isSkipped(_ asset: PHAsset) -> Bool {
        skippedIds.contains(asset.localIdentifier)
    }

    /// Clear all skipped photos
    func clearAll() {
        skippedIds.removeAll()
        saveToStorage()
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return
        }
        skippedIds = decoded
    }

    private func saveToStorage() {
        guard let encoded = try? JSONEncoder().encode(skippedIds) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }
}
