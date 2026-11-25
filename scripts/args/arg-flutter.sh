#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, and its project on the container runtime.')
parser.add_argument('--runtime',
                    dest='RUNTIME',
                    default="_none_",
                    choices=['ddev', 'docker', 'podman', 'kubernetes'],
                    help='The container runtime to build on: ddev (the default, or container.runtime of settings.yml), docker (Docker Compose), podman or kubernetes.')
parser.add_argument('-s', '--source',
                    default="${app_source}",
                    help='A git repository of a Flutter app to build; empty means a new app, the counter of flutter create. [default %(default)s]')
parser.add_argument('-r', '--ref',
                    default="${app_source_ref}",
                    help='A branch or a tag of that repository; empty means its default branch. Example: --ref main [default %(default)s]')
parser.add_argument('-p', '--path',
                    dest='APP_PATH',
                    default="${app_source_path}",
                    help='The folder of the app in that repository, for a repository of several apps; empty means its root. Example: --path form_app [default %(default)s]')
parser.add_argument('-w', '--wasm',
                    action='store_true',
                    default=False,
                    help='Build the app for WebAssembly (flutter build web --wasm), served with the cross-origin isolation headers it needs to run on several threads.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Serve the built app and check that it answers at its address (https://<name>.ddev.site on DDEV, a port of this machine on Docker Compose and Podman, a port of the node on Kubernetes).')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Taken so that every builder accepts the same flags: the app has no accounts of the workspace, and nothing is added.')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the app in a browser when it is ready.')
ARGEOF
