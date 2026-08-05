import XCTest

@testable import RedCodeCore

final class E2eeDeviceLifecycleTests: XCTestCase {
    private func makeLifecycle(
        mlsApi: FakeMLSApi,
        nowBox: NowBox = NowBox()
    ) -> (E2eeDeviceLifecycle, FakeStateStorage) {
        let storage = FakeStateStorage()
        let lifecycle = E2eeDeviceLifecycle(
            storage: storage,
            mlsApi: mlsApi,
            core: E2eeCommandClient(),
            newDeviceID: { "device-ios-test" },
            nowMillis: { nowBox.value }
        )
        return (lifecycle, storage)
    }

    func testEnsureReadyRegistersDeviceAndPublishesFirstKeyPackage() async throws {
        let mlsApi = FakeMLSApi()
        let (lifecycle, storage) = makeLifecycle(mlsApi: mlsApi)

        let profile = try await lifecycle.ensureReady(
            accountID: "account-a",
            deviceLabel: "iOS Test",
            token: "token"
        )

        XCTAssertEqual(profile.deviceId, "device-ios-test")
        XCTAssertTrue(profile.registered)
        XCTAssertTrue(profile.keyPackagePublished)
        XCTAssertEqual(profile.deviceStatus, "active")
        let registerCount = await mlsApi.registerCount
        XCTAssertEqual(registerCount, 1)
        let publishedTotal = await mlsApi.publishedTotal
        XCTAssertEqual(publishedTotal, 1)
        let inventory = await mlsApi.inventory
        XCTAssertEqual(inventory, 1)
        let state = try await storage.readState(accountID: "account-a")
        XCTAssertFalse(state?.isEmpty ?? true)
    }

    func testTopUpRefillsFromLowWatermarkInBatches() async throws {
        let mlsApi = FakeMLSApi()
        let (lifecycle, _) = makeLifecycle(mlsApi: mlsApi)
        try await lifecycle.ensureReady(accountID: "account-a", deviceLabel: "iOS Test", token: "token")
        await mlsApi.setInventory(0)

        let inserted = try await lifecycle.topUpKeyPackages(accountID: "account-a", token: "token")

        XCTAssertEqual(inserted, 20)
        let publishedTotal = await mlsApi.publishedTotal
        XCTAssertEqual(publishedTotal, 21)
        let inventory = await mlsApi.inventory
        XCTAssertEqual(inventory, 20)
    }

    func testTopUpAfterClaimsRefillsRemainingCapacity() async throws {
        let mlsApi = FakeMLSApi()
        let (lifecycle, _) = makeLifecycle(mlsApi: mlsApi)
        try await lifecycle.ensureReady(accountID: "account-a", deviceLabel: "iOS Test", token: "token")
        await mlsApi.setInventory(5)

        let inserted = try await lifecycle.topUpKeyPackages(accountID: "account-a", token: "token")

        XCTAssertEqual(inserted, 20)
        let publishedTotal = await mlsApi.publishedTotal
        XCTAssertEqual(publishedTotal, 21)
        let inventory = await mlsApi.inventory
        XCTAssertEqual(inventory, 25)
    }

    func testTopUpSkippedWhenInventoryAboveLowWatermark() async throws {
        let mlsApi = FakeMLSApi()
        let (lifecycle, _) = makeLifecycle(mlsApi: mlsApi)
        try await lifecycle.ensureReady(accountID: "account-a", deviceLabel: "iOS Test", token: "token")
        await mlsApi.setInventory(12)

        let inserted = try await lifecycle.topUpKeyPackages(accountID: "account-a", token: "token")

        XCTAssertEqual(inserted, 0)
        let publishedTotal = await mlsApi.publishedTotal
        XCTAssertEqual(publishedTotal, 1)
    }

