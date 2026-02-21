import XCTest
@testable import PhotoTriage

final class SkippedPhotosManagerTests: XCTestCase {
    private let storageKey = "com.phototriage.skippedPhotos"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    func testInitLoadsPersistedSkippedIds() async throws {
        let expected: Set<String> = ["a", "b", "c"]
        let encoded = try JSONEncoder().encode(expected)
        UserDefaults.standard.set(encoded, forKey: storageKey)

        await MainActor.run {
            let manager = SkippedPhotosManager()
            XCTAssertEqual(manager.skippedIds, expected)
            XCTAssertEqual(manager.count, expected.count)
        }
    }

    func testClearAllEmptiesStateAndPersistsEmptySet() async throws {
        let initial: Set<String> = ["a", "b"]
        let encoded = try JSONEncoder().encode(initial)
        UserDefaults.standard.set(encoded, forKey: storageKey)
        await MainActor.run {
            let manager = SkippedPhotosManager()
            manager.clearAll()
            XCTAssertEqual(manager.count, 0)
            XCTAssertTrue(manager.skippedIds.isEmpty)
        }

        let data = UserDefaults.standard.data(forKey: storageKey)
        XCTAssertNotNil(data)
        let decoded = try JSONDecoder().decode(Set<String>.self, from: data ?? Data())
        XCTAssertTrue(decoded.isEmpty)
    }
}
