package com.redcode.im.androidapp.data.auth

import com.redcode.im.androidapp.network.APIEndpoint
import com.redcode.im.androidapp.network.HTTPMethod

object AuthAPIEndpoint {
    val register = APIEndpoint(HTTPMethod.POST, "/auth/register")
    val login = APIEndpoint(HTTPMethod.POST, "/auth/login")
    val me = APIEndpoint(HTTPMethod.GET, "/auth/me")
    val refresh = APIEndpoint(HTTPMethod.POST, "/auth/refresh")
}
