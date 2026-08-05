package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod
import com.redcode.im.androidapp.network.NetworkFailure
import java.security.MessageDigest
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.Base64
import java.util.UUID
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class E2eeKeyPackageInventory(
    val available: Int,
    @SerialName("max_available") val maxAvailable: Int,
)

@Serializable
data class E2eeDeviceInfo(
    val id: String,
    @SerialName("device_label") val deviceLabel: String = "",
    @SerialName("protocol_version") val protocolVersion: Int = 0,
    @SerialName("credential_fingerprint") val credentialFingerprint: String = "",
    val status: String = "",
)

data class E2eeRootIdentity(
    val userId: String,
    val publicKey: ByteArray,
    val fingerprint: ByteArray,
    val protocolVersion: Int,
)

data class E2eePeerDevice(
    val id: String,
    val protocolVersion: Int,
    val credentialFingerprint: ByteArray,
)

data class E2eeRoomMemberDevices(val userId: String, val devices: List<E2eePeerDevice>)

data class E2eeRoomEpoch(val membershipRevision: Long, val activeEpoch: Long, val status: String)

data class E2eeClaimedKeyPackage(val id: String, val deviceId: String, val keyPackage: ByteArray)

data class E2eeControlMessage(
    val id: String,
    val epoch: Long,
    val membershipRevision: Long,
    val contentType: String,
    val envelope: ByteArray,
    val sequenceNo: Long,
)

data class E2eeOutgoingControlMessage(
    val roomId: String,
    val messageId: String,
    val epoch: Long,
    val membershipRevision: Long,
    val senderDeviceId: String,
    val contentType: String,
    val envelope: ByteArray,
    val recipientDeviceId: String? = null,
)

data class E2eeEncryptedMessageRequest(
    val roomId: String,
    val senderDeviceId: String,
    val epoch: Long,
    val ciphertext: ByteArray,
    val idempotencyKey: String,
    val controlMessageId: String,
)

/** e2ee-core MLS 服务端契约（与 H5 e2ee-mls-api-service 对齐）。 */
interface E2eeMlsApi {
    suspend fun fetchRootIdentity(userId: String, token: String): ByteArray

    suspend fun registerDevice(
        deviceId: String,
        deviceLabel: String,
        material: E2eeRegistrationMaterial,
        token: String,
    ): String

    suspend fun publishKeyPackages(deviceId: String, keyPackages: List<ByteArray>, token: String): Int

    suspend fun fetchKeyPackageInventory(deviceId: String, token: String): E2eeKeyPackageInventory

    suspend fun listDevices(token: String): List<E2eeDeviceInfo>

    suspend fun fetchIdentity(userId: String, token: String): E2eeRootIdentity =
        throw UnsupportedOperationException("N4 E2EE API 未实现")

    suspend fun listRoomMemberDevices(roomId: String, token: String): List<E2eeRoomMemberDevices> =
        throw UnsupportedOperationException("N4 E2EE API 未实现")

    suspend fun getRoomEpoch(roomId: String, token: String): E2eeRoomEpoch =
        throw UnsupportedOperationException("N4 E2EE API 未实现")

    suspend fun claimKeyPackage(roomId: String, consumerDeviceId: String, targetDeviceId: String, token: String): E2eeClaimedKeyPackage =
        throw UnsupportedOperationException("N4 E2EE API 未实现")

    suspend fun submitControlMessage(message: E2eeOutgoingControlMessage, token: String): Unit =
        throw UnsupportedOperationException("N4 E2EE API 未实现")

    suspend fun listControlMessages(roomId: String, deviceId: String, afterSequence: Long, token: String): List<E2eeControlMessage> =
        throw UnsupportedOperationException("N4 E2EE API 未实现")

    suspend fun consumeControlMessage(roomId: String, messageId: String, deviceId: String, token: String): Unit =
        throw UnsupportedOperationException("N4 E2EE API 未实现")

    suspend fun sendEncryptedMessage(message: E2eeEncryptedMessageRequest, token: String): String =
        throw UnsupportedOperationException("N4 E2EE API 未实现")
}

