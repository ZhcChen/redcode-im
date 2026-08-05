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

    private fun encode(bytes: ByteArray): String =
        Base64.getEncoder().encodeToString(bytes)

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

    private fun urlEncode(value: String): String =
        java.net.URLEncoder.encode(value, Charsets.UTF_8.name()).replace("+", "%20")
}

@Serializable
private data class E2eeRootIdentityResponse(
    @SerialName("public_key") val publicKey: String,
)

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
