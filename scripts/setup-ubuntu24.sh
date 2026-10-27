#!/usr/bin/env bash
# Provision an Ubuntu 24.04 VM and run Forkity with Docker Compose.
# Run as root: sudo bash scripts/setup-ubuntu24.sh
set -Eeuo pipefail

readonly REPOSITORY_URL="${FORKITY_REPO_URL:-https://github.com/itayLev-Ops-Playground/Forkity-V1.git}"
readonly INSTALL_DIR="${FORKITY_INSTALL_DIR:-/opt/forkity}"

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || fail "Run as root, for example: sudo bash $0"
[[ -r /etc/os-release ]] || fail "Cannot identify this operating system."
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || \
  fail "This script supports Ubuntu 24.04; detected ${PRETTY_NAME:-unknown}."

export DEBIAN_FRONTEND=noninteractive
log "Installing required system packages"
apt-get update
apt-get install -y ca-certificates curl git openssl

log "Installing Docker Engine and Compose v2 from Docker's official repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

# If this script lives in a checkout with Compose, deploy that checkout. Otherwise
# use the configured install directory and clone only when it is not already a repo.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/compose.yaml" ]]; then
  PROJECT_DIR="${SCRIPT_DIR}"
else
  PROJECT_DIR="${INSTALL_DIR}"
  if [[ ! -f "${PROJECT_DIR}/compose.yaml" ]]; then
    log "Cloning Forkity into ${PROJECT_DIR}"
    install -d "$(dirname -- "${PROJECT_DIR}")"
    git clone --depth 1 "${REPOSITORY_URL}" "${PROJECT_DIR}"
  fi
fi
[[ -f "${PROJECT_DIR}/compose.yaml" ]] || fail "compose.yaml not found in ${PROJECT_DIR}."
cd "${PROJECT_DIR}"

log "Creating or checking the production environment file"
if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
  else
    cat > .env <<'EOF'
POSTGRES_DB=forkity
POSTGRES_USER=forkity
FORKITY_PORT=8080
EOF
  fi
fi
chmod 600 .env

# Replace the checked-in example password, or add one if the key is missing.
if ! grep -q '^POSTGRES_PASSWORD=' .env || \
   grep -Eq '^POSTGRES_PASSWORD=(change_me_before_use|paste_your_generated_password_here)?$' .env; then
  DB_PASSWORD="$(openssl rand -hex 32)"
  if grep -q '^POSTGRES_PASSWORD=' .env; then
    sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${DB_PASSWORD}/" .env
  else
    printf '\nPOSTGRES_PASSWORD=%s\n' "${DB_PASSWORD}" >> .env
  fi
  unset DB_PASSWORD
fi
grep -q '^POSTGRES_DB=' .env || printf '\nPOSTGRES_DB=forkity\n' >> .env
grep -q '^POSTGRES_USER=' .env || printf '\nPOSTGRES_USER=forkity\n' >> .env
grep -q '^FORKITY_PORT=' .env || printf '\nFORKITY_PORT=8080\n' >> .env
chmod 600 .env

WEB_PORT="$(sed -n 's/^FORKITY_PORT=//p' .env | tail -n 1 | tr -d '\r"' )"
[[ "${WEB_PORT}" =~ ^[0-9]{1,5}$ ]] && (( WEB_PORT >= 1 && WEB_PORT <= 65535 )) || \
  fail "FORKITY_PORT in .env must be a valid TCP port (1-65535)."

# If UFW is already active, permit SSH and the app port. Do not enable UFW or
# modify provider-level security groups automatically.
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
  log "Allowing SSH and TCP ${WEB_PORT} through the active UFW firewall"
  ufw allow OpenSSH
  ufw allow "${WEB_PORT}/tcp"
fi

log "Building and starting Forkity"
docker compose up --build -d

log "Waiting for the application health endpoint"
healthy=false
for attempt in $(seq 1 60); do
  if curl --silent --show-error --fail --max-time 3 "http://127.0.0.1:${WEB_PORT}/api/health" >/dev/null 2>&1; then
    healthy=true
    break
  fi
  sleep 5
done

docker compose ps
if [[ "${healthy}" != true ]]; then
  docker compose logs --tail=100
  fail "The health endpoint did not respond. Review the container logs above."
fi

PUBLIC_IP="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
log "Forkity is healthy at http://localhost:${WEB_PORT}"
if [[ -n "${PUBLIC_IP}" ]]; then
  printf 'External URL (also allow TCP %s in the cloud firewall/security group): http://%s:%s\n' "${WEB_PORT}" "${PUBLIC_IP}" "${WEB_PORT}"
else
  printf 'Allow inbound TCP %s in the VM provider firewall/security group to access this VM.\n' "${WEB_PORT}"
fi
printf 'Project directory: %s\n' "${PROJECT_DIR}"
printf 'Useful commands: cd %q && docker compose ps && docker compose logs -f\n' "${PROJECT_DIR}"
