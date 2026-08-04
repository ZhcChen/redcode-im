package com.redcode.im.androidapp.persistence

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.redcode.im.androidapp.core.model.GroupSettingsInfo
import com.redcode.im.androidapp.core.model.GroupSettingsSnapshot
import com.redcode.im.androidapp.core.model.MyMuteInfo
import java.time.Instant

@Entity(tableName = "group_settings_cache")
data class GroupSettingsEntity(
    @PrimaryKey val roomId: String,
    val joinApprovalRequired: Boolean,
    val memberCanInvite: Boolean,
    val memberCanAddFriends: Boolean,
    val requireAdminToAddFriends: Boolean,
    val maxMembers: Int,
    val globalMuteEnabled: Boolean,
    val globalMuteUntilMillis: Long?,
    val globalMuteReason: String?,
    val globalMuteSetBy: String?,
    val myIsMuted: Boolean,
    val myMuteReason: String?,
    val myMutedAtMillis: Long?,
    val myMuteUntilMillis: Long?,
) {
    fun toDomain(): GroupSettingsSnapshot =
        GroupSettingsSnapshot(
            settings =
                GroupSettingsInfo(
                    roomId = roomId,
                    joinApprovalRequired = joinApprovalRequired,
                    memberCanInvite = memberCanInvite,
                    memberCanAddFriends = memberCanAddFriends,
                    requireAdminToAddFriends = requireAdminToAddFriends,
                    maxMembers = maxMembers,
                    globalMuteEnabled = globalMuteEnabled,
                    globalMuteUntil = globalMuteUntilMillis?.let(Instant::ofEpochMilli),
                    globalMuteReason = globalMuteReason,
                    globalMuteSetBy = globalMuteSetBy,
                ),
            myMute =
                if (myIsMuted) {
                    MyMuteInfo(
                        isMuted = true,
                        reason = myMuteReason,
                        mutedAt = myMutedAtMillis?.let(Instant::ofEpochMilli),
                        muteUntil = myMuteUntilMillis?.let(Instant::ofEpochMilli),
                    )
                } else {
                    null
                },
        )

    companion object {
        fun fromDomain(snapshot: GroupSettingsSnapshot): GroupSettingsEntity {
            val settings = snapshot.settings
            val myMute = snapshot.myMute
            return GroupSettingsEntity(
                roomId = settings.roomId,
                joinApprovalRequired = settings.joinApprovalRequired,
                memberCanInvite = settings.memberCanInvite,
                memberCanAddFriends = settings.memberCanAddFriends,
                requireAdminToAddFriends = settings.requireAdminToAddFriends,
                maxMembers = settings.maxMembers,
                globalMuteEnabled = settings.globalMuteEnabled,
                globalMuteUntilMillis = settings.globalMuteUntil?.toEpochMilli(),
                globalMuteReason = settings.globalMuteReason,
                globalMuteSetBy = settings.globalMuteSetBy,
                myIsMuted = myMute?.isMuted == true,
                myMuteReason = myMute?.reason,
                myMutedAtMillis = myMute?.mutedAt?.toEpochMilli(),
                myMuteUntilMillis = myMute?.muteUntil?.toEpochMilli(),
            )
        }
    }
}
