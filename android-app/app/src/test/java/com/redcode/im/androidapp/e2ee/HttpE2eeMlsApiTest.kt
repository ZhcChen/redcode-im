package com.redcode.im.androidapp.e2ee

import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HttpResponse
import com.redcode.im.androidapp.network.RecordingTransport
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test

class HttpE2eeMlsApiTest {
    @Test
    fun sendEncryptedMessageIncludesRequiredMetadataDefaults() = runTest {
        val transport = RecordingTransport(HttpResponse(200, """{"message":{"id":"message-1"}}"""))
        val api =
            HttpE2eeMlsApi(
                APIClient(
                    RedCodeEnvironment("http://127.0.0.1:8010", "ws://127.0.0.1:8010/ws"),
                    transport,
                ),
            )

        val messageId =
            api.sendEncryptedMessage(
                E2eeEncryptedMessageRequest(
                    roomId = "room-1",
                    senderDeviceId = "019fd16d-0812-7452-af38-139cec9f4154",
                    epoch = 1,
                    ciphertext = byteArrayOf(1, 2, 3),
                    idempotencyKey = "019fd16d-0812-7452-af38-139cec9f4155",
                    controlMessageId = "019fd16d-0812-7452-af38-139cec9f4156",
                ),
                "token",
            )

        assertEquals("message-1", messageId)
        val metadata =
            Json.parseToJsonElement(requireNotNull(transport.lastRequest.body))
                .jsonObject.getValue("encryption_metadata").jsonObject
        assertEquals("mls", metadata.getValue("protocol").jsonPrimitive.content)
        assertEquals("1", metadata.getValue("version").jsonPrimitive.content)
        assertEquals("application", metadata.getValue("content_type").jsonPrimitive.content)
    }
}
