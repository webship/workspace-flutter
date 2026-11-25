<p align="center"><img src="https://raw.githubusercontent.com/webship/workspace-flutter/1.0.x/assets/logo.svg" alt="Flutter logo" width="96"></p>

# @webship.co/workspace-flutter

Flutter for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that builds a Flutter
web app in a container of its own and serves the built app, the [Flutter step pack](https://github.com/webship/flutter-steps)
wired into the testing setup of that app, and its AI items — two agents, a skill, a command and two prompts for
building and testing Flutter web apps — each listed in the workspace folder of its kind.

The app brings its own language in its own container. The Flutter SDK goes into the project's web image, pinned (the
official stable archive of Flutter 3.50.1, checked against the checksum of Flutter's list of releases); the app is
built there with `flutter build web`, and a small web server of the plugin serves the built app from there. Nothing of
Flutter, Dart or Node.js runs on the machine. The app is the counter of `flutter create`, or an app of your own from
its repository.

The workspace is container-based (DDEV by default): an app is a row like any other, so the row menus the core draws
(start, stop, launch, backup, clone, remove, tests) work on it; what does not apply to a web app without a database is
listed under [What is different from a platform](#what-is-different-from-a-platform). The builder builds on DDEV by
default, and with `--runtime` on Docker Compose, Podman or a Kubernetes cluster: see [Runtimes](#runtimes).

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require flutter --with-needs     # npm install into the dashboard
bash core/scripts/plugins.sh --activate flutter --with-needs    # plugins.flutter in settings.yml
bash core/scripts/plugins.sh --install flutter                  # the builder, functions, args, AI items
bash core/scripts/plugins.sh --configure flutter                # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is idempotent.
`--uninstall` removes what it placed; an AI item you edited stays.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-flutter-project.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `flutter-app-builder`, `flutter-tester` | `ai-agents/` |
| The skill `flutter-scenarios` | `ai-skills/` |
| The command `/flutter-test` | `ai-commands/` |
| The prompts `flutter-build-and-test`, `flutter-scenarios-for-an-app` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is
missing first:

```bash
bash core/scripts/plugins.sh --activate flutter --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install flutter
```

Everything the builder runs for an app runs in the app's own container, through the container tool the workspace
already needs; the plugin asks for no command of its own on the machine. The Flutter SDK archive is built for x86-64
Linux: on another machine the build of the web image says so and stops.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-flutter-project.sh` | The builder, in the Build list as **Flutter (web app)**, installed into every sites folder |
| `scripts/functions/fun-flutter.sh` | The bash functions behind it, sourced by bootstrap once installed; the names the core's tools look for (`set_flutter_users`, `add_flutter_users`, `cancel_flutter_users`, `testing_configure_flutter`) |
| `scripts/args/arg-flutter.sh` | Its argparse; the Build form draws the builder's flags from it |
| `scripts/flutter-serve.py` | The app's web server (Python's standard library), copied into each project: the built app, its `index.html` for any route, the types of `.wasm` and `.mjs` files, and the cross-origin isolation headers of a WebAssembly build |
| `testing/site.feature` | The first feature the counter gets when testing is set up |
| `ai/agents/flutter-app-builder.md` | The agent that builds and fixes apps: the build in the container, and names the accessibility tree carries |
| `ai/agents/flutter-tester.md` | The agent that writes and runs scenarios with the step pack, an unnamed control reported as a finding |
| `ai/skills/flutter-scenarios/` | The skill: the step pack's phrases, the traps found on real apps, three example features |
| `ai/commands/flutter-test.md` | The slash command `/flutter-test <app>`: set up when missing, match every step, run, report |
| `ai/prompts/flutter-build-and-test.md`, `flutter-scenarios-for-an-app.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Flutter here |
| `features/flutter.feature`, `features/flutter-runtimes.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from a platform

| | WordPress (a platform) | Flutter |
| --- | --- | --- |
| What is built | A WordPress site | A Flutter web app: the counter of `flutter create`, or an app from its repository, built with `flutter build web` |
| Project | `--project-type=wordpress` | `--project-type=generic --webserver-type=generic`, no database: the app's own server serves the built app |
| The language | PHP, in the container tool's image | The Flutter SDK 3.50.1 in the project's web image: `.ddev/web-build/Dockerfile.flutter` on DDEV; on Docker Compose, Podman and Kubernetes the core's language stack (`rt_stack image` with Debian pinned by its digest, `rt_web_build` with the same SDK lines, `rt_serve`) |
| Recognised by | The project type | On DDEV a file the builder writes, `.ddev/config.flutter.yaml` (it also records where the app came from); on another runtime its claim, `platform: flutter` in the `x-webship` block of `compose.yaml` |
| Accounts | WP-CLI | None of the workspace's: `--add-users` is taken and adds nothing |
| Testing | The WordPress pack | The Flutter pack, which reads the app's accessibility tree |

## The commands

Run it from a sites folder. `--help` is safe.

### Build and serve an app

```bash
cd ~/workspace/dev
bash cmd-flutter-project.sh flapp --install                     # a new app: the counter of flutter create
bash cmd-flutter-project.sh flapp --install --wasm              # the same, built for WebAssembly
bash cmd-flutter-project.sh flform --install --source https://github.com/flutter/samples.git --path form_app
bash cmd-flutter-project.sh flapp --install --runtime docker    # on Docker Compose instead of DDEV
bash cmd-flutter-project.sh flapp --install --runtime kubernetes   # on the workspace's Kubernetes cluster
```

| Flag | What it does |
| --- | --- |
| `--install` | Serve the built app and check that it answers at its address (`https://<name>.ddev.site` on DDEV) |
| `--runtime ddev\|docker\|podman\|kubernetes` | The container runtime to build on (default: DDEV, or `container.runtime` of `settings.yml`); see [Runtimes](#runtimes) |
| `--source <git url>` | A repository of a Flutter app (default: none, a new app of `flutter create`) |
| `--ref <branch or tag>` | A branch or a tag of that repository (default: its default branch) |
| `--path <folder>` | The folder of the app in that repository, for a repository of several apps |
| `--wasm` | Build for WebAssembly (`flutter build web --wasm`), served with the cross-origin isolation headers it needs to run on several threads |
| `--add-users` | Taken so that every builder accepts the same flags; the app has no accounts of the workspace's |
| `--launch` | Open the app in a browser when it is ready |

The builder deletes a project of the same name first, then makes a container whose web image carries the Flutter SDK
(about 3 GB, built once in a few minutes and then taken from the build cache), makes the app (`flutter create`) or copies it from its
repository, builds it with `flutter build web --release`, and with `--install` checks that its server answers. A
package of a pub workspace (the official samples are one) is built on its own: its `resolution: workspace` line goes,
and a package it takes from a folder next to it in the repository (`path: ../analysis_defaults`) is copied next to
`app/`, at the same place (one from further away is refused, with a message). An app without the web platform gets it
(`flutter create --platforms web .`).

The project's folder holds the app's source in `app/`, the built app in `app/build/web/`, the server in `flutter/` and
the app's packages in `.pub-cache/`. After a change to the app, build it again in the container; the server serves the
new build at once:

```bash
cd ~/workspace/dev/flapp
ddev exec -d /var/www/html/app "flutter build web --release --base-href /"
```

### Test an app

```bash
bash cmd-tools-testing.sh flapp                                  # webship-js, the step pack, a first feature
bash cmd-tools-testing.sh flapp --run --path tests/features/site.feature
```

The testing setup adds `@webship-js/flutter-steps` to the project, lists its step definitions in `cucumber.js`, and,
for the counter of `flutter create`, writes `tests/features/site.feature`. An app of your own gets no first feature: it
has its own names. It changes nothing in a project that is not an app of this builder.

The steps read the accessibility tree the app builds for screen readers, which they turn on as assistive technology
does: a widget the app leaves out of that tree is out of their reach, and a step says so as an accessibility finding
about the app.

```gherkin
Feature: The counter
  Scenario: The button adds one to the count
    Given I am on the homepage
    And the app's accessibility tree is on
    When I tap "Increment"
    Then the app should show "You have pushed the button this many times: 1"
    And the app should have no unnamed buttons
```

### Runtimes

The commands are the same on every runtime: the builder speaks DDEV's verbs, and on another runtime the core's layer
(Webship Workspace 1.0.32 or later, webship/workspace#694 and #841) gives each verb its meaning there: the language
stack builds the web image from Debian, pinned by its digest, with the same SDK lines as on DDEV, and starts the app's
server in it. The app has no database, so on Kubernetes it needs core 1.0.35 or newer (webship/workspace#884).

| Runtime | The address of the app | Proven with this builder |
| --- | --- | --- |
| DDEV (the default) | `https://<name>.ddev.site` | The counter built and served; it starts in a browser and counts a tap; the testing setup and its first feature, 3 scenarios and 12 steps |
| Docker Compose (`--runtime docker`) | `http://127.0.0.1:<port>`, a free port kept in `compose.yaml` | The counter built and served, the files the host user's; the testing setup and its first feature (3 scenarios, 12 steps), and the skill's three examples on the counter, the forms sample and the testing sample built from their repository (6 scenarios, 67 steps); the counter built for WebAssembly in 36 s, served cross-origin isolated and run as WebAssembly; the plugin's features on the dashboard |
| Podman (`--runtime podman`) | `http://127.0.0.1:<port>` | The counter built in 7 minutes with the stack's image, served, the files the host user's; it starts in a browser and counts a tap; the plugin's features on the dashboard |
| Kubernetes (`--runtime kubernetes`) | `http://<node address>:<NodePort>` | On kind (Kubernetes 1.37.0) with core 1.0.35: the counter built in 5 minutes (the image loaded into the cluster, the app compiled in its pod), served, it starts in a browser and counts a tap; the plugin's features on the dashboard |

A project of the builder is known by DDEV's file on DDEV and by its claim on another runtime, so the testing setup,
the Users tools (which say there are no accounts) and the dashboard's row work the same on each. Lando and Docksal are
runtimes of the workspace too, not proven with this builder yet: it says so and stops, before anything is made.

### Users

The app has no accounts of the workspace's. `cmd-tools-add-users.sh <name> flutter` and
`cmd-tools-cancel-users.sh <name> flutter` say so and change nothing.

## The AI items

| Item | Kind | What it is for |
| --- | --- | --- |
| `flutter-app-builder` | agent | Builds and fixes Flutter web apps in their container, and gives every widget a person needs a name the accessibility tree carries |
| `flutter-tester` | agent | Writes and runs scenarios with the step pack: reads the app's tree in the browser first, never sleeps, never names a framework or platform in a step, reports an unnamed control as a finding |
| `flutter-scenarios` | skill | The step pack's phrases, the traps found on real apps, three example features that pass on the counter and on two official samples |
| `/flutter-test <app>` | command | Sets the pack up when missing, matches every step, runs, reports |
| `flutter-build-and-test` | prompt | Builds an app and proves it with its first feature |
| `flutter-scenarios-for-an-app` | prompt | Writes and runs the scenarios of one screen of an app of the workspace |

Every item says the workspace is container-based (DDEV by default), and the agents and the skill send the reader to
the book *Automated Functional Testing Recipes* first.

## Develop it

```bash
npm install
npm test        # builds, then the unit tests: the manifest, the scripts, the app's server, the AI items, the needs
npm run lint    # the TypeScript compiler, no output
```

CI runs the same on Node.js 24 and 26, checks that every shell script parses, and runs the plugin's webship-js
features against a dashboard with the plugin installed (the reusable workflow
`webship/workspace/.github/workflows/plugin-browser-suite.yml`). Before the features it builds the app the manifest
names (`featuresSite`: `cmd-flutter-project.sh ci-flutter --install --runtime docker`), so the scenarios of
`features/flutter-runtimes.feature` tagged `@needs-runtime-docker` drive a real app on Docker Compose; the Podman and
Kubernetes ones run where such an app is.
`tests/fixtures/step-definitions.txt` holds the step definitions of the step pack at the version the testing hook pins
and of webship-js, read from their packages: every phrase an AI item shows must match one of them.

## License

ISC (see `LICENSE`).

## Logo

The Flutter logo in this README comes from Simple Icons 16.37.0, filled with the colour the set lists for the brand;
the set is CC0-1.0 and points to Flutter's brand guidelines (https://flutter.dev/brand). The Flutter name and logo
are trademarks of their owner; this plugin is not affiliated with or endorsed by them.
