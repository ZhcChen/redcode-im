package com.redcode.im.androidapp.data.settings

import com.redcode.im.androidapp.core.model.SettingsDocumentKind
import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod

object SettingsAPIEndpoint {
    fun document(kind: SettingsDocumentKind): APIEndpoint =
        when (kind) {
            SettingsDocumentKind.PrivacyPolicy -> APIEndpoint(HTTPMethod.GET, "/settings/privacy-policy")
            SettingsDocumentKind.UserAgreement -> APIEndpoint(HTTPMethod.GET, "/settings/user-agreement")
        }
}
