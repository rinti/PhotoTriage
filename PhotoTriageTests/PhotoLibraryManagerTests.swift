import XCTest
import Photos
@testable import PhotoTriage

final class PhotoLibraryManagerTests: XCTestCase {
    func testIsAuthorizedIsTrueOnlyForAuthorizedAndLimited() async {
        await MainActor.run {
            let manager = PhotoLibraryManager()

            manager.authorizationStatus = .authorized
            XCTAssertTrue(manager.isAuthorized)

            manager.authorizationStatus = .limited
            XCTAssertTrue(manager.isAuthorized)

            manager.authorizationStatus = .denied
            XCTAssertFalse(manager.isAuthorized)
        }
    }

    func testAuthorizationStatusDescriptionMatchesStatus() async {
        await MainActor.run {
            let manager = PhotoLibraryManager()

            manager.authorizationStatus = .notDetermined
            XCTAssertEqual(manager.authorizationStatusDescription, "Photos access not yet requested")

            manager.authorizationStatus = .restricted
            XCTAssertEqual(manager.authorizationStatusDescription, "Photos access is restricted")

            manager.authorizationStatus = .denied
            XCTAssertEqual(manager.authorizationStatusDescription, "Photos access denied. Please enable in System Settings > Privacy > Photos")

            manager.authorizationStatus = .authorized
            XCTAssertEqual(manager.authorizationStatusDescription, "Full access to Photos library")

            manager.authorizationStatus = .limited
            XCTAssertEqual(manager.authorizationStatusDescription, "Limited access to Photos library")
        }
    }
}
