/**
 * Flutter for Webship Workspace: a plugin for Flutter web apps.
 *
 * What the package carries is placed by the installer from the manifest: the builder in the sites
 * folders, its functions, argparse and machine files (the app's web server, a first feature) under
 * core/scripts/plugins/flutter/, its AI items (ai/) in the AI folders. The builder builds a Flutter
 * web app in a container of its own: the Flutter SDK, pinned, goes into the project's web image, the
 * app (a new one of `flutter create`, or one cloned with --source) is built there with
 * `flutter build web`, and the built app is served from there. The step pack
 * (@webship-js/flutter-steps) goes into the testing setup of such an app with the core's
 * `cmd-tools-testing.sh <project>`. The dashboard needs nothing drawn for it: the builder is in the
 * Build list because it is a cmd-*-project.sh, the row menus are the core's, the AI items are listed
 * like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name, which its functions are named after. */
export const PLATFORM = 'flutter';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-flutter-project.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['flutter-app-builder', 'flutter-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['flutter-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['flutter-test'];

/** The prompts the installer places in the AI Prompts folder: whole launch commands for a new session. */
export const PROMPTS = ['flutter-build-and-test', 'flutter-scenarios-for-an-app'];

/** What the assistant is told about Flutter in this workspace. */
export function assistantContext(): string {
  return [
    'Flutter (a plugin, @webship.co/workspace-flutter): its builder builds a Flutter web app in a container of its own and serves',
    'the built app, with `bash cmd-flutter-project.sh <name> --install` from a sites folder (dev, test, sandboxes, demos): the',
    'Flutter SDK (3.50.1, pinned) goes into the project\'s web image, the app is the counter of `flutter create` (or a repository',
    'of your own with --source, --ref and --path), built with `flutter build web` in the container (--wasm for WebAssembly) and',
    'served at https://<name>.ddev.site. The app\'s source is in <name>/app/. There is no database, and the app has no accounts.',
    '`--runtime docker`, `podman` or `kubernetes` builds it on Docker Compose, Podman or a Kubernetes cluster instead of DDEV,',
    'at the address that runtime gives (the build prints it).',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the step pack @webship-js/flutter-steps on such an app: its',
    'steps read the accessibility tree Flutter builds for screen readers (they turn it on as assistive technology does), so a',
    'widget the app leaves out of that tree is out of their reach, and they say so as an accessibility finding about the app.',
    `For building or fixing a Flutter web app (its widgets' names and identifiers, its build), hand over to the agent \`${AGENTS[0]}\`; for testing one, to \`${AGENTS[1]}\`.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <app>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run flutter, dart, node, npm or npx on the host for a project.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
