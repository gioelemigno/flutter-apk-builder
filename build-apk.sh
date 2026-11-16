#!/usr/bin/env bash
# Builds a Flutter app (mounted read-only at $SRC_DIR) into a release APK copied to $OUT_DIR.
# The project is copied to a scratch directory first, so the host folder is never modified.
set -euo pipefail

SRC="${SRC_DIR:-/src}"
WORK="${WORK_DIR:-/work/app}"
OUT="${OUT_DIR:-/out}"
APK_NAME="${APK_NAME:-app-release.apk}"

if [ ! -f "$SRC/pubspec.yaml" ]; then
  echo "error: no pubspec.yaml in $SRC - mount your Flutter project there (APP_DIR in compose)." >&2
  exit 2
fi

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"
tar -C "$SRC" \
    --exclude=./build --exclude=./.dart_tool --exclude=./.git --exclude=./.gradle \
    --exclude=./android/.gradle --exclude=./android/local.properties \
    -cf - . | tar -C "$WORK" -xf -
cd "$WORK"

echo "== $(flutter --version 2>/dev/null | head -1)"
flutter pub get
if [ "${ANALYZE:-1}" != "0" ]; then
  flutter analyze
fi
# shellcheck disable=SC2086
flutter build apk --release ${BUILD_ARGS:-}

cp build/app/outputs/flutter-apk/app-release.apk "$OUT/$APK_NAME"

# Give the results to the host user instead of root.
if [ -n "${HOST_UID:-}" ]; then
  chown "$HOST_UID:${HOST_GID:-$HOST_UID}" "$OUT/$APK_NAME"
  [ -d /root/.android ] && chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" /root/.android || true
fi

echo "== done"
ls -l "$OUT/$APK_NAME"
md5sum "$OUT/$APK_NAME"
