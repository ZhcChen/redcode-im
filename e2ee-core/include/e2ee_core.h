// RedCode IM E2EE 共享核心 C ABI（RCCQ/RCCR 命令协议）。
//
// 本头文件是原生双端 FFI 的唯一 C 契约：Android 通过 JNA 绑定，
// iOS 通过 C 桥 + Swift 封装调用。协议版本与字节布局见
// e2ee-core/src/command.rs。
#ifndef REDCODE_E2EE_CORE_H
#define REDCODE_E2EE_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// 返回当前协议版本（当前为 1）。
uint16_t rc_e2ee_protocol_version(void);

// 校验 opaque 协议状态缓冲；1 有效、0 无效、-1 指针无效。
int32_t rc_e2ee_state_validate(const uint8_t *data, size_t length);

// 写入新的空协议状态到调用方缓冲；返回所需/写入字节数。
size_t rc_e2ee_state_new(uint8_t *output, size_t capacity);

// 执行 RCCQ 命令并分配 RCCR 响应；成功返回 0，失败返回 -1。
// 输出缓冲由调用方通过 rc_e2ee_command_free 释放。
int32_t rc_e2ee_command_execute(
    const uint8_t *input,
    size_t input_length,
    uint8_t **output,
    size_t *output_length);

// 释放 rc_e2ee_command_execute 分配的响应缓冲。
void rc_e2ee_command_free(uint8_t *output, size_t length);

#ifdef __cplusplus
}
#endif

#endif  // REDCODE_E2EE_CORE_H
