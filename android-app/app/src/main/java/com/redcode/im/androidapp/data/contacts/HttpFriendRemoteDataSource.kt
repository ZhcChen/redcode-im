package com.redcode.im.androidapp.data.contacts

import com.redcode.im.androidapp.network.APIClient

class HttpFriendRemoteDataSource(
    private val apiClient: APIClient,
) : FriendRemoteDataSource {
    override suspend fun searchUsers(keyword: String, token: String, limit: Int): List<BackendUser> {
        val normalized = keyword.trim()
        if (normalized.isBlank()) return emptyList()
        return apiClient.get(FriendAPIEndpoint.searchUsers(normalized, limit), bearerToken = token)
    }

    override suspend fun fetchFriends(token: String): List<BackendFriendInfo> =
        apiClient.get(FriendAPIEndpoint.friends, bearerToken = token)

    override suspend fun sendFriendRequest(targetUserId: String, message: String?, token: String): BackendFriendRequest =
        apiClient.post<CreateFriendRequestPayload, BackendFriendRequest>(
            FriendAPIEndpoint.createFriendRequest,
            CreateFriendRequestPayload(targetUserId = targetUserId.trim(), message = message?.trim()?.takeIf { it.isNotBlank() }),
            bearerToken = token,
        )

    override suspend fun fetchFriendRequests(direction: String?, status: String?, token: String): List<BackendFriendRequest> =
        apiClient.get(FriendAPIEndpoint.friendRequests(direction = direction, status = status), bearerToken = token)

    override suspend fun respondFriendRequest(requestId: String, accept: Boolean, token: String): BackendFriendRequest =
        apiClient.post<RespondFriendRequestPayload, BackendFriendRequest>(
            FriendAPIEndpoint.respondFriendRequest(requestId),
            RespondFriendRequestPayload(action = if (accept) "accept" else "decline"),
            bearerToken = token,
        )

    override suspend fun ensurePrivateChat(friendUserId: String, token: String): EnsurePrivateChatResponse =
        apiClient.post<kotlinx.serialization.json.JsonObject, EnsurePrivateChatResponse>(
            FriendAPIEndpoint.ensurePrivateChat(friendUserId),
            kotlinx.serialization.json.JsonObject(emptyMap()),
            bearerToken = token,
        )
}
