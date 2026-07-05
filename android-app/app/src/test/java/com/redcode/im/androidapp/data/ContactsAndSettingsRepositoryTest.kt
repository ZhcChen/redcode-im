package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.core.model.DocumentContent
import com.redcode.im.androidapp.core.config.RedCodeEnvironment
import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import com.redcode.im.androidapp.data.contacts.InMemoryContactsRepository
import com.redcode.im.androidapp.data.settings.InMemorySettingsRepository
import com.redcode.im.androidapp.data.settings.RemoteSettingsRepository
import com.redcode.im.androidapp.network.APIClient
import com.redcode.im.androidapp.network.HttpResponse
import com.redcode.im.androidapp.network.RecordingTransport
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ContactsAndSettingsRepositoryTest {
    @Test
    fun contacts_searchAndUpsertAreDeterministic() =
        runTest {
            val repository = InMemoryContactsRepository()

            assertEquals(emptyList<Contact>(), repository.search(" "))
            assertEquals("alice", repository.search("ali").single().accountName)
            assertEquals("bob", repository.search("Bob").single().accountName)
            repository.addLocalContact(Contact("user-charlie", "charlie", "Charlie"))
            repository.addLocalContact(Contact("user-charlie", "charlie2", "Charlie B"))
            assertEquals("charlie2", repository.search("Charlie B").single().accountName)

            val contacts = repository.contacts.first()
            assertEquals(3, contacts.size)
            assertEquals("charlie2", contacts.single { it.userId == "user-charlie" }.accountName)
        }

    @Test
    fun settings_toggleNotificationPersistsInStateFlow() =
        runTest {
            val repository = InMemorySettingsRepository()
            assertTrue(repository.settings.value.notificationEnabled)

            repository.setNotificationEnabled(false)

            assertEquals(false, repository.settings.value.notificationEnabled)
            repository.setNotificationEnabled(true)
            assertEquals(true, repository.settings.value.notificationEnabled)
        }

    @Test
    fun settings_fetchDocumentReturnsConfiguredContent() =
        runTest {
            val repository =
                InMemorySettingsRepository(
                    mapOf(
                        SettingsDocumentKind.UserAgreement to DocumentContent("协议", "terms"),
                        SettingsDocumentKind.PrivacyPolicy to DocumentContent("隐私", "privacy"),
                    ),
                )

            assertEquals("terms", repository.fetchDocument(SettingsDocumentKind.UserAgreement).content)
            assertEquals("privacy", repository.fetchDocument(SettingsDocumentKind.PrivacyPolicy).content)
        }

    @Test
    fun remoteSettings_fetchDocumentUsesPublicSettingsEndpoint() =
        runTest {
            val transport =
                RecordingTransport(
                    HttpResponse(200, """{"title":"用户协议","content":"<p>terms</p>","updated_at":null}"""),
                )
            val repository = RemoteSettingsRepository(APIClient(RedCodeEnvironment.localEmulator(), transport))

            val document = repository.fetchDocument(SettingsDocumentKind.UserAgreement)

            assertEquals("用户协议", document.title)
            assertEquals("<p>terms</p>", document.content)
            assertEquals("http://10.0.2.2:8010/settings/user-agreement", transport.lastRequest.url)
        }

    @Test
    fun remoteSettings_supportsPrivacyDocumentAndNotificationState() =
        runTest {
            val transport =
                RecordingTransport(
                    HttpResponse(200, """{"title":"隐私协议","content":"<p>privacy</p>","updated_at":"2026-07-05T00:00:00Z"}"""),
                )
            val repository = RemoteSettingsRepository(APIClient(RedCodeEnvironment.localEmulator(), transport))

            repository.setNotificationEnabled(false)
            val document = repository.fetchDocument(SettingsDocumentKind.PrivacyPolicy)

            assertEquals(false, repository.settings.value.notificationEnabled)
            assertEquals("隐私协议", document.title)
            assertEquals("2026-07-05T00:00:00Z", document.updatedAt)
            assertEquals("http://10.0.2.2:8010/settings/privacy-policy", transport.lastRequest.url)
        }
}
