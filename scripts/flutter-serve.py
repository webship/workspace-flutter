#!/usr/bin/env python3
# The web server of a Flutter app of the Webship Workspace's Flutter builder: it serves the built app (build/web) on
# 0.0.0.0:<port> in the project's web container. A path that is not a file of the build gets the app's index.html, so
# an app with path addresses opens at any of its routes; .wasm and .mjs files get their types; with --isolated it sends
# the cross-origin isolation headers a WebAssembly build needs to run on several threads. Python's standard library
# only. Copied into the project (flutter/) by the builder.
#   python3 flutter-serve.py <folder> <port> [--isolated]
import functools
import http.server
import os
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.js': 'text/javascript',
        '.mjs': 'text/javascript',
        '.wasm': 'application/wasm',
        '.json': 'application/json',
    }
    isolated = False

    def end_headers(self):
        if self.isolated:
            self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
            self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        # A build replaces the files under the same names: the browser asks again rather than keep an old one.
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

    def send_head(self):
        if not os.path.exists(self.translate_path(self.path)):
            self.path = '/index.html'
        return super().send_head()

    def log_message(self, format, *args):
        pass


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 2 or not args[1].isdigit():
        sys.exit('python3 flutter-serve.py <folder> <port> [--isolated]')
    folder, port = os.path.abspath(args[0]), int(args[1])
    Handler.isolated = '--isolated' in sys.argv[1:]
    server = http.server.ThreadingHTTPServer(('0.0.0.0', port), functools.partial(Handler, directory=folder))
    print('Serving %s on port %d%s' % (folder, port, ' (cross-origin isolated)' if Handler.isolated else ''), flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
