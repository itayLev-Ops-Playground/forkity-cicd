#!/usr/bin/env bash
set -Eeuo pipefail

failures=0

check() {
  local description="$1"
  shift
  printf '%-34s' "$description"
  if "$@"; then
    echo "OK"
  else
    echo "FAILED"
    failures=$((failures + 1))
  fi
}

check "Java 21+" bash -c 'java -version 2>&1 | grep -Eq "version \"(21|2[2-9]|[3-9][0-9])"'
check "Node.js 22+" bash -c 'node -e "process.exit(Number(process.versions.node.split(\".\")[0]) >= 22 ? 0 : 1)"'
check "npm" command -v npm
check "Git" command -v git
check "Docker CLI" command -v docker
check "Docker daemon" docker info
check "Docker Compose v2" docker compose version
check "Jenkins service" systemctl is-active --quiet jenkins
check "Docker daemon access" bash -c 'docker info >/dev/null 2>&1'

if (( failures > 0 )); then
  echo
  echo "$failures check(s) failed. Review the setup output and Jenkins/Docker service logs." >&2
  exit 1
fi

echo
echo "All Jenkins host prerequisites are ready."
