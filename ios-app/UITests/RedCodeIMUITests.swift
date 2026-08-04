import XCTest

final class RedCodeIMUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["RED_CODE_UI_TESTING"] = "1"
        addUIInterruptionMonitor(withDescription: "Notification Permission") { alert in
            if alert.buttons["允许"].exists {
                alert.buttons["允许"].tap()
                return true
            }
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testChatFixtureOpensDetailAndSendsTextMessage() throws {
        launch(with: ["--redcode-ui-testing-chat-fixture"])

        XCTAssertTrue(app.navigationBars["聊天"].waitForExistence(timeout: 5))

        let row = app.buttons["chat.row.ui-room"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let fixtureMessage = app.staticTexts["你好，iOS UI test"]
        if !fixtureMessage.waitForExistence(timeout: 5) {
            row.tap()
        }
        XCTAssertTrue(fixtureMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["👍 1"].waitForExistence(timeout: 5))

        let inputCandidates = [
            app.descendants(matching: .any)["chat.composer.input"],
            app.textFields["输入消息"],
            app.textViews["输入消息"],
        ]
        guard let messageInput = inputCandidates.first(where: { $0.waitForExistence(timeout: 2) }) else {
            XCTFail("未找到聊天输入框")
            return
        }
        messageInput.tap()
        messageInput.typeText("UI test sent message")

        let sendButton = app.buttons["chat.composer.send"].waitForExistence(timeout: 2)
            ? app.buttons["chat.composer.send"]
            : app.buttons["发送"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
        sendButton.tap()

        XCTAssertTrue(app.staticTexts["UI test sent message"].waitForExistence(timeout: 5))
    }

    func testAuthRequiresAgreementAndLogsInWithFixture() throws {
        launch(with: ["--redcode-ui-testing-auth-fixture"])

        fillLoginForm()

        let submitButton = app.buttons["auth.submit"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
        XCTAssertFalse(submitButton.isEnabled)

        app.terminate()
        launch(
            with: ["--redcode-ui-testing-auth-fixture"],
            environment: ["RED_CODE_UI_TESTING_AUTH_AUTO_AGREE": "1"]
        )
        fillLoginForm()

        let agreedSubmitButton = app.buttons["auth.submit"]
        XCTAssertTrue(agreedSubmitButton.waitForExistence(timeout: 5))
        XCTAssertTrue(agreedSubmitButton.isEnabled)

        agreedSubmitButton.tap()
        app.tap()
        XCTAssertTrue(app.navigationBars["聊天"].waitForExistence(timeout: 5))
    }

    private func fillLoginForm() {
        let accountInput = app.textFields["auth.account.input"]
        XCTAssertTrue(accountInput.waitForExistence(timeout: 5))
        accountInput.tap()
        accountInput.typeText("uitest")

        let passwordInput = app.secureTextFields["auth.password.input"]
        XCTAssertTrue(passwordInput.waitForExistence(timeout: 5))
        passwordInput.tap()
        passwordInput.typeText("password123")
        app.navigationBars["RedCode IM"].tap()
    }

    private func launch(with arguments: [String], environment: [String: String] = [:]) {
        app.launchArguments = arguments
        environment.forEach { key, value in
            app.launchEnvironment[key] = value
        }
        app.launch()
    }
}
