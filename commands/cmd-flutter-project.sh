#!/usr/bin/env bash

# workspace-name: Flutter (web app)

# Installed by the Flutter plugin (plugins.sh --install flutter); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Flutter web app in a container of its own and serve the built app: the Flutter SDK, pinned, goes into the
# project's web image, the app (the counter of `flutter create`, or a repository of your own with --source) is built
# there with `flutter build web`, and the built app is served from there. With --install the app is served and
# checked. It has no database, and no accounts of the workspace's. The workspace is container-based (DDEV by
# default, at https://<name>.ddev.site); --runtime docker builds it on Docker Compose instead, at the address that
# runtime gives.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Where the app comes from: nothing means a new app of `flutter create`.
app_source="";
app_source_ref="";
app_source_path="";

# Distribution.
distribution_name="flutter";
distribution_title="Flutter";
distribution_webroot="app/build/web";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/flutter/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/flutter/args/arg-flutter.sh || exit 1 ;

shift $#;

flutter_build ;
