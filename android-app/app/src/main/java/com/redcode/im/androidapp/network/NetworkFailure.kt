package com.redcode.im.androidapp.network

class NetworkFailure(
    val statusCode: Int? = null,
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause)
