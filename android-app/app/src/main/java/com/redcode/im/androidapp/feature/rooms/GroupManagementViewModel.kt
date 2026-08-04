package com.redcode.im.androidapp.feature.rooms

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.GroupAdmin
import com.redcode.im.androidapp.core.model.GroupMute
import com.redcode.im.androidapp.core.model.GroupOperationLog
import com.redcode.im.androidapp.core.model.GroupRule
import com.redcode.im.androidapp.core.model.GroupSettingsSnapshot
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.core.model.RoomMember
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import com.redcode.im.androidapp.data.rooms.RoomRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class GroupManagementFormState(
    val groupName: String = "",
    val groupDescription: String = "",
    val selectedMemberIds: Set<String> = emptySet(),
    val selectedRoomId: String? = null,
    val editName: String = "",
    val editDescription: String = "",
    val ruleTitle: String = "",
    val ruleContent: String = "",
    val admins: List<GroupAdmin> = emptyList(),
    val mutes: List<GroupMute> = emptyList(),
    val rules: List<GroupRule> = emptyList(),
    val logs: List<GroupOperationLog> = emptyList(),
    val isLoading: Boolean = false,
    val isSubmitting: Boolean = false,
    val errorMessage: String? = null,
    val infoMessage: String? = null,
)

data class GroupManagementUiState(
    val rooms: List<RoomInfo> = emptyList(),
    val contacts: List<Contact> = emptyList(),
    val selectedRoom: RoomInfo? = null,
    val members: List<RoomMember> = emptyList(),
    val settings: GroupSettingsSnapshot? = null,
    val groupName: String = "",
    val groupDescription: String = "",
    val selectedMemberIds: Set<String> = emptySet(),
    val editName: String = "",
    val editDescription: String = "",
    val ruleTitle: String = "",
    val ruleContent: String = "",
    val admins: List<GroupAdmin> = emptyList(),
    val mutes: List<GroupMute> = emptyList(),
    val rules: List<GroupRule> = emptyList(),
    val logs: List<GroupOperationLog> = emptyList(),
    val isLoading: Boolean = false,
    val isSubmitting: Boolean = false,
    val errorMessage: String? = null,
    val infoMessage: String? = null,
)

