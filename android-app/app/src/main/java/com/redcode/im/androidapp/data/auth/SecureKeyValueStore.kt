package com.redcode.im.androidapp.data.auth

interface SecureKeyValueStore {
    fun getString(key: String): String?

    fun putString(key: String, value: String)

    fun remove(key: String)
}
