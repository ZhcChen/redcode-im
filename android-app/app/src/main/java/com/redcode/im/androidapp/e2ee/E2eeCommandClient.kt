package com.redcode.im.androidapp.e2ee

import com.sun.jna.Memory
import com.sun.jna.NativeLong
import com.sun.jna.Pointer
import com.sun.jna.ptr.NativeLongByReference
import com.sun.jna.ptr.PointerByReference

/** 与 H5 E2eeCommandOperation 对齐的共享核心命令编号。 */
enum class E2eeCommandOperation(val wire: Int) {
    Initialize(1),
    GenerateKeyPackage(2),
    CreateGroup(3),
    AddMember(4),
    JoinGroup(5),
    Encrypt(6),
    Decrypt(7),
    PublicMaterial(8),
    ProcessCommit(9),
    RemoveMember(10),
    SignDeviceApproval(11),
    ListMembers(12),
}

class E2eeCommandException(message: String) : Exception(message)

class E2eeCommandResult(private val fields: List<ByteArray>) {
    val fieldCount: Int
        get() = fields.size

    fun field(index: Int): ByteArray =
        fields.getOrNull(index) ?: throw E2eeCommandException("E2EE 核心响应字段缺失")

    fun epoch(index: Int): Long {
        val bytes = field(index)
        if (bytes.size != 8) throw E2eeCommandException("E2EE 核心 epoch 格式无效")
        return bytes.fold(0L) { acc, byte -> (acc shl 8) or (byte.toLong() and 0xFF) }
    }
}

/**
 * e2ee-core C ABI 的 Kotlin 封装：RCCQ/RCCR 命令编解码与状态工具，
 * 字节布局与 H5 session.ts / e2ee-core/src/command.rs 一致。
 */
class E2eeCommandClient(
    private val native: E2eeCoreNative = E2eeCoreNative.load(),
) {
    val protocolVersion: Int get() = native.rc_e2ee_protocol_version().toInt()

    fun newProtocolState(): ByteArray {
        // JNA 5.17 的 Pointer.NULL 实际为 null，Kotlin 会对其做平台类型空检查并抛
        // NPE；Pointer(0) 的 peer 为 0，由 JNA 映射为原生 NULL 指针。
        val capacity = native.rc_e2ee_state_new(Pointer(0), NativeLong(0)).toInt()
        val buffer = Memory(capacity.toLong())
        val written = native.rc_e2ee_state_new(buffer, NativeLong(capacity.toLong())).toInt()
        if (written != capacity) throw E2eeCommandException("E2EE 核心状态初始化长度不一致")
        return buffer.getByteArray(0, written)
    }

    fun validateProtocolState(state: ByteArray): Boolean =
        native.rc_e2ee_state_validate(state.toPointer(), NativeLong(state.size.toLong())) == 1

    fun execute(operation: E2eeCommandOperation, fields: List<ByteArray>): E2eeCommandResult =
        decodeResponse(executeRaw(encodeRequest(operation, fields)))

    fun initialize(deviceIdentity: String, rootPublicKey: ByteArray? = null): E2eeCommandResult {
        val fields = mutableListOf(deviceIdentity.toByteArray())
        if (rootPublicKey != null) fields += rootPublicKey
        return execute(E2eeCommandOperation.Initialize, fields)
    }

    fun createGroup(state: ByteArray, roomId: String): E2eeCommandResult =
        execute(E2eeCommandOperation.CreateGroup, listOf(state, roomId.toByteArray()))

    fun generateKeyPackage(state: ByteArray): E2eeCommandResult =
        execute(E2eeCommandOperation.GenerateKeyPackage, listOf(state))

    fun publicMaterial(state: ByteArray): E2eeCommandResult =
        execute(E2eeCommandOperation.PublicMaterial, listOf(state))

    fun encrypt(state: ByteArray, roomId: String, plaintext: ByteArray): E2eeCommandResult =
        execute(E2eeCommandOperation.Encrypt, listOf(state, roomId.toByteArray(), plaintext))

    fun decrypt(state: ByteArray, roomId: String, ciphertext: ByteArray): E2eeCommandResult =
        execute(E2eeCommandOperation.Decrypt, listOf(state, roomId.toByteArray(), ciphertext))

    /** 直接执行一段 RCCQ 原始命令（测试与高级调用点使用）。 */
    fun executeRaw(request: ByteArray): ByteArray {
        val input = request.toPointer()
        val outputRef = PointerByReference()
        val outputLength = NativeLongByReference()
        val status = native.rc_e2ee_command_execute(
            input,
            NativeLong(request.size.toLong()),
            outputRef,
            outputLength,
        )
        if (status != 0) throw E2eeCommandException("E2EE 核心命令调用失败")
        val output = outputRef.value
        val length = outputLength.value.toInt()
        return try {
            output.getByteArray(0, length)
        } finally {
            native.rc_e2ee_command_free(output, NativeLong(length.toLong()))
        }
    }

    private fun encodeRequest(operation: E2eeCommandOperation, fields: List<ByteArray>): ByteArray {
        if (fields.size > 8) throw E2eeCommandException("E2EE 核心命令字段过多")
        val payloadSize = fields.sumOf { 4 + it.size }
        val request = ByteArray(8 + payloadSize)
        "RCCQ".toByteArray().copyInto(request, 0)
        request[4] = 0
        request[5] = 1
        request[6] = operation.wire.toByte()
        request[7] = fields.size.toByte()
        var offset = 8
        for (field in fields) {
            val length = field.size
            request[offset] = (length ushr 24).toByte()
            request[offset + 1] = (length ushr 16).toByte()
            request[offset + 2] = (length ushr 8).toByte()
            request[offset + 3] = length.toByte()
            field.copyInto(request, offset + 4)
            offset += 4 + length
        }
        return request
    }

    private fun decodeResponse(response: ByteArray): E2eeCommandResult {
        if (response.size < 8 ||
            !response.copyOfRange(0, 4).contentEquals("RCCR".toByteArray()) ||
            response[4] != 0.toByte() ||
            response[5] != 1.toByte()
        ) {
            throw E2eeCommandException("E2EE 核心响应头无效")
        }
        val status = response[6].toInt()
        val fieldCount = response[7].toInt()
        var offset = 8
        val fields = mutableListOf<ByteArray>()
        repeat(fieldCount) {
            if (offset + 4 > response.size) throw E2eeCommandException("E2EE 核心响应字段截断")
            val length = readUInt32(response, offset)
            offset += 4
            val end = offset + length
            if (end > response.size) throw E2eeCommandException("E2EE 核心响应字段超长")
            fields += response.copyOfRange(offset, end)
            offset = end
        }
        if (status != 0) {
            val message = fields.firstOrNull()?.toString(Charsets.UTF_8)
                ?: "未知 E2EE 命令错误"
            throw E2eeCommandException(message)
        }
        return E2eeCommandResult(fields)
    }

    private fun readUInt32(bytes: ByteArray, offset: Int): Int {
        return ((bytes[offset].toInt() and 0xFF) shl 24) or
            ((bytes[offset + 1].toInt() and 0xFF) shl 16) or
            ((bytes[offset + 2].toInt() and 0xFF) shl 8) or
            (bytes[offset + 3].toInt() and 0xFF)
    }

    private fun ByteArray.toPointer(): Pointer {
        val memory = Memory(size.toLong())
        memory.write(0, this, 0, size)
        return memory
    }
}
