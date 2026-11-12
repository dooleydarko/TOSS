import XCTest

final class TossFlowTests: XCTestCase {
    func testLightThemeSettingsAvailable() {
        let app = XCUIApplication()
        app.launchArguments = ["-toss.appearance", "Light"]
        app.launch()
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "settings.appearance").firstMatch.waitForExistence(timeout: 8))
    }

    func testStarterToEditableReviewAndTossScreen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-toss.appearance", "Dark"]
        app.launch()
        let discover = app.tabBars.buttons["Discover"]
        XCTAssertTrue(discover.waitForExistence(timeout: 10))
        discover.tap()
        let starter = app.buttons["starter.website"]
        XCTAssertTrue(starter.waitForExistence(timeout: 8))
        starter.tap()
        let useStarter = app.buttons["starter.use"]
        if !useStarter.isHittable { app.swipeUp() }
        XCTAssertTrue(useStarter.waitForExistence(timeout: 8))
        useStarter.tap()
        let plainText = app.segmentedControls.buttons["Text"]
        XCTAssertTrue(plainText.waitForExistence(timeout: 8))
        plainText.tap()
        XCTAssertTrue(app.buttons["Export handoff"].exists)
        let edit = app.buttons["review.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        edit.tap()
        let title = app.textFields["review.edit.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        title.tap()
        title.typeText(" test")
        app.buttons["Save"].tap()
        let ready = app.buttons["review.ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 8))
        ready.tap()
        XCTAssertTrue(app.otherElements["toss.ball"].waitForExistence(timeout: 8) ||
                      app.images["toss.ball"].exists || app.staticTexts["Handoff ball"].exists ||
                      app.buttons["Send handoff"].exists)
        // Never send to a discovered or actual receiver from simulator UI tests.
    }
}
