package com.redcode.im.androidapp.data.auth

class InMemorySecureKeyValueStore(
    initialValues: Map<String, String> = emptyMap(),
) : SecureKeyValueStore {
    private val values = initialValues.toMutableMap()

    override fun getString(key: String): String? = values[key]

    override fun putString(key: String, value: String) {
        values[key] = value
    }

    override fun remove(key: String) {
        values.remove(key)
    }
}
