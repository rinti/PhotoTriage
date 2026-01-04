//
//  LocationCache.swift
//  PhotoTriage
//

import Foundation
import CoreLocation
import MapKit
import Photos
import Combine

/// Caches geocoded location strings for photo assets to avoid repeated reverse geocoding calls
@MainActor
class LocationCache: ObservableObject {
    private static let cacheKey = "com.phototriage.locationCache"

    /// Maps asset localIdentifier to geocoded location string (e.g., "San Francisco, California, United States")
    @Published private(set) var cache: [String: String] = [:]

    init() {
        loadCache()
    }

    // MARK: - Cache Operations

    /// Get cached location for an asset
    func getLocation(for assetId: String) -> String? {
        cache[assetId]
    }

    /// Check if location matches the search query (case-insensitive fuzzy match)
    func matchesQuery(_ query: String, assetId: String) -> Bool {
        guard let cached = cache[assetId] else { return false }
        return cached.localizedCaseInsensitiveContains(query)
    }

    // MARK: - Geocoding

    /// Geocode a single asset's location and cache the result
    func geocodeAsset(_ asset: PHAsset) async -> String? {
        // Check cache first
        if let cached = cache[asset.localIdentifier] {
            return cached
        }

        // Need location data
        guard let location = asset.location else {
            return nil
        }

        // Use MKReverseGeocodingRequest for macOS 26+
        guard let geocodingRequest = MKReverseGeocodingRequest(location: location) else {
            return nil
        }

        do {
            let mapItems = try await geocodingRequest.mapItems

            guard let mapItem = mapItems.first else { return nil }

            // Use the full address from MKAddress (macOS 26+ API)
            let locationString = mapItem.address?.fullAddress ?? mapItem.name ?? ""

            guard !locationString.isEmpty else { return nil }

            // Cache the result
            cache[asset.localIdentifier] = locationString
            saveCache()

            return locationString
        } catch {
            print("Geocoding failed for asset \(asset.localIdentifier): \(error)")
            return nil
        }
    }

    /// Geocode multiple assets with progress callback
    /// Returns array of asset identifiers that match the location query
    func filterAssetsByLocation(
        assets: [PHAsset],
        query: String,
        progressHandler: @escaping (Int, Int) -> Void
    ) async -> [String] {
        var matchingIds: [String] = []
        let total = assets.count
        var uncachedCount = 0

        for (index, asset) in assets.enumerated() {
            progressHandler(index + 1, total)

            // Skip assets without location
            guard asset.location != nil else { continue }

            // Check if already cached (no rate limit needed for cache hits)
            let isCached = cache[asset.localIdentifier] != nil

            // Geocode (uses cache if available)
            if let locationString = await geocodeAsset(asset) {
                if locationString.localizedCaseInsensitiveContains(query) {
                    matchingIds.append(asset.localIdentifier)
                }
            }

            // Rate limit only for uncached requests
            // Apple limits to 50 requests per 60 seconds, so ~1.2s between requests
            if !isCached {
                uncachedCount += 1
                // Add 1.3 second delay between geocoding requests to stay under limit
                try? await Task.sleep(nanoseconds: 1_300_000_000)
            }
        }

        return matchingIds
    }

    // MARK: - Persistence

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        cache = decoded
    }

    private func saveCache() {
        guard let encoded = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.cacheKey)
    }

    /// Clear the entire cache
    func clearCache() {
        cache.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.cacheKey)
    }
}
