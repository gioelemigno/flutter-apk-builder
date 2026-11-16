# flutter-apk-builder

Docker image + compose wrapper that build Flutter projects into release APKs, with the Gradle and pub caches baked in.
Published on Docker Hub as `gmigno/flutter-apk-builder`. **Agents: read [AGENTS.md](AGENTS.md).**

| Tag | Contents |
|---|---|
| `3.47.9` | Flutter 3.47.9 / Dart 3.13.7, Android SDK platform 36, build-tools 36.0.0, NDK 28.2.13676358, JDK 17, Gradle/AGP/Kotlin cache of a bare app |
| `3.47.9-common` | `3.47.9` + the packages and Android libraries of `warmup/common` (the Timegrapher Log app's dependency set) |

## Use the published image (no build needed)

    docker compose pull                                   # or: docker pull gmigno/flutter-apk-builder:3.47.9
    APP_DIR=/path/to/project APK_NAME=my-app.apk ./run.sh # -> ./out/my-app.apk
    IMAGE_TAG=3.47.9-common APP_DIR=/path/to/project ./run.sh

Development tasks on a project (read-write, results are chowned back to you):

    APP_DIR=/path/to/project ./dev.sh analyze
    APP_DIR=/path/to/project ./dev.sh test
    APP_DIR=/path/to/project ./dev.sh codegen
    APP_DIR=/path/to/project ./dev.sh flutter format lib test

The Gradle and pub caches live in Docker volumes (one pair per tag, filled from the image the first time). The debug signing key is kept in `./keystore`
(same key on every build). Nothing from this folder or your project is modified by `run.sh`.

## Build the image yourself (needs normal internet, several minutes)

    cp .env.example .env            # optional: only to change REGISTRY / IMAGE_TAG
    ./build-image.sh base           # -> <REGISTRY>/flutter-apk-builder:3.47.9
    ./build-image.sh common         # -> <REGISTRY>/flutter-apk-builder:3.47.9-common (built on top of 3.47.9)

How it works: the Dockerfile builds a throw-away app once in release mode so that Gradle 9.3.1, AGP 9.1.0, Kotlin, the Maven artifacts and the pub
packages stay in the image. Which app is described by `warmup/<profile>/` (see [warmup/README.md](warmup/README.md)). To cache more packages, edit
`warmup/common/pubspec.yaml` (and refresh the lock file), then rebuild `common`.

Behind a TLS-intercepting proxy, pass a folder with an `env.sh` (proxy variables, CA bundle) to the build as `--build-context build-extras=<folder>`
(see the comments in the Dockerfile).

## Publish on Docker Hub

1. Free account at https://hub.docker.com. Account settings -> Personal access tokens -> new token with **Read & Write**.
2. Log in without exposing the token:

       read -s DOCKERHUB_TOKEN
       echo "$DOCKERHUB_TOKEN" | docker login -u <your-dockerhub-username> --password-stdin

3. `REGISTRY` must be `docker.io/<your-dockerhub-username>` (lowercase; default in `compose.yaml` is `docker.io/gmigno`).
4. Upload (about 12 GB the first time; later pushes only send changed layers):

       ./build-image.sh base --push
       ./build-image.sh common --push

5. On hub.docker.com check that the repository is **Public** (the free plan allows one private repository; anonymous pulls are limited to
   10 per hour per IP, 100 per hour when logged in).

The images contain no signing keys or secrets (the debug keystore is deleted in the Dockerfile).

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | image definition (`BASE_IMAGE`, `WARMUP_PROFILE` build arguments) |
| `compose.yaml` | services `build` (APK) and `dev` (analyze/test/codegen), cache volumes |
| `run.sh`, `dev.sh` | wrappers that set `HOST_UID`/`HOST_GID` and call compose |
| `build-apk.sh`, `dev-task.sh` | scripts that run inside the container |
| `build-image.sh` | builds / pushes the image for a profile |
| `warmup/` | profiles of packages baked into the image |
| `AGENTS.md` | instructions for coding agents |
