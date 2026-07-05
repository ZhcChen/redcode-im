package com.redcode.im.androidapp.feature.rooms

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.redcode.im.androidapp.core.model.RoomInfo
import com.redcode.im.androidapp.data.media.AvatarCacheRepository
import com.redcode.im.androidapp.ui.components.CachedAvatarBadge
import com.redcode.im.androidapp.ui.components.CachedAvatarKind

@Composable
fun GroupManagementScreen(
    viewModel: GroupManagementViewModel,
    accessToken: String,
    avatarCacheRepository: AvatarCacheRepository?,
    onOpenGroupChat: (RoomInfo) -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .testTag("groups-screen"),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "群聊",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = viewModel::refreshAll, enabled = !uiState.isLoading, modifier = Modifier.testTag("groups-refresh")) {
                Text(if (uiState.isLoading) "刷新中" else "刷新")
            }
        }
        uiState.errorMessage?.let {
            Text(text = it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp).testTag("groups-error"))
        }
        uiState.infoMessage?.let {
            Text(text = it, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(horizontal = 16.dp).testTag("groups-info"))
        }
        CreateGroupPanel(uiState, viewModel, accessToken, avatarCacheRepository)
        HorizontalDivider()
        GroupListPanel(uiState, viewModel, accessToken, avatarCacheRepository, onOpenGroupChat)
        uiState.selectedRoom?.let {
            HorizontalDivider()
            GroupDetailPanel(uiState, viewModel, accessToken, avatarCacheRepository, onOpenGroupChat)
        }
    }
}

