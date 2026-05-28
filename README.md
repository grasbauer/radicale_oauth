# radicale_oauth

Hybrid authentication for [Radicale](https://radicale.org/):
- **DAV clients** (Thunderbird, DAVx5, …) → IMAP authentication
- **Web UI** → OAuth2/OIDC via [oauth2-proxy](https://oauth2-proxy.github.io/) with automatic login

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Browser   │────▶│    Caddy     │────▶│ oauth2-proxy│──▶ Keycloak
│  (/.web/)   │     │  :5232       │     │  :4180      │
└─────────────┘     └──────────────┘     └─────────────┘
                           │
                           ▼ (Basic Auth)
                    ┌─────────────┐
                    │   Radicale  │──▶ IMAP
                    │   :5280     │
                    └─────────────┘
```

## Quick Start

```bash
# 1. Configure
cp .env.example .env
# Edit .env: IMAP_HOST, OAUTH2_* settings

# 2. Build & run
./build.sh

# 3. Test
pytest test_integration.py
```

## Configuration

| Variable | Description |
|----------|-------------|
| `IMAP_HOST` | IMAP server for DAV clients (e.g. `mail.example.com:993`) |
| `OAUTH2_CLIENT_ID` | OIDC client ID |
| `OAUTH2_CLIENT_SECRET` | OIDC client secret |
| `OAUTH2_ISSUER_URL` | Keycloak/realm URL |
| `OAUTH2_COOKIE_SECRET` | Random 32-byte base64 |
| `OAUTH2_COOKIE_SECURE` | `true` for HTTPS |

## License

GPL-3.0-or-later — same as Radicale.
