package com.redcode.im.androidapp.persistence

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.redcode.im.androidapp.core.model.Contact

@Entity(
    tableName = "contacts",
    indices = [Index(value = ["accountName"]), Index(value = ["displayName"])],
)
data class ContactEntity(
    @PrimaryKey val userId: String,
    val accountName: String,
    val displayName: String,
    val avatarUrl: String?,
) {
    fun toDomain(): Contact =
        Contact(
            userId = userId,
            accountName = accountName,
            displayName = displayName,
            avatarUrl = avatarUrl,
        )

    companion object {
        fun fromDomain(contact: Contact): ContactEntity =
            ContactEntity(
                userId = contact.userId,
                accountName = contact.accountName,
                displayName = contact.displayName,
                avatarUrl = contact.avatarUrl,
            )
    }
}
