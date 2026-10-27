#!/usr/bin/env bash
set -Eeuo pipefail

# Prepare a clean Ubuntu 24.04 host to run this repository's Jenkins pipeline.
# Run with: sudo bash scripts/prepare-jenkins-ubuntu24.sh

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo: sudo bash $0" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot identify the operating system (missing /etc/os-release)." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "This script supports Ubuntu 24.04 only; found ${PRETTY_NAME:-unknown}." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl fontconfig git gnupg openjdk-21-jre

install -d -m 0755 /etc/apt/keyrings

# Node.js 22, matching the Node major version used by the Docker images.
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg
cat > /etc/apt/sources.list.d/nodesource.sources <<EOF
Types: deb
URIs: https://deb.nodesource.com/node_22.x
Suites: nodistro
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/nodesource.gpg
EOF

# Docker Engine and the Compose v2 plugin, required by Jenkinsfile.
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Jenkins LTS signing key and package repository. See the official Jenkins docs.
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  -o /etc/apt/keyrings/jenkins-keyring.asc
chmod a+r /etc/apt/keyrings/jenkins-keyring.asc
cat > /etc/apt/sources.list.d/jenkins.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/
EOF

apt-get update
apt-get install -y nodejs docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin jenkins

systemctl enable --now docker
systemctl enable --now jenkins

# Required for the pipeline's `docker compose` commands. Membership grants
# root-equivalent access on this machine; only trusted Jenkins jobs should run.
usermod -aG docker jenkins
systemctl restart jenkins

echo
echo "Installed tool versions:"
java -version
node --version
npm --version
docker --version
docker compose version

echo
echo "Jenkins service:"
systemctl --no-pager --full status jenkins || true

if [[ -r /var/lib/jenkins/secrets/initialAdminPassword ]]; then
  echo
  echo "Jenkins initial administrator password:"
  cat /var/lib/jenkins/secrets/initialAdminPassword
fi

echo
echo "Setup complete. Open Jenkins on port 8080, complete its first-run setup,"
echo "then create a Pipeline job pointing to this repository's Jenkinsfile."
