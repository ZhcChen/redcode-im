import XCTest

final class RedCodeIMUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--redcode-ui-testing-chat-fixture"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testChatFixtureOpensDetailAndSendsTextMessage() throws {
        XCTAssertTrue(app.navigationBars["聊天"].waitForExistence(timeout: 5))

        let row = app.buttons["chat.row.ui-room"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.otherElements["chat.detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["你好，iOS UI test"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["👍 1"].waitForExistence(timeout: 5))

        let input = app.textFields["chat.composer.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("UI test sent message")

        let sendButton = app.buttons["chat.composer.send"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
        sendButton.tap()

        XCTAssertTrue(app.staticTexts["UI test sent message"].waitForExistence(timeout: 5))
    }
}
