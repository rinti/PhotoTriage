//
//  PhotoTriageUITests.swift
//  PhotoTriageUITests
//
//  Created by Andreas Bernacca on 2026-01-04.
//

import XCTest

final class PhotoTriageUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        throw XCTSkip("Disabled by default to avoid interacting with a real Photos library during automated runs.")
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
