import XCTest

@MainActor
final class SubscriptionImportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPasteSyntheticURIImportsAndReturnsToHome() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ROUTEVA_UI_TEST_DATABASE"] = UUID().uuidString
        app.launchEnvironment["ROUTEVA_UI_TEST_CLIPBOARD"] =
            "trojan://synthetic-ui-secret@ui.example.invalid:443?security=tls#TEST-UI"
        app.launch()

        let addButton = app.buttons["home.addSubscription"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let pasteButton = app.buttons["subscription.pasteClipboard"]
        if !pasteButton.waitForExistence(timeout: 5), addButton.exists, addButton.isHittable {
            addButton.tap()
        }
        XCTAssertTrue(pasteButton.waitForExistence(timeout: 5))
        pasteButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["home.importConfirmation"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["TEST-UI"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Home after synthetic subscription import"
        attachment.lifetime = .keepAlways
        add(attachment)

        let toastGone = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.descendants(matching: .any)["home.importConfirmation"]
        )
        wait(for: [toastGone], timeout: 5)
        let locationButton = app.buttons["home.location"]
        XCTAssertTrue(locationButton.waitForExistence(timeout: 5))

        let settledAttachment = XCTAttachment(screenshot: app.screenshot())
        settledAttachment.name = "Localized refreshed Home"
        settledAttachment.lifetime = .keepAlways
        add(settledAttachment)

        locationButton.tap()

        let firstNode = app.buttons["location.node.0"]
        XCTAssertTrue(firstNode.waitForExistence(timeout: 5))
        let locationAttachment = XCTAttachment(screenshot: app.screenshot())
        locationAttachment.name = "Location node selection"
        locationAttachment.lifetime = .keepAlways
        add(locationAttachment)
        firstNode.tap()
        XCTAssertTrue(locationButton.waitForExistence(timeout: 5))

        let connectControl = app.buttons["home.connect"]
        XCTAssertTrue(connectControl.waitForExistence(timeout: 5))
        connectControl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(
                forDuration: 0.1,
                thenDragTo: connectControl.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)
                )
            )

        let connectionNotice = app.descendants(matching: .any)["home.connectionFailureToast"]
        XCTAssertTrue(connectionNotice.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["VPN connection testing requires a signed build on a physical iPhone."]
                .exists
        )
    }

    /// Opt-in local verification for a developer-owned subscription already on
    /// the Simulator pasteboard. The private value never enters source, launch
    /// arguments, attachments, or XCTest output.
    func testPastePrivateSimulatorClipboardImportsWhenOptedIn() throws {
        guard ProcessInfo.processInfo.environment["ROUTEVA_PRIVATE_SUBSCRIPTION_UI_TEST"] == "1"
        else { throw XCTSkip("Private Simulator clipboard test is opt-in.") }

        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Paste Permission") { alert in
            let allowPaste = alert.buttons["Allow Paste"]
            if allowPaste.exists {
                allowPaste.tap()
                return true
            }
            let localizedAllowPaste = alert.buttons["允许粘贴"]
            if localizedAllowPaste.exists {
                localizedAllowPaste.tap()
                return true
            }
            return false
        }
        app.launch()

        let addButton = app.buttons["home.addSubscription"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 8))
        addButton.tap()

        let pasteButton = app.buttons["subscription.pasteClipboard"]
        XCTAssertTrue(pasteButton.waitForExistence(timeout: 5))
        pasteButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["home.importConfirmation"]
                .waitForExistence(timeout: 30)
        )
        XCTAssertTrue(app.buttons["home.location"].waitForExistence(timeout: 8))
    }
}
