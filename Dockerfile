# syntax=docker/dockerfile:1.7
#
# Flutter -> Android APK builder, based on the community image gmeligio/flutter-android.
# Pinned by digest so every machine / agent gets exactly the same bits.
#
#   Flutter 3.47.9 (c197ca5199e9), Dart 3.13.7, Android SDK platform 36, build-tools 36.0.0,
#   NDK 28.2.13676358, cmake 3.22.1, JDK 17 (the project targets Java 17 anyway).
#
# Tags are produced with ./build-image.sh:
#   3.47.9          WARMUP_PROFILE=base    bare template warmed up           (BASE_IMAGE = gmeligio, the default below)
#   3.47.9-common   WARMUP_PROFILE=common  + packages of warmup/common       (BASE_IMAGE = the 3.47.9 image above)
#
# To bump Flutter: change the default BASE_IMAGE
#   (docker buildx imagetools inspect ghcr.io/gmeligio/flutter-android:<version> | head -3).

ARG BASE_IMAGE=ghcr.io/gmeligio/flutter-android:3.47.9@sha256:7a05773211d493efe2c048196cd9a32418cfc00679d254729bdc00f45cc20816

# Optional build-time extras (empty by default). Behind a TLS-intercepting proxy, pass a directory with
#   docker build --build-context build-extras=./extras .
# If it contains an `env.sh`, it is sourced during the warm-up step below (proxy variables, CA bundle,
# JAVA_TOOL_OPTIONS with a trust store...). Nothing from it ends up in the final image.
FROM scratch AS build-extras

FROM ${BASE_IMAGE}

# base | common | none (see warmup/README.md)
ARG WARMUP_PROFILE=base

LABEL org.opencontainers.image.title="flutter-apk-builder"

# Same locations for the image's user (build-time warm-up) and for root (runtime), so the cache is shared.
ENV CI=true \
    GRADLE_USER_HOME=/home/flutter/.gradle \
    PUB_CACHE=/home/flutter/.pub-cache \
    FLUTTER_SUPPRESS_ANALYTICS=true

# The Flutter SDK is owned by `flutter`; let git accept it when we run as root.
USER root
RUN git config --system --get-all safe.directory | grep -qx '\*' || git config --system --add safe.directory '*'

# ---- Warm-up: download Gradle 9.3.1, AGP 9.1.0, Kotlin, all Maven artifacts and pub packages ----
# A throw-away app is built once in release mode, so later builds find everything in the cache.
#   base   : a bare `flutter create` template
#   <name> : the app described by warmup/<name>/ (pubspec.yaml + pubspec.lock + build.gradle.kts)
#   none   : skip (only the scripts below are refreshed)
USER flutter
WORKDIR /tmp
RUN --mount=type=bind,from=build-extras,target=/extras \
    --mount=type=bind,source=warmup,target=/warmup \
    set -eux; \
    if [ "$WARMUP_PROFILE" = none ]; then echo "warm-up skipped"; exit 0; fi; \
    if [ -f /extras/env.sh ]; then . /extras/env.sh; fi; \
    if [ "$WARMUP_PROFILE" = base ]; then \
      name=warmup; \
      flutter create "$name" --org com.example --platforms android; \
    else \
      p="/warmup/$WARMUP_PROFILE"; \
      test -f "$p/pubspec.yaml" -a -f "$p/pubspec.lock" -a -f "$p/build.gradle.kts"; \
      name="$(sed -n 's/^name: *//p' "$p/pubspec.yaml" | head -1)"; \
      flutter create "$name" --org com.example --platforms android; \
      cp "$p/pubspec.yaml" "$p/pubspec.lock" "/tmp/$name/"; \
      cp "$p/build.gradle.kts" "/tmp/$name/android/app/build.gradle.kts"; \
      (cd "/tmp/$name" && flutter pub get); \
    fi; \
    cd "/tmp/$name"; \
    flutter build apk --release; \
    (cd android && ./gradlew --stop) || true; \
    cd /tmp && rm -rf "/tmp/$name"; \
    rm -rf /home/flutter/.android/debug.keystore   # signing keys never live in the image

# ---- Entrypoints ----
USER root
COPY --chmod=755 build-apk.sh /usr/local/bin/build-apk
COPY --chmod=755 dev-task.sh /usr/local/bin/dev-task
WORKDIR /work
CMD ["build-apk"]