@OptIn(ExperimentalCoroutinesApi::class)
class GroupManagementViewModel(
    private val roomRepository: RoomRepository,
    private val contactsRepository: ContactsRepository,
) : ViewModel() {
    private val formState = MutableStateFlow(GroupManagementFormState())
    private val selectedRoomMembers =
        formState
            .flatMapLatest { form ->
                form.selectedRoomId?.let(roomRepository::members) ?: flowOf(emptyList())
            }
    private val selectedRoomSettings =
        formState
            .flatMapLatest { form ->
                form.selectedRoomId?.let(roomRepository::settings) ?: flowOf(null)
            }

    val uiState: StateFlow<GroupManagementUiState> =
        combine(
            roomRepository.rooms,
            contactsRepository.contacts,
            selectedRoomMembers,
            selectedRoomSettings,
            formState,
        ) { rooms, contacts, members, settings, form ->
            GroupManagementUiState(
                rooms = rooms.filter { it.roomType.lowercase() == "group" },
                contacts = contacts,
                selectedRoom = rooms.firstOrNull { it.id == form.selectedRoomId },
                members = members,
                settings = settings,
                groupName = form.groupName,
                groupDescription = form.groupDescription,
                selectedMemberIds = form.selectedMemberIds,
                editName = form.editName,
                editDescription = form.editDescription,
                ruleTitle = form.ruleTitle,
                ruleContent = form.ruleContent,
                admins = form.admins,
                mutes = form.mutes,
                rules = form.rules,
                logs = form.logs,
                isLoading = form.isLoading,
                isSubmitting = form.isSubmitting,
                errorMessage = form.errorMessage,
                infoMessage = form.infoMessage,
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), GroupManagementUiState())

    init {
        refreshAll()
    }

    fun onGroupNameChange(value: String) {
        formState.update { it.copy(groupName = value, errorMessage = null, infoMessage = null) }
    }

    fun onGroupDescriptionChange(value: String) {
        formState.update { it.copy(groupDescription = value, errorMessage = null, infoMessage = null) }
    }

    fun toggleCreateMember(userId: String) {
        formState.update { form ->
            val next =
                if (userId in form.selectedMemberIds) {
                    form.selectedMemberIds - userId
                } else {
                    form.selectedMemberIds + userId
                }
            form.copy(selectedMemberIds = next, errorMessage = null, infoMessage = null)
        }
    }

    fun onEditNameChange(value: String) {
        formState.update { it.copy(editName = value, errorMessage = null, infoMessage = null) }
    }

    fun onEditDescriptionChange(value: String) {
        formState.update { it.copy(editDescription = value, errorMessage = null, infoMessage = null) }
    }

    fun onRuleTitleChange(value: String) {
        formState.update { it.copy(ruleTitle = value, errorMessage = null, infoMessage = null) }
    }

    fun onRuleContentChange(value: String) {
        formState.update { it.copy(ruleContent = value, errorMessage = null, infoMessage = null) }
    }

    fun refreshAll() {
        viewModelScope.launch {
            formState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                contactsRepository.refreshContacts()
                roomRepository.refreshRooms()
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "群聊加载失败") }
            }
            formState.update { it.copy(isLoading = false) }
        }
    }

    fun createGroup() {
        val form = formState.value
        viewModelScope.launch {
            formState.update { it.copy(isSubmitting = true, errorMessage = null, infoMessage = null) }
            runCatching {
                roomRepository.createGroup(
                    name = form.groupName,
                    description = form.groupDescription,
                    memberIds = form.selectedMemberIds.toList(),
                )
            }.onSuccess { room ->
                formState.update {
                    it.copy(
                        groupName = "",
                        groupDescription = "",
                        selectedMemberIds = emptySet(),
                        selectedRoomId = room.id,
                        editName = room.name,
                        editDescription = room.description.orEmpty(),
                        infoMessage = "群聊已创建",
                    )
                }
                loadSelectedRoomDetails(room.id)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "创建群聊失败") }
            }
            formState.update { it.copy(isSubmitting = false) }
        }
    }

    fun selectRoom(room: RoomInfo) {
        formState.update {
            it.copy(
                selectedRoomId = room.id,
                editName = room.name,
                editDescription = room.description.orEmpty(),
                errorMessage = null,
                infoMessage = null,
            )
        }
        loadSelectedRoomDetails(room.id)
    }

    fun clearSelection() {
        formState.update { it.copy(selectedRoomId = null, admins = emptyList(), mutes = emptyList(), rules = emptyList(), logs = emptyList()) }
    }

    fun updateSelectedRoom() {
        val form = formState.value
        val roomId = form.selectedRoomId ?: return
        viewModelScope.launch {
            formState.update { it.copy(isSubmitting = true, errorMessage = null, infoMessage = null) }
            runCatching {
                roomRepository.updateRoom(roomId, name = form.editName, description = form.editDescription)
            }.onSuccess {
                formState.update { it.copy(infoMessage = "群资料已更新") }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "更新群资料失败") }
            }
            formState.update { it.copy(isSubmitting = false) }
        }
    }

    fun addSelectedContactsToRoom() {
        val form = formState.value
        val roomId = form.selectedRoomId ?: return
        viewModelScope.launch {
            formState.update { it.copy(isSubmitting = true, errorMessage = null, infoMessage = null) }
            runCatching {
                roomRepository.addMembers(roomId, form.selectedMemberIds.toList())
            }.onSuccess { result ->
                formState.update {
                    it.copy(
                        selectedMemberIds = emptySet(),
                        infoMessage = "新增 ${result.addedUserIds.size} 人，跳过 ${result.skippedUserIds.size} 人",
                    )
                }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "添加群成员失败") }
            }
            formState.update { it.copy(isSubmitting = false) }
        }
    }

    fun removeMember(member: RoomMember) {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.removeMember(roomId, member.userId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "移除成员失败") }
            }
        }
    }

    fun toggleJoinApproval() {
        val roomId = formState.value.selectedRoomId ?: return
        val current = uiState.value.settings?.settings ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.updateGroupSettings(roomId, joinApprovalRequired = !current.joinApprovalRequired)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "更新入群审批失败") }
            }
        }
    }

    fun toggleGlobalMute() {
        val roomId = formState.value.selectedRoomId ?: return
        val current = uiState.value.settings?.settings ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.updateGlobalMute(
                    roomId = roomId,
                    enabled = !current.globalMuteEnabled,
                    reason = if (current.globalMuteEnabled) null else "Android 管理端操作",
                    durationMinutes = if (current.globalMuteEnabled) null else 60,
                )
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "更新全员禁言失败") }
            }
        }
    }

    fun setRoomPinned(pinned: Boolean) {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.setRoomPinned(roomId, pinned)
            }.onSuccess {
                formState.update { it.copy(infoMessage = if (pinned) "群聊已置顶" else "已取消置顶") }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "更新置顶失败") }
            }
        }
    }

    fun setRoomMuted(muted: Boolean) {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.updateNotificationSettings(roomId, if (muted) 2 else 0)
            }.onSuccess {
                formState.update { it.copy(infoMessage = if (muted) "已设为免打扰" else "已取消免打扰") }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "更新免打扰失败") }
            }
        }
    }

    fun appointAdmin(member: RoomMember) {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.appointAdmin(roomId, member.userId)
                reloadManagementLists(roomId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "设置管理员失败") }
            }
        }
    }

    fun removeAdmin(admin: GroupAdmin) {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.removeAdmin(roomId, admin.adminId)
                reloadManagementLists(roomId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "移除管理员失败") }
            }
        }
    }

    fun muteMember(member: RoomMember) {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.muteUser(roomId, member.userId, reason = "Android 管理端操作", muteDurationHours = 1)
                reloadManagementLists(roomId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "禁言成员失败") }
            }
        }
    }

    fun unmute(mute: GroupMute) {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.unmuteUser(roomId, mute.userId)
                reloadManagementLists(roomId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "解除禁言失败") }
            }
        }
    }

    fun createRule() {
        val form = formState.value
        val roomId = form.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.createRule(roomId, form.ruleTitle, form.ruleContent)
                roomRepository.listRules(roomId)
            }.onSuccess { rules ->
                formState.update { it.copy(ruleTitle = "", ruleContent = "", rules = rules, infoMessage = "群规已创建") }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "创建群规失败") }
            }
        }
    }

    fun deactivateRule(rule: GroupRule) {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.updateRule(roomId, rule.id, isActive = false)
                roomRepository.listRules(roomId)
            }.onSuccess { rules ->
                formState.update { it.copy(rules = rules) }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "停用群规失败") }
            }
        }
    }

    fun deleteRule(rule: GroupRule) {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.deleteRule(roomId, rule.id)
                roomRepository.listRules(roomId)
            }.onSuccess { rules ->
                formState.update { it.copy(rules = rules) }
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "删除群规失败") }
            }
        }
    }

    fun leaveSelectedRoom() {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.leaveRoom(roomId)
            }.onSuccess {
                clearSelection()
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "退出群聊失败") }
            }
        }
    }

    fun dissolveSelectedRoom() {
        val roomId = formState.value.selectedRoomId ?: return
        viewModelScope.launch {
            runCatching {
                roomRepository.dissolveRoom(roomId)
            }.onSuccess {
                clearSelection()
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "解散群聊失败") }
            }
        }
    }

    private fun loadSelectedRoomDetails(roomId: String) {
        viewModelScope.launch {
            formState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                roomRepository.getRoom(roomId)
                roomRepository.refreshMembers(roomId)
                roomRepository.fetchGroupSettings(roomId)
                reloadManagementLists(roomId)
            }.onFailure { error ->
                formState.update { it.copy(errorMessage = error.message ?: "群详情加载失败") }
            }
            formState.update { it.copy(isLoading = false) }
        }
    }

    private suspend fun reloadManagementLists(roomId: String) {
        val admins = roomRepository.listAdmins(roomId)
        val mutes = roomRepository.listMutes(roomId)
        val rules = roomRepository.listRules(roomId)
        val logs = roomRepository.listOperationLogs(roomId)
        formState.update {
            it.copy(admins = admins, mutes = mutes, rules = rules, logs = logs)
        }
    }
}
