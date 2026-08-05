package com.redcode.im.androidapp.e2ee

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** 与 H5 device-profile.ts 对齐的本地设备档案。 */
@Serializable
data class E2eeDeviceProfile(
    val version: Int = PROFILE_VERSION,
    @SerialName("device_id") val deviceId: String,
    @SerialName("device_label") val deviceLabel: String,
    val registered: Boolean = false,
    @SerialName("key_package_published") val keyPackagePublished: Boolean = false,
    @SerialName("device_status") val deviceStatus: String = "active",
    @SerialName("last_control_sequences") val lastControlSequences: Map<String, Long> = emptyMap(),
    @SerialName("last_commit_message_ids") val lastCommitMessageIds: Map<String, String> = emptyMap(),
) {
    companion object {
        private const val PROFILE_VERSION = 1

        private val json =
            Json {
                ignoreUnknownKeys = true
            }

        fun encode(profile: E2eeDeviceProfile): ByteArray =
            json.encodeToString(profile).toByteArray(Charsets.UTF_8)

        fun decode(bytes: ByteArray): E2eeDeviceProfile {
            val profile = json.decodeFromString<E2eeDeviceProfile>(bytes.toString(Charsets.UTF_8))
            if (profile.version != PROFILE_VERSION || profile.deviceId.isBlank()) {
                throw E2eeStateCorruptedException("E2EE 设备档案格式无效")
            }
            return profile
        }
    }
}

/** 注册/恢复设备的 MLS 登记材料，字段顺序与 e2ee-core 命令契约一致。 */
data class E2eeRegistrationMaterial(
    val state: ByteArray,
    val keyPackage: ByteArray,
    val rootPublicKey: ByteArray,
    val rootFingerprint: ByteArray,
    val credential: ByteArray,
    val credentialFingerprint: ByteArray,
    val approvalPublicKey: ByteArray,
) {
    companion object {
        fun fromInitialize(result: E2eeCommandResult): E2eeRegistrationMaterial {
            if (result.fieldCount != 7) {
                throw E2eeCommandException("E2EE 初始化响应字段数量无效")
            }
            return E2eeRegistrationMaterial(
                state = result.field(0),
                keyPackage = result.field(1),
                rootPublicKey = result.field(2),
                rootFingerprint = result.field(3),
                credential = result.field(4),
                credentialFingerprint = result.field(5),
                approvalPublicKey = result.field(6),
            )
        }

        fun fromPublicMaterial(result: E2eeCommandResult): E2eeRegistrationMaterial {
            if (result.fieldCount != 6) {
                throw E2eeCommandException("E2EE 公开材料响应字段数量无效")
            }
            return E2eeRegistrationMaterial(
                state = result.field(0),
                keyPackage = ByteArray(0),
                rootPublicKey = result.field(1),
                rootFingerprint = result.field(2),
                credential = result.field(3),
                credentialFingerprint = result.field(4),
                approvalPublicKey = result.field(5),
            )
        }
    }
}
