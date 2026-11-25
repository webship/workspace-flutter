#!/usr/bin/env bash

# Flutter for the Webship Workspace: build a Flutter web app in a container of its own, serve the built app, and wire
# the Flutter step pack into the testing setup of that app.
#
# Placed by `plugins.sh --install flutter` in core/scripts/plugins/flutter/functions/, where bootstrap sources it after
# the core's own functions. Everything runs in the project's containers, never on the host: the Flutter SDK is in the
# project's web image, pinned (the official stable archive, checked against the checksum of Flutter's list of
# releases), the app is built there with `flutter build web`, and the plugin's web server (flutter-serve.py) serves the
# built app from there.
#   - DDEV (the default): a project with DDEV's generic web server. The web image gets the SDK
#     (.ddev/web-build/Dockerfile.flutter); the app's server is a daemon of the web container, and the router sends
#     the project's address to it (.ddev/config.flutter.yaml).
#   - Docker Compose, Podman and Kubernetes (--runtime docker, podman, kubernetes): the language stack of the core's
#     runtime layer (webship/workspace#841): Debian, pinned by its digest, as the stack's image (rt_stack image), the
#     same SDK on top of it (rt_web_build), and the app's server as the web container's own (rt_serve); at
#     http://127.0.0.1:<port>, or on Kubernetes (kind) at the node's address and a NodePort, the project's folder
#     mounted from the host. There is no database, so Kubernetes needs core 1.0.35 or newer (webship/workspace#884).
# Lando and Docksal are not proven for it yet: asked for one, the builder says so and changes nothing.
#
# The project's folder: app/ (the Flutter app: the counter of `flutter create`, or a repository cloned with --source),
# app/build/web/ (the built app, which is served), flutter/ (the plugin's web server, copied in) and .pub-cache/ (the
# app's packages). There is no database.
#
# The container tool has no project type for Flutter, so a project of this builder is recognised by its mark
# (.ddev/config.flutter.yaml on DDEV, `platform: flutter` in compose.yaml elsewhere), and four names are the ones the
# core's tools look for:
#   set_flutter_users          an empty list: the app has no accounts of the workspace's  (cmd-tools-add-users.sh)
#   add_flutter_users          says so, and adds nothing                                    (the same tool)
#   cancel_flutter_users       says so, and removes nothing                                 (cmd-tools-cancel-users.sh)
#   testing_configure_flutter  the step pack in the testing stack                           (cmd-tools-testing.sh)

# The step pack an app is tested with, and the release line it is required at.
readonly FLUTTER_STEPS_PACKAGE='@webship-js/flutter-steps';
readonly FLUTTER_STEPS_VERSION='^2.0.0';

# The Flutter SDK in the web image: a stable release, and the checksum of its archive in Flutter's list of releases
# (https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json). The archive is built for
# x86-64 Linux.
readonly FLUTTER_SDK_VERSION='3.50.1';
readonly FLUTTER_SDK_SHA256='4ad17fc8462fbcef2ba19ff4a78c0a16b7147fde1add8578e267ea62cdb92678';

# The stack's image on a runtime other than DDEV: Debian (bookworm, slim), pinned by its digest.
readonly FLUTTER_BASE_IMAGE='debian:bookworm-slim@sha256:e67eeead736ff7bbe258ef088bff683635c561b1fcfefad0806c1df4ab49ce0e';

# The port the app's server listens on in the web container, the app's folder, and the folder of the plugin's files.
readonly FLUTTER_PORT='8080';
readonly FLUTTER_APP='app';
readonly FLUTTER_FILES='flutter';

# The runtimes an app is built on.
readonly FLUTTER_RUNTIMES='ddev docker podman kubernetes';

# The app has no accounts of the workspace's: the list is empty.
function set_flutter_users() {
  users=();
}

# The runtime of the project in this folder, or of a new build (--runtime, else the workspace's setting, else DDEV).
# A core without the runtime layer has DDEV only.
function flutter_runtime() {
  if declare -f runtime_of > /dev/null ; then runtime_of ; else echo 'ddev' ; fi
}

