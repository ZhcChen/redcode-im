import Foundation
import RedCodeE2EECBridge

/// 与 H5 `E2eeCommandOperation` 对齐的共享核心命令。
enum E2eeCommandOperation: UInt8 {
    case initialize = 1
    case generateKeyPackage = 2
    case createGroup = 3
    case addMember = 4
    case joinGroup = 5
    case encrypt = 6
    case decrypt = 7
    case publicMaterial = 8
    case processCommit = 9
    case removeMember = 10
    case signDeviceApproval = 11
    case listMembers = 12
}

struct E2eeCommandError: Error, Equatable {
    let message: String
}

struct E2eeCommandResult {
    let fields: [Data]

    func field(_ index: Int) throws -> Data {
        guard fields.indices.contains(index) else {
            throw E2eeCommandError(message: "E2EE 核心响应字段缺失")
        }
        return fields[index]
    }

    func epoch(_ index: Int) throws -> UInt64 {
        let bytes = try field(index)
        guard bytes.count == 8 else {
            throw E2eeCommandError(message: "E2EE 核心 epoch 格式无效")
        }
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self).bigEndian }
    }
}

/// e2ee-core C ABI 的 Swift 封装：RCCQ/RCCR 命令编解码 + 状态工具。
public struct E2eeCommandClient {
    public static let protocolVersion = rc_e2ee_protocol_version()

    public init() {}

    public func newProtocolState() throws -> Data {
        let capacity = Int(rc_e2ee_state_new(nil, 0))
        var state = Data(count: capacity)
        let written = state.withUnsafeMutableBytes { buffer in
            rc_e2ee_state_new(buffer.bindMemory(to: UInt8.self).baseAddress, capacity)
        }
        guard written == capacity else {
            throw E2eeCommandError(message: "E2EE 核心状态初始化长度不一致")
        }
        return state
    }

    public func validateProtocolState(_ state: Data) -> Bool {
        state.withUnsafeBytes { buffer in
            rc_e2ee_state_validate(buffer.bindMemory(to: UInt8.self).baseAddress, state.count) == 1
        }
    }

    func execute(operation: E2eeCommandOperation, fields: [Data]) throws -> E2eeCommandResult {
        guard fields.count <= 8 else {
            throw E2eeCommandError(message: "E2EE 核心命令字段过多")
        }
        var request = Data("RCCQ".utf8)
        request.append(contentsOf: [0, 1, operation.rawValue, UInt8(fields.count)])
        for field in fields {
            var length = UInt32(field.count).bigEndian
            withUnsafeBytes(of: &length) { request.append(contentsOf: $0) }
            request.append(field)
        }

        let response = try executeRaw(request)
        return try Self.decodeResponse(response)
    }

    func initialize(deviceIdentity: String) throws -> E2eeCommandResult {
        try execute(operation: .initialize, fields: [Data(deviceIdentity.utf8)])
    }

    func createGroup(state: Data, roomID: String) throws -> E2eeCommandResult {
        try execute(operation: .createGroup, fields: [state, Data(roomID.utf8)])
    }

    func encrypt(state: Data, roomID: String, plaintext: Data) throws -> E2eeCommandResult {
        try execute(operation: .encrypt, fields: [state, Data(roomID.utf8), plaintext])
    }

    func decrypt(state: Data, roomID: String, ciphertext: Data) throws -> E2eeCommandResult {
        try execute(operation: .decrypt, fields: [state, Data(roomID.utf8), ciphertext])
    }

    /// 直接执行一段 RCCQ 原始命令（测试与高级调用点使用）。
    func executeRaw(_ request: Data) throws -> Data {
        var output: UnsafeMutablePointer<UInt8>?
        var outputLength: size_t = 0
        let status = request.withUnsafeBytes { buffer in
            rc_e2ee_command_execute(
                buffer.bindMemory(to: UInt8.self).baseAddress,
                request.count,
                &output,
                &outputLength
            )
        }
        guard status == 0, let output else {
            throw E2eeCommandError(message: "E2EE 核心命令调用失败")
        }
        defer { rc_e2ee_command_free(output, outputLength) }
        return Data(bytes: output, count: outputLength)
    }

    private static func decodeResponse(_ response: Data) throws -> E2eeCommandResult {
        guard response.count >= 8,
              response.prefix(4) == Data("RCCR".utf8),
              response[4] == 0,
              response[5] == 1
        else {
            throw E2eeCommandError(message: "E2EE 核心响应头无效")
        }
        let status = response[6]
        let fieldCount = Int(response[7])
        var offset = 8
        var fields: [Data] = []
        fields.reserveCapacity(fieldCount)
        for _ in 0..<fieldCount {
            guard offset + 4 <= response.count else {
                throw E2eeCommandError(message: "E2EE 核心响应字段截断")
            }
            let length = UInt32(
                response[offset..<offset + 4].withUnsafeBytes {
                    $0.loadUnaligned(as: UInt32.self)
                }
            ).bigEndian
            offset += 4
            let end = offset + Int(length)
            guard end <= response.count else {
                throw E2eeCommandError(message: "E2EE 核心响应字段超长")
            }
            fields.append(response.subdata(in: offset..<end))
            offset = end
        }
        guard status == 0 else {
            let message = fields.first.flatMap { String(data: $0, encoding: .utf8) }
                ?? "未知 E2EE 命令错误"
            throw E2eeCommandError(message: message)
        }
        return E2eeCommandResult(fields: fields)
    }
}
