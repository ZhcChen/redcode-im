import XCTest
@testable import RedCodeCore

final class AuthCoreTests: XCTestCase {
    func testAccountNameNormalizesBeforeAuthRequests() throws {
        let account = try AccountName("  Red_User-01  ")

        XCTAssertEqual(account.value, "red_user-01")
        XCTAssertEqual(try AccountName.normalize("Red.User_02"), "red.user_02")
    }

    func testAccountNameRejectsInvalidInput() {
        XCTAssertThrowsError(try AccountName("ab"))
        XCTAssertThrowsError(try AccountName("user@example.com"))
        XCTAssertThrowsError(try AccountName("user name"))
        XCTAssertThrowsError(try AccountName("123456789012345678901"))
    }

    func testAuthUserDisplayNameMatchesAccountFallbackOrder() {
        let nicknameUser = AuthUser(
            id: "u1",
            username: "user1",
            email: "user@example.com",
            nickname: "小红"
        )
        let emailUser = AuthUser(id: "u2", username: "user2", email: "user2@example.com")
        let usernameUser = AuthUser(id: "u3", username: "user3")

        XCTAssertEqual(nicknameUser.displayName, "小红")
        XCTAssertEqual(emailUser.displayName, "user2@example.com")
        XCTAssertEqual(usernameUser.displayName, "user3")
    }

    func testAuthSessionRequiresNonEmptyToken() {
        let user = AuthUser(id: "u1", username: "user1")

        XCTAssertTrue(AuthSession(token: "token", user: user).isValid)
        XCTAssertFalse(AuthSession(token: "   ", user: user).isValid)
    }
}
