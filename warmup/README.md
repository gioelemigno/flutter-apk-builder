# Warm-up profiles

A profile is a folder here that describes an app whose dependencies get baked into the image:

    warmup/<profile>/pubspec.yaml        the packages (the `name:` is used as the project name)
    warmup/<profile>/pubspec.lock        exact versions (keep it: Gradle artifacts follow the plugin versions)
    warmup/<profile>/build.gradle.kts    android/app/build.gradle.kts of that app (e.g. the desugaring dependency)

The Dockerfile creates a throw-away project from the profile, builds it once in release mode and deletes it, so the
Gradle and pub caches stay in the image. Profiles:

- `base`    - no folder: a bare `flutter create` template (tag `3.47.9`).
- `common`  - the packages of the Timegrapher Log app (tag `3.47.9-common`, built on top of the `3.47.9` image).
- `none`    - no warm-up at all (only refreshes the scripts; useful for quick tests).

To add packages: edit `warmup/common/pubspec.yaml` and run `flutter pub get` in a project that uses it to refresh the lock file
(or copy the app's `pubspec.yaml` + `pubspec.lock`), then rebuild the image with `./build-image.sh common`.
