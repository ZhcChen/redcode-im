#ifndef REDCODE_E2EE_CORE_BRIDGE_H
#define REDCODE_E2EE_CORE_BRIDGE_H

// 直接暴露 e2ee-core 的 C ABI；静态库由构建脚本产出并在
// Package.swift 中通过 linkerSettings 链接。
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint16_t rc_e2ee_protocol_version(void);
int32_t rc_e2ee_state_validate(const uint8_t *data, size_t length);
size_t rc_e2ee_state_new(uint8_t *output, size_t capacity);
int32_t rc_e2ee_command_execute(
    const uint8_t *input,
    size_t input_length,
    uint8_t **output,
    size_t *output_length);
void rc_e2ee_command_free(uint8_t *output, size_t length);

#ifdef __cplusplus
}
#endif

#endif  // REDCODE_E2EE_CORE_BRIDGE_H
