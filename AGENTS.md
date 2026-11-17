# Instructions for agents: build Android apps with the Flutter Docker image

You help a user create and build Android apps with Flutter. You do **not** install Flutter or the Android SDK yourself.
Everything runs inside a ready-made Docker image that the user published on Docker Hub. This repository only contains the
small wrapper (compose file and scripts) that runs it. Follow the steps in order, check each result against the "Expected"
lines, and if something differs, stop and report the difference instead of improvising.

## Start here: ask the user first, before doing anything else

Your **first message** to the user, before checking Docker or downloading anything, is this one short question (then wait for the answer,
but see below: the preparation can already run while they answer):

> I can build Android apps with a ready-made Docker environment. I suggest we start with a small "Hello World" app to test that everything works
> (about 3 minutes once the image is downloaded). Do you want to do that, or go straight to another app?

- **Hello World** (or no clear preference) -> after the preparation (sections 2 and 3) go to section 5, then offer section 6.
- **Another app** -> after the preparation go to section 6 (ask what the app should do).
- Start the preparation (sections 2 and 3, in the background) right after asking, so the image is already downloading while the user thinks.
- In the same first message, add a short heads-up (two lines): the image is about 12 GB and is downloaded from Docker Hub, which can fail or be
  slow (I will retry and tell you); and the sandbox needs network access to a few domains (section 2a), which the user may have to allow in their settings.

## 0. Rules for long-running work (applies to every step)