    func testConcurrentTopUpsShareSingleFlight() async throws {
        let mlsApi = FakeMLSApi()
        let (lifecycle, _) = makeLifecycle(mlsApi: mlsApi)
        try await lifecycle.ensureReady(accountID: "account-a", deviceLabel: "iOS Test", token: "token")
        await mlsApi.setInventory(0)
        await mlsApi.setPublishDelayMillis(50)

        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await lifecycle.topUpKeyPackages(accountID: "account-a", token: "token")
                }
            }
            var values: [Int] = []
            for try await value in group {
                values.append(value)
            }
            return values
        }

        XCTAssertEqual(results, [20, 20, 20, 20, 20])
        let publishCalls = await mlsApi.publishCalls
        XCTAssertEqual(publishCalls, 2)
        let publishedTotal = await mlsApi.publishedTotal
        XCTAssertEqual(publishedTotal, 21)
    }

    func testRevokedDevicePublishFailsThenBacksOffAndRecovers() async throws {
        let mlsApi = FakeMLSApi()
        let nowBox = NowBox(value: 1_000_000)
        let (lifecycle, _) = makeLifecycle(mlsApi: mlsApi, nowBox: nowBox)
        try await lifecycle.ensureReady(accountID: "account-a", deviceLabel: "iOS Test", token: "token")
        await mlsApi.setInventory(0)
        await mlsApi.setPublishShouldFail(true)

        do {
            _ = try await lifecycle.topUpKeyPackages(accountID: "account-a", token: "token")
            XCTFail("撤销设备发布必须失败")
        } catch {
            // 预期失败
        }

        // 退避窗口内不再重试。
        let withinWindow = try await lifecycle.topUpKeyPackages(accountID: "account-a", token: "token")
        XCTAssertEqual(withinWindow, 0)

        // 窗口过后恢复补充。
        nowBox.value += 61_000
        await mlsApi.setPublishShouldFail(false)
        let recovered = try await lifecycle.topUpKeyPackages(accountID: "account-a", token: "token")
        XCTAssertEqual(recovered, 20)
    }

    func testPendingApprovalDeviceCannotTopUp() async throws {
        let mlsApi = FakeMLSApi()
        await mlsApi.setRegisterStatus("pending_approval")
        let (lifecycle, _) = makeLifecycle(mlsApi: mlsApi)

        let profile = try await lifecycle.ensureReady(
            accountID: "account-a",
            deviceLabel: "iOS Test",
            token: "token"
        )

        XCTAssertEqual(profile.deviceStatus, "pending_approval")
        XCTAssertFalse(profile.keyPackagePublished)
        do {
            _ = try await lifecycle.topUpKeyPackages(accountID: "account-a", token: "token")
            XCTFail("待批准设备必须拒绝补充")
        } catch let error as E2eeDeviceNotReadyError {
            XCTAssertFalse(error.message.isEmpty)
        }
    }

    func testMissingStateWithRegisteredProfileRejectsReinitialization() async throws {
        let mlsApi = FakeMLSApi()
        let storage = FakeStateStorage()
        try await storage.writeProfile(
            accountID: "account-a",
            profile: E2eeDeviceProfile(deviceId: "device-x", deviceLabel: "X", registered: true)
        )
        let lifecycle = E2eeDeviceLifecycle(
            storage: storage,
            mlsApi: mlsApi,
            core: E2eeCommandClient(),
            newDeviceID: { "device-ios-test" },
            nowMillis: { 0 }
        )

        do {
            _ = try await lifecycle.ensureReady(accountID: "account-a", deviceLabel: "iOS Test", token: "token")
            XCTFail("已注册设备状态缺失必须拒绝")
        } catch let error as E2eeDeviceNotReadyError {
            XCTAssertFalse(error.message.isEmpty)
        }
    }
}

private final class NowBox: @unchecked Sendable {
    var value: Int64

    init(value: Int64 = 0) {
        self.value = value
    }
}

private actor FakeStateStorage: E2eeDeviceStateStorage {
    private var states: [String: Data] = [:]
    private var profiles: [String: E2eeDeviceProfile] = [:]

    func readState(accountID: String) async throws -> Data? {
        states[accountID]
    }

    func writeState(accountID: String, state: Data) async throws {
        states[accountID] = state
    }

    func readProfile(accountID: String) async throws -> E2eeDeviceProfile? {
        profiles[accountID]
    }

    func writeProfile(accountID: String, profile: E2eeDeviceProfile) async throws {
        profiles[accountID] = profile
    }

    func deleteProfile(accountID: String) async throws {
        profiles.removeValue(forKey: accountID)
    }
}

private actor FakeMLSApi: E2eeMLSApi {
    var registerCount = 0
    var publishCalls = 0
    var publishedTotal = 0
    var inventory = 0
    var registerStatus = "active"
    var publishShouldFail = false
    var publishDelayMillis = 0

    func fetchRootIdentity(userID: String, token: String) async throws -> Data? {
        nil
    }

    func registerDevice(
        deviceID: String,
        deviceLabel: String,
        material: E2eeRegistrationMaterial,
        token: String
    ) async throws -> String {
        registerCount += 1
        return registerStatus
    }

    func publishKeyPackages(deviceID: String, keyPackages: [Data], token: String) async throws -> Int {
        publishCalls += 1
        if publishDelayMillis > 0 {
            try await Task.sleep(for: .milliseconds(publishDelayMillis))
        }
        if publishShouldFail {
            throw NetworkFailureForTest()
        }
        publishedTotal += keyPackages.count
        inventory += keyPackages.count
        return keyPackages.count
    }

    func fetchKeyPackageInventory(deviceID: String, token: String) async throws -> E2eeKeyPackageInventory {
        E2eeKeyPackageInventory(available: inventory, maxAvailable: 100)
    }

    func listDevices(token: String) async throws -> [E2eeDeviceInfo] {
        [E2eeDeviceInfo(id: "device-ios-test", status: "active")]
    }

    func setInventory(_ value: Int) {
        inventory = value
    }

    func setRegisterStatus(_ value: String) {
        registerStatus = value
    }

    func setPublishShouldFail(_ value: Bool) {
        publishShouldFail = value
    }

    func setPublishDelayMillis(_ value: Int) {
        publishDelayMillis = value
    }
}

private struct NetworkFailureForTest: Error {}
