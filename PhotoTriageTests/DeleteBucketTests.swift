import XCTest
@testable import PhotoTriage

final class DeleteBucketTests: XCTestCase {
    func testRestoreFromSessionLoadsUniqueIdentifiers() async {
        await MainActor.run {
            let bucket = DeleteBucket()
            bucket.restoreFromSession(["a", "b", "b"])

            XCTAssertEqual(bucket.count, 2)
            XCTAssertFalse(bucket.isEmpty)
            XCTAssertTrue(bucket.isMarkedByIdentifier("a"))
            XCTAssertTrue(bucket.isMarkedByIdentifier("b"))
        }
    }

    func testRestoreByIdentifierRemovesOnlyRequestedItem() async {
        await MainActor.run {
            let bucket = DeleteBucket()
            bucket.restoreFromSession(["a", "b", "c"])
            bucket.restoreByIdentifier("b")

            XCTAssertEqual(bucket.count, 2)
            XCTAssertFalse(bucket.isMarkedByIdentifier("b"))
            XCTAssertTrue(bucket.isMarkedByIdentifier("a"))
            XCTAssertTrue(bucket.isMarkedByIdentifier("c"))
        }
    }

    func testClearRemovesAllItems() async {
        await MainActor.run {
            let bucket = DeleteBucket()
            bucket.restoreFromSession(["a", "b"])
            bucket.clear()

            XCTAssertEqual(bucket.count, 0)
            XCTAssertTrue(bucket.isEmpty)
        }
    }
}