- **Pulling an image and building are always long: run them in the background, never in the foreground.** This covers `docker pull`,
  `./run.sh`, `./dev.sh test` / `codegen`, and the first run that fills the cache volumes. Start the command with `nohup ... > log 2>&1 &` (or your
  tool's background mode), return control immediately, and check the log every few minutes. A foreground command is usually cut off after about 10
  minutes, which would lose the work.
  Wrong: `docker pull gmigno/flutter-apk-builder:3.47.9` and waiting for it. Right: `nohup docker pull gmigno/flutter-apk-builder:3.47.9 > /tmp/pull.log 2>&1 &`.
- Anything that can take more than about a minute (image download, builds, tests) runs **in the background**, writing to a log
  file as above.
- Do not narrate progress. Look at the log now and then (every few minutes) and **write to the user when the step has finished or
  when you detect a block** (below). Never leave the user waiting without a message.
- Run **one** heavy command at a time. Before starting one, check that none is running (`docker ps`).
- Block / loop detection. Stop and report to the user (do not keep retrying) when:
  - the log has not grown for **10 minutes** during a build or test run, or **15 minutes** during a download;
  - the same error message appears twice in a row;
  - you already retried a step **2 times**;
  - a step exceeds its time budget: image download 30 min, build 20 min, tests 15 min.
  A retry is allowed only for network errors (for example "HTTP 429", "Could not resolve", "Could not find ...", "connection reset",
  "timeout"), and only after waiting at least 2 minutes. Any other error: stop at once and report it. A TLS / certificate error
  (`CERTIFICATE_VERIFY_FAILED`, `Got TLS error ...`) is not a glitch: read section 3b once, apply it if it matches, otherwise stop.
- To stop a stuck container: `docker ps` then `docker stop <id>`. Never use `pkill -f '<text that appears in your own command>'`
  (it kills your own shell).
- Never disable TLS verification, never unset a proxy, never paste or ask for passwords or tokens in the chat.
- Never rebuild or push the image (`./build-image.sh`) unless the user explicitly asks. Normal work only **pulls** it.
- Disk space can run out in sandboxes ("no space left on device"). The image needs about 13 GB, each cache volume a few GB more.
  Check `df -h /` before the first download; if there is less than 20 GB free, tell the user.
- When you report, say in plain words what worked, what failed (last relevant log lines) and what you suggest.

## 1. What the image contains

Image: `docker.io/gmigno/flutter-apk-builder` (public). Tags:

| Tag | Use it for | Cached inside |
|---|---|---|
| `3.47.9` | plain apps (Material widgets, no extra packages) | Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, pub packages of a bare Flutter app |
| `3.47.9-common` | apps that use the packages listed in `warmup/common/pubspec.yaml` | everything above **plus** those packages and their Android libraries (CameraX, desugar_jdk_libs, ...) and the dev tools (`build_runner`, `drift_dev`) |

Both: Flutter 3.47.9 (stable), Dart 3.13.7, JDK 17, Android SDK platform 36, build-tools 36.0.0, NDK 28.2.13676358, cmake 3.22.1, `apkanalyzer`.
The container runs as root; the wrapper scripts hand the results back to the host user. APKs are signed with a **debug key** created in
`./keystore` on the first build (sideloading only, not the Play Store). `flutter --version` prints `channel [user-branch]`: expected, harmless.

Wrapper scripts (in this repository):

| Command | Does |
|---|---|
| `APP_DIR=<project> APK_NAME=<name>.apk ./run.sh` | builds a release APK of the project into `./out/<name>.apk` (the project folder is only read) |
| `APP_DIR=<project> ./dev.sh analyze` | `flutter pub get` + `flutter analyze` (project mounted read-write) |
| `APP_DIR=<project> ./dev.sh test [files]` | `flutter pub get` + `flutter test` |
| `APP_DIR=<project> ./dev.sh codegen` | `build_runner` (needed after changing Drift tables) |
| `APP_DIR=<project> ./dev.sh <any command>` | for example `./dev.sh flutter format lib test` |

Choose the tag with the environment variable `IMAGE_TAG` (default `3.47.9`), for example `IMAGE_TAG=3.47.9-common APP_DIR=... ./run.sh`.
The project's own `scripts/*.sh` (if it has them) assume a hand-installed Flutter: do not use them, use the commands above.

## 2. Check automatically that Docker works and that a container can run

Do this yourself, without asking the user. Two levels:

**a0) Network access (only if you run in a sandbox with restricted internet, e.g. Claude's cloud workspace)**

The pulls and builds need the internet. In Claude (claude.ai app: Settings -> Capabilities) the user must have **"Allow network egress"** turned on, and the
**Domain allowlist** must be **"All domains"**, or, if it is a custom list, must include at least:

| Purpose | Domains |
|---|---|
| Docker Hub (image download) | `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com`, `docker.io` |
| Dart / Flutter packages (`pub get`) | `pub.dev`, `storage.googleapis.com` |
| Android / Gradle libraries (only for packages not cached in the image) | `dl.google.com`, `maven.google.com`, `repo.maven.apache.org`, `repo1.maven.org`, `plugins.gradle.org`, `services.gradle.org` |
| `sqlite3` library used by `flutter test` | `github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com` |

Test it before the pull, without asking: `curl -sS -o /dev/null -w "%{http_code}\n" https://registry-1.docker.io/v2/` (expected `401`, which means
"reachable, login needed" and is fine) and `curl -sS -o /dev/null -w "%{http_code}\n" https://pub.dev` (expected `200`). If a request is refused
(`403`, `Forbidden`, `blocked`, "host not allowed", or a connection that never opens), stop and tell the user exactly which domain was blocked and how to
fix it: turn on "Allow network egress" and set the Domain allowlist to "All domains" (or add the domain), then say "continue". The list above is what
the image is known to use; if a build log names another blocked domain, report that one too. Do not work around a block (no mirrors, no other proxies).

**a) Docker is usable**

    docker --version
    docker compose version
    docker info

Expected: all three work. If the daemon is not running and you are root in a Linux sandbox, start it in the background
(`dockerd > /tmp/dockerd.log 2>&1 &`, wait up to 30 s, `docker info` again). Sandboxes may stop background programs between turns:
if Docker "disappears", start it again (the image stays on disk). If Docker is not available at all, stop and tell the user:
this method needs Docker. Do not try to install Flutter by hand.

**b) A container really starts** (smoke test, run it after the pull of section 3, in the background, with a log)

    nohup docker run --rm gmigno/flutter-apk-builder:3.47.9 flutter --version > /tmp/smoke.log 2>&1 &

Expected: exit code 0 and output with `Flutter 3.47.9` and `Dart 3.13.7` (`channel [user-branch]` is normal). In a proxied sandbox add the options
of section 3b. If it fails: a TLS error -> section 3b; "no space left on device" -> stop and report `df -h /`; anything else -> stop and report
the last log lines. Repeat this smoke test whenever Docker had to be restarted, and always before telling the user that the environment is ready.
If it fails, do not go on to the Hello World or to the user's app.

