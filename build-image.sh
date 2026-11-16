#!/usr/bin/env bash
# Builds (and optionally pushes) the image for a warm-up profile.
#   ./build-image.sh base            -> <REGISTRY>/flutter-apk-builder:3.47.9
#   ./build-image.sh common          -> <REGISTRY>/flutter-apk-builder:3.47.9-common   (built on top of the 3.47.9 image)
#   ./build-image.sh common --push   also uploads it (after `docker login`)
# REGISTRY comes from .env (default docker.io/gmigno). Needs normal internet access, takes several minutes.
set -euo pipefail
cd "$(dirname "$0")"

FLUTTER_VERSION=3.47.9
profile="${1:?usage: ./build-image.sh <base|common> [--push]}"
push="${2:-}"

set -a
[ -f .env ] && . ./.env
set +a
REGISTRY="${REGISTRY:-docker.io/gmigno}"

case "$profile" in
  base)
    IMAGE_TAG="$FLUTTER_VERSION"
    unset BASE_IMAGE || true          # the Dockerfile default (gmeligio, pinned by digest)
    ;;
  common)
    IMAGE_TAG="$FLUTTER_VERSION-common"
    BASE_IMAGE="$REGISTRY/flutter-apk-builder:$FLUTTER_VERSION"
    ;;
  *)
    test -d "warmup/$profile" || { echo "unknown profile: $profile (no warmup/$profile folder)" >&2; exit 2; }
    IMAGE_TAG="$FLUTTER_VERSION-$profile"
    BASE_IMAGE="$REGISTRY/flutter-apk-builder:$FLUTTER_VERSION"
    ;;
esac
export REGISTRY IMAGE_TAG WARMUP_PROFILE="$profile"
[ -n "${BASE_IMAGE:-}" ] && export BASE_IMAGE

echo "== building $REGISTRY/flutter-apk-builder:$IMAGE_TAG (profile $profile${BASE_IMAGE:+, base $BASE_IMAGE})"
docker compose build build
if [ "$push" = "--push" ]; then
  docker compose push build
fi
docker images --digests "$REGISTRY/flutter-apk-builder"
