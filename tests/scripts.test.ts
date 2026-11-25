import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawn, spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-flutter.sh');
const SERVER = path.join(PKG, 'scripts', 'flutter-serve.py');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/** A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. */
function project(kind: 'counter' | 'own' | 'drupal') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'flutter-plugin-'));
  const dir = path.join(root, 'dev', 'app1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: app1\ntype: ${kind === 'drupal' ? 'drupal11' : 'generic'}\n`);
  if (kind !== 'drupal') {
    fs.writeFileSync(path.join(dir, '.ddev', 'config.flutter.yaml'), '# A Flutter web app in this project.\n');
    fs.mkdirSync(path.join(dir, 'app', 'lib'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'app', 'lib', 'main.dart'), kind === 'counter'
      ? "Text('You have pushed the button this many times:'),\n" : "Text('Sign in'),\n");
  }
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'app1', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'flutter'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'flutter', 'site.feature'));
  return { root, dir, scripts };
}

/** Run bash with the plugin's functions sourced and `ddev` replaced by a recorder. */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = 'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; return 0 ; }';
  return spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

test('the app has no accounts of the workspace: the list is empty, and adding or removing them says so', () => {
  let r = bash('set_flutter_users ; echo "${#users[@]}"');
  assert.strictEqual(r.status, 0, r.stderr);
  assert.strictEqual(r.stdout.trim(), '0');
  r = bash('add_flutter_users ; cancel_flutter_users');
  assert.strictEqual(r.status, 0, r.stderr);
  assert.match(r.stdout, /no accounts of the workspace's, so there are none to add/);
  assert.match(r.stdout, /no accounts of the workspace's, so there are none to remove/);
});

const hook = (p: { dir: string; root: string; scripts: string }) =>
  bash(`cd ${p.dir} && testing_configure_flutter ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1' });

test('the testing hook adds the step pack and, for the counter, a first feature, once', () => {
  const p = project('counter');
  const r = hook(p);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/flutter-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.16', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/flutter-steps/tests/step-definitions/*.js',", 'the pack is listed right after webship-js');
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require.length, c.paths]))`], { encoding: 'utf8' });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  assert.deepStrictEqual(JSON.parse(loaded.stdout), [3, ['tests/features/**/*.feature']]);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), read('testing/site.feature'));
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  const again = hook(p);
  assert.strictEqual(again.status, 0);
  assert.doesNotMatch(again.stdout, /package\.json:|cucumber\.js:|tests\/features\/site\.feature:/, 'a second run adds nothing');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('an app of your own gets the step pack, and no first feature: it has its own names', () => {
  const p = project('own');
  const r = hook(p);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), /@webship-js\/flutter-steps\/tests\/step-definitions/);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(r.stdout, /the app is not the counter of flutter create, so no first feature is written/);
});

test('the testing hook waits for the testing stack: without cucumber.js it says to run the setup again', () => {
  const p = project('counter');
  fs.rmSync(path.join(p.dir, 'cucumber.js'));
  const r = hook(p);
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /cucumber\.js is not here yet/);
});