# The address of the app in this folder: https://<name>.ddev.site on DDEV, http://127.0.0.1:<port> on Docker Compose
# and Podman, the node's address and a port on Kubernetes. Asked after `ddev config`.
function flutter_url() {
  if declare -f rt_url > /dev/null ; then rt_url ; else echo "https://${PROJECT_NAME}.ddev.site" ; fi
}

# The project's folder in the web container.
function flutter_root() {
  echo '/var/www/html' ;
}

# Is this folder a project of the Flutter builder? On DDEV the builder leaves .ddev/config.flutter.yaml in it; on
# another runtime it claims the project (`platform: flutter` in the x-webship block).
function flutter_is_project() {
  local project_path="$1";
  [ -f "${project_path}/.ddev/config.flutter.yaml" ] && return 0 ;
  declare -f rt_is_platform > /dev/null && rt_is_platform "${project_path}" flutter ;
}

# The Dart package name of a new app, from the project's name: small letters, digits and _, not starting with a digit,
# and not a word of the language or a package the app depends on.
function flutter_package_name() {
  local name="${1,,}" ;
  name="${name//[^a-z0-9_]/_}" ;
  [[ "${name}" =~ ^[a-z_] ]] || name="app_${name}" ;
  local taken=' abstract as assert async await base break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for function get hide if implements import in interface is late library mixin new null of on operator part required rethrow return sealed set show static super switch sync this throw true try type typedef var void when while with yield flutter flutter_test flutter_web_plugins sky_engine test ' ;
  case "${taken}" in *" ${name} "*) name="app_${name}" ;; esac
  echo "${name}" ;
}

