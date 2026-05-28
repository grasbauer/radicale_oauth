# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2024 Jan Grasnick
"""
Hybrid Radicale auth: IMAP for DAV clients + trusted X-Remote-User header
for the web UI (set by oauth2-proxy via Caddy forward_auth).
"""
from __future__ import annotations
from typing import Tuple, Union

from radicale import types
from radicale.auth import imap as _upstream
from radicale.log import logger


class Auth(_upstream.Auth):
    def get_external_login(self, environ: types.WSGIEnviron) -> Union[
            Tuple[()], Tuple[str, str]]:
        user = environ.get("HTTP_X_REMOTE_USER", "").strip()
        if user:
            logger.debug("auth_hybrid: trusted header login for %r", user)
            return user, ""
        return ()

    def _login_ext(self, login: str, password: str, context) -> str:
        if login and not password:
            return login
        return super()._login_ext(login, password, context)