test('the testing hook leaves any other project alone', () => {
  const p = project('drupal');
  const r = hook(p);
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('a new app takes a Dart package name made from the project\'s name', () => {
  const names: Record<string, string> = { 'ci-flutter': 'ci_flutter', flapp: 'flapp', '9lives': 'app_9lives', test: 'app_test', class: 'app_class', flutter: 'app_flutter' };
  for (const [project, wanted] of Object.entries(names)) {
    const r = bash(`flutter_package_name ${project}`);
    assert.strictEqual(r.stdout.trim(), wanted, project);
  }
});

test('the SDK goes into the web image pinned: the release, the checksum of its archive, the web artifacts only', () => {
  const r = bash('flutter_sdk_dockerfile');
  assert.strictEqual(r.status, 0, r.stderr);
  const lines = r.stdout;
  assert.match(lines, /flutter_infra_release\/releases\/stable\/linux\/flutter_linux_3\.50\.1-stable\.tar\.xz/);
  assert.match(lines, /echo "[0-9a-f]{64}  \/tmp\/flutter\.tar\.xz" \| sha256sum -c -/);
  assert.match(lines, /\[ "\$\(uname -m\)" = x86_64 \]/, 'the archive is for x86-64 Linux, and the build says so on another machine');
  assert.match(lines, /flutter precache --web --no-android --no-ios --no-linux --no-windows --no-macos --no-fuchsia/);
  assert.match(lines, /chmod -R a\+rwX \/opt\/flutter/, 'the host user who builds the app can use the SDK');
  assert.match(lines, /python3:python3/, 'the app\'s server runs on Python');
  assert.match(lines, /command -v "\$\{p%%:\*\}" > \/dev\/null \|\| pkgs=/, 'only the tools the image lacks are installed');
  assert.match(lines, /\{ apt-get update \|\| true ; \}/, 'a package list of the base image that cannot be refreshed does not stop the build');
  assert.match(lines, /for c in curl git unzip xz python3 ; do command -v "\$\{c\}" > \/dev\/null \|\| \{ echo "The web image has no \$\{c\} after its packages were installed/, 'but a tool still missing after it stops the build, by its name');
  assert.ok(lines.indexOf('for c in curl git unzip xz python3') < lines.indexOf('curl -fsSL'), 'before anything is downloaded');
  assert.ok(lines.indexOf('ENV PUB_CACHE=/var/www/html/.pub-cache') > lines.indexOf('flutter precache'), 'the app\'s packages go to the project once the SDK is set up');
  assert.match(lines, /ENV PATH="\/opt\/flutter\/bin:\$\{PATH\}"/);
});

test('on DDEV the router sends the address to the app\'s server, a daemon that waits for the build', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'flutter-ddev-'));
  for (const wasm of ['', 'yes']) {
    const r = bash(`flutter_write_ddev_config ${root} https://example.com/app.git main form_app '${wasm}'`);
    assert.strictEqual(r.status, 0, r.stderr);
    const yaml = fs.readFileSync(path.join(root, '.ddev', 'config.flutter.yaml'), 'utf8');
    assert.match(yaml, /web_extra_exposed_ports:\n  - name: flutter\n    container_port: 8080\n    http_port: 80\n    https_port: 443/);
    assert.match(yaml, /command: "bash -c 'while \[ ! -f \/var\/www\/html\/app\/build\/web\/index\.html \]; do sleep 2; done; exec python3 \/var\/www\/html\/flutter\/flutter-serve\.py \/var\/www\/html\/app\/build\/web 8080( --isolated)?'"/);
    assert.doesNotMatch(yaml.split('command: ')[1].split('\n')[0], / ;/, 'no " ;", which starts a comment in the supervisor configuration DDEV writes from it');
    assert.strictEqual(/--isolated/.test(yaml), wasm === 'yes', 'the isolation headers for a WebAssembly build only');
    assert.match(yaml, /^# source: https:\/\/example\.com\/app\.git \(main\), form_app\//m);
    assert.match(yaml, /- PUB_CACHE=\/var\/www\/html\/\.pub-cache/);
    assert.strictEqual(fs.readFileSync(path.join(root, '.ddev', 'web-build', 'Dockerfile.flutter'), 'utf8'), bash('flutter_sdk_dockerfile').stdout);
  }
});

/** A build of app1 in a fresh workspace folder, with `ddev` and the core's helpers recorded; `layer` stands for the
 * core's runtime layer (fun-runtime.sh), as far as the builder asks it. The recorder makes the files the commands in
 * the container would: the new app, the cloned one (with a web platform unless NOWEB), the build. */
function build(opts: { layer?: string; env?: Record<string, string> } = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'flutter-build-'));
  fs.mkdirSync(path.join(root, 'dev'), { recursive: true });
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'flutter'), { recursive: true });
  fs.copyFileSync(SERVER, path.join(scripts, 'plugins', 'flutter', 'flutter-serve.py'));
  const log = path.join(root, 'ddev.log');
  const app = path.join(root, 'dev', 'app1', 'app');
  const script = [
    'trim_project_name() { :; } ; drop_database() { :; } ; ddev_up() { ddev "$@" ; } ; ddev_nodejs_version() { echo 24 ; }',
    `ddev() { echo "ddev $*" >> ${log} ; case "$*" in`,
    `  *"flutter create --platforms web --project-name"*) mkdir -p ${app}/lib ${app}/web && echo "You have pushed the button this many times" > ${app}/lib/main.dart && touch ${app}/web/index.html ;;`,
    `  *"cp -a '/tmp/flutter-source/analysis_defaults/."*) mkdir -p ${root}/dev/app1/analysis_defaults && printf 'name: analysis_defaults\\nresolution: workspace\\n' > ${root}/dev/app1/analysis_defaults/pubspec.yaml ;;`,
    `  *"cp -a"*) mkdir -p ${app} && printf 'name: form_app\\nresolution: workspace\\nenvironment:\\n%s' "$DEPS" > ${app}/pubspec.yaml && { [ -n "$NOWEB" ] || { mkdir -p ${app}/web && touch ${app}/web/index.html ; } ; } ;;`,
    `  *"flutter build web"*) mkdir -p ${app}/build/web && touch ${app}/build/web/index.html ;;`,
    'esac ; return 0 ; }',
    opts.layer || '',
    'PROJECT_NAME=app1',
    'flutter_build',
  ].join('\n');
  const r = spawnSync('bash', ['-c', `source ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, WORKSPACE_ROOT: root, WORKSPACE_SCRIPTS: scripts, doc_name: 'dev', INSTALL: 'yes', ...(opts.env || {}) } });
  const calls = fs.existsSync(log) ? fs.readFileSync(log, 'utf8') : '';
  return { r, calls, root, log, project: path.join(root, 'dev', 'app1') };
}

test('a new app: the SDK in the web image, the counter of flutter create, built for the web and served', () => {
  const b = build();
  assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
  assert.match(b.calls, /^ddev config --project-type=generic --webserver-type=generic --docroot= --project-name=app1 --omit-containers=db --nodejs-version=24$/m);
  assert.ok(fs.existsSync(path.join(b.project, '.ddev', 'config.flutter.yaml')), 'DDEV\'s own file marks the project');
  assert.ok(fs.existsSync(path.join(b.project, '.ddev', 'web-build', 'Dockerfile.flutter')), 'the web image gets the SDK');
  assert.strictEqual(fs.readFileSync(path.join(b.project, 'flutter', 'flutter-serve.py'), 'utf8'), fs.readFileSync(SERVER, 'utf8'), 'the server is in the project');
  assert.match(b.calls, /^ddev start -y$/m);
  assert.match(b.calls, /^ddev exec -d \/var\/www\/html flutter create --platforms web --project-name app1 app$/m);
  assert.match(b.calls, /^ddev exec -d \/var\/www\/html\/app flutter pub get && flutter build web --release --base-href \/$/m);
  assert.ok(b.calls.indexOf('ddev start') < b.calls.indexOf('flutter create'), 'the app is made in the container, once it runs');
  assert.match(b.calls, /curl -fsS -o \/dev\/null http:\/\/127\.0\.0\.1:8080\/index\.html/, '--install waits for the app\'s server');
  assert.match(b.r.stdout, /^Go to https:\/\/app1\.ddev\.site$/m);
  assert.doesNotMatch(b.calls, /^ddev stop/m, 'with --install the app stays served');
  assert.strictEqual(fs.readFileSync(path.join(b.project, '.gitignore'), 'utf8'), '.pub-cache/\n');
});

test('without --install the app is built and the project stopped; with --wasm it is built for WebAssembly', () => {
  const b = build({ env: { INSTALL: '', WASM: 'yes' } });
  assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
  assert.match(b.calls, /flutter build web --release --wasm --base-href \//);
  assert.match(fs.readFileSync(path.join(b.project, '.ddev', 'config.flutter.yaml'), 'utf8'), /8080 --isolated'"/);
  assert.match(b.calls, /^ddev stop$/m, 'ddev stop takes no -y');
  assert.match(b.r.stdout, /dev app1 is ready: the Flutter app in app\/, built for the web \(WebAssembly\)\./);
});

test('an app from a repository: the folder of the app is copied out, built on its own, and given the web platform when it has none', () => {
  const DEPS = 'dev_dependencies:\n  analysis_defaults:\n    path: ../analysis_defaults\n';
  let b = build({ env: { SOURCE: 'https://example.com/samples.git', REF: 'main', APP_PATH: 'form_app', DEPS } });
  assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
  assert.match(b.calls, /git clone --quiet --depth 1 --branch 'main' 'https:\/\/example\.com\/samples\.git' \/tmp\/flutter-source/);
  assert.match(b.calls, /test -f '\/tmp\/flutter-source\/form_app\/pubspec\.yaml' && mkdir -p \/var\/www\/html\/app && cp -a '\/tmp\/flutter-source\/form_app\/\.' \/var\/www\/html\/app\//);
  assert.doesNotMatch(b.calls, /flutter create --platforms web --project-name/, 'no new app is made');
  assert.strictEqual(fs.readFileSync(path.join(b.project, 'app', 'pubspec.yaml'), 'utf8'), `name: form_app\nenvironment:\n${DEPS}`, 'a package of a pub workspace is built on its own');
  // The package it takes from the folder next to it comes along, to the same place next to app/.
  assert.match(b.calls, /test -f '\/tmp\/flutter-source\/analysis_defaults\/pubspec\.yaml' && mkdir -p '\/var\/www\/html\/analysis_defaults' && cp -a '\/tmp\/flutter-source\/analysis_defaults\/\.' '\/var\/www\/html\/analysis_defaults\/'/);
  assert.strictEqual(fs.readFileSync(path.join(b.project, 'analysis_defaults', 'pubspec.yaml'), 'utf8'), 'name: analysis_defaults\n');
  assert.match(b.r.stdout, /The app takes \.\.\/analysis_defaults from its repository: copying it next to app\/\./);
  assert.ok(b.calls.indexOf('analysis_defaults/.') < b.calls.indexOf('ddev exec rm -rf /tmp/flutter-source\n'), 'before the clone goes');
  assert.doesNotMatch(b.calls, /flutter create --platforms web \./, 'an app with a web platform keeps it as it is');
  b = build({ env: { SOURCE: 'https://example.com/app.git', NOWEB: 'yes' } });
  assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
  assert.match(b.calls, /^ddev exec -d \/var\/www\/html\/app flutter create --platforms web \.$/m);
  assert.match(b.r.stdout, /The app has no web platform yet: adding it/);
});

test('a package the app takes from further away, or onto the project\'s own folders, stops the build with a message', () => {
  for (const [dep, message] of [
    ['../../shared', /takes \.\.\/\.\.\/shared from outside the folder next to it/],
    ['../flutter', /would land on the project's own flutter\//],
    ['../app', /would land on the project's own app\//],
  ] as Array<[string, RegExp]>) {
    const b = build({ env: { SOURCE: 'https://example.com/samples.git', APP_PATH: 'form_app', DEPS: `dependencies:\n  shared:\n    path: ${dep}\n` } });
    assert.strictEqual(b.r.status, 1, dep);
    assert.match(b.r.stdout, message);
    assert.doesNotMatch(b.calls, /flutter build web/, 'nothing is built');
  }
  // An app at the root of its repository has no folder next to it in the repository.
  const b = build({ env: { SOURCE: 'https://example.com/app.git', DEPS: 'dependencies:\n  shared:\n    path: ../shared\n' } });
  assert.strictEqual(b.r.status, 1);
  assert.match(b.r.stdout, /The app takes \.\.\/shared, outside its repository\./);
});

test('--path without --source, a path out of the repository, or a bad project name stop the build before anything is made', () => {
  for (const [env, message] of [
    [{ APP_PATH: 'form_app' }, /--path names a folder of the repository given with --source: give --source too\./],
    [{ SOURCE: 'https://example.com/app.git', APP_PATH: '../etc' }, /take a repository, a branch or tag, and a folder inside the repository/],
    [{ SOURCE: "https://example.com/app.git'; rm -rf /" }, /take a repository, a branch or tag, and a folder inside the repository/],
  ] as Array<[Record<string, string>, RegExp]>) {
    const b = build({ env });
    assert.strictEqual(b.r.status, 1, JSON.stringify(env));
    assert.match(b.r.stdout, message);
    assert.strictEqual(b.calls, '', 'no ddev command ran');
    assert.ok(!fs.existsSync(b.project), 'no project folder was made');
  }
});

/** The core's runtime layer, as far as the builder asks it: the runtime, the address, the claim, the stack. */
const layer = (rt: string, url: string) => [
  `runtime_of() { echo ${rt} ; }`,
  `rt_url() { echo ${url} ; }`,
  'rt_claim() { echo "rt_claim $*" >> "$WORKSPACE_ROOT/ddev.log" ; }',
  'rt_stack() { echo "rt_stack $*" >> "$WORKSPACE_ROOT/ddev.log" ; }',
  'rt_web_build() { echo "rt_web_build $*" >> "$WORKSPACE_ROOT/ddev.log" ; cat > "$WORKSPACE_ROOT/web-build.txt" ; }',
  'rt_serve() { echo "rt_serve $1" >> "$WORKSPACE_ROOT/ddev.log" ; printf "%s\\n" "$2" > "$WORKSPACE_ROOT/serve.txt" ; }',
].join(' ; ');

test('on DDEV the build runs the same commands with the runtime layer as without it', () => {
  const without = build();
  const withLayer = build({ layer: layer('ddev', 'https://app1.ddev.site') });
  for (const b of [without, withLayer]) {
    assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
    assert.doesNotMatch(b.calls, /rt_claim|rt_stack|rt_serve/, 'the language stack is for the other runtimes');
  }
  assert.strictEqual(withLayer.calls, without.calls, 'the same ddev commands, to the letter');
});

for (const [rt, url] of [['docker', 'http://127.0.0.1:43210'], ['podman', 'http://127.0.0.1:43211'], ['kubernetes', 'http://172.18.0.2:30080']]) {
  test(`on ${rt}: the claim, Debian pinned by its digest, the same SDK on top, the app's server; never a ddev.site`, () => {
    const b = build({ layer: layer(rt, url), env: { RUNTIME: rt } });
    assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
    assert.match(b.calls, /^ddev config --project-type=generic --webserver-type=generic --docroot= --project-name=app1 --omit-containers=db --auto$/m);
    assert.match(b.calls, /^rt_claim flutter$/m);
    assert.match(b.calls, /^rt_stack image debian:bookworm-slim@sha256:[0-9a-f]{64}$/m);
    assert.match(b.calls, /^rt_web_build flutter$/m);
    assert.match(b.calls, /^rt_serve 8080$/m);
    assert.strictEqual(fs.readFileSync(path.join(b.root, 'web-build.txt'), 'utf8'), bash('flutter_sdk_dockerfile').stdout, 'the SDK lines are DDEV\'s');
    assert.match(fs.readFileSync(path.join(b.root, 'serve.txt'), 'utf8'), /exec python3 \/var\/www\/html\/flutter\/flutter-serve\.py \/var\/www\/html\/app\/build\/web 8080$/m);
    assert.ok(!fs.existsSync(path.join(b.project, '.ddev')), 'no .ddev folder: it would make the project a DDEV one');
    assert.ok(b.calls.indexOf('ddev config') < b.calls.indexOf('rt_claim flutter'), 'the claim comes after the runtime\'s files are written');
    assert.match(b.r.stdout, new RegExp(`^Go to ${url.replace(/[.:/]/g, '\\$&')}$`, 'm'));
    assert.doesNotMatch(b.r.stdout, /ddev\.site/, 'no message names a DDEV address');
  });
}

