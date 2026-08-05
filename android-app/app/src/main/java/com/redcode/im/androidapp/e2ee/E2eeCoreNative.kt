package com.redcode.im.androidapp.e2ee

import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.NativeLong
import com.sun.jna.Pointer
import com.sun.jna.ptr.NativeLongByReference
import com.sun.jna.ptr.PointerByReference

/**
 * e2ee-core C ABI 的 JNA 绑定（见 e2ee-core/include/e2ee_core.h）。
 * 测试加载 host cdylib，Android 设备/模拟器加载 jniLibs 中的 .so。
 */
interface E2eeCoreNative : Library {
    fun rc_e2ee_protocol_version(): Short
    fun rc_e2ee_state_validate(data: Pointer, length: NativeLong): Int
    fun rc_e2ee_state_new(output: Pointer, capacity: NativeLong): NativeLong
    fun rc_e2ee_command_execute(
        input: Pointer,
        inputLength: NativeLong,
        output: PointerByReference,
        outputLength: NativeLongByReference,
    ): Int
    fun rc_e2ee_command_free(output: Pointer, length: NativeLong)

    companion object {
        const val LIBRARY_NAME = "redcode_e2ee_core"

        /** 按测试/运行环境解析宿主库目录并加载。 */
        fun load(searchDirs: List<String> = defaultSearchDirs()): E2eeCoreNative {
            for (dir in searchDirs) {
                if (java.io.File(dir).isDirectory && libraryExists(dir)) {
                    System.setProperty("jna.library.path", dir)
                    break
                }
            }
            return Native.load(LIBRARY_NAME, E2eeCoreNative::class.java)
        }

        private fun defaultSearchDirs(): List<String> {
            val candidates = mutableListOf<String>()
            System.getenv("E2EE_CORE_LIB_DIR")?.let { candidates += it }
            // Gradle test 的 workingDir 可能是 android-app/ 或 android-app/app/，
            // 逐级向上探测仓库根目录。
            var current: java.io.File? =
                java.io.File(System.getProperty("user.dir") ?: ".").canonicalFile
            while (current != null) {
                candidates += "$current/e2ee-core/target/aarch64-apple-darwin/release"
                candidates += "$current/e2ee-core/target/x86_64-apple-darwin/release"
                if (current.resolve("Makefile").exists()) break
                current = current.parentFile
            }
            // 显式兜底：宿主库目录（本机默认结构）。
            candidates += "/Users/chen/code/redcode-im/e2ee-core/target/aarch64-apple-darwin/release"
            return candidates
        }

        private fun libraryExists(dir: String): Boolean {
            val lib = when ((System.getProperty("os.name") ?: "").lowercase()) {
                "mac os x" -> "libredcode_e2ee_core.dylib"
                else -> "libredcode_e2ee_core.so"
            }
            return java.io.File(dir, lib).exists()
        }
    }
}
