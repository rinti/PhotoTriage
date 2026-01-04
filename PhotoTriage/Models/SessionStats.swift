import Foundation

/// Tracks statistics for a photo review session
struct SessionStats {
    var sessionStartTime: Date
    var photosKept: Int = 0
    var photosDeleted: Int = 0
    var storageFreed: Int64 = 0  // bytes
    var backNavigations: Int = 0

    /// Total photos reviewed (kept + deleted)
    var totalPhotosReviewed: Int {
        photosKept + photosDeleted
    }

    /// Session duration in seconds
    var duration: TimeInterval {
        Date().timeIntervalSince(sessionStartTime)
    }

    /// Formatted duration string (e.g., "12 min 34 sec")
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return "\(minutes) min \(seconds) sec"
        } else {
            return "\(seconds) sec"
        }
    }

    /// Photos reviewed per minute
    var photosPerMinute: Double {
        let minutes = duration / 60.0
        guard minutes > 0 else { return 0 }
        return Double(totalPhotosReviewed) / minutes
    }

    /// Formatted storage freed string (e.g., "2.3 GB")
    var formattedStorageFreed: String {
        ByteCountFormatter.string(fromByteCount: storageFreed, countStyle: .file)
    }

    init(sessionStartTime: Date = Date()) {
        self.sessionStartTime = sessionStartTime
    }
}
