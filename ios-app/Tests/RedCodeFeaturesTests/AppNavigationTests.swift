import XCTest
@testable import RedCodeCore
@testable import RedCodeFeatures

final class AppNavigationTests: XCTestCase {
    func testDefaultTabsMatchFlutterHomeShellOrder() {
        XCTAssertEqual(AppTab.allCases, [.chats, .contacts, .settings])
        XCTAssertEqual(AppTab.allCases.map(\.title), ["聊天", "联系人", "设置"])
    }

    func testSessionStateReportsAuthentication() {
        XCTAssertFalse(AppSessionState.unauthenticated.isAuthenticated)
        XCTAssertTrue(AppSessionState.authenticated(userID: "u1").isAuthenticated)
    }

    func testSessionStateRestoresFromAuthSession() {
        let user = AuthUser(id: "u1", username: "user1")

        XCTAssertEqual(
            AppSessionState.from(session: AuthSession(token: "token", user: user)),
            .authenticated(userID: "u1")
        )
        XCTAssertEqual(
            AppSessionState.from(session: AuthSession(token: "", user: user)),
            .unauthenticated
        )
        XCTAssertEqual(AppSessionState.from(session: nil), .unauthenticated)
    }

    func testRoutesAreHashableForNavigationStackPath() {
        let routes: Set<AppRoute> = [
            .login,
            .chat(roomID: "room-1"),
            .contact(userID: "user-1"),
            .settings,
        ]

        XCTAssertTrue(routes.contains(.chat(roomID: "room-1")))
    }
}
