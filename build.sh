#!/bin/bash
set -euo pipefail

POD_NAME="radicale-pod"
IMAGE="localhost/radicale:latest"
PORT="${PORT:-5232}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
CONFIG_DIR="${SCRIPT_DIR}/config"
ENV_FILE="${SCRIPT_DIR}/.env"

mkdir -p "${DATA_DIR}"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: ${ENV_FILE} missing. Copy .env.example and fill it in." >&2
    exit 1
fi

_env() { grep "^$1=" "${ENV_FILE}" | cut -d= -f2-; }
CLIENT_ID=$(_env OAUTH2_CLIENT_ID)
CLIENT_SECRET=$(_env OAUTH2_CLIENT_SECRET)
ISSUER_URL=$(_env OAUTH2_ISSUER_URL)
COOKIE_SECRET=$(_env OAUTH2_COOKIE_SECRET)
COOKIE_SECURE=$(_env OAUTH2_COOKIE_SECURE)
IMAP_HOST=$(_env IMAP_HOST)

echo "==> Building image..."
podman build -t "${IMAGE}" -f Containerfile "${SCRIPT_DIR}"

echo "==> Resetting pod..."
podman pod rm -f "${POD_NAME}" 2>/dev/null || true
podman rm -f radicale-app radicale-oauth2-proxy radicale-caddy 2>/dev/null || true
podman pod create --name "${POD_NAME}" -p "${PORT}:5232"

RADICALE_CONFIG="${CONFIG_DIR}/config-pod.generated"
sed "s|__IMAP_HOST__|${IMAP_HOST}|g" "${CONFIG_DIR}/config-pod" > "${RADICALE_CONFIG}"

echo "==> Starting radicale..."
podman run -d \
  --name radicale-app \
  --pod "${POD_NAME}" \
  -v "${RADICALE_CONFIG}:/etc/radicale/config:ro,Z" \
  -v "${DATA_DIR}:/data:Z" \
  "${IMAGE}"

echo "==> Starting oauth2-proxy..."
podman run -d \
  --name radicale-oauth2-proxy \
  --pod "${POD_NAME}" \
  -e OAUTH2_PROXY_PROVIDER=oidc \
  -e OAUTH2_PROXY_OIDC_ISSUER_URL="${ISSUER_URL}" \
  -e OAUTH2_PROXY_CLIENT_ID="${CLIENT_ID}" \
  -e OAUTH2_PROXY_CLIENT_SECRET="${CLIENT_SECRET}" \
  -e OAUTH2_PROXY_COOKIE_SECRET="${COOKIE_SECRET}" \
  -e OAUTH2_PROXY_COOKIE_SECURE="${COOKIE_SECURE}" \
  -e OAUTH2_PROXY_EMAIL_DOMAINS="*" \
  -e OAUTH2_PROXY_HTTP_ADDRESS="0.0.0.0:4180" \
  -e OAUTH2_PROXY_UPSTREAMS="static://200" \
  -e OAUTH2_PROXY_REDIRECT_URL="http://localhost:${PORT}/oauth2/callback" \
  -e OAUTH2_PROXY_SKIP_PROVIDER_BUTTON="true" \
  -e OAUTH2_PROXY_SET_XAUTHREQUEST="true" \
  -e OAUTH2_PROXY_PREFER_EMAIL_TO_USER="true" \
  quay.io/oauth2-proxy/oauth2-proxy:v7.8.2

echo "==> Starting caddy..."
podman run -d \
  --name radicale-caddy \
  --pod "${POD_NAME}" \
  -v "${CONFIG_DIR}/Caddyfile:/etc/caddy/Caddyfile:ro,Z" \
  docker.io/caddy:alpine

echo
echo "==> http://localhost:${PORT}/"