## 3. Get the image (background)

    nohup docker pull gmigno/flutter-apk-builder:3.47.9 > /tmp/pull.log 2>&1 &         # about 12 GB
    # if the app needs the common packages:
    nohup docker pull gmigno/flutter-apk-builder:3.47.9-common > /tmp/pull-common.log 2>&1 &   # shares most layers: much smaller extra download

Run the pulls one at a time, never in the foreground. **The download from Docker Hub can fail** (connection reset, `unexpected EOF`, `timeout`,
`TLS handshake timeout`, `received unexpected HTTP status: 5xx`, or the rate limit `toomanyrequests` / "You have reached your pull rate limit"):
- Send the user a short message at the **first** failure (what failed, that you will retry), so they are not surprised.
- Wait at least 2 minutes and run the same `docker pull` again: layers already downloaded are kept, so a retry continues where it stopped. Retry up to
  **3 times** in total (this overrides the limit of 2 in section 0 for pulls only), always in the background.
- `toomanyrequests` means Docker Hub's hourly limit for anonymous downloads (10 per hour per IP): wait, do not hammer; if it persists, tell the user
  (a free `docker login` by the user raises it to 100 per hour; never ask for or paste the password or token in the chat).
- A `denied` / `unauthorized` / `not found` error is not a glitch: stop and report it (check the image name and that the repository is public).
- After 3 failed retries stop and report: last log lines, the number of retries, and what you suggest (wait and retry later, check the network access of section 2a).
Expected: pull ends without error. Print and keep the digest
(`docker images --digests gmigno/flutter-apk-builder`) for your report. Write to the user when the download has finished (or when a block is detected),
then run the smoke test of section 2b.

## 3b. Only if the sandbox reaches the internet through a proxy with its own certificate

Symptoms inside the container: `Got TLS error trying to find package ... at https://pub.dev`, or `CERTIFICATE_VERIFY_FAILED ...
self signed certificate in certificate chain` (also from `flutter test`, where the `sqlite3` package downloads a library from GitHub).
Applies only if `echo "$HTTPS_PROXY"` is not empty. Otherwise skip this section.

The container must use the host network (the proxy listens on `127.0.0.1`), the same proxy, and trust the same certificate authority.
Keep TLS verification **on**. The host's own system bundle already trusts the proxy if `curl https://pub.dev` works on the host without `-k`.

Create `compose.proxy.yaml` in this folder (sandbox only, never commit it), replacing `<PORT>` with the port in `$HTTPS_PROXY`
(it can change between turns: read it again each time):

    services:
      build:
        network_mode: host
        environment:
          HTTPS_PROXY: http://127.0.0.1:<PORT>
          https_proxy: http://127.0.0.1:<PORT>
        volumes:
          - /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro
      dev:
        network_mode: host
        environment:
          HTTPS_PROXY: http://127.0.0.1:<PORT>
          https_proxy: http://127.0.0.1:<PORT>
        volumes:
          - /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro

and run everything with `COMPOSE_FILE=compose.yaml:compose.proxy.yaml`, for example
`COMPOSE_FILE=compose.yaml:compose.proxy.yaml APP_DIR=... ./dev.sh test`. This was tested for `./dev.sh analyze|test|codegen`.
If Gradle itself has to download something (a package not cached in the image), the JVM needs the proxy and trust store too; that case is
not covered here: report it to the user instead of improvising.
For `docker run ...` commands, pass the same options by hand: `--network host -e HTTPS_PROXY=... -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro`.

## 4. Route by the user's answer

The question was already asked at the very beginning ("Start here"). When the image is pulled and the smoke test passed, tell the user the environment
is ready, then follow the answer: **Hello World** -> section 5 (afterwards offer section 6); **another app** -> section 6. If the user has not answered
yet, remind them once, recommending the Hello World.

## 5. Optional test: the Hello World app

Create the project **inside the image** so no local Flutter is needed (use `<apps>` for the folder that will hold your projects):

    docker run --rm -u root -v "<apps>":/work -w /work gmigno/flutter-apk-builder:3.47.9 \
        flutter create hello_app --org com.example --platforms android
    chown -R "$(id -u):$(id -g)" "<apps>/hello_app"        # sudo if you are not root
    rm -f "<apps>/hello_app/test/widget_test.dart"

