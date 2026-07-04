package com.redcode.im.androidapp.network

import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class JavaNetHttpTransport : HttpTransport {
    override suspend fun execute(request: HttpRequest): HttpResponse =
        withContext(Dispatchers.IO) {
            val connection = URL(request.url).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = request.method.name
                connection.connectTimeout = 10_000
                connection.readTimeout = 15_000
                request.headers.forEach { (key, value) -> connection.setRequestProperty(key, value) }
                val body = request.body
                if (body != null) {
                    connection.doOutput = true
                    connection.outputStream.use { output ->
                        output.write(body.toByteArray(Charsets.UTF_8))
                    }
                }

                val statusCode = connection.responseCode
                val stream =
                    if (statusCode in 200..299) {
                        connection.inputStream
                    } else {
                        connection.errorStream ?: connection.inputStream
                    }
                HttpResponse(
                    statusCode = statusCode,
                    body = stream.use { it.readBytes().toString(Charsets.UTF_8) },
                )
            } finally {
                connection.disconnect()
            }
        }
}
