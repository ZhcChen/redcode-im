package com.redcode.im.androidapp.data.contacts

interface FriendRemoteDataSource {
    suspend fun searchUsers(keyword: String, token: String, limit: Int = 20): List<BackendUser>

    suspend fun fetchFriends(token: String): List<BackendFriendInfo>

    suspend fun sendFriendRequest(targetUserId: String, message: String?, token: String): BackendFriendRequest

    suspend fun fetchFriendRequests(direction: String? = null, status: String? = null, token: String): List<BackendFriendRequest>

    suspend fun respondFriendRequest(requestId: String, accept: Boolean, token: String): BackendFriendRequest

    suspend fun ensurePrivateChat(friendUserId: String, token: String): EnsurePrivateChatResponse
}
