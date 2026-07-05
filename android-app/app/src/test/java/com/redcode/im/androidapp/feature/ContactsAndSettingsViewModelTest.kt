package com.redcode.im.androidapp.feature

import com.redcode.im.androidapp.core.model.DocumentContent
import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import com.redcode.im.androidapp.MainDispatcherRule
import com.redcode.im.androidapp.core.model.AppSettings
import com.redcode.im.androidapp.data.contacts.InMemoryContactsRepository
import com.redcode.im.androidapp.data.settings.InMemorySettingsRepository
import com.redcode.im.androidapp.data.settings.SettingsRepository
import com.redcode.im.androidapp.feature.contacts.ContactsViewModel
import com.redcode.im.androidapp.feature.settings.SettingsViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.ExperimentalCoroutinesApi
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
