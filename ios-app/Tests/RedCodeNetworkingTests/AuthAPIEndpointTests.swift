import XCTest
@testable import RedCodeCore
@testable import RedCodeNetworking

final class AuthAPIEndpointTests: XCTestCase {
    func testAuthEndpointsMatchBackendRoutes() throws {
        let environment = RedCodeEnvironment.simulatorDevelopment()

        XCTAssertEqual(
            try AuthAPIEndpoint.register.url(in: environment).absoluteString,
            "http://127.0.0.1:8010/auth/register"
        )
        XCTAssertEqual(
            try AuthAPIEndpoint.login.url(in: environment).absoluteString,
            "http://127.0.0.1:8010/auth/login"
        )
        XCTAssertEqual(
            try AuthAPIEndpoint.me.url(in: environment).absoluteString,
            "http://127.0.0.1:8010/auth/me"
        )
        XCTAssertEqual(
            try AuthAPIEndpoint.refresh.url(in: environment).absoluteString,
            "http://127.0.0.1:8010/auth/refresh"
        )
        XCTAssertEqual(
            try AuthAPIEndpoint.changePassword.url(in: environment).absoluteString,
            "http://127.0.0.1:8010/users/me/password"
        )
    }

    func testAccountLoginRequestNormalizesUsername() throws {
        let request = try AccountLoginRequest(username: " Red_User-01 ", password: "secret")

        XCTAssertEqual(request.username, "red_user-01")
        XCTAssertEqual(request.password, "secret")
    }

    func testAccountRegistrationRequestDefaultsNicknameToUsername() throws {
        let request = try AccountRegistrationRequest(
            username: " Red_User-01 ",
            password: "secret",
            nickname: " "
        )

        XCTAssertEqual(request.username, "red_user-01")
        XCTAssertEqual(request.nickname, "red_user-01")
    }

    func testAccountRegistrationPayloadDoesNotRequireEmail() throws {
        let request = try AccountRegistrationRequest(username: "red_user", password: "secret")
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: String]
        )

        XCTAssertEqual(json["username"], "red_user")
        XCTAssertEqual(json["password"], "secret")
        XCTAssertNil(json["email"])
    }

    func testRefreshTokenPayloadUsesBackendSnakeCase() throws {
        let request = RefreshTokenRequest(refreshToken: "refresh-token")
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: String]
        )

        XCTAssertEqual(json["refresh_token"], "refresh-token")
        XCTAssertNil(json["refreshToken"])
    }

    func testChangePasswordPayloadUsesBackendSnakeCase() throws {
        let request = ChangePasswordRequest(oldPassword: "old", newPassword: "new")
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: String]
        )

        XCTAssertEqual(json["old_password"], "old")
        XCTAssertEqual(json["new_password"], "new")
    }
}
