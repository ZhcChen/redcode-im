package com.redcode.im.androidapp.data

import com.redcode.im.androidapp.core.model.Contact
import com.redcode.im.androidapp.data.contacts.InMemoryContactsRepository
import com.redcode.im.androidapp.data.settings.InMemorySettingsRepository
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
}
