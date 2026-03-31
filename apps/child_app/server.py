from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


def normalize_base_path(base_path: str) -> str:
    if not base_path or base_path == '/':
        return '/'

    return f"/{base_path.strip('/')}/"


class SpaRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, base_path: str = '/', **kwargs):
        self._base_path = normalize_base_path(base_path)
        super().__init__(*args, **kwargs)

    def _normalized_request_path(self, path: str) -> str:
        parsed = urlsplit(path)
        request_path = parsed.path or '/'

        if self._base_path != '/':
            prefix_without_trailing_slash = self._base_path.rstrip('/')

            if request_path in {prefix_without_trailing_slash, self._base_path}:
                request_path = '/'
            elif request_path.startswith(self._base_path):
                request_path = f"/{request_path[len(self._base_path):].lstrip('/')}"

        if not request_path:
            request_path = '/'

        if parsed.query:
            return f'{request_path}?{parsed.query}'

        return request_path

    def translate_path(self, path: str) -> str:
        return super().translate_path(self._normalized_request_path(path))

    def _is_health_request(self) -> bool:
        return urlsplit(self._normalized_request_path(self.path)).path == '/health'

    def _respond_health(self, head_only: bool) -> None:
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Content-Length', '2')
        self.end_headers()
        if not head_only:
            self.wfile.write(b'ok')

    def do_GET(self) -> None:
        if self._is_health_request():
            self._respond_health(head_only=False)
            return

        super().do_GET()

    def do_HEAD(self) -> None:
        if self._is_health_request():
            self._respond_health(head_only=True)
            return

        super().do_HEAD()

    def send_head(self):
        normalized_path = self._normalized_request_path(self.path)
        requested_path = Path(self.translate_path(normalized_path))
        if requested_path.exists():
            return super().send_head()

        route_name = Path(urlsplit(normalized_path).path).name
        if '.' not in route_name:
            original_path = self.path
            self.path = '/index.html'
            try:
                return super().send_head()
            finally:
                self.path = original_path

        self.send_error(404, 'File not found')
        return None


def main() -> None:
    parser = argparse.ArgumentParser(description='Serve the compiled VANAVIL child web app.')
    parser.add_argument('--directory', default='/app/public')
    parser.add_argument('--port', type=int, default=80)
    parser.add_argument('--base-path', default='/')
    args = parser.parse_args()

    handler = partial(
        SpaRequestHandler,
        directory=args.directory,
        base_path=args.base_path,
    )
    server = ThreadingHTTPServer(('0.0.0.0', args.port), handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()