# The Dockerfile lines that put the Flutter SDK into the web image: the same on DDEV (.ddev/web-build/) and on another
# runtime (rt_web_build). Python is the app's web server's. Only the tools the image lacks are installed, and a package
# list that cannot be refreshed (a third-party list of the base image whose key expired: packages.sury.org in DDEV
# 1.24.7's web image) does not stop the build, as DDEV's own extra packages do not; a tool still missing after it does,
# with its name. flutter and dart are also linked into /usr/local/bin, so a command in the container
# finds them whatever PATH its shell was given.
function flutter_sdk_dockerfile() {
  cat <<DOCKEREOF
# The Flutter SDK ${FLUTTER_SDK_VERSION} (stable) for the app of this project: the official archive, checked against the
# checksum of Flutter's list of releases, in /opt/flutter, with the artifacts of the web only. Written by the Flutter
# builder of the workspace; build again rather than editing by hand.
ENV PATH="/opt/flutter/bin:\${PATH}" \\
    FLUTTER_SUPPRESS_ANALYTICS=true
RUN [ "\$(uname -m)" = x86_64 ] || { echo "The Flutter SDK archive is built for x86-64 Linux, and this machine is \$(uname -m)." >&2 ; exit 1 ; } \\
 && pkgs="" \\
 && for p in curl:curl git:git unzip:unzip xz:xz-utils python3:python3 ; do command -v "\${p%%:*}" > /dev/null || pkgs="\${pkgs} \${p#*:}" ; done \\
 && if [ -n "\${pkgs}" ] ; then { apt-get update || true ; } && apt-get install -y --no-install-recommends ca-certificates \${pkgs} && rm -rf /var/lib/apt/lists/* ; fi \\
 && for c in curl git unzip xz python3 ; do command -v "\${c}" > /dev/null || { echo "The web image has no \${c} after its packages were installed: the Flutter SDK cannot be set up without it (a package list of the image that could not be refreshed?)." >&2 ; exit 1 ; } ; done \\
 && curl -fsSL -o /tmp/flutter.tar.xz "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_SDK_VERSION}-stable.tar.xz" \\
 && echo "${FLUTTER_SDK_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \\
 && tar -xJf /tmp/flutter.tar.xz -C /opt \\
 && rm /tmp/flutter.tar.xz \\
 && git config --system --add safe.directory '*' \\
 && flutter config --no-analytics --no-cli-animations \\
 && flutter precache --web --no-android --no-ios --no-linux --no-windows --no-macos --no-fuchsia \\
 && chmod -R a+rwX /opt/flutter \\
 && ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter \\
 && ln -sf /opt/flutter/bin/dart /usr/local/bin/dart
# The app's packages, in the project's folder: they stay when the container is made again.
ENV PUB_CACHE=$(flutter_root)/.pub-cache
DOCKEREOF
}

# The command that serves the built app once it is there: the plugin's server on FLUTTER_PORT, with the cross-origin
# isolation headers for a WebAssembly build. No space before a `;`: in the supervisor configuration DDEV writes from
# it, " ;" starts a comment.
function flutter_serve_command() {
  local isolated="$1" root ; root="$(flutter_root)" ;
  echo "while [ ! -f ${root}/${FLUTTER_APP}/build/web/index.html ]; do sleep 2; done; exec python3 ${root}/${FLUTTER_FILES}/flutter-serve.py ${root}/${FLUTTER_APP}/build/web ${FLUTTER_PORT}${isolated:+ --isolated}" ;
}

# What DDEV is told about the app: the web image gets the SDK, the router sends the project's address to the app's
# server, which the web container runs as a daemon. The file also marks the project as one of this builder.
function flutter_write_ddev_config() {
  local project_path="$1" source="$2" ref="$3" app_path="$4" isolated="$5" ;
  mkdir -p "${project_path}/.ddev/web-build" || return 1 ;
  cat > "${project_path}/.ddev/config.flutter.yaml" <<YAMLEOF
# A Flutter web app in this project. Written by the Flutter builder of the workspace; build again rather than editing
# by hand. The web image carries the Flutter SDK ${FLUTTER_SDK_VERSION} (web-build/Dockerfile.flutter). The web container
# serves no files of its own: the router sends ports 80 and 443 of the project's address to the app's server, a daemon
# of the web container that serves the built app (${FLUTTER_APP}/build/web) once it is there.
# source: ${source:-flutter create}${ref:+ (${ref})}${app_path:+, ${app_path}/}${isolated:+ (WebAssembly)}
web_extra_exposed_ports:
  - name: flutter
    container_port: ${FLUTTER_PORT}
    http_port: 80
    https_port: 443
web_extra_daemons:
  - name: flutter
    command: "bash -c '$(flutter_serve_command "${isolated}")'"
    directory: $(flutter_root)
web_environment:
  - PUB_CACHE=$(flutter_root)/.pub-cache
YAMLEOF
  flutter_sdk_dockerfile > "${project_path}/.ddev/web-build/Dockerfile.flutter" ;
}

# On another runtime than DDEV (webship/workspace#841): the plugin's claim, Debian pinned by its digest as the stack's
# image, the SDK on top of it, and the app's server as the web container's own, once the app is built.
function flutter_runtime_config() {
  local isolated="$1" ;
  rt_claim flutter || return 1 ;
  rt_stack image "${FLUTTER_BASE_IMAGE}" || return 1 ;
  flutter_sdk_dockerfile | rt_web_build flutter || return 1 ;
  rt_serve "${FLUTTER_PORT}" "$(flutter_serve_command "${isolated}")" ;
}

# Wait until the app's server answers with the built app.
function flutter_wait() {
  local attempt ;
  for attempt in $(seq 1 60) ; do
    if ddev exec "curl -fsS -o /dev/null http://127.0.0.1:${FLUTTER_PORT}/index.html" < /dev/null > /dev/null 2>&1 ; then
      return 0 ;
    fi
    sleep 2 ;
  done
  echo "The app's server does not answer with the built app." ;
  return 1 ;
}

# The app in app/: a new one of `flutter create`, or the folder of a repository. A package of a pub workspace (the
# official samples are one) is built on its own: its `resolution: workspace` line goes, and the packages it takes from a
# folder next to it in the repository (`path: ../analysis_defaults`) are copied next to app/, at the same place. An app
# without the web platform gets it.
function flutter_get_app() {
  local project_path="$1" source="$2" ref="$3" app_path="$4" root ;
  root="$(flutter_root)" ;
  if [ -z "${source}" ] ; then
    local package ; package="$(flutter_package_name "${PROJECT_NAME}")" ;
    echo "Making a new app (${package}) with flutter create." ;
    ddev exec -d "${root}" "flutter create --platforms web --project-name ${package} ${FLUTTER_APP}" < /dev/null \
      || { echo "flutter create failed." ; return 1 ; } ;
    return 0 ;
  fi
  echo "Getting the app: ${source}${ref:+ at ${ref}}${app_path:+, its folder ${app_path}/}" ;
  ddev exec "rm -rf /tmp/flutter-source && git clone --quiet --depth 1 ${ref:+--branch '${ref}'} '${source}' /tmp/flutter-source" < /dev/null \
    || { echo "The app could not be cloned from ${source}${ref:+ at ${ref}}." ; return 1 ; } ;
  ddev exec "test -f '/tmp/flutter-source/${app_path:+${app_path}/}pubspec.yaml' && mkdir -p ${root}/${FLUTTER_APP} && cp -a '/tmp/flutter-source/${app_path:+${app_path}/}.' ${root}/${FLUTTER_APP}/" < /dev/null \
    || { echo "${source}${app_path:+ (${app_path}/)} has no pubspec.yaml: it is not the folder of a Flutter app." ; return 1 ; } ;
  local dep rest from ;
  for dep in $(sed -nE "s/^[[:space:]]+path:[[:space:]]*['\"]?(\.\.\/[A-Za-z0-9._\/-]+)['\"]?[[:space:]]*(#.*)?$/\1/p" "${project_path}/${FLUTTER_APP}/pubspec.yaml") ; do
    dep="${dep%/}" ; rest="${dep#../}" ;
    from="$(python3 -c 'import os, sys ; print(os.path.normpath(os.path.join(sys.argv[1], sys.argv[2])))' "${app_path:-.}" "${dep}")" ;
    case "/${rest}/" in
      */../*|*/./*|//) echo "The app takes ${dep} from outside the folder next to it, which is not copied: build the app from a repository that holds it, or give that package a version." ; return 1 ;;
    esac
    case "${rest%%/*}" in
      "${FLUTTER_APP}"|"${FLUTTER_FILES}"|.ddev|.webship|.pub-cache|tests|node_modules|k8s) echo "The app takes ${dep}, which would land on the project's own ${rest%%/*}/: build it from its repository's root instead." ; return 1 ;;
    esac
    case "${from}" in ..|../*) echo "The app takes ${dep}, outside its repository." ; return 1 ;; esac
    echo "The app takes ${dep} from its repository: copying it next to ${FLUTTER_APP}/." ;
    ddev exec "test -f '/tmp/flutter-source/${from}/pubspec.yaml' && mkdir -p '${root}/${rest}' && cp -a '/tmp/flutter-source/${from}/.' '${root}/${rest}/'" < /dev/null \
      || { echo "${dep} is not a package of ${source}." ; return 1 ; } ;
    sed -i '/^resolution: workspace$/d' "${project_path}/${rest}/pubspec.yaml" || return 1 ;
  done
  ddev exec "rm -rf /tmp/flutter-source" < /dev/null ;
  sed -i '/^resolution: workspace$/d' "${project_path}/${FLUTTER_APP}/pubspec.yaml" || return 1 ;
  if [ ! -f "${project_path}/${FLUTTER_APP}/web/index.html" ] ; then
    echo "The app has no web platform yet: adding it (flutter create --platforms web .)." ;
    ddev exec -d "${root}/${FLUTTER_APP}" "flutter create --platforms web ." < /dev/null \
      || { echo "The web platform could not be added to the app." ; return 1 ; } ;
  fi
}

# Build an app from nothing: the container with the SDK, the app, its build for the web, and with --install the app
# served and checked.
function flutter_build() {
  trim_project_name ;
  local base_url runtime ;
  runtime="$(flutter_runtime)" ;
  if [ "${RUNTIME:-_none_}" != '_none_' ] && [ "${RUNTIME}" != "${runtime}" ] ; then
    echo "--runtime ${RUNTIME} needs a Webship Workspace with the container runtimes (webship/workspace#694): update the workspace, or build on DDEV." ;
    exit 1 ;
  fi
  case " ${FLUTTER_RUNTIMES} " in
    *" ${runtime} "*) ;;
    *) echo "A Flutter app builds on DDEV, Docker Compose, Podman and Kubernetes for now (--runtime ddev, docker, podman or kubernetes), not on ${runtime}: that runtime is not proven for it yet. Nothing was changed." ; exit 1 ;;
  esac
  if [ "${runtime}" != 'ddev' ] && ! declare -f rt_serve > /dev/null ; then
    echo "Flutter on ${runtime} needs a Webship Workspace whose runtimes take an application's own language and server (webship/workspace#841, core 1.0.32 or later): update the workspace, or build on DDEV." ;
    exit 1 ;
  fi
  local source="${SOURCE:-${app_source:-}}" ;
  local ref="${REF:-${app_source_ref:-}}" ;
  local app_path="${APP_PATH:-${app_source_path:-}}" ;
  local isolated="" ;
  [ "${WASM}" == 'yes' ] && isolated='yes' ;
  if [ -n "${app_path}" ] && [ -z "${source}" ] ; then
    echo "--path names a folder of the repository given with --source: give --source too. Nothing was changed." ;
    exit 1 ;
  fi
  if [[ "${app_path}" == /* ]] || [[ "/${app_path}/" == */../* ]] || [[ "${app_path}" == *"'"* ]] || [[ "${source}${ref}" == *"'"* ]] ; then
    echo "--source, --ref and --path take a repository, a branch or tag, and a folder inside the repository. Nothing was changed." ;
    exit 1 ;
  fi
  if [ ${#PROJECT_NAME} -gt 40 ] || ! [[ "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ; then
    echo "The project name ${PROJECT_NAME} must be small letters, digits and dashes (its address and its containers take it). Nothing was changed." ;
    exit 1 ;
  fi
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;
  local root ; root="$(flutter_root)" ;
  local server="${WORKSPACE_SCRIPTS}/plugins/flutter/flutter-serve.py" ;
  if [ ! -f "${server}" ] ; then
    echo "flutter-serve.py is not in ${WORKSPACE_SCRIPTS}/plugins/flutter: install the plugin (plugins.sh --install flutter)." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  # A project of the same name goes first, with its containers.
  drop_database ;
  rm -rf "${PROJECT_NAME:?}" ;
  mkdir -p "${PROJECT_NAME}/${FLUTTER_FILES}" ;
  cd "${project_path}" || exit 1 ;
  cp "${server}" "${project_path}/${FLUTTER_FILES}/flutter-serve.py" || exit 1 ;
  printf '.pub-cache/\n' > "${project_path}/.gitignore" ;

  # A generic web server and no database: the app's own server serves the built app.
  if [ "${runtime}" == 'ddev' ] ; then
    ddev config --project-type=generic --webserver-type=generic --docroot="" --project-name=${PROJECT_NAME} \
      --omit-containers=db --nodejs-version=$(ddev_nodejs_version) < /dev/null || exit 1 ;
    flutter_write_ddev_config "${project_path}" "${source}" "${ref}" "${app_path}" "${isolated}" || exit 1 ;
  else
    # The runtime's own project: Docker Compose, Podman or Kubernetes, through the runtime layer.
    ddev config --project-type=generic --webserver-type=generic --docroot="" --project-name=${PROJECT_NAME} \
      --omit-containers=db --auto < /dev/null || exit 1 ;
    flutter_runtime_config "${isolated}" || { echo "The app's stack could not be written through the runtime layer." ; exit 1 ; } ;
  fi
  # The address is the runtime's to say, once the project is configured: never a written ddev.site.
  base_url="$(flutter_url)" ;

  echo "Starting the project: its web image gets the Flutter SDK ${FLUTTER_SDK_VERSION} (about 3 GB, the first time)." ;
  ddev_up start -y < /dev/null || exit 1 ;

  flutter_get_app "${project_path}" "${source}" "${ref}" "${app_path}" || exit 1 ;

  echo "Building the app for the web${isolated:+ (WebAssembly)}: flutter build web --release${isolated:+ --wasm}." ;
  ddev exec -d "${root}/${FLUTTER_APP}" "flutter pub get && flutter build web --release${isolated:+ --wasm} --base-href /" < /dev/null \
    || { echo "flutter build web failed." ; exit 1 ; } ;
  if [ ! -f "${project_path}/${FLUTTER_APP}/build/web/index.html" ] ; then
    echo "The build left no ${FLUTTER_APP}/build/web/index.html." ;
    exit 1 ;
  fi

  [ "${ADD_USERS}" == 'yes' ] && echo "--add-users: the app has no accounts of the workspace's; nothing is added." ;

  if [ "${INSTALL}" == 'yes' ] ; then
    flutter_wait || exit 1 ;
    echo "${doc_name} ${PROJECT_NAME} is served: the Flutter app in ${FLUTTER_APP}/, built for the web${isolated:+ (WebAssembly)} with Flutter ${FLUTTER_SDK_VERSION}.";
    echo "Go to ${base_url}";
  else
    ddev stop < /dev/null ;
    echo "${doc_name} ${PROJECT_NAME} is ready: the Flutter app in ${FLUTTER_APP}/, built for the web${isolated:+ (WebAssembly)}.";
    if [ "${runtime}" = 'ddev' ] ; then
      echo "Serve it with: cd ${PROJECT_NAME} && ddev start   (or build with --install)";
    else
      echo "Serve it with Start in its row of the dashboard (or build with --install)";
    fi
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The app has no accounts of the workspace's: there is nothing to add, and nothing to remove.
function add_flutter_users() {
  echo "The Flutter app has no accounts of the workspace's, so there are none to add." ;
}

function cancel_flutter_users() {
  echo "The Flutter app has no accounts of the workspace's, so there are none to remove." ;
}

# The step pack in the testing stack of an app of this builder. The core's testing_configure calls this in the project
# folder once webship-js is scaffolded and before the dependencies are installed; for a project that is not an app of
# this builder it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own, and, for the
# counter of `flutter create`, writes a first feature when the project has none of its own. There is no users
# registry: the app has no accounts. Every part is skipped when it is already there, so a second run adds what the
# first missed and never resets a suite. The suite is the project's (its package.json, cucumber.js and tests/ are next
# to app/, not in it).
function testing_configure_flutter() {
  local project_path="$1";
  flutter_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Flutter: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Flutter step pack (${FLUTTER_STEPS_PACKAGE} ${FLUTTER_STEPS_VERSION}).";

  python3 - "${project_path}" "${FLUTTER_STEPS_PACKAGE}" "${FLUTTER_STEPS_VERSION}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version = sys.argv[1:4]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=2) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, for the counter of `flutter create` only (an app of your own has its own names), when the project
  # has none for the app yet.
  local feature="${WORKSPACE_SCRIPTS}/plugins/flutter/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    if grep -qs 'You have pushed the button this many times' "${project_path}/${FLUTTER_APP}/lib/main.dart" ; then
      mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
        && echo "  tests/features/site.feature: a first feature for the counter" ;
    else
      echo "  Flutter: the app is not the counter of flutter create, so no first feature is written: write one from what its accessibility tree shows." ;
    fi
  fi
}
