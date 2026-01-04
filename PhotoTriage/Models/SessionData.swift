//
//  SessionData.swift
//  PhotoTriage
//

import Foundation

/// Model representing saved session state for persistence
struct SessionData: Codable {
    /// Sort order used when fetching assets
    let sortOrder: SortOrder

    /// Current position in the photo list
    let currentIndex: Int

    /// Navigation history for back (z key) functionality
    let visitedIndices: [Int]

    /// Asset identifiers marked for deletion (bucket contents)
    let markedAssets: [String]

    /// Total number of assets when session was saved (for validation)
    let totalAssetCount: Int

    /// Timestamp when session was saved
    let savedAt: Date

    // MARK: - Filter Settings (Sprint 6)

    /// Album localIdentifier (nil = All Photos)
    let albumIdentifier: String?

    /// Date range filter - start date
    let dateFrom: Date?

    /// Date range filter - end date
    let dateTo: Date?

    /// Location filter text (fuzzy match on city/region/country)
    let location: String?
}
