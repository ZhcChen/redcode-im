package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.core.model.DocumentContent
import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import com.redcode.im.androidapp.MainDispatcherRule
import com.redcode.im.androidapp.core.model.AppSettings
import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.FriendRequest
import com.redcode.im.androidapp.core.model.FriendRequestStatus
import com.redcode.im.androidapp.data.contacts.ContactsRepository
import com.redcode.im.androidapp.data.contacts.InMemoryContactsRepository
import com.redcode.im.androidapp.data.settings.InMemorySettingsRepository
import com.redcode.im.androidapp.data.settings.SettingsRepository
import com.redcode.im.androidapp.feature.contacts.ContactsViewModel
import com.redcode.im.androidapp.feature.settings.SettingsViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ContactsAndSettingsViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun contacts_searchAndAddClearsSearchState() =
        runTest {
            val viewModel = ContactsViewModel(InMemoryContactsRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.onQueryChange("alice")
            viewModel.search()
            advanceUntilIdle()
            val alice = viewModel.uiState.value.searchResults.single()
            viewModel.addContact(alice)
            advanceUntilIdle()

            assertEquals("", viewModel.uiState.value.query)
            assertEquals(emptyList<Any>(), viewModel.uiState.value.searchResults)
            assertEquals(alice.userId, viewModel.uiState.value.outgoingRequests.single().counterpartyUserId)
            collectJob.cancel()
        }

    @Test
    fun contacts_acceptIncomingRequestAddsContact() =
        runTest {
            val viewModel = ContactsViewModel(InMemoryContactsRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.respondRequest("request-mia", accept = true)
            advanceUntilIdle()

            assertEquals(FriendRequestStatus.Accepted, viewModel.uiState.value.incomingRequests.single().status)
            assertEquals("Mia", viewModel.uiState.value.contacts.single { it.userId == "user-mia" }.displayName)
            collectJob.cancel()
        }

    @Test
    fun contacts_openPrivateChatEmitsRoomId() =
        runTest {
            val viewModel = ContactsViewModel(InMemoryContactsRepository())
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            var openedRoomId = ""
            advanceUntilIdle()

            viewModel.openPrivateChat(Contact("user-bob", "bob", "Bob")) { roomId ->
                openedRoomId = roomId
            }
            advanceUntilIdle()

            assertEquals("room-private-user-bob", openedRoomId)
            assertEquals(false, viewModel.uiState.value.isSubmitting)
            collectJob.cancel()
        }

    @Test
    fun contacts_refreshFailureShowsError() =
        runTest {
            val viewModel =
                ContactsViewModel(
                    object : ContactsRepository {
                        override val contacts: Flow<List<Contact>> = MutableStateFlow(emptyList())
                        override val incomingRequests: Flow<List<FriendRequest>> = MutableStateFlow(emptyList())
                        override val outgoingRequests: Flow<List<FriendRequest>> = MutableStateFlow(emptyList())

                        override suspend fun refreshContacts() {
                            throw IllegalStateException("boom")
                        }

                        override suspend fun search(query: String): List<Contact> = emptyList()

                        override suspend fun addLocalContact(contact: Contact) = Unit
                    },
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            assertEquals("boom", viewModel.uiState.value.errorMessage)
            collectJob.cancel()
        }

    @Test
    fun contacts_operationFailuresSetErrorsAndBlankRoomDoesNotOpen() =
        runTest {
            val contactState = MutableStateFlow(listOf(Contact("user-a", "alice", "Alice")))
            val repository =
                object : ContactsRepository {
                    override val contacts: Flow<List<Contact>> = contactState
                    override val incomingRequests: Flow<List<FriendRequest>> = MutableStateFlow(emptyList())
                    override val outgoingRequests: Flow<List<FriendRequest>> = MutableStateFlow(emptyList())

                    override suspend fun search(query: String): List<Contact> {
                        throw IllegalStateException("search failed")
                    }

                    override suspend fun addLocalContact(contact: Contact) = Unit

                    override suspend fun sendFriendRequest(targetUserId: String, message: String?) {
                        throw IllegalStateException("request failed")
                    }

                    override suspend fun ensurePrivateChat(friendUserId: String): String? = ""
                }
            val viewModel = ContactsViewModel(repository)
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            var opened = false
            advanceUntilIdle()

            viewModel.search()
            advanceUntilIdle()
            assertEquals("search failed", viewModel.uiState.value.errorMessage)

            viewModel.addContact(Contact("user-a", "alice", "Alice"))
            advanceUntilIdle()
            assertEquals("request failed", viewModel.uiState.value.errorMessage)

            viewModel.openPrivateChat(Contact("user-a", "alice", "Alice")) {
                opened = true
            }
            advanceUntilIdle()

            assertEquals(false, opened)
            assertEquals(false, viewModel.uiState.value.isSubmitting)
            collectJob.cancel()
        }

    @Test
    fun contacts_respondFailureAndOpenFailureSetErrors() =
        runTest {
            val viewModel =
                ContactsViewModel(
                    object : ContactsRepository {
                        override val contacts: Flow<List<Contact>> = MutableStateFlow(emptyList())
                        override val incomingRequests: Flow<List<FriendRequest>> = MutableStateFlow(emptyList())
                        override val outgoingRequests: Flow<List<FriendRequest>> = MutableStateFlow(emptyList())

                        override suspend fun search(query: String): List<Contact> = emptyList()

                        override suspend fun addLocalContact(contact: Contact) = Unit

                        override suspend fun respondFriendRequest(requestId: String, accept: Boolean) {
                            throw IllegalStateException("respond failed")
                        }

                        override suspend fun ensurePrivateChat(friendUserId: String): String? {
                            throw IllegalStateException("open failed")
                        }
                    },
                )
            val collectJob = backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { viewModel.uiState.collect() }
            advanceUntilIdle()

            viewModel.respondRequest("missing", accept = false)
            advanceUntilIdle()
            assertEquals("respond failed", viewModel.uiState.value.errorMessage)

            viewModel.openPrivateChat(Contact("user-a", "alice", "Alice")) {}
            advanceUntilIdle()
            assertEquals("open failed", viewModel.uiState.value.errorMessage)
            collectJob.cancel()
        }

    @Test
    fun settings_toggleNotification() =
        runTest {
            val viewModel = SettingsViewModel(InMemorySettingsRepository())

            viewModel.toggleNotification()
            advanceUntilIdle()

            assertEquals(false, viewModel.settings.value.notificationEnabled)
            viewModel.toggleNotification()
            advanceUntilIdle()
            assertEquals(true, viewModel.settings.value.notificationEnabled)
        }

    @Test
    fun settings_loadAndDismissDocument() =
        runTest {
            val viewModel =
                SettingsViewModel(
                    InMemorySettingsRepository(
                        mapOf(
                            SettingsDocumentKind.PrivacyPolicy to DocumentContent("隐私协议", "privacy"),
                            SettingsDocumentKind.UserAgreement to DocumentContent("用户协议", "terms"),
                        ),
                    ),
                )

            viewModel.loadDocument(SettingsDocumentKind.PrivacyPolicy)
            advanceUntilIdle()

            assertEquals("隐私协议", viewModel.document.value.document?.title)
            assertEquals(false, viewModel.document.value.isLoading)

            viewModel.dismissDocument()
            assertEquals(null, viewModel.document.value.kind)
        }

    @Test
    fun settings_loadDocumentFailureShowsFallbackMessage() =
        runTest {
            val viewModel =
                SettingsViewModel(
                    object : SettingsRepository {
                        override val settings = MutableStateFlow(AppSettings())

                        override suspend fun setNotificationEnabled(enabled: Boolean) {
                            settings.value = settings.value.copy(notificationEnabled = enabled)
                        }

                        override suspend fun fetchDocument(kind: SettingsDocumentKind): DocumentContent {
                            throw RuntimeException()
                        }
                    },
                )

            viewModel.loadDocument(SettingsDocumentKind.UserAgreement)
            advanceUntilIdle()

            assertEquals("用户协议加载失败", viewModel.document.value.errorMessage)
            assertEquals(null, viewModel.document.value.document)
        }
}
