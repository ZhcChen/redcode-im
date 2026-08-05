import CryptoKit
import Foundation
import Security

public struct E2eeEncryptedAttachment: Equatable, Sendable {
    public let ciphertext: Data; public let nonce: Data; public let dek: Data
}

public enum E2eeAttachmentCrypto {
    public static func attachmentAAD(roomID: String, partKey: String, partPosition: UInt32, objectKey: String) throws -> Data {
        guard !objectKey.isEmpty else { throw E2eeDirectMessageError("E2EE 附件 object key 不能为空") }
        var output = Data("redcode-im/e2ee/attachment/v1\u{0}".utf8)
        for value in [roomID, partKey] {
            guard let uuid = UUID(uuidString: value) else { throw E2eeDirectMessageError("E2EE 附件 UUID 格式无效") }
            var bytes = uuid.uuid; withUnsafeBytes(of: &bytes) { output.append(contentsOf: $0) }
        }
        var position = partPosition.bigEndian; withUnsafeBytes(of: &position) { output.append(contentsOf: $0) }
        output.append(Data(objectKey.utf8)); return output
    }

    public static func encrypt(_ plaintext: Data, aad: Data) throws -> E2eeEncryptedAttachment {
        let dek = try randomData(count: 32); let nonceData = try randomData(count: 12)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.seal(plaintext, using: SymmetricKey(data: dek), nonce: nonce, authenticating: aad)
        return E2eeEncryptedAttachment(ciphertext: sealed.ciphertext + sealed.tag, nonce: nonceData, dek: dek)
    }

    public static func decrypt(_ ciphertextAndTag: Data, aad: Data, nonce: Data, dek: Data) throws -> Data {
        guard nonce.count == 12, dek.count == 32, ciphertextAndTag.count >= 16 else { throw E2eeDirectMessageError("E2EE 附件密钥参数无效") }
        let split = ciphertextAndTag.count - 16
        do {
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertextAndTag.prefix(split), tag: ciphertextAndTag.suffix(16))
            return try AES.GCM.open(box, using: SymmetricKey(data: dek), authenticating: aad)
        } catch { throw E2eeDirectMessageError("E2EE 附件密文校验失败") }
    }

    private static func randomData(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw E2eeDirectMessageError("E2EE 安全随机数生成失败") }
        return data
    }
}

public enum E2eePeripheralPolicy {
    public static let pushPlaceholder = "你收到一条加密消息"
    public static let decryptionFailed = "[无法解密的消息]"
    public static func canIndexLocally(decrypted: Bool, text: String?) -> Bool { decrypted && !(text?.isEmpty ?? true) }
    public static var canUseServerSearch: Bool { false }
    public static var canForwardCiphertext: Bool { false }
    public static func quotePreview(_ decryptedText: String?) -> String { decryptedText?.isEmpty == false ? decryptedText! : "[加密消息]" }
}