class HttpE2eeMlsApi(
    private val apiClient: APIClient,
    private val platform: String = "android",
    private val version: String = "2.0.0",
    private val build: String = "dev",
) : E2eeMlsApi {
    override suspend fun fetchRootIdentity(userId: String, token: String): ByteArray {
        val response = apiClient.get<E2eeRootIdentityResponse>(E2eeMlsEndpoint.identity(userId), bearerToken = token)
        return Base64.getDecoder().decode(response.publicKey)
    }

    override suspend fun registerDevice(
        deviceId: String,
        deviceLabel: String,
        material: E2eeRegistrationMaterial,
        token: String,
    ): String {
        val response =
            apiClient.post<E2eeRegisterDeviceRequest, E2eeRegisterDeviceResponse>(
                E2eeMlsEndpoint.devices,
                E2eeRegisterDeviceRequest(
                    deviceId = deviceId,
                    deviceLabel = deviceLabel,
                    rootPublicKey = encode(material.rootPublicKey),
                    rootFingerprint = encode(material.rootFingerprint),
                    credential = encode(material.credential),
                    credentialFingerprint = encode(material.credentialFingerprint),
                    approvalPublicKey = encode(material.approvalPublicKey),
                    protocolVersion = 1,
                    clientPlatform = platform,
                    clientVersion = version,
                    clientBuild = build,
                ),
                bearerToken = token,
            )
        return response.status
    }

    override suspend fun publishKeyPackages(
        deviceId: String,
        keyPackages: List<ByteArray>,
        token: String,
    ): Int {
        if (keyPackages.isEmpty()) throw E2eeCommandException("E2EE KeyPackage 批次不能为空")
        if (keyPackages.size > 100) throw E2eeCommandException("E2EE KeyPackage 单批最多 100 个")
        val expiresAt = Instant.now().plus(7, ChronoUnit.DAYS).toString()
        val packages =
            keyPackages.map { keyPackage ->
                E2eeKeyPackagePayload(
                    id = UUID.randomUUID().toString(),
                    packageRef = encode(sha256(keyPackage)),
                    keyPackage = encode(keyPackage),
                    protocolVersion = 1,
                    expiresAt = expiresAt,
                )
            }
        val response =
            apiClient.post<E2eePublishKeyPackagesRequest, E2eePublishKeyPackagesResponse>(
                E2eeMlsEndpoint.publishKeyPackages(deviceId),
                E2eePublishKeyPackagesRequest(packages),
                bearerToken = token,
            )
        return response.inserted
    }

    override suspend fun fetchKeyPackageInventory(deviceId: String, token: String): E2eeKeyPackageInventory =
        apiClient.get(
            E2eeMlsEndpoint.keyPackageInventory(deviceId),
            bearerToken = token,
        )

    override suspend fun listDevices(token: String): List<E2eeDeviceInfo> =
        apiClient.get(
            E2eeMlsEndpoint.listDevices,
            bearerToken = token,
        )

    override suspend fun fetchIdentity(userId: String, token: String): E2eeRootIdentity {
        val response = apiClient.get<E2eeRootIdentityResponse>(E2eeMlsEndpoint.identity(userId), bearerToken = token)
        if (response.userId != userId || response.protocolVersion != 1) {
            throw E2eeCommandException("E2EE 根身份响应格式无效")
        }
        return E2eeRootIdentity(response.userId, decode(response.publicKey), decode(response.fingerprint), response.protocolVersion)
    }

    override suspend fun listRoomMemberDevices(roomId: String, token: String): List<E2eeRoomMemberDevices> =
        apiClient.get<List<E2eeRoomMemberDevicesResponse>>(E2eeMlsEndpoint.roomMembers(roomId), bearerToken = token)
            .map { member ->
                E2eeRoomMemberDevices(
                    member.userId,
                    member.devices.map { E2eePeerDevice(it.id, it.protocolVersion, decode(it.credentialFingerprint)) },
                )
            }

    override suspend fun getRoomEpoch(roomId: String, token: String): E2eeRoomEpoch {
        val response = apiClient.get<E2eeRoomEpochResponse>(E2eeMlsEndpoint.roomEpoch(roomId), bearerToken = token)
        return E2eeRoomEpoch(response.membershipRevision, response.activeEpoch, response.status)
    }

    override suspend fun claimKeyPackage(roomId: String, consumerDeviceId: String, targetDeviceId: String, token: String): E2eeClaimedKeyPackage {
        val response = apiClient.post<E2eeClaimKeyPackageRequest, E2eeClaimKeyPackageResponse>(
            E2eeMlsEndpoint.claimKeyPackage(targetDeviceId),
            E2eeClaimKeyPackageRequest(roomId, consumerDeviceId),
            bearerToken = token,
        )
        return E2eeClaimedKeyPackage(response.id, response.deviceId, decode(response.keyPackage))
    }

    override suspend fun submitControlMessage(message: E2eeOutgoingControlMessage, token: String) {
        apiClient.postNoResponse(
            E2eeMlsEndpoint.controlMessages(message.roomId),
            E2eeSubmitControlRequest(
                message.messageId, message.epoch, message.membershipRevision, message.senderDeviceId,
                message.recipientDeviceId, message.contentType, encode(message.envelope), message.messageId,
            ),
            bearerToken = token,
        )
    }

    override suspend fun listControlMessages(roomId: String, deviceId: String, afterSequence: Long, token: String): List<E2eeControlMessage> =
        apiClient.get<List<E2eeControlMessageResponse>>(
            E2eeMlsEndpoint.controlMessages(roomId, deviceId, afterSequence), bearerToken = token,
        ).map { E2eeControlMessage(it.id, it.epoch, it.membershipRevision, it.contentType, decode(it.envelope), it.sequenceNo) }

    override suspend fun consumeControlMessage(roomId: String, messageId: String, deviceId: String, token: String) {
        apiClient.postNoResponse(
            E2eeMlsEndpoint.consumeControl(roomId, messageId),
            E2eeConsumeControlRequest(deviceId), bearerToken = token,
        )
    }

    override suspend fun sendEncryptedMessage(message: E2eeEncryptedMessageRequest, token: String): String {
        val response = apiClient.post<E2eeSendEncryptedRequest, E2eeSendEncryptedResponse>(
            E2eeMlsEndpoint.encryptedMessages(message.roomId),
            E2eeSendEncryptedRequest(
                encode(message.ciphertext),
                E2eeEncryptionMetadata(
                    epoch = message.epoch,
                    senderDeviceId = message.senderDeviceId,
                    controlMessageId = message.controlMessageId,
                ),
                message.idempotencyKey,
            ),
            bearerToken = token,
        )
        return response.message.id
    }

    private fun encode(bytes: ByteArray): String =
        Base64.getEncoder().encodeToString(bytes)

    private fun decode(value: String): ByteArray = Base64.getDecoder().decode(value)

    private fun sha256(bytes: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(bytes)
}

/** 与 H5 fetchRootIdentity 的 404 语义一致：无根身份返回 null。 */
suspend fun E2eeMlsApi.fetchRootIdentityOrNull(userId: String, token: String): ByteArray? =
    try {
        fetchRootIdentity(userId, token)
    } catch (e: NetworkFailure) {
        if (e.statusCode == 404) null else throw e
    }

object E2eeMlsEndpoint {
    val devices = APIEndpoint(HTTPMethod.POST, "/e2ee/mls/devices")

    val listDevices = APIEndpoint(HTTPMethod.GET, "/e2ee/mls/devices")

    fun identity(userId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.GET, "/e2ee/mls/identities/${urlEncode(userId)}")

    fun keyPackageInventory(deviceId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.GET, "/e2ee/mls/devices/$deviceId/key-packages")

    fun publishKeyPackages(deviceId: String): APIEndpoint =
        APIEndpoint(HTTPMethod.POST, "/e2ee/mls/devices/$deviceId/key-packages")

    fun roomMembers(roomId: String) = APIEndpoint(HTTPMethod.GET, "/rooms/$roomId/e2ee/members")
    fun roomEpoch(roomId: String) = APIEndpoint(HTTPMethod.GET, "/rooms/$roomId/e2ee/epoch")
    fun claimKeyPackage(deviceId: String) = APIEndpoint(HTTPMethod.POST, "/e2ee/mls/devices/$deviceId/key-packages/claim")
    fun controlMessages(roomId: String) = APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/e2ee/control-messages")
    fun controlMessages(roomId: String, deviceId: String, after: Long) = APIEndpoint(
        HTTPMethod.GET,
        "/rooms/$roomId/e2ee/control-messages?device_id=${urlEncode(deviceId)}&after_sequence=$after&limit=100",
    )
    fun consumeControl(roomId: String, messageId: String) = APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/e2ee/control-messages/$messageId/consume")
    fun encryptedMessages(roomId: String) = APIEndpoint(HTTPMethod.POST, "/rooms/$roomId/messages/encrypted")

    private fun urlEncode(value: String): String =
        java.net.URLEncoder.encode(value, Charsets.UTF_8.name()).replace("+", "%20")
}

@Serializable
private data class E2eeRootIdentityResponse(
    @SerialName("user_id") val userId: String = "",
    @SerialName("root_public_key") val publicKey: String,
    @SerialName("root_fingerprint") val fingerprint: String = "",
    @SerialName("protocol_version") val protocolVersion: Int = 0,
)

@Serializable private data class E2eePeerDeviceResponse(val id: String, @SerialName("protocol_version") val protocolVersion: Int, @SerialName("credential_fingerprint") val credentialFingerprint: String)
@Serializable private data class E2eeRoomMemberDevicesResponse(@SerialName("user_id") val userId: String, val devices: List<E2eePeerDeviceResponse>)
@Serializable private data class E2eeRoomEpochResponse(@SerialName("membership_revision") val membershipRevision: Long, @SerialName("active_epoch") val activeEpoch: Long, val status: String)
@Serializable private data class E2eeClaimKeyPackageRequest(@SerialName("room_id") val roomId: String, @SerialName("consumer_device_id") val consumerDeviceId: String)
@Serializable private data class E2eeClaimKeyPackageResponse(val id: String, @SerialName("device_id") val deviceId: String, @SerialName("key_package") val keyPackage: String)
@Serializable private data class E2eeSubmitControlRequest(val id: String, val epoch: Long, @SerialName("membership_revision") val membershipRevision: Long, @SerialName("sender_device_id") val senderDeviceId: String, @SerialName("recipient_device_id") val recipientDeviceId: String?, @SerialName("content_type") val contentType: String, val envelope: String, @SerialName("idempotency_key") val idempotencyKey: String)
@Serializable private data class E2eeControlMessageResponse(val id: String, val epoch: Long, @SerialName("membership_revision") val membershipRevision: Long, @SerialName("content_type") val contentType: String, val envelope: String, @SerialName("sequence_no") val sequenceNo: Long)
@Serializable private data class E2eeConsumeControlRequest(@SerialName("device_id") val deviceId: String)
@Serializable private data class E2eeEncryptionMetadata(val protocol: String = "mls", val version: Int = 1, val epoch: Long, @SerialName("sender_device_id") val senderDeviceId: String, @SerialName("content_type") val contentType: String = "application", @SerialName("control_message_id") val controlMessageId: String)
@Serializable private data class E2eeSendEncryptedRequest(@SerialName("encrypted_content") val encryptedContent: String, @SerialName("encryption_metadata") val encryptionMetadata: E2eeEncryptionMetadata, @SerialName("idempotency_key") val idempotencyKey: String)
@Serializable private data class E2eeSentMessage(val id: String)
@Serializable private data class E2eeSendEncryptedResponse(val message: E2eeSentMessage)

@Serializable
private data class E2eeRegisterDeviceRequest(
    @SerialName("device_id") val deviceId: String,
    @SerialName("device_label") val deviceLabel: String,
    @SerialName("root_public_key") val rootPublicKey: String,
    @SerialName("root_fingerprint") val rootFingerprint: String,
    val credential: String,
    @SerialName("credential_fingerprint") val credentialFingerprint: String,
    @SerialName("approval_public_key") val approvalPublicKey: String,
    @SerialName("protocol_version") val protocolVersion: Int,
    @SerialName("client_platform") val clientPlatform: String,
    @SerialName("client_version") val clientVersion: String,
    @SerialName("client_build") val clientBuild: String,
)

@Serializable
private data class E2eeRegisterDeviceResponse(val status: String)

@Serializable
private data class E2eeKeyPackagePayload(
    val id: String,
    @SerialName("package_ref") val packageRef: String,
    @SerialName("key_package") val keyPackage: String,
    @SerialName("protocol_version") val protocolVersion: Int,
    @SerialName("expires_at") val expiresAt: String,
)

@Serializable
private data class E2eePublishKeyPackagesRequest(val packages: List<E2eeKeyPackagePayload>)

@Serializable
private data class E2eePublishKeyPackagesResponse(val inserted: Int)