(In a proxied sandbox add the options of section 3b to the `docker run`.) Replace `<apps>/hello_app/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';

void main() => runApp(const HelloApp());

class HelloApp extends StatelessWidget {
  const HelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello World',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HelloScreen(),
    );
  }
}

class HelloScreen extends StatefulWidget {
  const HelloScreen({super.key});

  @override
  State<HelloScreen> createState() => _HelloScreenState();
}

class _HelloScreenState extends State<HelloScreen> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My First App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Hello, World!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('You tapped the button $_taps times'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _taps++),
              child: const Text('Tap me'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Build it **in the background** (section 0; the first run also creates the cache volumes, which copies a few GB and takes a minute), then write to the user when it is done:

    APP_DIR="<apps>/hello_app" APK_NAME=hello-world.apk nohup ./run.sh > /tmp/build-hello.log 2>&1 &

Expected: `No issues found!`; the log ends with `✓ Built build/app/outputs/flutter-apk/app-release.apk (~44 MB)`; the APK is `out/hello-world.apk`,
about 43.9 to 44.0 million bytes; about 2 to 3 minutes.
**Give the APK file to the user** (send the file itself, not only a path) with its size and `md5sum`, and say it is signed with a debug key, so the phone
may ask to allow "install from unknown sources". Then ask what app they want to build (section 6).

## 6. Build the user's own app

1. Ask what the app should do and its name. Keep it simple unless the user asks otherwise.
2. Create the project as in section 5 (`flutter create <name> --org com.example --platforms android`, fix ownership, remove `test/widget_test.dart`
   if you replace the counter app) and write the Dart code under `lib/`.
3. **Packages: decide the tag first.**
   - No extra packages -> tag `3.47.9` (default). Fast.
   - Only packages that appear in `warmup/common/pubspec.yaml` (for example `flutter_riverpod`, `drift`, `camera`, `share_plus`, `sensors_plus`, `shared_preferences`,
     `path_provider`, `audioplayers`, `vibration`, `wakelock_plus`, `flutter_local_notifications`, `image`, `archive`, ...) -> use tag `3.47.9-common`
     (`export IMAGE_TAG=3.47.9-common`). To keep the cached versions, **start from the profile**: copy `warmup/common/pubspec.lock` next to your `pubspec.yaml`,
     list only the packages you need (removing is safe), and run `./dev.sh flutter pub get`. If the app uses `flutter_local_notifications`, also copy the
     `coreLibraryDesugaring` lines of `warmup/common/build.gradle.kts` into `android/app/build.gradle.kts` (it needs them).
   - Any other package -> allowed, but tell the user first: Dart packages download during the build, and packages with Android code also pull Maven
     artifacts that are **not** cached, so the build is slower and can hit network errors. If it fails with a network error, follow the retry rules of
     section 0 and then report it. The user can add the package to `warmup/common/` and rebuild the image; you do not.
4. Check and test before building: `APP_DIR=... ./dev.sh analyze` must say `No issues found!`; run `./dev.sh test` if the project has tests; if you changed
   Drift tables run `./dev.sh codegen` (and bump `schemaVersion` with a migration). Typical timings: analyze 30 s, tests 1 to 2 min, codegen 1 min.
5. Build **in the background**: `APP_DIR="<apps>/<name>" APK_NAME=<name>.apk nohup ./run.sh > /tmp/build-<name>.log 2>&1 &`, and write to the user when it is done. Give the APK to the user with size, `md5sum` and the debug-key note. If the app must not use the
   network, check the permissions of the built APK: `docker compose run --rm build apkanalyzer manifest permissions /out/<name>.apk`
   (use the same `IMAGE_TAG` as for the build; `INTERNET` must not be listed; the only extra one a Flutter app normally has is
   `<applicationId>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`).
6. To change the app, edit the code and repeat. Each `run.sh` builds a clean copy; every build reuses the debug key in `./keystore`, so APKs of the same app install over each other.

## 7. What to report to the user (short, plain language)

- what you did and whether it worked; for each APK: file name, size, `md5sum`, build time; the image tag and digest used;
- anything that differed from the "Expected" lines, and anything you changed and why;
- if you stopped because of a block: which step, the last relevant log lines, how many retries, and what you suggest.

## 8. Out of scope

Publishing to the Play Store, creating a release keystore, rebuilding or pushing the Docker image, installing Flutter or the Android SDK on the host.
If the user needs another Flutter version, another Android SDK platform or more cached packages, tell them the image has to be rebuilt by them
(`./build-image.sh`, see `README.md` and `warmup/README.md`) and stop.
