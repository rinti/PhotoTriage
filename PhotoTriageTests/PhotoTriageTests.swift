import XCTest
@testable import PhotoTriage

final class SessionManagerTests: XCTestCase {
    private let sessionKey = "com.phototriage.savedSession"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        super.tearDown()
    }

    func testInitWithoutSavedSessionStartsInactive() async {
        await MainActor.run {
            let manager = SessionManager()
            XCTAssertFalse(manager.hasActiveSession)
            XCTAssertNil(manager.sessionData)
        }
    }

    func testSaveAndLoadSessionPersistsAllFields() async {
        let expected = makeSessionData()
        await MainActor.run {
            let manager = SessionManager()
            manager.saveSession(expected)

            XCTAssertTrue(manager.hasActiveSession)
            XCTAssertNotNil(manager.sessionData)

            let loaded = manager.loadSession()
            XCTAssertNotNil(loaded)
            assertSession(loaded, matches: expected)
        }
    }

    func testInitWithCorruptedSavedDataClearsSession() async {
        UserDefaults.standard.set(Data("invalid-json".utf8), forKey: sessionKey)

        await MainActor.run {
            let manager = SessionManager()
            XCTAssertFalse(manager.hasActiveSession)
            XCTAssertNil(manager.sessionData)
            XCTAssertNil(UserDefaults.standard.data(forKey: sessionKey))
            XCTAssertNil(manager.loadSession())
        }
    }

    func testValidateSessionMatchesAssetCount() async {
        let session = makeSessionData(totalAssetCount: 42)
        await MainActor.run {
            let manager = SessionManager()
            manager.saveSession(session)

            XCTAssertTrue(manager.validateSession(currentAssetCount: 42))
            XCTAssertFalse(manager.validateSession(currentAssetCount: 41))
        }
    }

    private func makeSessionData(totalAssetCount: Int = 20) -> SessionData {
        SessionData(
            sortOrder: .newestFirst,
            currentIndex: 3,
            visitedIndices: [0, 1, 2],
            markedAssets: ["asset-1", "asset-2"],
            totalAssetCount: totalAssetCount,
            savedAt: Date(timeIntervalSince1970: 1_735_000_000),
            albumIdentifier: "album-123",
            dateFrom: Date(timeIntervalSince1970: 1_700_000_000),
            dateTo: Date(timeIntervalSince1970: 1_710_000_000),
            location: "San Francisco"
        )
    }

    private func assertSession(_ actual: SessionData?, matches expected: SessionData) {
        XCTAssertEqual(actual?.sortOrder, expected.sortOrder)
        XCTAssertEqual(actual?.currentIndex, expected.currentIndex)
        XCTAssertEqual(actual?.visitedIndices, expected.visitedIndices)
        XCTAssertEqual(actual?.markedAssets, expected.markedAssets)
        XCTAssertEqual(actual?.totalAssetCount, expected.totalAssetCount)
        XCTAssertEqual(actual?.savedAt, expected.savedAt)
        XCTAssertEqual(actual?.albumIdentifier, expected.albumIdentifier)
        XCTAssertEqual(actual?.dateFrom, expected.dateFrom)
        XCTAssertEqual(actual?.dateTo, expected.dateTo)
        XCTAssertEqual(actual?.location, expected.location)
    }
}
