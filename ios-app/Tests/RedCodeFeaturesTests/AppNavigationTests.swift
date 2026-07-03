import XCTest
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
