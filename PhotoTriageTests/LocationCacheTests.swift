import XCTest
@testable import PhotoTriage

final class LocationCacheTests: XCTestCase {
    private let cacheKey = "com.phototriage.locationCache"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        super.tearDown()
    }

    func testInitLoadsPersistedCache() async throws {
        let persisted = ["asset-1": "San Francisco, California, United States"]
        let encoded = try JSONEncoder().encode(persisted)
        UserDefaults.standard.set(encoded, forKey: cacheKey)

        let loaded = await MainActor.run { () -> String? in
            let cache = LocationCache()
            return cache.getLocation(for: "asset-1")
        }

        XCTAssertEqual(loaded, persisted["asset-1"])
    }

    func testMatchesQueryUsesCaseInsensitiveContains() async throws {
        let persisted = ["asset-1": "San Francisco, California, United States"]
        let encoded = try JSONEncoder().encode(persisted)
        UserDefaults.standard.set(encoded, forKey: cacheKey)
        await MainActor.run {
            let cache = LocationCache()
            XCTAssertTrue(cache.matchesQuery("francisco", assetId: "asset-1"))
            XCTAssertTrue(cache.matchesQuery("UNITED", assetId: "asset-1"))
            XCTAssertFalse(cache.matchesQuery("tokyo", assetId: "asset-1"))
            XCTAssertFalse(cache.matchesQuery("francisco", assetId: "missing"))
        }
    }

    func testClearCacheRemovesInMemoryAndStorage() async throws {
        let persisted = ["asset-1": "Rome, Lazio, Italy"]
        let encoded = try JSONEncoder().encode(persisted)
        UserDefaults.standard.set(encoded, forKey: cacheKey)
        let cachedAfterClear = await MainActor.run { () -> String? in
            let cache = LocationCache()
            cache.clearCache()
            return cache.getLocation(for: "asset-1")
        }

        XCTAssertNil(cachedAfterClear)
        XCTAssertNil(UserDefaults.standard.data(forKey: cacheKey))
    }
}
