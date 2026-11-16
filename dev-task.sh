#!/usr/bin/env bash
# Development tasks on a Flutter project mounted READ-WRITE at $APP_WORKDIR (default /work/app).
# Files created or changed by the tools (build/, .dart_tool/, generated *.g.dart ...) are given back to the host user.
#
#   dev-task analyze          flutter pub get + flutter analyze
#   dev-task test [args]      flutter pub get + flutter test [args]
#   dev-task codegen          flutter pub get + dart run build_runner build --delete-conflicting-outputs
#   dev-task shell            interactive bash
#   dev-task <any command>    e.g.  dev-task flutter format lib test    or    dev-task scripts/check_permissions.sh some.apk
set -uo pipefail

APP="${APP_WORKDIR:-/work/app}"
if [ ! -f "$APP/pubspec.yaml" ]; then
  echo "error: no pubspec.yaml in $APP - mount your Flutter project there (APP_DIR in compose)." >&2
  exit 2
fi
cd "$APP"

fix_owner() {
  if [ -n "${HOST_UID:-}" ]; then
    chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$APP" 2>/dev/null || true
    [ -d /root/.android ] && chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" /root/.android 2>/dev/null || true
  fi
}
trap fix_owner EXIT

task="${1:-}"
case "$task" in
  analyze) flutter pub get && flutter analyze ;;
  test)    shift; flutter pub get && flutter test "$@" ;;
  codegen) flutter pub get && dart run build_runner build --delete-conflicting-outputs ;;
  shell)   bash ;;
  "")      echo "usage: dev-task analyze | test [args] | codegen | shell | <command...>" >&2; exit 2 ;;
  *)       "$@" ;;
esac
