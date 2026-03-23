from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class SpaRequestHandler(SimpleHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path.split('?', 1)[0] == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Content-Length', '2')
            self.end_headers()
            self.wfile.write(b'ok')
            return

        super().do_GET()

    def send_head(self):
        requested_path = Path(self.translate_path(self.path))
        if requested_path.exists():
            return super().send_head()

        route_name = Path(self.path.split('?', 1)[0]).name
        if '.' not in route_name:
            self.path = '/index.html'
            return super().send_head()

        self.send_error(404, 'File not found')
        return None


def main() -> None:
    parser = argparse.ArgumentParser(description='Serve the compiled VANAVIL admin web app.')
    parser.add_argument('--directory', default='/app/public')
    parser.add_argument('--port', type=int, default=80)
    args = parser.parse_args()

    handler = partial(SpaRequestHandler, directory=args.directory)
    server = ThreadingHTTPServer(('0.0.0.0', args.port), handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()