package com.redcode.im.androidapp.core.validation

object AccountName {
    private val pattern = Regex("^[a-zA-Z0-9._-]{3,32}$")

    fun normalize(input: String): String = input.trim()

    fun validate(input: String): ValidationResult {
        val value = normalize(input)
        return when {
            value.isBlank() -> ValidationResult.Invalid("请输入账号")
            "@" in value -> ValidationResult.Invalid("当前已关闭邮箱登录，请使用普通账号")
            !pattern.matches(value) -> ValidationResult.Invalid("账号需为 3-32 位字母、数字、点、下划线或短横线")
            else -> ValidationResult.Valid
        }
    }
}
