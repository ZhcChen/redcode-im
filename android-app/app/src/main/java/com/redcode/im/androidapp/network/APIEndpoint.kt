package com.redcode.im.androidapp.network

import com.redcode.im.androidapp.core.config.RedCodeEnvironment

data class APIEndpoint(
    val method: HTTPMethod,
    val path: String,
) {
    init {
        require(path.startsWith("/")) { "API path 必须以 / 开头" }
    }

    fun url(environment: RedCodeEnvironment): String =
        environment.apiBaseUrl.trimEnd('/') + path
}