@Composable
private fun CreateGroupPanel(
    uiState: GroupManagementUiState,
    viewModel: GroupManagementViewModel,
    accessToken: String,
    avatarCacheRepository: AvatarCacheRepository?,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(16.dp).testTag("create-group-panel")) {
        Text("创建群聊", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedTextField(
            value = uiState.groupName,
            onValueChange = viewModel::onGroupNameChange,
            label = { Text("群名称") },
            modifier = Modifier.fillMaxWidth().testTag("group-name-input"),
        )
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedTextField(
            value = uiState.groupDescription,
            onValueChange = viewModel::onGroupDescriptionChange,
            label = { Text("群描述") },
            modifier = Modifier.fillMaxWidth().testTag("group-description-input"),
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text("选择成员 · ${uiState.selectedMemberIds.size}", fontWeight = FontWeight.SemiBold)
        if (uiState.contacts.isEmpty()) {
            Text("暂无联系人，先添加好友后再建群。", style = MaterialTheme.typography.bodyMedium)
        }
        uiState.contacts.forEach { contact ->
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Checkbox(
                    checked = contact.userId in uiState.selectedMemberIds,
                    onCheckedChange = { viewModel.toggleCreateMember(contact.userId) },
                    modifier = Modifier.testTag("group-member-toggle-${contact.userId}"),
                )
                CachedAvatarBadge(
                    kind = CachedAvatarKind.User,
                    entityId = contact.userId,
                    objectKey = contact.avatarObjectKey,
                    label = contact.displayName,
                    token = accessToken,
                    avatarCacheRepository = avatarCacheRepository,
                    size = 32.dp,
                )
                Spacer(modifier = Modifier.width(8.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(contact.displayName)
                    Text(contact.accountName, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Button(
            onClick = viewModel::createGroup,
            enabled = !uiState.isSubmitting,
            modifier = Modifier.fillMaxWidth().testTag("create-group-submit"),
        ) {
            Text(if (uiState.isSubmitting) "提交中" else "创建群聊")
        }
    }
}

@Composable
private fun GroupListPanel(
    uiState: GroupManagementUiState,
    viewModel: GroupManagementViewModel,
    accessToken: String,
    avatarCacheRepository: AvatarCacheRepository?,
    onOpenGroupChat: (RoomInfo) -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(16.dp).testTag("group-list-panel")) {
        Text("我的群聊 · ${uiState.rooms.size}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        if (uiState.rooms.isEmpty()) {
            Text("暂无群聊。", style = MaterialTheme.typography.bodyMedium)
        }
        uiState.rooms.forEach { room ->
            Row(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                CachedAvatarBadge(
                    kind = CachedAvatarKind.Room,
                    entityId = room.id,
                    objectKey = room.avatarObjectKey,
                    label = room.name,
                    token = accessToken,
                    avatarCacheRepository = avatarCacheRepository,
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(room.name, fontWeight = FontWeight.SemiBold)
                    if (!room.description.isNullOrBlank()) {
                        Text(room.description, style = MaterialTheme.typography.bodyMedium)
                    }
                    Row {
                        TextButton(onClick = { viewModel.selectRoom(room) }, modifier = Modifier.testTag("manage-group-${room.id}")) {
                            Text("管理")
                        }
                        TextButton(onClick = { onOpenGroupChat(room) }, modifier = Modifier.testTag("open-group-chat-${room.id}")) {
                            Text("打开聊天")
                        }
                    }
                }
            }
            HorizontalDivider()
        }
    }
}

@Composable
private fun GroupDetailPanel(
    uiState: GroupManagementUiState,
    viewModel: GroupManagementViewModel,
    accessToken: String,
    avatarCacheRepository: AvatarCacheRepository?,
    onOpenGroupChat: (RoomInfo) -> Unit,
) {
    val room = uiState.selectedRoom ?: return
    Column(modifier = Modifier.fillMaxWidth().padding(16.dp).testTag("group-detail-panel")) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            CachedAvatarBadge(
                kind = CachedAvatarKind.Room,
                entityId = room.id,
                objectKey = room.avatarObjectKey,
                label = room.name,
                token = accessToken,
                avatarCacheRepository = avatarCacheRepository,
                size = 48.dp,
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text("群管理：${room.name}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            TextButton(onClick = viewModel::clearSelection) {
                Text("关闭")
            }
        }
        Row {
            TextButton(onClick = { onOpenGroupChat(room) }) {
                Text("进入聊天")
            }
            TextButton(onClick = { viewModel.setRoomPinned(true) }) {
                Text("置顶")
            }
            TextButton(onClick = { viewModel.setRoomPinned(false) }) {
                Text("取消置顶")
            }
            TextButton(onClick = { viewModel.setRoomMuted(true) }) {
                Text("免打扰")
            }
            TextButton(onClick = { viewModel.setRoomMuted(false) }) {
                Text("取消免打扰")
            }
        }
        OutlinedTextField(
            value = uiState.editName,
            onValueChange = viewModel::onEditNameChange,
            label = { Text("群名称") },
            modifier = Modifier.fillMaxWidth().testTag("edit-group-name"),
        )
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedTextField(
            value = uiState.editDescription,
            onValueChange = viewModel::onEditDescriptionChange,
            label = { Text("群描述") },
            modifier = Modifier.fillMaxWidth().testTag("edit-group-description"),
        )
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = viewModel::updateSelectedRoom, enabled = !uiState.isSubmitting, modifier = Modifier.testTag("update-group-submit")) {
            Text("保存群资料")
        }
        Spacer(modifier = Modifier.height(12.dp))
        val settings = uiState.settings?.settings
        Text(
            text =
                "设置：入群审批 ${if (settings?.joinApprovalRequired == true) "开" else "关"} · 全员禁言 ${if (settings?.globalMuteEnabled == true) "开" else "关"} · 上限 ${settings?.maxMembers ?: "-"}",
            style = MaterialTheme.typography.bodyMedium,
        )
        Row {
            TextButton(onClick = viewModel::toggleJoinApproval) {
                Text("切换入群审批")
            }
            TextButton(onClick = viewModel::toggleGlobalMute) {
                Text("切换全员禁言")
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        GroupMembersPanel(uiState, viewModel, accessToken, avatarCacheRepository)
        Spacer(modifier = Modifier.height(8.dp))
        GroupRulesPanel(uiState, viewModel)
        Spacer(modifier = Modifier.height(8.dp))
        GroupManagementListsPanel(uiState, viewModel)
        Spacer(modifier = Modifier.height(8.dp))
        Row {
            TextButton(onClick = viewModel::leaveSelectedRoom, modifier = Modifier.testTag("leave-group")) {
                Text("退出群聊")
            }
            Spacer(modifier = Modifier.width(8.dp))
            TextButton(onClick = viewModel::dissolveSelectedRoom, modifier = Modifier.testTag("dissolve-group")) {
                Text("解散群聊")
            }
        }
    }
}

@Composable
private fun GroupMembersPanel(
    uiState: GroupManagementUiState,
    viewModel: GroupManagementViewModel,
    accessToken: String,
    avatarCacheRepository: AvatarCacheRepository?,
) {
    Text("成员 · ${uiState.members.size}", fontWeight = FontWeight.SemiBold)
    uiState.members.forEach { member ->
        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            CachedAvatarBadge(
                kind = CachedAvatarKind.User,
                entityId = member.userId,
                objectKey = member.avatarObjectKey,
                label = member.displayName,
                token = accessToken,
                avatarCacheRepository = avatarCacheRepository,
                size = 32.dp,
            )
            Spacer(modifier = Modifier.width(8.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text("${member.displayName} · ${member.role}")
                Text(member.userId, style = MaterialTheme.typography.bodySmall)
            }
            TextButton(onClick = { viewModel.appointAdmin(member) }) {
                Text("设管理员")
            }
            TextButton(onClick = { viewModel.muteMember(member) }) {
                Text("禁言")
            }
            if (member.role != "owner") {
                TextButton(onClick = { viewModel.removeMember(member) }) {
                    Text("移除")
                }
            }
        }
    }
    if (uiState.contacts.isNotEmpty()) {
        Text("添加联系人到当前群", fontWeight = FontWeight.SemiBold)
        uiState.contacts.forEach { contact ->
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Checkbox(
                    checked = contact.userId in uiState.selectedMemberIds,
                    onCheckedChange = { viewModel.toggleCreateMember(contact.userId) },
                )
                Text(contact.displayName, modifier = Modifier.weight(1f))
            }
        }
        Button(onClick = viewModel::addSelectedContactsToRoom, enabled = !uiState.isSubmitting, modifier = Modifier.testTag("add-group-members-submit")) {
            Text("添加成员")
        }
    }
}

@Composable
private fun GroupRulesPanel(uiState: GroupManagementUiState, viewModel: GroupManagementViewModel) {
    Text("群规 · ${uiState.rules.size}", fontWeight = FontWeight.SemiBold)
    Row(verticalAlignment = Alignment.CenterVertically) {
        OutlinedTextField(
            value = uiState.ruleTitle,
            onValueChange = viewModel::onRuleTitleChange,
            label = { Text("标题") },
            modifier = Modifier.weight(1f).testTag("group-rule-title"),
        )
        Spacer(modifier = Modifier.width(8.dp))
        OutlinedTextField(
            value = uiState.ruleContent,
            onValueChange = viewModel::onRuleContentChange,
            label = { Text("内容") },
            modifier = Modifier.weight(1f).testTag("group-rule-content"),
        )
    }
    Button(onClick = viewModel::createRule, enabled = !uiState.isSubmitting, modifier = Modifier.testTag("create-group-rule")) {
        Text("新增群规")
    }
    uiState.rules.forEach { rule ->
        Column(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
            Text("${rule.title} · ${if (rule.isActive) "启用" else "停用"}", fontWeight = FontWeight.SemiBold)
            Text(rule.content, style = MaterialTheme.typography.bodyMedium)
            Row {
                TextButton(onClick = { viewModel.deactivateRule(rule) }) {
                    Text("停用")
                }
                TextButton(onClick = { viewModel.deleteRule(rule) }) {
                    Text("删除")
                }
            }
        }
    }
}

@Composable
private fun GroupManagementListsPanel(uiState: GroupManagementUiState, viewModel: GroupManagementViewModel) {
    Text("管理员 · ${uiState.admins.size}", fontWeight = FontWeight.SemiBold)
    uiState.admins.forEach { admin ->
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text("${admin.adminId} · ${admin.role}", modifier = Modifier.weight(1f))
            TextButton(onClick = { viewModel.removeAdmin(admin) }) {
                Text("移除")
            }
        }
    }
    Text("禁言 · ${uiState.mutes.size}", fontWeight = FontWeight.SemiBold)
    uiState.mutes.forEach { mute ->
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text("${mute.userId} · ${mute.reason ?: "禁言"}", modifier = Modifier.weight(1f))
            TextButton(onClick = { viewModel.unmute(mute) }) {
                Text("解除")
            }
        }
    }
    Text("操作日志 · ${uiState.logs.size}", fontWeight = FontWeight.SemiBold)
    uiState.logs.take(10).forEach { log ->
        Text("${log.operationType} · ${log.operatorId}", style = MaterialTheme.typography.bodySmall)
    }
}
