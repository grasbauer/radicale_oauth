"""Integration tests for the running radicale pod.

Run with: pytest test_integration.py
Requires the pod to be running (see build.sh).
"""
from __future__ import annotations

import base64
import os
import urllib.error
import urllib.request

BASE = f"http://localhost:{os.environ.get('PORT', '5232')}"


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_, **__):
        return None


def _request(
    method: str,
    path: str,
    headers: dict[str, str] | None = None,
    auth: tuple[str, str] | None = None,
):
    req = urllib.request.Request(
        f"{BASE}{path}", method=method, headers=headers or {}
    )
    if auth:
        token = base64.b64encode(
            f"{auth[0]}:{auth[1]}".encode()
        ).decode()
        req.add_header("Authorization", f"Basic {token}")

    opener = urllib.request.build_opener(_NoRedirect())
    try:
        return opener.open(req)
    except urllib.error.HTTPError as exc:
        return exc


# --- browser flow ---


def test_web_ui_redirects_when_unauthenticated():
    response = _request("GET", "/.web/")
    assert response.status == 302


def test_web_ui_redirect_targets_oidc_provider():
    response = _request("GET", "/.web/")
    assert "openid-connect/auth" in response.headers.get("Location", "")


# --- DAV flow ---


def test_propfind_without_auth_returns_401():
    response = _request("PROPFIND", "/")
    assert response.status == 401


def test_propfind_sends_basic_auth_challenge():
    response = _request("PROPFIND", "/")
    www_authenticate = response.headers.get("WWW-Authenticate", "")
    assert 'Basic realm="Radicale"' in www_authenticate


def test_propfind_with_bad_credentials_returns_401():
    response = _request(
        "PROPFIND", "/", auth=("nobody@example.com", "wrong")
    )
    assert response.status == 401


# --- spoofing protection ---


def test_untrusted_x_remote_user_header_is_ignored():
    response = _request(
        "GET", "/.web/",
        headers={"X-Remote-User": "attacker@example.com"},
    )
    assert response.status == 302


# --- oauth2-proxy ---


def test_oauth2_sign_in_redirects_to_provider():
    # SKIP_PROVIDER_BUTTON=true skips the provider-selection page.
    response = _request("GET", "/oauth2/sign_in")
    assert response.status == 302
