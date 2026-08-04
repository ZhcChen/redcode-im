package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.MainDispatcherRule
import com.redcode.im.androidapp.data.contacts.InMemoryContactsRepository
import com.redcode.im.androidapp.data.rooms.InMemoryRoomRepository
import com.redcode.im.androidapp.feature.rooms.GroupManagementViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class GroupManagementViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun createsSelectsAndUpdatesGroup() =
        runTest {
            val viewModel = GroupManagementViewModel(InMemoryRoomRepository(), InMemoryContactsRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onGroupNameChange("Android Group")
            viewModel.onGroupDescriptionChange("desc")
            viewModel.toggleCreateMember("user-alice")
            viewModel.createGroup()
            advanceUntilIdle()

            val created = viewModel.uiState.value.selectedRoom
            assertNotNull(created)
            assertEquals("Android Group", created?.name)
            assertEquals(2, viewModel.uiState.value.members.size)

            viewModel.onEditNameChange("Renamed")
            viewModel.onEditDescriptionChange("updated")
            viewModel.updateSelectedRoom()
            advanceUntilIdle()

            assertEquals("Renamed", viewModel.uiState.value.selectedRoom?.name)
            collectJob.cancel()
        }

    @Test
    fun managesSettingsRulesAndMembers() =
        runTest {
            val viewModel = GroupManagementViewModel(InMemoryRoomRepository(), InMemoryContactsRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()
            viewModel.onGroupNameChange("Managed")
            viewModel.toggleCreateMember("user-alice")
            viewModel.createGroup()
            advanceUntilIdle()

            viewModel.toggleJoinApproval()
            viewModel.toggleGlobalMute()
            viewModel.onRuleTitleChange("Rule")
            viewModel.onRuleContentChange("Content")
            viewModel.createRule()
            viewModel.toggleCreateMember("user-bob")
            viewModel.addSelectedContactsToRoom()
            advanceUntilIdle()

            val state = viewModel.uiState.value
            assertEquals(true, state.settings?.settings?.joinApprovalRequired)
            assertEquals(true, state.settings?.settings?.globalMuteEnabled)
            assertEquals("Rule", state.rules.single().title)
            assertEquals(true, state.members.any { it.userId == "user-bob" })
            assertEquals(true, state.logs.isNotEmpty())
            collectJob.cancel()
        }
}
