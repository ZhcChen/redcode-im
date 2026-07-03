import XCTest
@testable import RedCodeCore

final class AuthCoreTests: XCTestCase {
    func testEmailAddressNormalizesBeforeAuthRequests() throws {
        let email = try EmailAddress("  USER@Example.COM  ")

        XCTAssertEqual(email.value, "user@example.com")
        XCTAssertEqual(try EmailAddress.normalize("USER@Example.COM"), "user@example.com")
        XCTAssertEqual(try EmailAddress.normalize("user+tag@example.co.uk"), "user+tag@example.co.uk")
    }

    func testEmailAddressRejectsInvalidInput() {
        XCTAssertThrowsError(try EmailAddress("not-an-email"))
        XCTAssertThrowsError(try EmailAddress("user@example"))
        XCTAssertThrowsError(try EmailAddress("user @example.com"))
        XCTAssertThrowsError(try EmailAddress("user@.com"))
        XCTAssertThrowsError(try EmailAddress("user@domain.c"))
    }

    func testAuthUserDisplayNameMatchesFlutterFallbackOrder() {
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
