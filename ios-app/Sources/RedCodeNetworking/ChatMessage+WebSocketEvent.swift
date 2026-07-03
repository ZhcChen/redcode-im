import Foundation

public extension ChatMessage {
    init(webSocketEvent event: WebSocketServerEvent, currentUserID: String? = nil) throws {
        guard event.type == "message" else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "WebSocket event is not a message event"
                )
            )
        }

        let data = try JSONEncoder().encode(event.fields)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        if decoded.status == nil, decoded.senderID == currentUserID {
            self = decoded.replacing(status: .sent)
        } else {
            self = decoded
        }
    }

    private func replacing(status: ChatMessageStatus) -> ChatMessage {
        ChatMessage(
            id: id,
            roomID: roomID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            messageType: messageType,
            status: status,
            timestamp: timestamp,
            isDeleted: isDeleted,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            pinnedBy: pinnedBy,
            quotedMessage: quotedMessage,
            parts: parts,
            attachments: attachments
        )
    }
}
