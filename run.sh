#!/usr/bin/env bash
# Usage: [APP_DIR=path/to/project] [APK_NAME=name.apk] ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out keystore
HOST_UID="$(id -u)" HOST_GID="$(id -g)" exec docker compose run --rm build "$@"
