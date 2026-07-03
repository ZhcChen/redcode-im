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

    func testEmailLoginRequestNormalizesEmail() throws {
        let request = try EmailLoginRequest(email: " USER@Example.COM ", password: "secret")

        XCTAssertEqual(request.email, "user@example.com")
        XCTAssertEqual(request.password, "secret")
    }

    func testEmailRegistrationRequestDefaultsNicknameToEmail() throws {
        let request = try EmailRegistrationRequest(
            email: " USER@Example.COM ",
            password: "secret",
            nickname: " "
        )

        XCTAssertEqual(request.email, "user@example.com")
        XCTAssertEqual(request.nickname, "user@example.com")
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
