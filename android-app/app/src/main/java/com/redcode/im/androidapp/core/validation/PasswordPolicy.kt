package com.redcode.im.androidapp.core.validation

object PasswordPolicy {
    fun validate(input: String): ValidationResult =
        when {
            input.length < 6 -> ValidationResult.Invalid("密码至少 6 位")
            input.length > 128 -> ValidationResult.Invalid("密码不能超过 128 位")
            input.any(Char::isWhitespace) -> ValidationResult.Invalid("密码不能包含空白字符")
            else -> ValidationResult.Valid
        }
}