test('--runtime on a core without the runtime layer is refused, and nothing is started', () => {
  const b = build({ env: { RUNTIME: 'docker' } });
  assert.strictEqual(b.r.status, 1);
  assert.match(b.r.stdout, /--runtime docker needs a Webship Workspace with the container runtimes \(webship\/workspace#694\)/);
  assert.strictEqual(b.calls, '', 'no ddev command ran');
  assert.ok(!fs.existsSync(b.project), 'no project folder was made');
});

for (const rt of ['lando', 'docksal']) {
  test(`a runtime this builder is not proven on (${rt}, the workspace's setting) stops the build before anything is made`, () => {
    const b = build({ layer: layer(rt, 'http://127.0.0.1:43212') });
    assert.strictEqual(b.r.status, 1);
    assert.match(b.r.stdout, new RegExp(`builds on DDEV, Docker Compose, Podman and Kubernetes for now \\(--runtime ddev, docker, podman or kubernetes\\), not on ${rt}`));
    assert.strictEqual(b.calls, '', 'no ddev command ran');
    assert.ok(!fs.existsSync(b.project), 'no project folder was made');
  });
}

test('a project of the builder is known by DDEV\'s file, else by the core\'s rt_is_platform', () => {
  let r = bash('rt_is_platform() { echo "asked $*" ; return 0 ; } ; flutter_is_project /x/app1');
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout.trim(), 'asked /x/app1 flutter');
  r = bash('rt_is_platform() { return 1 ; } ; flutter_is_project /x/app1');
  assert.strictEqual(r.status, 1);
  const p = project('counter');
  assert.strictEqual(bash(`flutter_is_project ${p.dir}`).status, 0, 'without the layer, .ddev/config.flutter.yaml says so');
  fs.rmSync(path.join(p.dir, '.ddev', 'config.flutter.yaml'));
  assert.strictEqual(bash(`flutter_is_project ${p.dir}`).status, 1);
});

test('the builder takes the runtimes it is proven on, and never a flag that would take the name PATH', () => {
  const args = read('scripts/args/arg-flutter.sh');
  assert.match(args, /choices=\['ddev', 'docker', 'podman', 'kubernetes'\]/);
  assert.match(args, /dest='RUNTIME',\n\s+default="_none_"/);
  assert.match(args, /'--path',\n\s+dest='APP_PATH',/, '--path would otherwise set PATH');
  assert.match(read('scripts/functions/fun-flutter.sh'), /^readonly FLUTTER_RUNTIMES='ddev docker podman kubernetes';$/m);
});

/** The plugin's server on a free port, serving a folder; stopped by the caller. */
async function serve(folder: string, isolated: boolean) {
  const port = 20000 + Math.floor(Math.random() * 20000);
  const child = spawn('python3', ['-I', SERVER, folder, String(port), ...(isolated ? ['--isolated'] : [])], { stdio: ['ignore', 'pipe', 'pipe'] });
  for (let i = 0; i < 50; i += 1) {
    try { await fetch(`http://127.0.0.1:${port}/`); break; } catch (e) { await new Promise((r) => setTimeout(r, 100)); }
  }
  return { port, stop: () => child.kill() };
}

test('the app\'s server serves the build, its index for any route, WebAssembly with its type, and isolates only when asked', async () => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'flutter-serve-'));
  fs.writeFileSync(path.join(folder, 'index.html'), '<!doctype html><title>app1</title>');
  fs.writeFileSync(path.join(folder, 'main.dart.wasm'), Buffer.from([0, 97, 115, 109]));
  fs.writeFileSync(path.join(folder, 'main.dart.mjs'), 'export {};');
  for (const isolated of [false, true]) {
    const s = await serve(folder, isolated);
    try {
      let res = await fetch(`http://127.0.0.1:${s.port}/`);
      assert.strictEqual(res.status, 200);
      assert.match(await res.text(), /<title>app1<\/title>/);
      assert.strictEqual(res.headers.get('cross-origin-opener-policy'), isolated ? 'same-origin' : null);
      assert.strictEqual(res.headers.get('cross-origin-embedder-policy'), isolated ? 'require-corp' : null);
      res = await fetch(`http://127.0.0.1:${s.port}/favorites_page`);
      assert.strictEqual(res.status, 200, 'a route of an app with path addresses opens the app');
      assert.match(await res.text(), /<title>app1<\/title>/);
      res = await fetch(`http://127.0.0.1:${s.port}/main.dart.wasm`);
      assert.strictEqual(res.headers.get('content-type'), 'application/wasm');
      res = await fetch(`http://127.0.0.1:${s.port}/main.dart.mjs`);
      assert.strictEqual(res.headers.get('content-type'), 'text/javascript');
    } finally {
      s.stop();
    }
  }
});

test('the first feature names no framework or platform in the words of a step', () => {
  const feature = read('testing/site.feature');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s.replace(/"[^"]*"/g, '""'), /flutter|dart|drupal|wordpress|joomla/i, s);
});
