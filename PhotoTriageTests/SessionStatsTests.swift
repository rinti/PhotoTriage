import XCTest
@testable import PhotoTriage

final class SessionStatsTests: XCTestCase {
    func testTotalPhotosReviewedIsKeptPlusDeleted() {
        var stats = SessionStats(sessionStartTime: Date())
        stats.photosKept = 7
        stats.photosDeleted = 5

        XCTAssertEqual(stats.totalPhotosReviewed, 12)
    }

    func testPhotosPerMinuteUsesElapsedTime() {
        var stats = SessionStats(sessionStartTime: Date().addingTimeInterval(-120))
        stats.photosKept = 3
        stats.photosDeleted = 1

        XCTAssertEqual(stats.photosPerMinute, 2.0, accuracy: 0.2)
    }

    func testFormattedDurationUnderOneMinuteHasSecondsOnly() {
        let stats = SessionStats(sessionStartTime: Date().addingTimeInterval(-10))
        let formatted = stats.formattedDuration

        XCTAssertFalse(formatted.contains("min"))
        XCTAssertTrue(formatted.hasSuffix(" sec"))
    }

    func testFormattedDurationOverOneMinuteIncludesMinutesAndSeconds() {
        let stats = SessionStats(sessionStartTime: Date().addingTimeInterval(-130))
        let formatted = stats.formattedDuration

        XCTAssertTrue(formatted.hasPrefix("2 min "))
        XCTAssertTrue(formatted.hasSuffix(" sec"))
    }
}
