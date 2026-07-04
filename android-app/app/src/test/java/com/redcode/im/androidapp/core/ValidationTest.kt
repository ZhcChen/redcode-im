package com.redcode.im.androidapp.core

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.core.validation.AccountName
import com.redcode.im.androidapp.core.validation.PasswordPolicy
import com.redcode.im.androidapp.core.validation.ValidationResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ValidationTest {
    @Test
    fun accountName_acceptsOrdinaryAccountOnly() {
        assertEquals(ValidationResult.Valid, AccountName.validate("redcode_001"))
        assertTrue(AccountName.validate(" ") is ValidationResult.Invalid)
        assertTrue(AccountName.validate("red code") is ValidationResult.Invalid)
        assertTrue(AccountName.validate("user@example.com") is ValidationResult.Invalid)
        assertTrue(AccountName.validate("ab") is ValidationResult.Invalid)
        assertEquals("redcode", AccountName.normalize("  redcode  "))
    }

    @Test
    fun passwordPolicy_rejectsWeakOrWhitespacePassword() {
        assertEquals(ValidationResult.Valid, PasswordPolicy.validate("redcode123"))
        assertTrue(PasswordPolicy.validate("12345") is ValidationResult.Invalid)
        assertTrue(PasswordPolicy.validate("red code") is ValidationResult.Invalid)
        assertTrue(PasswordPolicy.validate("a".repeat(129)) is ValidationResult.Invalid)
    }

    @Test
    fun environment_requiresHttpAndWebSocketSchemes() {
        val environment = RedCodeEnvironment.localEmulator()
        assertEquals("http://10.0.2.2:8010", environment.apiBaseUrl)
        assertEquals("ws://10.0.2.2:8010/ws", environment.wsUrl)
        assertEquals("https://api.example.test", RedCodeEnvironment("https://api.example.test", "wss://api.example.test/ws").apiBaseUrl)

        assertThrows(IllegalArgumentException::class.java) {
            RedCodeEnvironment(apiBaseUrl = "ftp://example.test", wsUrl = "ws://example.test/ws")
        }
        assertThrows(IllegalArgumentException::class.java) {
            RedCodeEnvironment(apiBaseUrl = "http://example.test", wsUrl = "http://example.test/ws")
        }
    }
}
