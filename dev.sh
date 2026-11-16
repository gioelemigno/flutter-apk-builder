#!/usr/bin/env bash
# Development tasks inside the container, on a project mounted read-write.
#   APP_DIR=/path/to/project ./dev.sh analyze
#   APP_DIR=/path/to/project ./dev.sh test
#   APP_DIR=/path/to/project ./dev.sh codegen
#   APP_DIR=/path/to/project ./dev.sh flutter format lib test
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out keystore
HOST_UID="$(id -u)" HOST_GID="$(id -g)" exec docker compose run --rm dev dev-task "$@"
